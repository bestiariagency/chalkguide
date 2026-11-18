import type { Database } from '~/types/database.types'
import { fetchNewsSummary } from '~/services/admin/news'

/**
 * Menu counters of Noticias (drafts to review) and Ingesta (red dot when the health of the agent fails). Shared state:
 * the sidebar loads it and the Noticias page refreshes it after approving or rejecting.
 */
export function useAdminNewsBadge() {
  const client = useSupabaseClient<Database>()
  const count = useState<number>('admin-news-pending', () => 0)
  const ingestFailing = useState<boolean>('admin-ingest-failing', () => false)

  async function refresh() {
    try {
      const summary = await fetchNewsSummary(client)
      count.value = summary.pending
      ingestFailing.value = summary.health?.ok === false
    } catch {
      // The counter is a hint: when it fails the menu simply shows none.
    }
  }

  return { count, ingestFailing, refresh }
}
