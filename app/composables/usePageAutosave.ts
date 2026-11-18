import type { Database } from '~/types/database.types'
import type { SaveState } from '~/composables/useArticleAutosave'
import { savePageChanges } from '~/services/admin/pages'
import { pageErrorMessage } from '~/utils/admin-pages'
import { markSaved, type FormSignature } from '~/utils/article-patch'
import type { ArticleErrors } from '~/utils/article-form'
import type { PageForm } from '~/utils/page-form'
import { buildPagePatch, pageSignature } from '~/utils/page-patch'

/**
 * Autosave of a not-published page: after a pause it sends only the valid fields that changed
 * (sanitised HTML included). Invalid fields stay on screen and are not sent ("blocked"); a failed
 * save keeps the changes and offers `retry`. Never writes when `enabled` is false.
 */
export function usePageAutosave(options: {
  id: Ref<string>
  form: Ref<PageForm | null>
  errors: Ref<ArticleErrors>
  enabled: Ref<boolean>
  onError?: (error: unknown) => void
  onSaved?: (updatedAt: string) => void
}) {
  const client = useSupabaseClient<Database>()
  const { clean, whenReady } = useAdminSanitize()

  const state = ref<SaveState>('idle')
  const savedAt = ref<number | null>(null)
  const errorMessage = ref('')
  let base: FormSignature = {}
  const unsaved = computed(() => ['dirty', 'saving', 'error'].includes(state.value))
  const queue = useSaveQueue(run, unsaved)
  const { save, schedule } = queue

  /** Take the current form as "already saved" (after loading). */
  function reset(form: PageForm) {
    base = pageSignature(form)
    state.value = 'idle'
  }
  const plan = () => (options.form.value ? buildPagePatch(options.form.value, base, options.errors.value, clean) : null)

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
    const sent = pageSignature(form)
    state.value = 'saving'
    try {
      const updatedAt = await savePageChanges(client, options.id.value, next.patch)
      base = markSaved(base, sent, next.saved)
      savedAt.value = Date.now()
      errorMessage.value = ''
      options.onSaved?.(updatedAt)
      state.value = 'saved'
    } catch (e) {
      options.onError?.(e)
      errorMessage.value = pageErrorMessage(e)
      state.value = 'error'
      return
    }
    if (queue.takeAgain() || (plan()?.saved.length ?? 0) > 0) {
      schedule()
    } else if (plan()?.blocked.length) state.value = 'blocked'
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

  return { state, savedAt, errorMessage, unsaved, reset, save, retry: save }
}
