import type {
  Article,
  ArticleItemRef,
  ArticleSummary,
  CategoryNavItem,
  Locale,
  VisitType,
} from '~/types/domain'
import { type GuideClient, one, pick, unwrap } from './client'
import { MEDIA_COLUMNS, toMediaRef } from './media'
import { countArticlesByCategory, listArticles, listCategories } from './articles'

type ReviewEmbed = { visit_type: VisitType; has_en: boolean | null }

type LinkRow = {
  item: {
    id: string
    slug: string
    name: string
    category: ArticleItemRef['kind']
    summary_es: string | null
    summary_en: string | null
    has_en: boolean | null
    cover: unknown
    author_review: ReviewEmbed | ReviewEmbed[] | null
    shoe: { is_affiliate: boolean } | { is_affiliate: boolean }[] | null
  } | null
}

/**
 * Items an article mentions (guide.article_items) in editorial order: one query with embeds.
 * In English only items with an English version (D3, like the listings).
 */
export async function listItemsForArticle(
  db: GuideClient,
  locale: Locale,
  articleId: string,
): Promise<ArticleItemRef[]> {
  let query = db
    .from('article_items')
    .select(
      `sort_order, item:items!inner(id, slug, name, category, summary_es, summary_en, has_en,
        cover:media!items_cover_media_id_fkey(${MEDIA_COLUMNS}),
        author_review:author_reviews(visit_type, has_en), shoe:shoes(is_affiliate))`,
    )
    .eq('article_id', articleId)
    .eq('item.published', true)
  if (locale === 'en') query = query.eq('item.has_en', true)
  const rows = unwrap(await query.order('sort_order')) as unknown as LinkRow[]
  return rows.flatMap(({ item }) => {
    if (!item) return []
    const review = one(item.author_review)
    if (locale === 'en' && review && review.has_en !== true) return []
    return [
      {
        id: item.id,
        slug: item.slug,
        name: item.name,
        kind: item.category,
        summary: pick(locale, item.summary_es, item.summary_en),
        cover: toMediaRef(one(item.cover as Parameters<typeof toMediaRef>[0]), locale),
        visitType: review?.visit_type ?? null,
        isAffiliate: one(item.shoe)?.is_affiliate === true,
      },
    ]
  })
}

/** "Sigue leyendo": same category first, completed with the newest other articles. */
export async function listRelatedArticles(
  db: GuideClient,
  locale: Locale,
  article: Pick<Article, 'id' | 'categoryId'>,
  limit = 3,
): Promise<ArticleSummary[]> {
  const same = await listArticles(db, locale, {
    categoryId: article.categoryId,
    excludeIds: [article.id],
    limit,
  })
  if (same.length >= limit) return same
  const rest = await listArticles(db, locale, {
    excludeIds: [article.id, ...same.map((item) => item.id)],
    limit: limit - same.length,
  })
  return [...same, ...rest]
}

/** Category chips: only categories with live articles in this locale, in sort_order. */
export async function listCategoryNav(
  db: GuideClient,
  locale: Locale,
): Promise<{ items: CategoryNavItem[]; total: number }> {
  const [categories, counts] = await Promise.all([
    listCategories(db, locale),
    countArticlesByCategory(db, locale),
  ])
  const items = categories
    .map((category) => ({
      slug: category.slug,
      name: category.name,
      count: counts.get(category.id) ?? 0,
    }))
    .filter((category) => category.count > 0)
  return { items, total: items.reduce((sum, category) => sum + category.count, 0) }
}
