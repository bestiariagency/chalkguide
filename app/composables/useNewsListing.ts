import type { NewsCategory, NewsScope } from '~/types/news'

export const NEWS_LIST_ANCHOR = 'news-list'

/**
 * State of the news index and of a category (same logic, two pages): page and scope come from the
 * query (`?pagina=`, `?alcance=`, untrusted, parsed), the list is one server page of 21 and the search (`?q=`) replaces it.
 * The opener and the two sides of the front page (§18.1) are positions inside that same page, not another query.
 */
export async function useNewsListing(category?: MaybeRefOrGetter<NewsCategory | null | undefined>) {
  const route = useRoute()
  const router = useRouter()
  const page = computed(() => parseNewsPage(route.query.pagina))
  const scope = computed(() => parseNewsScope(route.query.alcance))
  // The scope filter also narrows the search (`p_scope`).
  const search = useNewsSearch(() => toValue(category)?.id, scope)
  // One round of requests: an `await` between composables would lose the Nuxt instance.
  if (import.meta.client) {
    // Page changes keep the header in view: back to the start of the list.
    watch(page, () => document.getElementById(NEWS_LIST_ANCHOR)?.scrollIntoView({ block: 'start' }))
  }
  const [list, nav] = await Promise.all([
    useNewsList(
      () => ({ categoryId: toValue(category)?.id, scope: scope.value ?? undefined, page: page.value }),
      NEWS_PAGE_SIZE,
    ),
    useNewsCategoryNav(),
  ])

  const items = computed(() => list.data.value?.items ?? [])
  const total = computed(() => list.data.value?.total ?? 0)
  const pages = computed(() => Math.max(1, Math.ceil(total.value / NEWS_PAGE_SIZE)))

  function setScope(value: NewsScope | null) {
    const query = { ...route.query }
    delete query.pagina
    if (value) query.alcance = value
    else delete query.alcance
    return router.replace({ query })
  }

  return { page, scope, setScope, items, total, pages, list, nav, search }
}
