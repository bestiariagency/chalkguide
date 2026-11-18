import type { Database } from '~/types/database.types'
import { fetchRuns } from '~/services/admin/ingest'
import { fetchNews, fetchNewsCategories, fetchNewsSummary } from '~/services/admin/news'
import { ADMIN_NEWS_SCOPES, applyLocalFilters, emptyNewsFilters, facetCounts, newsViewOf, statusOfView, type AdminNews, type NewsFilters, type NewsScope, type NewsView } from '~/utils/admin-news'

/**
 * Noticias data (F8, README §19.2): view and filters live in the URL (`?vista=&categoria=&alcance=&fuente=&recogida=&q=`).
 * Without `vista` it opens on Por revisar when there are drafts, else on Publicadas. The database filters by state, scope,
 * collection and text; category and source are multi-select, so the panel applies them on the rows it received.
 */
export function useAdminNews() {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const { text, setQuery } = useAdminUrlQuery()

  const summary = useAsyncData('admin-news-summary', () => fetchNewsSummary(client), { server: false })
  const categories = useAsyncData('admin-news-categories', () => fetchNewsCategories(client), { server: false })
  // Collections of the last 30 days for the «Recogida» filter; without them the filter just lists none.
  const runs = useAsyncData('admin-news-runs', () => fetchRuns(client, 30).catch(() => []), { server: false })

  const initial = ref<NewsView>()
  watch(
    () => summary.data.value,
    (s) => {
      if (s && !initial.value) initial.value = s.pending > 0 ? 'revisar' : 'publicadas'
    },
    { immediate: true },
  )
  watch(
    () => summary.error.value,
    (error) => {
      if (error && !initial.value) initial.value = 'publicadas'
    },
  )
  const view = computed(() => newsViewOf(route.query.vista) ?? initial.value)

  const search = ref(text('q'))
  const debounced = useDebouncedValue(search, 300)
  const scope = computed(() => ADMIN_NEWS_SCOPES.find((s) => s.value === text('alcance'))?.value ?? '')
  const filters = computed<NewsFilters>(() => ({
    ...emptyNewsFilters(),
    search: debounced.value,
    categories: text('categoria') ? text('categoria').split(',').filter(Boolean) : [],
    scope: scope.value as '' | NewsScope,
    sources: text('fuente') ? text('fuente').split(',').filter(Boolean) : [],
    run: text('recogida'),
  }))
  watch(debounced, (value) => void setQuery({ q: value.trim() || undefined }))

  const all = ref<AdminNews[]>([])
  const serverKey = computed(() => [view.value, debounced.value, scope.value, text('recogida')].join('|'))
  const list = useAsyncData(
    'admin-news',
    async () => {
      const current = view.value
      if (!current) return null
      all.value = await fetchNews(client, { status: statusOfView(current), scope: scope.value || undefined, runId: text('recogida') || undefined, search: debounced.value })
      return all.value.length
    },
    { server: false, watch: [serverKey] },
  )
  watch(view, () => (all.value = []))

  const rows = computed(() => applyLocalFilters(all.value, filters.value))
  /** Menu facets: counted over what the server returned, so each box shows what ticking it would leave. */
  const categoryCounts = computed(() => facetCounts(all.value, (n) => n.categoryKey))
  const sourceFacets = computed(() => {
    const counts = facetCounts(all.value, (n) => n.sourceId)
    const names = new Map(all.value.filter((n) => n.sourceId).map((n) => [n.sourceId as string, n.sourceName]))
    return [...counts].map(([id, count]) => ({ id, name: names.get(id) ?? id, count })).sort((a, b) => a.name.localeCompare(b.name, 'es'))
  })

  const runOptions = computed(() => (runs.data.value ?? []).map((r) => ({ id: r.id, label: runLabel(r.startedAt) })))

  const counts = computed(() => {
    const s = summary.data.value
    return s ? { revisar: s.pending, publicadas: s.published, rechazadas: s.rejected, todas: s.total } : undefined
  })
  const badge = useAdminNewsBadge()
  /** Re-reads the list and the counters (also the menu's) after any change. */
  async function reload() {
    await Promise.all([list.refresh(), summary.refresh()])
    void badge.refresh()
  }

  return { view, filters, search, setQuery, all, rows, list, summary: computed(() => summary.data.value), counts, categories: computed(() => categories.data.value ?? []), categoryCounts, sourceFacets, runOptions, reload, reloadCategories: () => categories.refresh() }
}
