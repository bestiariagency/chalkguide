/** Head shared by every panel page: Spanish, noindex (the X-Robots-Tag header comes from routeRules). */
export function useAdminHead(title: MaybeRefOrGetter<string>) {
  useHead({
    // The layout default is already "Panel": do not repeat it ("Panel · Panel").
    title: () => (toValue(title) === 'Panel' ? 'Panel' : `${toValue(title)} · Panel`),
    htmlAttrs: { lang: 'es' },
    meta: [{ name: 'robots', content: 'noindex, nofollow' }],
  })
}
