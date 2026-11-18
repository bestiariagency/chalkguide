import type { Database } from '~/types/database.types'
import { fetchActivity } from '~/services/admin/activity'
import { activityArgs, filtersFromQuery, groupByDay, type ActivityFilters, type ActivityPage, type ActivityRecord } from '~/utils/admin-activity'

/**
 * Actividad (F6.18): the filters live in the URL (`?vista=&q=&periodo=&desde=&hasta=`), the server filters and pages by
 * cursor. The first page comes from `useAsyncData` (it restarts whenever a filter changes); «Cargar más» appends.
 * `counts` come with every page and ignore the tab, so the tab counters stay put while you switch.
 */
export function useAdminActivity() {
  const client = useSupabaseClient<Database>()
  const { text, setQuery } = useAdminUrlQuery()
  const route = useRoute()

  const filters = computed<ActivityFilters>(() => {
    void route.query
    return filtersFromQuery(text)
  })
  const search = ref(filters.value.search)
  const debounced = useDebouncedValue(search, 300)
  watch(debounced, (value) => void setQuery({ q: value.trim() || undefined }))
  // The URL is the source: Back/Forward or «Quitar filtros» also refresh the box.
  watch(() => filters.value.search, (value) => value !== search.value.trim() && (search.value = value))

  // A filter change must not keep a stale «Cargar más» answer.
  let generation = 0
  const extra = ref<ActivityRecord[]>([])
  const next = ref<ActivityPage['next']>(null)
  const loadingMore = ref(false)
  const moreFailed = ref(false)

  const list = useAsyncData(
    'admin-activity',
    async () => {
      generation++
      extra.value = []
      loadingMore.value = false
      moreFailed.value = false
      const page = await fetchActivity(client, activityArgs({ ...filters.value, search: debounced.value }))
      next.value = page.next
      return page
    },
    { server: false, watch: [() => filters.value.tab, () => filters.value.period, () => filters.value.from, () => filters.value.to, debounced] },
  )

  async function more() {
    const cursor = next.value
    if (!cursor || loadingMore.value) return
    const mine = generation
    loadingMore.value = true
    moreFailed.value = false
    try {
      const page = await fetchActivity(client, activityArgs({ ...filters.value, search: debounced.value }, cursor))
      if (mine !== generation) return
      extra.value = [...extra.value, ...page.entries]
      next.value = page.next
    } catch {
      if (mine === generation) moreFailed.value = true
    } finally {
      if (mine === generation) loadingMore.value = false
    }
  }

  const entries = computed(() => [...(list.data.value?.entries ?? []), ...extra.value])
  const days = computed(() => groupByDay(entries.value))
  const counts = computed(() => list.data.value?.counts)
  const errorCode = computed(() => (list.error.value as { code?: string } | undefined)?.code)

  return {
    filters,
    search,
    setQuery,
    list,
    days,
    entries,
    counts,
    hasMore: computed(() => !!next.value),
    loadingMore,
    moreFailed,
    more,
    errorCode,
  }
}
