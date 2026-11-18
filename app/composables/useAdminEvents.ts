import type { Database } from '~/types/database.types'
import { fetchRuns } from '~/services/admin/ingest'
import { fetchEvents, fetchEventsSummary, fetchGymOptions } from '~/services/admin/events'
import { emptyEventFilters, eventViewOf, inView, queryFor, viewCounts, type AdminEvent, type EventFilters, type EventView } from '~/utils/admin-events'
import { todayMadrid } from '~/utils/admin-madrid'
import { runLabel } from '~/utils/admin-source'

/**
 * Agenda data (F6.12): view, filters and calendar month live in the URL (`?vista=&tipo=&q=&lugar=&desde=&hasta=
 * &origen=&recogida=&cal=mes&mes=`). Without `vista` it opens on Por aprobar when there are drafts, else on Próximos (D33).
 * The database filters and sorts; the panel only drops what a view cannot ask for (published = approved + cancelled).
 */
export function useAdminEvents() {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const { text, setQuery } = useAdminUrlQuery()

  const summary = useAsyncData('admin-events-summary', () => fetchEventsSummary(client), { server: false })
  const gyms = useAsyncData('admin-events-gyms', () => fetchGymOptions(client), { server: false })

  // Collections of the last 30 days for the «Recogida» option of Origen; without them the option lists none.
  const runs = useAsyncData('admin-events-runs', () => fetchRuns(client, 30).catch(() => []), { server: false })
  const runOptions = computed(() => (runs.data.value ?? []).map((r) => ({ id: r.id, label: runLabel(r.startedAt) })))

  const initial = ref<EventView>()
  watch(
    () => summary.data.value,
    (s) => {
      if (s && !initial.value) initial.value = s.pending + s.pendingPast > 0 ? 'revisar' : 'proximos'
    },
    { immediate: true },
  )
  // Without the counters the default view is unknown; if they fail the panel still opens on Próximos.
  watch(
    () => summary.error.value,
    (error) => {
      if (error && !initial.value) initial.value = 'proximos'
    },
  )
  const view = computed(() => eventViewOf(route.query.vista) ?? initial.value)

  const search = ref(text('q'))
  const debounced = useDebouncedValue(search, 300)
  const filters = computed<EventFilters>(() => ({
    ...emptyEventFilters(),
    search: debounced.value,
    types: text('tipo') ? text('tipo').split(',').filter(Boolean) : [],
    itemId: text('lugar'),
    from: /^\d{4}-\d{2}-\d{2}$/.test(text('desde')) ? text('desde') : '',
    to: /^\d{4}-\d{2}-\d{2}$/.test(text('hasta')) ? text('hasta') : '',
    source: text('origen') === 'agent' || text('origen') === 'manual' ? (text('origen') as 'agent' | 'manual') : '',
    run: text('recogida'),
  }))
  const calendar = computed(() => text('cal') === 'mes' && view.value === 'proximos')
  const month = computed(() => (/^\d{4}-\d{2}$/.test(text('mes')) ? text('mes') : todayMadrid().slice(0, 7)))

  watch(debounced, (value) => void setQuery({ q: value.trim() || undefined }))

  const rows = ref<AdminEvent[]>([])
  const list = useAsyncData(
    'admin-events',
    async () => {
      const current = view.value
      if (!current) return null
      const run = filters.value.run
      const fetched = await fetchEvents(client, queryFor(current, filters.value, calendar.value ? month.value : undefined))
      const found = run ? fetched.filter((e) => e.runId === run) : fetched
      rows.value = calendar.value ? found.filter((e) => e.status !== 'rejected') : found.filter((e) => inView(current, e))
      return found.length
    },
    { server: false, watch: [view, filters, calendar, month] },
  )
  watch(view, () => (rows.value = []))

  const counts = computed(() => (summary.data.value ? viewCounts(summary.data.value) : undefined))
  const badge = useAdminEventsBadge()
  /** Re-reads the list and the counters (also the menu's) after any change. */
  async function reload() {
    await Promise.all([list.refresh(), summary.refresh()])
    void badge.refresh()
  }

  return { view, filters, search, calendar, month, setQuery, rows, list, summary: computed(() => summary.data.value), counts, gyms: computed(() => gyms.data.value ?? []), runOptions, reload }
}
