export interface UrlListingConfig<T, S extends string, F extends string> {
  items: MaybeRefOrGetter<T[]>
  sortKeys: MaybeRefOrGetter<readonly S[]>
  defaultSort: S
  filterKeys: readonly F[]
  sort: (items: T[], key: S) => T[]
  filter: (items: T[], active: F[]) => T[]
  /** Text the search box looks into (name, area, services…). Omit for no search. */
  searchFields?: (item: T) => (string | null | undefined)[]
}

/**
 * Listing state in the URL (`?q=gracia&sort=price&f=lead,kids`): shareable and back-button friendly.
 * The search ignores accents and combines with the filters (AND).
 * The canonical stays the route without query (lince-max, README §6). Filtering and sorting
 * happen in the client over the already-fetched list. Query values are untrusted: unknown
 * values fall back to the default.
 */
export function useUrlListing<T, S extends string, F extends string>(
  config: UrlListingConfig<T, S, F>,
) {
  const route = useRoute()
  const router = useRouter()

  const sortKey = computed<S>(
    () => toValue(config.sortKeys).find((key) => key === route.query.sort) ?? config.defaultSort,
  )
  const active = computed<F[]>(() => {
    const raw = Array.isArray(route.query.f) ? route.query.f[0] : route.query.f
    if (typeof raw !== 'string') return []
    const wanted = raw.split(',')
    return config.filterKeys.filter((key) => wanted.includes(key))
  })

  function update(sort: S, filters: F[]) {
    const query = { ...route.query }
    if (sort === config.defaultSort) delete query.sort
    else query.sort = sort
    if (filters.length) query.f = filters.join(',')
    else delete query.f
    return router.replace({ query })
  }

  const search = useUrlSearch()
  const byChips = computed(() => config.filter(toValue(config.items), active.value))
  const filtered = computed(() => {
    const { searchFields } = config
    return searchFields
      ? byChips.value.filter((item) => matchesTokens(searchFields(item), search.tokens.value))
      : byChips.value
  })
  const sorted = computed(() => config.sort(filtered.value, sortKey.value))

  return {
    sortKey,
    active,
    sorted,
    query: search.query,
    tokens: search.tokens,
    hasQuery: search.hasQuery,
    clearQuery: search.clearQuery,
    total: computed(() => toValue(config.items).length),
    setSort: (key: S) => update(key, active.value),
    isActive: (key: F) => active.value.includes(key),
    toggle: (key: F) =>
      update(
        sortKey.value,
        active.value.includes(key) ? active.value.filter((k) => k !== key) : [...active.value, key],
      ),
    clear: () => update(sortKey.value, []),
  }
}
