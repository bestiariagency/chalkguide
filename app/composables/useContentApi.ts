/**
 * Editorial content with HTML (articles, pages, item reviews) comes from `/api/content/*` (D64): the
 * server sanitizes it, so the browser never gets raw `body_html` nor ships the sanitizer. On the
 * server `$fetch` is an internal call (no HTTP); on client navigation it is a plain GET. A 404 is
 * `null` (the pages decide what that means); any other failure is the `error` of useAsyncData.
 * Key is `${key}:${locale}`, as in useGuideData (same payload reuse on hydration).
 */
export function useContentData<T>(key: MaybeRefOrGetter<string>, path: MaybeRefOrGetter<string>) {
  const locale = useGuideLocale()
  return useAsyncData<T | null>(
    () => `${toValue(key)}:${locale.value}`,
    async () => {
      try {
        return await $fetch<T>(toValue(path), { query: { locale: locale.value } })
      } catch (error) {
        if ((error as { statusCode?: number }).statusCode === 404) return null
        throw error
      }
    },
  )
}
