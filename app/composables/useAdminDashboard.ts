import type { Database } from '~/types/database.types'
import {
  countProvisionalPages,
  countReviewsSince,
  fetchCalendarArticles,
  fetchCalendarEvents,
  fetchContentDrafts,
  fetchDashboardStats,
  fetchLastPublished,
  fetchReviewsSeenAt,
  fetchTimeseries,
} from '~/services/admin/dashboard'
import { fetchJobHealth } from '~/services/admin/job-health'
import { fetchNewsSummary } from '~/services/admin/news'

const WEEKS = 12

/** Data of the panel home (F6.3, v2 D52/D55): KPIs, pending, activity, charts and the editorial calendar (2 weeks or month). */
export function useAdminDashboard() {
  const client = useSupabaseClient<Database>()
  const today = dayKey(new Date())
  const month = ref(today.slice(0, 7))
  const stored = readStorage(CALENDAR_VIEW_KEY)
  const view = ref<CalendarView>(stored === 'month' ? 'month' : '2w')
  /** Monday of the first visible week in the 2-week view. */
  const start = ref(weekStart(today))
  watch(view, (value) => writeStorage(CALENDAR_VIEW_KEY, value))

  // Optional pieces never break the page: without them their row simply loses that part.
  const optional = <T>(run: Promise<T>, fallback: T) => run.catch(() => fallback)

  const summary = useAsyncData('admin-dashboard', async () => {
    const from = addDays(today, -7 * WEEKS)
    const [raw, drafts, series, totals, provisionalPages, lastPublished, news, health] = await Promise.all([
      fetchDashboardStats(client),
      fetchContentDrafts(client),
      fetchTimeseries(client, 'subscribers_new', from, today, 'week'),
      fetchTimeseries(client, 'subscribers_total', from, today, 'week'),
      optional(countProvisionalPages(client), 0),
      optional(fetchLastPublished(client), null),
      optional(fetchNewsSummary(client), null),
      optional(fetchJobHealth(client, HEALTH_JOBS), null),
    ])
    const { data } = await client.auth.getSession()
    const userId = data.session?.user.id
    const seen = userId ? await fetchReviewsSeenAt(client, userId) : null
    const since = seen ?? new Date(Date.now() - 30 * 86_400_000).toISOString()
    const newReviews = await countReviewsSince(client, since)
    return {
      stats: parseDashboardStats(raw),
      drafts,
      newReviews,
      provisionalPages,
      lastPublished,
      health,
      news: news ? { pending: news.pending, warnings: news.pendingWarnings, ingestFailing: news.health?.ok === false } : null,
      signups: series.map((p) => ({ bucket: p.bucket, value: Number(p.value) })),
      totals: totals.map((p) => Number(p.value)),
    }
  }, { server: false })

  /** Where the 14-day list (phones) begins: the visible weeks in 2-week view, today in month view. */
  const listFrom = computed(() => (view.value === '2w' ? start.value : today))

  const calendar = useAsyncData(
    'admin-calendar',
    async () => {
      const { from, to } = calendarWindow(view.value, month.value, start.value, listFrom.value)
      const [fromIso, toIso] = [new Date(`${from}T00:00:00`).toISOString(), new Date(`${to}T00:00:00`).toISOString()]
      const [articles, events] = await Promise.all([fetchCalendarArticles(client, fromIso, toIso), fetchCalendarEvents(client, fromIso, toIso)])
      return { articles, events }
    },
    { server: false, watch: [month, start, view] },
  )

  const revisedIds = computed(
    () => new Set((summary.data.value?.drafts ?? []).filter((d) => d.article_id).map((d) => d.article_id as string)),
  )
  const items = computed(() =>
    buildCalendarItems(calendar.data.value?.articles ?? [], calendar.data.value?.events ?? [], revisedIds.value),
  )
  const grid = computed(() => (view.value === 'month' ? buildMonthGrid(month.value, today, items.value) : buildWeeksGrid(start.value, today, items.value)))
  const upcoming = computed(() => buildUpcoming(listFrom.value, today, items.value))
  const title = computed(() => (view.value === 'month' ? monthTitle(month.value) : rangeTitle(start.value)))
  const step = (delta: 1 | -1) => (view.value === 'month' ? (month.value = shiftMonth(month.value, delta)) : (start.value = addDays(start.value, 14 * delta)))

  return {
    today,
    month,
    view,
    title,
    summary,
    calendar,
    grid,
    upcoming,
    prev: () => step(-1),
    next: () => step(1),
    refresh: () => Promise.all([summary.refresh(), calendar.refresh()]),
  }
}
