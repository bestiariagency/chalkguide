import type { Database } from '~/types/database.types'
import { createSource, deleteSource, fetchSources, setSourceActive, updateSource } from '~/services/admin/ingest'
import type { AdminSource } from '~/utils/admin-ingest'
import { ingestError, type SourceForm } from '~/utils/admin-ingest-form'

/** Sources of the agent (allowlist): list, create, edit, activate and delete. Active ones are what the routine reads. */
export function useAdminIngestSources() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-ingest-sources', () => fetchSources(client), { server: false })
  const busy = ref(false)
  const error = ref<string>()

  async function attempt(run: () => Promise<void>, message: string, toast = false): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    error.value = undefined
    try {
      await run()
      success(message)
      await list.refresh()
      return true
    } catch (e) {
      error.value = ingestError(e)
      if (toast) toastError({ message: error.value })
      return false
    } finally {
      busy.value = false
    }
  }

  const save = (source: AdminSource | undefined, form: SourceForm) =>
    attempt(() => (source ? updateSource(client, source.id, form) : createSource(client, form)), source ? 'Fuente guardada' : 'Fuente creada · se revisará en la próxima recogida')
  const toggle = (s: AdminSource, active: boolean) => attempt(() => setSourceActive(client, s.id, active), active ? `«${s.name}» activada` : `«${s.name}» desactivada`, true)
  const remove = (s: AdminSource) => attempt(() => deleteSource(client, s.id), 'Fuente eliminada', true)

  return { sources: computed(() => list.data.value ?? []), pending: computed(() => list.status.value === 'pending' && !list.data.value), failed: computed(() => list.status.value === 'error'), busy, error, save, toggle, remove, reload: () => list.refresh() }
}
