import { type ListingKind, isCategoryIndexable } from '~/utils/seo'
import { type GuideClient, nowIso, ServiceError } from './client'

/**
 * Number of English elements of a listing (head count, no rows): decides whether the /en
 * listing exists as an indexable page and gets an hreflang from its Spanish twin (README §6, D3).
 */
export async function countEnglish(db: GuideClient, kind: ListingKind): Promise<number> {
  const query =
    kind === 'article'
      ? db
          .from('articles')
          .select('id', { count: 'exact', head: true })
          .in('status', ['published', 'scheduled'])
          .lte('published_at', nowIso())
      : kind === 'event'
        ? db
            .from('events')
            .select('id', { count: 'exact', head: true })
            .eq('status', 'approved')
            .gte('starts_at', nowIso())
            .lt('starts_at', new Date(Date.now() + 60 * 24 * 3600 * 1000).toISOString())
        : kind === 'news'
          ? db.from('news').select('id', { count: 'exact', head: true }).eq('status', 'published')
          : db
            .from('items')
            .select('id', { count: 'exact', head: true })
            .eq('category', kind)
            .eq('published', true)
  const { count, error } = await query.eq('has_en', true)
  if (error) throw new ServiceError(error.message, error.code)
  return count ?? 0
}

/**
 * Is the English version of a category indexable? (>= 3 English articles and its own English
 * text.) Needed on the Spanish category page to decide whether to emit the `en` hreflang.
 */
export async function isEnglishCategoryIndexable(db: GuideClient, categoryId: string) {
  const [articles, category] = await Promise.all([
    db
      .from('articles')
      .select('id', { count: 'exact', head: true })
      .in('status', ['published', 'scheduled'])
      .lte('published_at', nowIso())
      .eq('category_id', categoryId)
      .eq('has_en', true),
    db
      .from('article_categories')
      .select('description_en, has_en')
      .eq('id', categoryId)
      .maybeSingle(),
  ])
  if (articles.error) throw new ServiceError(articles.error.message, articles.error.code)
  if (category.error) throw new ServiceError(category.error.message, category.error.code)
  return (
    category.data?.has_en === true &&
    isCategoryIndexable(articles.count ?? 0, category.data.description_en)
  )
}
