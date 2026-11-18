const WRITE_DELAY_MS = 250

/**
 * Listing search text mirrored in `?q=`. The field filters instantly from the local ref; the
 * URL is rewritten (replace, no history entries) after a short pause. Query values are
 * untrusted: non-strings are dropped and the length is capped. Back/forward re-syncs the field.
 */
export function useUrlSearch() {
  const route = useRoute()
  const router = useRouter()

  const read = () => {
    const raw = Array.isArray(route.query.q) ? route.query.q[0] : route.query.q
    return typeof raw === 'string' ? raw.slice(0, MAX_QUERY_LENGTH) : ''
  }
  const query = ref(read())
  let pending: ReturnType<typeof setTimeout> | undefined

  function write() {
    pending = undefined
    const value = query.value.trim()
    if (value === read().trim()) return
    const next = { ...route.query }
    if (value) next.q = value
    else delete next.q
    return router.replace({ query: next })
  }

  watch(query, (value) => {
    if (value.length > MAX_QUERY_LENGTH) query.value = value.slice(0, MAX_QUERY_LENGTH)
    clearTimeout(pending)
    pending = setTimeout(write, WRITE_DELAY_MS)
  })
  watch(
    () => route.query.q,
    () => {
      if (!pending && read().trim() !== query.value.trim()) query.value = read()
    },
  )
  onScopeDispose(() => clearTimeout(pending))

  return {
    query,
    tokens: computed(() => searchTokens(query.value)),
    hasQuery: computed(() => query.value.trim().length > 0),
    clearQuery() {
      query.value = ''
      clearTimeout(pending)
      return write()
    },
  }
}
