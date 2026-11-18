import type { Database } from '~/types/database.types'
import { createToken, fetchTokens, revokeToken } from '~/services/admin/ingest'
import { MAX_ACTIVE_TOKENS } from '~/utils/admin-ingest'
import { ingestError } from '~/utils/admin-ingest-form'

/**
 * Tokens of the routine (J1–J7): list (only `hint`, never the hash), create and revoke. `create` **returns** the plain token to
 * its caller and keeps nothing: it is not stored in the state, in a toast or in any log (F-token of 8.9).
 */
export function useAdminIngestTokens() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-ingest-tokens', () => fetchTokens(client), { server: false })
  const busy = ref(false)
  const error = ref<string>()
  const active = computed(() => (list.data.value ?? []).filter((t) => t.status === 'active'))

  /** The plain token, once; `undefined` when the server refused (the reason is in `error`). */
  async function create(label: string, days: number): Promise<string | undefined> {
    if (busy.value) return undefined
    busy.value = true
    error.value = undefined
    try {
      const token = await createToken(client, label.trim(), days)
      await list.refresh()
      return token
    } catch (e) {
      error.value = ingestError(e)
      return undefined
    } finally {
      busy.value = false
    }
  }

  async function revoke(id: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      await revokeToken(client, id)
      success('Token revocado')
      await list.refresh()
      return true
    } catch (e) {
      toastError({ message: ingestError(e) })
      return false
    } finally {
      busy.value = false
    }
  }

  return { tokens: computed(() => list.data.value ?? []), active, canCreate: computed(() => active.value.length < MAX_ACTIVE_TOKENS), pending: computed(() => list.status.value === 'pending' && !list.data.value), failed: computed(() => list.status.value === 'error'), busy, error, create, revoke, reload: () => list.refresh() }
}
