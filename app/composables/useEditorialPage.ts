/**
 * Editorial page from guide.pages by key (about, transparency, privacy, cookies, legal_notice).
 * D3: under /en a page without a published English version is a 404. In Spanish an unpublished
 * page (e.g. legal drafts) is not an error: the page renders an "en preparación" notice.
 */
export async function useEditorialPage(key: string) {
  // Composables needing the instance run before the first await (no context after it).
  const locale = useGuideLocale()
  const { setPageLocales } = usePageLocales()
  const { data, error, refresh } = await usePageContent(key)
  if (!data.value && !error.value && locale.value === 'en') {
    throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true })
  }
  setPageLocales(data.value?.hasEn ? ['es', 'en'] : ['es'], { en: 'index' })
  return { page: data, error, refresh }
}
