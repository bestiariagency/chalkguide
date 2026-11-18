import type { ShoeSummary } from '~/types/domain'

const RANGE_DEBOUNCE_MS = 250

/**
 * Comparator state in the URL: `?q=scarpa&comparar=a,b&perfil=flat&cierre=velcro&rigidez=soft&uso=gym
 * &min=40&max=120&mios=1`. Shareable; filters update the URL with `replace` (no history entry per click, so Back leaves the page); the canonical (from
 * @nuxtjs/i18n) stays the route without query. Query values are untrusted: unknown slugs and
 * values are dropped, at most MAX_COMPARE models. The price range is kept in local state
 * while dragging and written to the URL after a short pause.
 */
export function useShoeComparator(shoes: MaybeRefOrGetter<ShoeSummary[]>) {
  const route = useRoute()
  const router = useRouter()

  const all = computed(() => toValue(shoes))
  const bounds = computed(() => priceBounds(all.value))
  const options = computed(() => filterOptions(all.value))

  const queryNumber = (raw: unknown, fallback: number) => {
    const value = Number(Array.isArray(raw) ? raw[0] : raw)
    return Number.isFinite(value) && raw !== undefined && raw !== '' ? value : fallback
  }
  const readRange = (): [number, number] => {
    const { min, max } = bounds.value
    const lo = Math.min(Math.max(queryNumber(route.query.min, min), min), max)
    const hi = Math.min(Math.max(queryNumber(route.query.max, max), min), max)
    return lo <= hi ? [lo, hi] : [min, max]
  }
  const range = ref<[number, number]>(readRange())
  let pending: ReturnType<typeof setTimeout> | undefined
  watch(
    () => [route.query.min, route.query.max],
    () => {
      if (!pending) range.value = readRange()
    },
  )

  const filters = computed<ShoeFilters>(() => ({
    level: parseList(route.query.nivel, SHOE_LEVELS),
    profile: parseList(route.query.perfil, SHOE_PROFILES),
    closure: parseList(route.query.cierre, SHOE_CLOSURES),
    stiffness: parseList(route.query.rigidez, STIFFNESS_GROUPS),
    use: parseList(route.query.uso, SHOE_USES),
    owned: route.query.mios === '1',
    min: range.value[0],
    max: range.value[1],
  }))

  // `?q=`: brand, model and rubber, accent-insensitive, combined with the filters (AND).
  const search = useUrlSearch()
  const sort = computed(() => parseSort(route.query.sort))
  const counts = computed(() => filterCounts(all.value))
  const results = computed(() =>
    sortShoes(
      filterShoes(all.value, filters.value, bounds.value).filter((shoe) =>
        matchesTokens(shoeSearchFields(shoe), search.tokens.value),
      ),
      sort.value,
    ),
  )
  const activeCount = computed(() => {
    const f = filters.value
    const priced = f.min > bounds.value.min || f.max < bounds.value.max
    return f.level.length + f.profile.length + f.closure.length + f.stiffness.length + f.use.length +
      Number(f.owned) + Number(priced)
  })

  // The chosen models are local and optimistic (router.replace can take a while in dev); the
  // URL stays the source on load and on back/forward (synced when no write is in flight).
  const urlSlugs = computed(() => {
    const raw = Array.isArray(route.query.comparar) ? route.query.comparar[0] : route.query.comparar
    const known = new Set(all.value.map((s) => s.slug))
    const slugs = typeof raw === 'string' ? raw.split(',').filter((s) => known.has(s)) : []
    return [...new Set(slugs)].slice(0, MAX_COMPARE)
  })
  const localSlugs = ref<string[]>(urlSlugs.value)
  let inflight = 0
  watch(urlSlugs, (slugs) => {
    if (!inflight) localSlugs.value = slugs
  })
  const selectedSlugs = computed(() => localSlugs.value)
  function writeSelection(slugs: string[]) {
    localSlugs.value = slugs
    inflight++
    return Promise.resolve(writeQuery({ comparar: list(slugs) })).finally(() => {
      if (--inflight === 0) localSlugs.value = urlSlugs.value
    })
  }
  const selected = computed(() =>
    selectedSlugs.value.flatMap((slug) => all.value.find((s) => s.slug === slug) ?? []),
  )

  function writeQuery(patch: Record<string, string | undefined>) {
    const query = Object.fromEntries(
      Object.entries({ ...route.query, ...patch }).filter(([, value]) => value),
    )
    return router.replace({ query })
  }
  const list = (values: string[]) => (values.length ? values.join(',') : undefined)

  function writeRange() {
    pending = undefined
    const [lo, hi] = range.value
    return writeQuery({
      min: lo > bounds.value.min ? String(lo) : undefined,
      max: hi < bounds.value.max ? String(hi) : undefined,
    })
  }
  function setRange(value: [number, number]) {
    range.value = value
    clearTimeout(pending)
    pending = setTimeout(writeRange, RANGE_DEBOUNCE_MS)
  }
  onScopeDispose(() => clearTimeout(pending))

  const queryKey: Record<ShoeListKey, string> = {
    level: 'nivel',
    profile: 'perfil',
    closure: 'cierre',
    stiffness: 'rigidez',
    use: 'uso',
  }

  return {
    results,
    query: search.query,
    tokens: search.tokens,
    hasQuery: search.hasQuery,
    clearQuery: search.clearQuery,
    filters,
    options,
    counts,
    sort,
    bounds,
    range,
    activeCount,
    selected,
    selectedSlugs,
    isFull: computed(() => selectedSlugs.value.length >= MAX_COMPARE),
    setRange,
    setList: (key: ShoeListKey, values: string[]) => writeQuery({ [queryKey[key]]: list(values) }),
    setSort: (value: ShoeSort) => writeQuery({ sort: value === 'price-asc' ? undefined : value }),
    setOwned: (owned: boolean) => writeQuery({ mios: owned ? '1' : undefined }),
    clearFilters() {
      clearTimeout(pending)
      pending = undefined
      range.value = [bounds.value.min, bounds.value.max]
      return writeQuery({
        nivel: undefined, perfil: undefined, cierre: undefined, rigidez: undefined, uso: undefined,
        mios: undefined, min: undefined, max: undefined,
      })
    },
    isSelected: (slug: string) => selectedSlugs.value.includes(slug),
    /** No-op when it is already there or the comparison is full (the UI asks which to replace). */
    add(slug: string) {
      const current = selectedSlugs.value
      if (current.includes(slug) || current.length >= MAX_COMPARE) return
      return writeSelection([...current, slug])
    },
    remove: (slug: string) => writeSelection(selectedSlugs.value.filter((s) => s !== slug)),
    replace: (oldSlug: string, newSlug: string) =>
      writeSelection(selectedSlugs.value.map((s) => (s === oldSlug ? newSlug : s))),
  }
}
