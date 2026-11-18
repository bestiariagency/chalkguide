/**
 * URL state of a panel list: `text(key)` reads a string param ('' when missing) and `setQuery(patch)` merges a patch
 * into the current query (empty or `undefined` values are dropped), replacing the history entry.
 */
export function useAdminUrlQuery() {
  const route = useRoute()
  const text = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : '')
  function setQuery(patch: Record<string, string | undefined>) {
    const merged = { ...route.query, ...patch }
    return navigateTo({ query: Object.fromEntries(Object.entries(merged).filter(([, value]) => value)) }, { replace: true })
  }
  return { text, setQuery }
}
