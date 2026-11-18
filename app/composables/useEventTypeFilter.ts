import type { EventType, GuideEvent } from '~/types/domain'

/** Client-side type filter for the agenda: no selection = all types. */
export function useEventTypeFilter(events: MaybeRefOrGetter<GuideEvent[]>) {
  const selected = ref<EventType[]>([])
  const types = computed(() => presentEventTypes(toValue(events)))
  const filtered = computed(() =>
    selected.value.length
      ? toValue(events).filter((event) => selected.value.includes(event.type))
      : toValue(events),
  )

  function isSelected(type: EventType) {
    return selected.value.includes(type)
  }
  function toggle(type: EventType, on: boolean) {
    selected.value = on
      ? [...selected.value, type]
      : selected.value.filter((current) => current !== type)
  }
  const clear = () => (selected.value = [])

  return { types, filtered, isSelected, toggle, clear, hasFilter: computed(() => !!selected.value.length) }
}
