import type { Article, ArticleCategory, AuthorProfile, ArticleSummary, Locale, RawBody } from '~/types/domain'
import { type GuideClient, nowIso, one, pick, unwrap, unwrapMaybe } from './client'
import { MEDIA_COLUMNS, refreshBodyHtml, toMediaRef } from './media'
import { cleanText } from '~/utils/author'

export const SUMMARY_COLUMNS = `id, slug_es, slug_en, title_es, title_en, excerpt_es, excerpt_en,
  published_at, updated_at, is_featured, has_en, reading_minutes_es, reading_minutes_en,
  category:article_categories!articles_category_id_fkey(slug_es, slug_en, name_es, name_en),
  cover:media!articles_cover_media_id_fkey(${MEDIA_COLUMNS})`

const DETAIL_COLUMNS = `${SUMMARY_COLUMNS}, category_id, body_html_es, body_html_en,
  seo_title_es, seo_title_en, seo_description_es, seo_description_en, noindex,
  author:authors!articles_author_id_fkey(slug, name, role_es, role_en, bio_es, bio_en,
    photo:media!authors_photo_media_id_fkey(${MEDIA_COLUMNS}))`

type AuthorEmbed = {
  name: string
  role_es: string | null
  role_en: string | null
  bio_es: string | null
  bio_en: string | null
  photo: unknown
}

/** Article author (guide.authors) as a profile; null = the site author (site_settings). */
function toAuthor(embed: unknown, locale: Locale): AuthorProfile | null {
  const row = one(embed as AuthorEmbed | AuthorEmbed[] | null)
  if (!row) return null
  return {
    name: cleanText(row.name),
    role: cleanText(pick(locale, row.role_es, row.role_en)),
    lede: null,
    bio: cleanText(pick(locale, row.bio_es, row.bio_en)),
    photo: toMediaRef(one(row.photo as Parameters<typeof toMediaRef>[0]), locale),
    stats: [],
  }
}

type SummaryRow = {
  id: string
  slug_es: string
  slug_en: string | null
  title_es: string
  title_en: string | null
  excerpt_es: string | null
  excerpt_en: string | null
  published_at: string | null
  updated_at: string
  is_featured: boolean
  has_en: boolean | null
  reading_minutes_es: number | null
  reading_minutes_en: number | null
  category: unknown
  cover: unknown
}

type CategoryEmbed = {
  slug_es: string
  slug_en: string | null
  name_es: string
  name_en: string | null
}

export function toSummary(row: SummaryRow, locale: Locale): ArticleSummary {
  const category = one(row.category as CategoryEmbed | CategoryEmbed[] | null)
  const categorySlug = category && pick(locale, category.slug_es, category.slug_en)
  const categoryName = category && pick(locale, category.name_es, category.name_en)
  return {
    id: row.id,
    slug: pick(locale, row.slug_es, row.slug_en) ?? row.slug_es,
    slugs: { es: row.slug_es, ...(row.slug_en ? { en: row.slug_en } : {}) },
    title: pick(locale, row.title_es, row.title_en) ?? row.title_es,
    excerpt: pick(locale, row.excerpt_es, row.excerpt_en),
    category: categorySlug && categoryName && category ? { slug: categorySlug, slugEs: category.slug_es, name: categoryName } : null,
    cover: toMediaRef(one(row.cover as Parameters<typeof toMediaRef>[0]), locale),
    publishedAt: row.published_at,
    updatedAt: row.updated_at,
    readingMinutes: pick(locale, row.reading_minutes_es, row.reading_minutes_en),
    isFeatured: row.is_featured,
    hasEn: row.has_en === true,
  }
}

/** Live articles only (also when an admin session would let RLS return drafts). */
export function liveArticles(db: GuideClient, columns: string, locale: Locale) {
  let query = db
    .from('articles')
    .select(columns)
    .in('status', ['published', 'scheduled'])
    .lte('published_at', nowIso())
  if (locale === 'en') query = query.eq('has_en', true)
  return query
}

export interface ListArticlesOptions {
  limit?: number
  featuredFirst?: boolean
  /** Editorial order inside a category (articles.sort_order) instead of newest first. */
  bySortOrder?: boolean
  categoryId?: string
  excludeIds?: string[]
}

export async function listArticles(
  db: GuideClient,
  locale: Locale,
  { limit = 12, featuredFirst = false, bySortOrder = false, categoryId, excludeIds = [] }: ListArticlesOptions = {},
): Promise<ArticleSummary[]> {
  let query = liveArticles(db, SUMMARY_COLUMNS, locale)
  if (categoryId) query = query.eq('category_id', categoryId)
  if (excludeIds.length) query = query.not('id', 'in', `(${excludeIds.join(',')})`)
  if (featuredFirst) query = query.order('is_featured', { ascending: false })
  if (bySortOrder) query = query.order('sort_order')
  const rows = unwrap(await query.order('published_at', { ascending: false }).limit(limit))
  return (rows as unknown as SummaryRow[]).map((row) => toSummary(row, locale))
}

/** Live articles that mention an item (guide.article_items), in editorial order. */
export async function listArticlesForItem(
  db: GuideClient,
  locale: Locale,
  itemId: string,
  limit = 4,
): Promise<ArticleSummary[]> {
  const rows = unwrap(
    await liveArticles(db, `${SUMMARY_COLUMNS}, article_items!inner(item_id)`, locale)
      .eq('article_items.item_id', itemId)
      .order('published_at', { ascending: false })
      .limit(limit),
  )
  return (rows as unknown as SummaryRow[]).map((row) => toSummary(row, locale))
}

/** Article by its slug in the current locale; null if missing or without an English version. */
export async function getArticleBySlug(
  db: GuideClient,
  locale: Locale,
  slug: string,
): Promise<RawBody<Article> | null> {
  const row = unwrapMaybe(
    await liveArticles(db, DETAIL_COLUMNS, locale)
      .eq(locale === 'en' ? 'slug_en' : 'slug_es', slug)
      .maybeSingle(),
  ) as unknown as
    | (SummaryRow & {
        body_html_es: string
        body_html_en: string | null
        seo_title_es: string | null
        seo_title_en: string | null
        seo_description_es: string | null
        seo_description_en: string | null
        noindex: boolean
        category_id: string
        author: unknown
      })
    | null
  if (!row) return null
  return {
    ...toSummary(row, locale),
    categoryId: row.category_id,
    author: toAuthor(row.author, locale),
    bodyHtml: await refreshBodyHtml(db, pick(locale, row.body_html_es, row.body_html_en) ?? ''),
    seoTitle: pick(locale, row.seo_title_es, row.seo_title_en),
    seoDescription: pick(locale, row.seo_description_es, row.seo_description_en),
    noindex: row.noindex,
  }
}

const CATEGORY_COLUMNS =
  'id, slug_es, slug_en, name_es, name_en, description_es, description_en, has_en'

type CategoryRow = {
  id: string
  slug_es: string
  slug_en: string | null
  name_es: string
  name_en: string | null
  description_es: string | null
  description_en: string | null
  has_en: boolean | null
}

function toCategory(row: CategoryRow, locale: Locale): ArticleCategory {
  return {
    id: row.id,
    slug: pick(locale, row.slug_es, row.slug_en) ?? row.slug_es,
    slugs: { es: row.slug_es, ...(row.slug_en ? { en: row.slug_en } : {}) },
    name: pick(locale, row.name_es, row.name_en) ?? row.name_es,
    description: pick(locale, row.description_es, row.description_en),
    hasEn: row.has_en === true,
  }
}

export async function listCategories(db: GuideClient, locale: Locale): Promise<ArticleCategory[]> {
  let query = db.from('article_categories').select(CATEGORY_COLUMNS)
  if (locale === 'en') query = query.eq('has_en', true)
  const rows = unwrap(await query.order('sort_order'))
  return rows.map((row) => toCategory(row, locale))
}

export async function getCategoryBySlug(
  db: GuideClient,
  locale: Locale,
  slug: string,
): Promise<ArticleCategory | null> {
  const row = unwrapMaybe(
    await db
      .from('article_categories')
      .select(CATEGORY_COLUMNS)
      .eq(locale === 'en' ? 'slug_en' : 'slug_es', slug)
      .maybeSingle(),
  )
  return row ? toCategory(row, locale) : null
}

/** Live article count per category id (one light query; counted here, categories are few). */
export async function countArticlesByCategory(
  db: GuideClient,
  locale: Locale,
): Promise<Map<string, number>> {
  const rows = unwrap(await liveArticles(db, 'category_id', locale)) as unknown as {
    category_id: string
  }[]
  const counts = new Map<string, number>()
  for (const row of rows) counts.set(row.category_id, (counts.get(row.category_id) ?? 0) + 1)
  return counts
}
