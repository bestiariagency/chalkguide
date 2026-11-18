/** Reactive copy of `source` that follows it after `delay` ms of quiet (screen-reader announcements). */
export function useDebouncedValue<T>(source: MaybeRefOrGetter<T>, delay: number) {
  const value = ref(toValue(source)) as Ref<T>
  let timer: ReturnType<typeof setTimeout> | undefined
  watch(
    () => toValue(source),
    (next) => {
      clearTimeout(timer)
      timer = setTimeout(() => (value.value = next), delay)
    },
  )
  onScopeDispose(() => clearTimeout(timer))
  return value
}
