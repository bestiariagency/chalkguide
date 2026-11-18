const DEBOUNCE_MS = 1200

/**
 * Debounce + single-flight + leave-the-editor guard shared by the page autosaves. `run` does one save
 * pass; `save()` never runs two at once (a second call flags `takeAgain()` and joins the running one).
 * On unmount the pending changes are sent (best effort) and the browser warns while `unsaved` is true.
 */
export function useSaveQueue(run: () => Promise<void>, unsaved: Ref<boolean>) {
  let timer: ReturnType<typeof setTimeout> | undefined
  let again = false
  let running: Promise<void> | null = null

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
  /** Whether a save was requested while one was running (clears the flag). */
  function takeAgain() {
    const pending = again
    again = false
    return pending
  }
  /** Cancels the timer and waits for the running pass (used before discarding). */
  async function settle() {
    clearTimeout(timer)
    await running
  }

  function beforeUnload(event: BeforeUnloadEvent) {
    if (unsaved.value) event.preventDefault()
  }
  onMounted(() => window.addEventListener('beforeunload', beforeUnload))
  onBeforeUnmount(() => {
    window.removeEventListener('beforeunload', beforeUnload)
    clearTimeout(timer)
    if (unsaved.value) void save()
  })

  return { save, schedule, takeAgain, settle }
}
