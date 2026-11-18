import type { Database } from '~/types/database.types'
import { fetchAuthorImpact } from '~/services/admin/authors'
import type { AuthorImpact } from '~/utils/admin-authors'

/** Counts and first three titles of one author, asked when the delete dialog opens (never computed in the client). */
export function useAdminAuthorImpact(authorId: string) {
  const client = useSupabaseClient<Database>()
  const impact = ref<AuthorImpact>()
  const pending = ref(true)
  const failed = ref(false)

  async function load() {
    pending.value = true
    failed.value = false
    try {
      impact.value = await fetchAuthorImpact(client, authorId)
    } catch {
      failed.value = true
    } finally {
      pending.value = false
    }
  }
  void load()

  return { impact, pending, failed, reload: load }
}
