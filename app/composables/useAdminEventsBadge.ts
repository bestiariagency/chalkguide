import type { Database } from '~/types/database.types'
import { fetchEventsSummary } from '~/services/admin/events'

/**
 * Menu counter of Agenda: drafts that have not expired (`badge` of `admin_events_summary`). Shared state:
 * the sidebar loads it and the Agenda page refreshes it after approving or discarding.
 */
export function useAdminEventsBadge() {
  const client = useSupabaseClient<Database>()
  const count = useState<number>('admin-events-pending', () => 0)

  async function refresh() {
    try {
      count.value = (await fetchEventsSummary(client)).badge
    } catch {
      // The counter is a hint: when it fails the menu simply shows none.
    }
  }

  return { count, refresh }
}
