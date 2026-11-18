import type { Database } from '~/types/database.types'
import { searchAdminContent } from '~/services/admin/search'
import { toResultRow, GROUP_LIMIT, KINDS, MIN_QUERY, SCOPES, SCOPE_LIMIT, type ResultRow, type SearchScope } from '~/utils/admin-search'

export interface SearchGroup {
  kind: string
  rows: ResultRow[]
  total: number
}

const DEBOUNCE_MS = 150
const SLOW_MS = 150
const CACHE_SIZE = 10

/**
 * Content search of the ⌘K palette: debounce 150 ms, late answers dropped (AbortController + request id), in-memory cache
 * of the last 10 queries of the session and per-scope counts taken from the last «Todo» answer.
 */
export function useAdminSearch(query: Ref<string>, scope: Ref<SearchScope>) {
  const client = useSupabaseClient<Database>()
  const groups = ref<SearchGroup[]>([])
  const status = ref<'idle' | 'loading' | 'ready' | 'error'>('idle')
  /** Answer is slow and there is nothing to show yet: skeleton rows. */
  const slow = ref(false)
  /** Query the shown groups answer to. */
  const answered = ref('')
  const counts = ref<Partial<Record<SearchScope, number>>>({})
  const cache = new Map<string, { groups: SearchGroup[]; counts?: Partial<Record<SearchScope, number>> }>()

  let controller: AbortController | undefined
  let timer: ReturnType<typeof setTimeout> | undefined
  let slowTimer: ReturnType<typeof setTimeout> | undefined
  let request = 0

  const term = computed(() => query.value.trim().slice(0, 100))
  const active = computed(() => term.value.length >= MIN_QUERY)

  function countsOf(found: SearchGroup[]) {
    const total = (kinds: string[] | null) => found.filter((g) => !kinds || kinds.includes(g.kind)).reduce((sum, g) => sum + g.total, 0)
    return Object.fromEntries(SCOPES.map((s) => [s.value, total(s.kinds)])) as Partial<Record<SearchScope, number>>
  }

  async function run(q: string, s: SearchScope) {
    controller?.abort()
    clearTimeout(slowTimer)
    const key = `${s}\u0000${q}`
    const hit = cache.get(key)
    if (hit) {
      groups.value = hit.groups
      if (hit.counts) counts.value = hit.counts
      answered.value = q
      status.value = 'ready'
      slow.value = false
      return
    }
    const mine = ++request
    controller = new AbortController()
    status.value = 'loading'
    if (!groups.value.length) slowTimer = setTimeout(() => mine === request && (slow.value = true), SLOW_MS)
    const kinds = SCOPES.find((x) => x.value === s)?.kinds ?? null
    try {
      const rows = await searchAdminContent(client, q, kinds, s === 'all' ? GROUP_LIMIT : SCOPE_LIMIT, controller.signal)
      if (mine !== request) return
      const found: SearchGroup[] = KINDS.map(({ kind }) => {
        const own = rows.filter((r) => r.kind === kind)
        return { kind, rows: own.map(toResultRow), total: own[0]?.total_in_kind ?? 0 }
      }).filter((g) => g.rows.length)
      const entry = { groups: found, counts: s === 'all' ? countsOf(found) : undefined }
      cache.set(key, entry)
      if (cache.size > CACHE_SIZE) cache.delete(cache.keys().next().value as string)
      groups.value = found
      if (entry.counts) counts.value = entry.counts
      answered.value = q
      status.value = 'ready'
    } catch (e) {
      if (mine !== request || (e as { name?: string }).name === 'AbortError') return
      status.value = 'error'
    } finally {
      if (mine === request) {
        clearTimeout(slowTimer)
        slow.value = false
      }
    }
  }

  function reset() {
    clearTimeout(timer)
    controller?.abort()
    request++
    groups.value = []
    counts.value = {}
    answered.value = ''
    status.value = 'idle'
    slow.value = false
  }

  watch([term, scope], ([q, s], [, before]) => {
    clearTimeout(timer)
    if (q.length < MIN_QUERY) return reset()
    timer = setTimeout(() => void run(q, s), s !== before ? 0 : DEBOUNCE_MS)
  })
  onScopeDispose(reset)

  return { groups, status, slow, answered, counts, active, term, retry: () => run(term.value, scope.value), reset }
}
