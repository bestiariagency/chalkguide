import type { Database } from '~/types/database.types'
import { fetchSubscribers, fetchSubscribersSummary } from '~/services/admin/subscribers'
import {
  dateFieldFromSlug,
  defaultSubscriberView,
  emptySubscriberFilters,
  listArgs,
  viewFromSlug,
  type Subscriber,
  type SubscriberFilters,
  type SubscriberList,
  type SubscriberLocale,
  type SubscriberStatus,
  STATUS_FILTERS,
} from '~/utils/admin-subscribers'
import { relatedFromSlug, type RelatedStatus } from '~/utils/admin-subscribers-related'

/**
 * Suscriptores list (F6.14): view and filters live in the URL (`?vista=&origen=&idioma=&fecha=&desde=&hasta=
 * &version=&estado=&afines=&q=`); page, page size and sort are local and go back to page 1 whenever the view or a filter
 * changes. The server filters, sorts and pages (`admin_list_subscribers`); `known` remembers every row seen so a
 * selection that spans pages can still be checked before a bulk unsubscribe.
 */
export function useAdminSubscribers() {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const { text, setQuery } = useAdminUrlQuery()
  const list_ = (key: string) => text(key).split(',').filter(Boolean)

  const view = computed(() => viewFromSlug(route.query.vista) ?? defaultSubscriberView())
  const search = ref(text('q'))
  const debounced = useDebouncedValue(search, 300)
  const date = (key: string) => (/^\d{4}-\d{2}-\d{2}$/.test(text(key)) ? text(key) : '')
  const filters = computed<SubscriberFilters>(() => ({
    ...emptySubscriberFilters(),
    search: debounced.value,
    sources: list_('origen'),
    locale: (['es', 'en'].includes(text('idioma')) ? text('idioma') : '') as SubscriberLocale | '',
    dateField: dateFieldFromSlug(text('fecha')),
    from: date('desde'),
    to: date('hasta'),
    versions: list_('version').map(Number).filter((n) => Number.isInteger(n) && n > 0),
    statuses: list_('estado').filter((s): s is SubscriberStatus => STATUS_FILTERS.some((f) => f.value === s)),
    related: list_('afines').map(relatedFromSlug).filter((s): s is RelatedStatus => !!s),
  }))

  watch(debounced, (value) => void setQuery({ q: value.trim() || undefined }))

  // Page, size and sort: the page is only valid for the view and filters it was chosen in.
  const signature = computed(() => JSON.stringify([view.value, { ...filters.value, search: filters.value.search.trim() }]))
  const paging = ref({ signature: '', page: 0, pageSize: 25, sort: { id: 'consent', desc: true } as AdminTableQuery['sort'] })
  const tableQuery = computed<AdminTableQuery>({
    get: () => ({ search: '', sort: paging.value.sort, page: paging.value.signature === signature.value ? paging.value.page : 0, pageSize: paging.value.pageSize }),
    set: (q) => (paging.value = { signature: signature.value, page: q.page, pageSize: q.pageSize, sort: q.sort }),
  })

  const known = new Map<string, Subscriber>()
  const rows = ref<Subscriber[]>([])
  const result = ref<SubscriberList>()
  const summary = useAsyncData('admin-subscribers-summary', () => fetchSubscribersSummary(client), { server: false })
  const list = useAsyncData(
    'admin-subscribers',
    async () => {
      const q = tableQuery.value
      const found = await fetchSubscribers(client, listArgs(view.value, filters.value, q.sort, q.page, q.pageSize))
      for (const row of found.rows) known.set(row.id, row)
      rows.value = found.rows
      result.value = found
      return found.total
    },
    { server: false, watch: [view, filters, tableQuery] },
  )
  watch(view, () => (rows.value = []))

  /** Re-reads list and summary after an unsubscribe or an erasure. */
  async function reload() {
    await Promise.all([list.refresh(), summary.refresh()])
  }

  return { view, filters, search, setQuery, tableQuery, rows, result, list, summary: computed(() => summary.data.value), known, reload }
}
