/**
 * Robots for a guide listing: any search, filter, sort or comparison in the query string makes
 * it a filtered view → `noindex, follow` (the canonical, from useSiteSeo, is the route without
 * query). Without them, the listing's own value (English below its threshold, see
 * useListingSeo). Reactive: it flips as the visitor filters.
 */
export function useListingRobots(base?: string) {
  const route = useRoute()
  return computed(() =>
    LISTING_QUERY_KEYS.some((key) => route.query[key] !== undefined) ? ROBOTS_NOINDEX_FOLLOW : base,
  )
}
