import type { Article } from '~/types/domain'
import {
  listCategoryNav,
  listItemsForArticle,
  listRelatedArticles,
} from '~/services/article-relations'
import {
  type ListArticlesOptions,
  getCategoryBySlug,
  listArticles,
} from '~/services/articles'

export function useArticles(key: string, options: ListArticlesOptions = {}) {
  return useGuideData(`articles:${key}`, (db, locale) => listArticles(db, locale, options))
}

export function useArticle(slug: MaybeRefOrGetter<string>) {
  return useContentData<Article>(
    () => `article:${toValue(slug)}`,
    () => `/api/content/article/${encodeURIComponent(toValue(slug))}`,
  )
}

export function useArticleCategory(slug: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `article-category:${toValue(slug)}`,
    (db, locale) => getCategoryBySlug(db, locale, toValue(slug)),
  )
}

/** Items and related articles of an article; fetched in parallel once the article is known. */
export function useArticleRelations(article: MaybeRefOrGetter<Pick<Article, 'id' | 'categoryId'>>) {
  const id = () => toValue(article).id
  const items = useGuideData(
    () => `article-items:${id()}`,
    (db, locale) => listItemsForArticle(db, locale, id()),
  )
  const related = useGuideData(
    () => `article-related:${id()}`,
    (db, locale) => listRelatedArticles(db, locale, toValue(article)),
  )
  return { items, related }
}

export function useCategoryNav() {
  return useGuideData('category-nav', listCategoryNav)
}
