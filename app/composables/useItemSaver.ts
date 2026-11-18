import type { ItemForm, Sections } from '~/utils/item-fields'
import { diffSections, errorFieldIds, patchSize, type ItemErrors, type ItemPatch } from '~/utils/item-patch'
import type { SaveState } from '~/composables/useArticleAutosave'

const DEBOUNCE_MS = 1200

/**
 * Autosave of the item editors (gyms, resolers), shared by both modes. After a pause it measures the form (invalid
 * fields keep their baseline value, so they are "blocked", not sent) against `baseline()` and calls
 * `send`. Direct mode (unpublished): the baseline is what was last saved, `send` writes the columns.
 * Draft mode (published, D23): the baseline is the published version and the whole difference goes
 * to the draft each time; an empty difference (`sendEmpty`) lets the caller drop the draft.
 */
export function useItemSaver<F extends ItemForm>(options: {
  form: Ref<F | null>
  errors: Ref<ItemErrors>
  /** Database-shaped state of the form (per category). */
  sectionsOf: (form: F, clean: (html: string) => string, skip: ReadonlySet<string>, fallback: Sections) => Sections
  enabled: Ref<boolean>
  baseline: () => Sections | null
  sendEmpty: Ref<boolean>
  send: (patch: ItemPatch, sections: Sections) => Promise<void>
  /** Error text for the save indicator. */
  describe: (error: unknown) => string
  onError?: (error: unknown) => void
}) {
  const { clean, whenReady } = useAdminSanitize()

  const state = ref<SaveState>('idle')
  const savedAt = ref<number | null>(null)
  const errorMessage = ref('')
  let lastPatch = '{}'
  let timer: ReturnType<typeof setTimeout> | undefined
  let again = false
  let running: Promise<void> | null = null

  /** Forget what was sent (after loading, or after the baseline changed under us). */
  function reset(patch: ItemPatch = {}) {
    lastPatch = JSON.stringify(patch)
    state.value = 'idle'
  }

  function plan() {
    const form = options.form.value
    const base = options.baseline()
    if (!form || !base) return null
    const skip = errorFieldIds(options.errors.value)
    const sections = options.sectionsOf(form, clean, skip, base)
    const patch = diffSections(sections, base)
    return { patch, sections, json: JSON.stringify(patch), blocked: skip.size > 0 }
  }

  const hasChange = (n: NonNullable<ReturnType<typeof plan>>) => (options.sendEmpty.value ? n.json !== lastPatch : patchSize(n.patch) > 0)

  async function run() {
    await whenReady()
    if (!options.enabled.value) return
    const next = plan()
    if (!next) return
    if (!hasChange(next)) {
      state.value = next.blocked ? 'blocked' : state.value === 'saved' ? 'saved' : 'idle'
      return
    }
    state.value = 'saving'
    try {
      await options.send(next.patch, next.sections)
      lastPatch = options.sendEmpty.value ? next.json : '{}'
      savedAt.value = Date.now()
      errorMessage.value = ''
      state.value = next.blocked ? 'blocked' : 'saved'
    } catch (e) {
      options.onError?.(e)
      errorMessage.value = options.describe(e)
      state.value = 'error'
      return
    }
    const after = plan()
    if (again || (after && hasChange(after))) {
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
    () => {
      if (!options.enabled.value) return
      const next = plan()
      if (!next) return
      if (!hasChange(next)) {
        if (next.blocked && state.value !== 'saving') state.value = 'blocked'
        return
      }
      if (state.value !== 'saving') state.value = 'dirty'
      schedule()
    },
    { deep: true },
  )

  const unsaved = computed(() => ['dirty', 'saving', 'error'].includes(state.value))
  const beforeUnload = (event: BeforeUnloadEvent) => unsaved.value && event.preventDefault()
  onMounted(() => window.addEventListener('beforeunload', beforeUnload))
  onBeforeUnmount(() => {
    window.removeEventListener('beforeunload', beforeUnload)
    clearTimeout(timer)
    if (unsaved.value) void save()
  })

  return { state, savedAt, errorMessage, unsaved, reset, save, retry: save, clean }
}
