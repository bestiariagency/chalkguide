import type { Database } from '~/types/database.types'
import { countArticleDrafts, fetchArticlesBetween, fetchLastArticle, fetchStats } from '~/services/admin/stats'
import { todayMadrid, madridToIso } from '~/utils/admin-madrid'
import { parseStats } from '~/utils/admin-stats'
import { statsCsv, statsCsvName } from '~/utils/admin-stats-csv'
import { allowedGrains, daysIn, defaultGrain, keyAdd, statsCutoff, viewFromQuery, viewToArgs, viewToQuery, type StatsGrain, type StatsPeriod, type StatsView } from '~/utils/admin-stats-range'
import { saveTextFile } from '~/utils/admin-download'

/**
 * Estadísticas (F6.16, README §16): the view (period, grouping, custom range) lives in the URL and every change is a
 * history entry (Back works). One `admin_stats` call feeds the screen; the lists under the charts are optional
 * (they never break the page). While a new answer loads, the old one stays (the page dims it).
 */
export function useAdminStats() {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const toast = useAdminToast()
  const { text } = useAdminUrlQuery()

  const today = todayMadrid()
  const cutoff = statsCutoff(today)
  const view = computed<StatsView>(() => {
    void route.query
    return viewFromQuery(text, today)
  })
  /** The last applied custom range, kept for the session (the picker opens with it). */
  const lastCustom = useState<{ from: string; to: string } | null>('admin-stats-custom', () => null)
  watch(view, (v) => v.period === 'custom' && v.from && v.to && (lastCustom.value = { from: v.from, to: v.to }), { immediate: true })

  const go = (next: StatsView) => navigateTo({ query: Object.fromEntries(Object.entries(viewToQuery(next)).filter(([, v]) => v)) })

  function setPeriod(period: Exclude<StatsPeriod, 'custom'>) {
    const grain = allowedGrains(period, 0).includes(view.value.grain) ? view.value.grain : defaultGrain(period)
    return go({ period, grain })
  }
  function setGrain(grain: StatsGrain) {
    return go({ ...view.value, grain })
  }
  function applyRange(from: string, to: string) {
    const days = daysIn(from, to)
    const grain = allowedGrains('custom', days).includes(view.value.grain) ? view.value.grain : defaultGrain('custom', days)
    return go({ period: 'custom', grain, from, to })
  }

  const optional = <T>(run: Promise<T>, fallback: T) => run.catch(() => fallback)
  const stats = useAsyncData(
    'admin-stats',
    async () => {
      const current = view.value
      const data = parseStats(await fetchStats(client, viewToArgs(current)))
      const list = current.period === '30d' ? optional(fetchArticlesBetween(client, madridToIso(data.from), madridToIso(keyAdd(data.to, 1))), []) : Promise.resolve([])
      const last = current.period === '12m' ? optional(fetchLastArticle(client), null) : Promise.resolve(null)
      const [articles, lastArticle, drafts] = await Promise.all([list, last, optional(countArticleDrafts(client), 0)])
      return { data, articles, lastArticle, drafts }
    },
    { server: false, watch: [() => JSON.stringify(viewToQuery(view.value))] },
  )

  const loading = computed(() => !stats.data.value && !stats.error.value)
  const failed = computed(() => !!stats.error.value)
  /** A new answer is on its way and the old one is still drawn. */
  const refreshing = computed(() => stats.status.value === 'pending' && !!stats.data.value)

  function exportCsv() {
    const data = stats.data.value?.data
    if (!data) return
    saveTextFile(statsCsvName(data), statsCsv(data))
    toast.success('CSV descargado')
  }

  return { today, cutoff, view, lastCustom, stats, loading, failed, refreshing, setPeriod, setGrain, applyRange, exportCsv, retry: () => stats.refresh() }
}
