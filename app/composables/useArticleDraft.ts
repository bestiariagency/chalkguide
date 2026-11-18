import type { Database } from '~/types/database.types'
import { discardArticleDraft, publishArticleDraft, saveArticleDraft } from '~/services/admin/article-drafts'
import { articleErrorMessage } from '~/utils/admin-articles'
import { describeChanges, revertGroup } from '~/utils/article-changes'
import type { ArticleErrors, ArticleForm } from '~/utils/article-form'
import { buildDraftArticle, changedGroups, formSignature } from '~/utils/article-patch'
import type { SaveState } from '~/composables/useArticleAutosave'

const DEBOUNCE_MS = 1200
const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T
const codeOf = (e: unknown) => (e as { code?: string } | null)?.code

/**
 * Draft of changes of a LIVE article (D23). The form shows the published version with the stored
 * draft laid over it; the autosave writes only through `save_draft` (never to `articles`), sending
 * every white-listed column that differs from the published version. Publishing and discarding go
 * through `publish_draft` / `discard_draft`. A `PT409` means the published version changed while
 * editing (`conflict`): publishing can then be forced, or the editor reloaded.
 */
export function useArticleDraft(options: { id: string; form: Ref<ArticleForm | null>; errors: Ref<ArticleErrors>; enabled: Ref<boolean>; onError?: (error: unknown) => void; nameOf?: (mediaId: string) => string | undefined; onAltRefused?: () => void }) {
  const client = useSupabaseClient<Database>()
  const { clean, whenReady } = useAdminSanitize()

  const published = shallowRef<ArticleForm | null>(null)
  /** Published version the stored draft starts from (`base_updated_at`); sent with every save. */
  const base = ref('')
  /** Current published version (`updated_at`), for starting a new draft after discarding. */
  const version = ref('')
  const stored = ref<Record<string, unknown>>({})
  const storedAt = ref<string | null>(null)
  const conflict = ref(false)
  /** Bumped when the form is replaced from outside the editors (revert, discard) so they remount. */
  const revision = ref(0)

  const state = ref<SaveState>('idle')
  const savedAt = ref<number | null>(null)
  const errorMessage = ref('')
  let lastSignature = ''
  let lastPayload = '{}'
  let timer: ReturnType<typeof setTimeout> | undefined
  let again = false
  let running: Promise<void> | null = null

  const publishedSignature = computed(() => (published.value ? formSignature(published.value) : {}))
  const changed = computed(() => (options.form.value && published.value ? changedGroups(options.form.value, publishedSignature.value) : []))

  /** Starts from the published form, the version it has, and the stored draft's article section (if any). */
  function init(publishedForm: ArticleForm, publishedVersion: string, draft: { article: Record<string, unknown>; baseUpdatedAt: string; updatedAt: string } | null) {
    published.value = plain(publishedForm)
    version.value = publishedVersion
    base.value = draft?.baseUpdatedAt ?? publishedVersion
    stored.value = draft?.article ?? {}
    storedAt.value = draft?.updatedAt ?? null
    lastPayload = JSON.stringify(stored.value)
    conflict.value = false
    state.value = 'idle'
    syncSignature()
  }
  function syncSignature() {
    lastSignature = options.form.value ? JSON.stringify(formSignature(options.form.value)) : ''
  }

  async function run() {
    await whenReady()
    const form = options.form.value
    if (!form || !published.value || !options.enabled.value) return
    const signature = JSON.stringify(formSignature(form))
    const plan = buildDraftArticle(form, publishedSignature.value, options.errors.value, clean, stored.value)
    const payload = JSON.stringify(plan.article)
    if (payload === lastPayload) {
      lastSignature = signature
      state.value = plan.blocked.length ? 'blocked' : state.value === 'saved' ? 'saved' : 'idle'
      return
    }
    state.value = 'saving'
    try {
      if (Object.keys(plan.article).length) {
        const saved = await saveArticleDraft(client, options.id, plan.article, base.value)
        base.value = saved.baseUpdatedAt
        storedAt.value = saved.updatedAt
      } else {
        await discardArticleDraft(client, options.id)
        storedAt.value = null
      }
      stored.value = plan.article
      lastPayload = payload
      lastSignature = signature
      savedAt.value = Date.now()
      errorMessage.value = ''
      state.value = plan.blocked.length ? 'blocked' : 'saved'
    } catch (e) {
      if (codeOf(e) === 'PT409') conflict.value = true
      options.onError?.(e)
      errorMessage.value = articleErrorMessage(e)
      state.value = 'error'
      return
    }
    if (again || JSON.stringify(formSignature(form)) !== lastSignature) {
      again = false
      schedule()
    }
  }

  function save(): Promise<void> {
    clearTimeout(timer)
    if (running) {
      again = true
      return running
    }
    running = run().finally(() => (running = null))
    return running
  }
  function schedule() {
    clearTimeout(timer)
    timer = setTimeout(() => void save(), DEBOUNCE_MS)
  }

  watch(
    options.form,
    (form) => {
      if (!form || !options.enabled.value || !published.value) return
      if (JSON.stringify(formSignature(form)) === lastSignature) return
      if (state.value !== 'saving') state.value = 'dirty'
      schedule()
    },
    { deep: true },
  )

  const unsaved = computed(() => ['dirty', 'saving', 'error'].includes(state.value))
  function beforeUnload(event: BeforeUnloadEvent) {
    if (unsaved.value) event.preventDefault()
  }
  onMounted(() => window.addEventListener('beforeunload', beforeUnload))
  onBeforeUnmount(() => {
    window.removeEventListener('beforeunload', beforeUnload)
    clearTimeout(timer)
    if (unsaved.value) void save()
  })

  const entries = (categoryName: (id: string) => string, authorName?: (id: string | null) => string) =>
    options.form.value && published.value ? describeChanges(published.value, options.form.value, categoryName, authorName) : []

  /** "Revertir": put the published value back; the autosave then drops the key from the draft. */
  function revert(key: string) {
    if (!options.form.value || !published.value) return
    revertGroup(options.form.value, published.value, key)
    if (key.endsWith('.body')) revision.value++
  }

  /** Flushes the autosave and publishes the draft. Returns the new version, or `null` (see `conflict`/`errorMessage`). */
  async function publish(force = false): Promise<string | null> {
    await save()
    if (state.value === 'error' || state.value === 'blocked') {
      errorMessage.value ||= 'Hay cambios con errores. Corrígelos primero.'
      return null
    }
    try {
      const next = await publishArticleDraft(client, options.id, force)
      conflict.value = false
      if (options.form.value) init(options.form.value, next, null)
      return next
    } catch (e) {
      conflict.value = codeOf(e) === 'PT409'
      errorMessage.value = articleErrorMessage(e, options.nameOf)
      if (codeOf(e) === 'PT422') options.onAltRefused?.()
      return null
    }
  }

  /** Deletes the draft and puts the published version back in the editor. */
  async function discard(): Promise<boolean> {
    clearTimeout(timer)
    try {
      await running
      await discardArticleDraft(client, options.id)
    } catch (e) {
      errorMessage.value = articleErrorMessage(e)
      return false
    }
    if (published.value) options.form.value = plain(published.value)
    init(published.value!, version.value, null)
    revision.value++
    return true
  }

  return { published, base, version, conflict, revision, state, savedAt, storedAt, errorMessage, unsaved, changed, init, entries, revert, publish, discard, save, retry: save }
}
