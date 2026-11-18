import type { Database } from '~/types/database.types'
import { saveArticleChanges } from '~/services/admin/article-editor'
import { articleErrorMessage } from '~/utils/admin-articles'
import type { ArticleErrors, ArticleForm } from '~/utils/article-form'
import { buildPatch, formSignature, markSaved, type FormSignature } from '~/utils/article-patch'

export type SaveState = 'idle' | 'dirty' | 'saving' | 'saved' | 'blocked' | 'error'

const DEBOUNCE_MS = 1200

/**
 * Autosave of a not-live article: after a pause it sends only the valid fields that changed
 * (sanitised HTML included). Invalid fields stay on screen with their error and are not sent
 * ("blocked"); a failed save keeps the changes and offers `retry`. Never writes when `enabled` is false.
 */
export function useArticleAutosave(options: {
  id: string
  form: Ref<ArticleForm | null>
  errors: Ref<ArticleErrors>
  enabled: Ref<boolean>
  /** Called with every failed save (to map refused CHECKs to fields). */
  onError?: (error: unknown) => void
  /** Called with the new `updated_at` after each successful save. */
  onSaved?: (updatedAt: string) => void
}) {
  const client = useSupabaseClient<Database>()
  const { clean, whenReady } = useAdminSanitize()

  const state = ref<SaveState>('idle')
  const savedAt = ref<number | null>(null)
  const errorMessage = ref('')
  let base: FormSignature = {}
  let timer: ReturnType<typeof setTimeout> | undefined
  let again = false
  let running: Promise<void> | null = null

  /** Take the current form as "already saved" (after loading or after an explicit save). */
  function reset(form: ArticleForm) {
    base = formSignature(form)
    state.value = 'idle'
  }

  function plan() {
    return options.form.value ? buildPatch(options.form.value, base, options.errors.value, clean) : null
  }

  async function run() {
    await whenReady()
    const form = options.form.value
    if (!form || !options.enabled.value) return
    const next = plan()
    if (!next) return
    if (!next.saved.length) {
      state.value = next.blocked.length ? 'blocked' : state.value === 'saved' ? 'saved' : 'idle'
      return
    }
    const sent = formSignature(form)
    state.value = 'saving'
    try {
      const updatedAt = await saveArticleChanges(client, options.id, next.patch)
      base = markSaved(base, sent, next.saved)
      savedAt.value = Date.now()
      errorMessage.value = ''
      options.onSaved?.(updatedAt)
      state.value = 'saved'
    } catch (e) {
      options.onError?.(e)
      errorMessage.value = articleErrorMessage(e)
      state.value = 'error'
      return
    }
    if (again || (plan()?.saved.length ?? 0) > 0) {
      again = false
      schedule()
    } else if (plan()?.blocked.length) state.value = 'blocked'
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
    () => {
      if (!options.enabled.value || !options.form.value) return
      const next = plan()
      if (!next || (!next.saved.length && !next.blocked.length)) return
      if (state.value !== 'saving') state.value = next.saved.length ? 'dirty' : 'blocked'
      if (next.saved.length) schedule()
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
    // Best effort: send what is pending when leaving the editor.
    if (unsaved.value) void save()
  })

  return { state, savedAt, errorMessage, unsaved, reset, save, retry: save }
}
