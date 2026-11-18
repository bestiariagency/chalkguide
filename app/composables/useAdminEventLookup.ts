import type { Database } from '~/types/database.types'
import { fetchEvent } from '~/services/admin/events'
import type { AdminEvent } from '~/utils/admin-events'

/** Reads one event by id (e.g. the existing event a draft may duplicate); `null` while loading or when it is gone. */
export function useAdminEventLookup(id: MaybeRefOrGetter<string | undefined>) {
  const client = useSupabaseClient<Database>()
  const event = ref<AdminEvent | null>(null)
  watch(
    () => toValue(id),
    async (value) => {
      event.value = null
      if (!value) return
      try {
        event.value = await fetchEvent(client, value)
      } catch {
        // The banner still works without the original's title.
      }
    },
    { immediate: true },
  )
  return event
}
