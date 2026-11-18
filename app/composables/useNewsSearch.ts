import { searchNews } from '~/services/news'
import type { NewsScope, NewsSearchHit } from '~/types/news'
import { MIN_SEARCH_LENGTH, SEARCH_PAGE_SIZE } from './useArticleSearch'

export type NewsSearchStatus = 'loading' | 'ready' | 'error'

/**
 * News search (index and category): text in `?q=`, short debounce, stale responses discarded,
 * "load more" past 20. Client-only (the SSR/ISR HTML is the plain listing). On a category page the
 * search stays inside that category.
 */
export function useNewsSearch(categoryId?: MaybeRefOrGetter<string | undefined>, scope?: MaybeRefOrGetter<NewsScope | null | undefined>) {
  const db = useGuideClient()
  const locale = useGuideLocale()
  const { query, hasQuery, clearQuery } = useUrlSearch()
  const term = useDebouncedValue(query, 250)

  const status = ref<NewsSearchStatus>('loading')
  const hits = ref<NewsSearchHit[]>([])
  const total = ref(0)
  const loadingMore = ref(false)
  const mounted = ref(false)
  let request = 0

  const cleanTerm = computed(() => term.value.replace(/\s+/g, ' ').trim())
  const tooShort = computed(() => hasQuery.value && query.value.trim().length < MIN_SEARCH_LENGTH)
  const active = computed(() => mounted.value && cleanTerm.value.length >= MIN_SEARCH_LENGTH)
  const hasMore = computed(() => hits.value.length < total.value)

  async function run(offset: number) {
    const id = ++request
    if (offset === 0) status.value = 'loading'
    else loadingMore.value = true
    try {
      const page = await searchNews(db, locale.value, {
        query: cleanTerm.value,
        categoryId: toValue(categoryId),
        scope: toValue(scope) ?? undefined,
        limit: SEARCH_PAGE_SIZE,
        offset,
      })
      if (id !== request) return
      hits.value = offset === 0 ? page.hits : [...hits.value, ...page.hits]
      total.value = page.total
      status.value = 'ready'
    } catch {
      if (id !== request) return
      if (offset === 0) status.value = 'error'
    } finally {
      if (id === request) loadingMore.value = false
    }
  }

  onMounted(() => (mounted.value = true))
  watch([active, cleanTerm, locale, () => toValue(scope)], () => {
    if (!active.value) {
      request++
      return
    }
    void run(0)
  })

  return {
    query,
    clearQuery,
    term: cleanTerm,
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
