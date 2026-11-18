/**
 * `true` only once `source` has been true for `delay` ms (loading placeholders: no flash on fast loads);
 * goes back to `false` right away. Unlike `useDebouncedValue`, hiding is not delayed.
 */
export function useDelayedFlag(source: MaybeRefOrGetter<boolean>, delay = 300) {
  const delayed = ref(false)
  let timer: ReturnType<typeof setTimeout> | undefined
  watch(
    () => toValue(source),
    (on) => {
      clearTimeout(timer)
      if (on) timer = setTimeout(() => (delayed.value = true), delay)
      else delayed.value = false
    },
    { immediate: true },
  )
  onScopeDispose(() => clearTimeout(timer))
  return delayed
}
