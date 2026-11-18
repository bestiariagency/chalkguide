import { getNewsBySlug, listNewsRelated } from '~/services/news-detail'
import {
  getFeaturedNews,
  getNewsCategory,
  listHomeNews,
  listNews,
  listNewsCategoryNav,
  type ListNewsOptions,
} from '~/services/news'

/** One page of the news index or of a category (the key carries page, scope and category: a new page is a new fetch). */
export function useNewsList(
  options: MaybeRefOrGetter<Omit<ListNewsOptions, 'pageSize'>>,
  pageSize: number,
) {
  const key = () => {
    const o = toValue(options)
    return `news:${o.categoryId ?? 'all'}:${o.scope ?? 'all'}:${o.page}:${o.excludeId ?? ''}`
  }
  return useGuideData(key, (db, locale) => listNews(db, locale, { ...toValue(options), pageSize }))
}

export function useFeaturedNews(enabled: MaybeRefOrGetter<boolean>) {
  return useGuideData(
    () => `news-featured:${toValue(enabled)}`,
    async (db, locale) => (toValue(enabled) ? getFeaturedNews(db, locale) : null),
  )
}

export function useHomeNews() {
  return useGuideData('news-home', (db, locale) => listHomeNews(db, locale))
}

export function useNewsCategoryNav() {
  return useGuideData('news-category-nav', listNewsCategoryNav)
}

export function useNewsCategory(key: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `news-category:${toValue(key)}`,
    (db, locale) => getNewsCategory(db, locale, toValue(key)),
  )
}

export function useNewsItem(slug: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `news-item:${toValue(slug)}`,
    (db, locale) => getNewsBySlug(db, locale, toValue(slug)),
  )
}

export function useNewsRelated(newsId: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `news-related:${toValue(newsId)}`,
    (db, locale) => listNewsRelated(db, locale, toValue(newsId)),
  )
}

/** "More news" at the end of a news page: the 3 newest, without the current one. */
export function useMoreNews(excludeId: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `news-more:${toValue(excludeId)}`,
    async (db, locale) => (await listNews(db, locale, { page: 1, pageSize: 3, excludeId: toValue(excludeId) })).items,
  )
}
