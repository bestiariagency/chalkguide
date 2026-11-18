import type { Database } from '~/types/database.types'
import { fetchIngestHealth, fetchRuns, fetchWindowUntil, setIngestWindow } from '~/services/admin/ingest'
import { fetchNews } from '~/services/admin/news'
import { runKpis } from '~/utils/admin-ingest'
import { ingestError } from '~/utils/admin-ingest-form'

/**
 * Ingesta · recogidas and health (F8, README §19.4): health banner (`job_health` of `ingest`), the last 30 days of collections
 * with their KPIs, and the manual window (R1). The share of approved news is counted over the published ones that came
 * from those collections.
 */
export function useAdminIngest() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const health = useAsyncData('admin-ingest-health', () => fetchIngestHealth(client), { server: false })
  const windowUntil = useAsyncData('admin-ingest-window', () => fetchWindowUntil(client), { server: false })
  const runs = useAsyncData('admin-ingest-runs', () => fetchRuns(client, 30), { server: false })
  const published = useAsyncData('admin-ingest-published', () => fetchNews(client, { status: 'published' }), { server: false })

  const kpis = computed(() => {
    const list = runs.data.value ?? []
    const base = runKpis(list)
    const ids = new Set(list.filter((r) => !r.dryRun).map((r) => r.id))
    const approved = (published.data.value ?? []).filter((n) => n.runId && ids.has(n.runId)).length
    return { ...base, approved: base.created ? Math.min(100, Math.round((approved / base.created) * 100)) : null }
  })
  /** The window is open right now. */
  const windowOpen = computed(() => !!windowUntil.data.value && Date.parse(windowUntil.data.value) > Date.now())

  const busy = ref(false)
  async function openWindow() {
    if (busy.value) return
    busy.value = true
    try {
      await setIngestWindow(client, true)
      success('Ventana abierta 2 h · la rutina puede recoger ahora')
      await windowUntil.refresh()
    } catch (e) {
      toastError({ message: ingestError(e) })
    } finally {
      busy.value = false
    }
  }
  async function closeWindow() {
    if (busy.value) return
    busy.value = true
    try {
      await setIngestWindow(client, false)
      success('Ventana cerrada')
      await windowUntil.refresh()
    } catch (e) {
      toastError({ message: ingestError(e) })
    } finally {
      busy.value = false
    }
  }

  const failed = computed(() => runs.status.value === 'error')
  const reload = () => Promise.all([health.refresh(), runs.refresh(), windowUntil.refresh(), published.refresh()])

  return { health: computed(() => health.data.value ?? null), runs: computed(() => runs.data.value ?? []), pending: computed(() => runs.status.value === 'pending' && !runs.data.value), failed, kpis, windowUntil: computed(() => windowUntil.data.value ?? null), windowOpen, busy, openWindow, closeWindow, reload }
}
