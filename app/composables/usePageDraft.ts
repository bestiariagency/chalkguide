import type { Database } from '~/types/database.types'
import type { SaveState } from '~/composables/useArticleAutosave'
import { discardPageDraft, publishPageDraft, savePageDraft, type PageRevision } from '~/services/admin/page-drafts'
import { pageErrorMessage } from '~/utils/admin-pages'
import type { ArticleErrors } from '~/utils/article-form'
import { describePageChanges, revertPageGroup } from '~/utils/page-changes'
import type { PageForm } from '~/utils/page-form'
import { buildDraftPage, changedPageGroups, pageSignature } from '~/utils/page-patch'

const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T
const codeOf = (e: unknown) => (e as { code?: string } | null)?.code

/**
 * Draft of changes of a PUBLISHED page (D23). The form shows the published version with the stored
 * draft laid over it; the autosave writes only through `save_draft` (never to `pages`), sending every
 * white-listed column that differs from the published version. Publishing and discarding go through
 * `publish_draft` / `discard_draft`. A `PT409` means the published version changed while editing
 * (`conflict`): publishing can then be forced, or the editor reloaded.
 */
export function usePageDraft(options: {
  id: Ref<string>
  form: Ref<PageForm | null>
  errors: Ref<ArticleErrors>
  enabled: Ref<boolean>
  onError?: (error: unknown) => void
  nameOf?: (mediaId: string) => string | undefined
  onAltRefused?: () => void
}) {
  const client = useSupabaseClient<Database>()
  const { clean, whenReady } = useAdminSanitize()

  const published = shallowRef<PageForm | null>(null)
  /** Published version the stored draft starts from (`base_updated_at`); sent with every save. */
  const base = ref('')
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
  const unsaved = computed(() => ['dirty', 'saving', 'error'].includes(state.value))
  const queue = useSaveQueue(run, unsaved)
  const { save, schedule } = queue

  const publishedSignature = computed(() => (published.value ? pageSignature(published.value) : {}))
  const changed = computed(() => (options.form.value && published.value ? changedPageGroups(options.form.value, publishedSignature.value) : []))

  /** Starts from the published form, the version it has, and the stored draft's `page` section (if any). */
  function init(publishedForm: PageForm, publishedVersion: string, draft: { page: Record<string, unknown>; baseUpdatedAt: string; updatedAt: string } | null) {
    published.value = plain(publishedForm)
    version.value = publishedVersion
    base.value = draft?.baseUpdatedAt ?? publishedVersion
    stored.value = draft?.page ?? {}
    storedAt.value = draft?.updatedAt ?? null
    lastPayload = JSON.stringify(stored.value)
    conflict.value = false
    state.value = 'idle'
    lastSignature = options.form.value ? JSON.stringify(pageSignature(options.form.value)) : ''
  }

  async function run() {
    await whenReady()
    const form = options.form.value
    if (!form || !published.value || !options.enabled.value) return
    const signature = JSON.stringify(pageSignature(form))
    const plan = buildDraftPage(form, publishedSignature.value, options.errors.value, clean, stored.value)
    const payload = JSON.stringify(plan.page)
    if (payload === lastPayload) {
      lastSignature = signature
      state.value = plan.blocked.length ? 'blocked' : state.value === 'saved' ? 'saved' : 'idle'
      return
    }
    state.value = 'saving'
    try {
      if (Object.keys(plan.page).length) {
        const saved = await savePageDraft(client, options.id.value, plan.page, base.value)
        base.value = saved.baseUpdatedAt
        storedAt.value = saved.updatedAt
      } else {
        await discardPageDraft(client, options.id.value)
        storedAt.value = null
      }
      stored.value = plan.page
      lastPayload = payload
      lastSignature = signature
      savedAt.value = Date.now()
      errorMessage.value = ''
      state.value = plan.blocked.length ? 'blocked' : 'saved'
    } catch (e) {
      if (codeOf(e) === 'PT409') conflict.value = true
      options.onError?.(e)
      errorMessage.value = pageErrorMessage(e)
      state.value = 'error'
      return
    }
    if (queue.takeAgain() || JSON.stringify(pageSignature(form)) !== lastSignature) {
      schedule()
    }
  }

  watch(
    options.form,
    (form) => {
      if (!form || !options.enabled.value || !published.value) return
      if (JSON.stringify(pageSignature(form)) === lastSignature) return
      if (state.value !== 'saving') state.value = 'dirty'
      schedule()
    },
    { deep: true },
  )

  const entries = () => (options.form.value && published.value ? describePageChanges(published.value, options.form.value) : [])

  /** "Revertir": put the published value back; the autosave then drops the key from the draft. */
  function revert(key: string) {
    if (!options.form.value || !published.value) return
    revertPageGroup(options.form.value, published.value, key)
    if (key.endsWith('.body')) revision.value++
  }

  /** Flushes the autosave and publishes the draft. Returns the new version, or `null` (see `conflict`/`errorMessage`). */
  async function publish(force = false, how?: PageRevision): Promise<string | null> {
    await save()
    if (state.value === 'error' || state.value === 'blocked') {
      errorMessage.value ||= 'Hay cambios con errores. Corrígelos primero.'
      return null
    }
    try {
      const next = await publishPageDraft(client, options.id.value, force, how)
      conflict.value = false
      errorMessage.value = ''
      if (options.form.value) init(options.form.value, next, null)
      return next
    } catch (e) {
      conflict.value = codeOf(e) === 'PT409'
      errorMessage.value = pageErrorMessage(e, options.nameOf)
      if (codeOf(e) === 'PT422') options.onAltRefused?.()
      return null
    }
  }

  /** Deletes the draft and puts the published version back in the editor. */
  async function discard(): Promise<boolean> {
    try {
      await queue.settle()
      await discardPageDraft(client, options.id.value)
    } catch (e) {
      errorMessage.value = pageErrorMessage(e)
      return false
    }
    if (published.value) options.form.value = plain(published.value)
    init(published.value!, version.value, null)
    revision.value++
    return true
  }

  return { published, base, version, conflict, revision, state, savedAt, storedAt, errorMessage, unsaved, changed, init, entries, revert, publish, discard, save, retry: save }
}
