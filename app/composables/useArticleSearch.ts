import { type ArticleSearchHit, searchArticles } from '~/services/article-search'

export const SEARCH_PAGE_SIZE = 20
export const MIN_SEARCH_LENGTH = 2

export type ArticleSearchStatus = 'loading' | 'ready' | 'error'
export type ArticleSearchScope = 'category' | 'all'

/**
 * Blog search (index and category): text in `?q=` (useUrlSearch), a short debounce, discarded
 * stale responses, and "load more" past 20 results. Client-only: the search never runs on the
 * server, so prerendered/ISR pages stay the plain listing. `categoryId` limits the search to a
 * category until the visitor widens it to the whole blog.
 */
export function useArticleSearch(categoryId?: MaybeRefOrGetter<string | undefined>) {
  const db = useGuideClient()
  const { track } = useTrack()
  const locale = useGuideLocale()
  const { query, hasQuery, clearQuery } = useUrlSearch()
  const term = useDebouncedValue(query, 250)

  const scope = ref<ArticleSearchScope>('category')
  const status = ref<ArticleSearchStatus>('loading')
  const hits = ref<ArticleSearchHit[]>([])
  const total = ref(0)
  const loadingMore = ref(false)
  const mounted = ref(false)
  let request = 0

  const cleanTerm = computed(() => term.value.replace(/\s+/g, ' ').trim())
  const tooShort = computed(() => hasQuery.value && query.value.trim().length < MIN_SEARCH_LENGTH)
  /** Search view replaces the listing only once hydrated (the SSR HTML is the plain listing). */
  const active = computed(() => mounted.value && cleanTerm.value.length >= MIN_SEARCH_LENGTH)
  const scopedCategory = computed(() =>
    scope.value === 'category' ? toValue(categoryId) : undefined,
  )
  const hasMore = computed(() => hits.value.length < total.value)

  async function run(offset: number) {
    const id = ++request
    if (offset === 0) status.value = 'loading'
    else loadingMore.value = true
    try {
      const page = await searchArticles(db, locale.value, {
        query: cleanTerm.value,
        categoryId: scopedCategory.value,
        limit: SEARCH_PAGE_SIZE,
        offset,
      })
      if (id !== request) return // a newer search superseded this one
      hits.value = offset === 0 ? page.hits : [...hits.value, ...page.hits]
      total.value = page.total
      status.value = 'ready'
      if (offset === 0) track('search_blog') // never the text searched (D69)
    } catch {
      if (id !== request) return
      if (offset === 0) status.value = 'error'
    } finally {
      if (id === request) loadingMore.value = false
    }
  }

  onMounted(() => (mounted.value = true))
  watch(
    [active, cleanTerm, scopedCategory, locale],
    () => {
      if (!active.value) {
        request++ // invalidate anything in flight
        return
      }
      void run(0)
    },
  )

  return {
    query,
    hasQuery,
    clearQuery,
    term: cleanTerm,
    scope,
    status,
    hits,
    total,
    loadingMore,
    hasMore,
    tooShort,
    active,
    retry: () => run(0),
    loadMore: () => run(hits.value.length),
  }
}
