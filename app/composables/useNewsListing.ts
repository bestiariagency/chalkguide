import type { NewsCategory, NewsScope } from '~/types/news'

export const NEWS_LIST_ANCHOR = 'news-list'

/**
 * State of the news index and of a category (same logic, two pages): page and scope come from the
 * query (`?pagina=`, `?alcance=`, untrusted, parsed), the list is one server page of 20, the featured
 * item only shows on page 1 of the unfiltered index (no category, no scope, no search), and the search
 * (`?q=`) replaces both. The featured item is removed from the list (not repeated) without shifting the pages.
 */
export async function useNewsListing(category?: MaybeRefOrGetter<NewsCategory | null | undefined>) {
  const route = useRoute()
  const router = useRouter()
  const page = computed(() => parseNewsPage(route.query.pagina))
  const scope = computed(() => parseNewsScope(route.query.alcance))
  // The scope filter also narrows the search (`p_scope`).
  const search = useNewsSearch(() => toValue(category)?.id, scope)
  const isIndex = computed(() => !toValue(category))

  const showFeatured = computed(() => isIndex.value && page.value === 1 && !scope.value && !search.active.value && !route.query.q)
  // One round of requests: an `await` between composables would lose the Nuxt instance.
  if (import.meta.client) {
    // Page changes keep the header in view: back to the start of the list.
    watch(page, () => document.getElementById(NEWS_LIST_ANCHOR)?.scrollIntoView({ block: 'start' }))
  }
  const [featured, list, nav] = await Promise.all([
    useFeaturedNews(isIndex),
    useNewsList(
      () => ({ categoryId: toValue(category)?.id, scope: scope.value ?? undefined, page: page.value }),
      NEWS_PAGE_SIZE,
    ),
    useNewsCategoryNav(),
  ])

  const featuredItem = computed(() => (showFeatured.value ? (featured.data.value ?? null) : null))
  const items = computed(() =>
    (list.data.value?.items ?? []).filter((item) => item.id !== featuredItem.value?.id),
  )
  const total = computed(() => list.data.value?.total ?? 0)
  const pages = computed(() => Math.max(1, Math.ceil(total.value / NEWS_PAGE_SIZE)))

  function setScope(value: NewsScope | null) {
    const query = { ...route.query }
    delete query.pagina
    if (value) query.alcance = value
    else delete query.alcance
    return router.replace({ query })
  }

  return { page, scope, setScope, featured: featuredItem, items, total, pages, list, nav, search }
}
