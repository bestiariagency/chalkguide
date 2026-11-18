import type { Database } from '~/types/database.types'
import { fetchReviewsSummary } from '~/services/admin/reviews'

/**
 * Menu counter of Opiniones (`badge` of `admin_reviews_summary`: pending plus visible ones to review
 * since the last visit, D24). Shared state: the sidebar loads it and the Opiniones page resets it.
 */
export function useAdminReviewsBadge() {
  const client = useSupabaseClient<Database>()
  const count = useState<number>('admin-reviews-new', () => 0)

  async function refresh() {
    try {
      count.value = (await fetchReviewsSummary(client)).badge
    } catch {
      // The counter is a hint: when it fails the menu simply shows none.
    }
  }

  return { count, refresh, clear: () => (count.value = 0) }
}
