import type { Locale } from '~/types/domain'
import type {
  NewsCategory,
  NewsCategoryNavItem,
  NewsPage,
  NewsScope,
  NewsSearchHit,
  NewsSummary,
} from '~/types/news'
import { pickHomeNews } from '~/utils/news'
import { type GuideClient, one, pick, ServiceError, unwrap, unwrapMaybe } from './client'

/** Columns of the anon grant on guide.news (J27): never anything outside it. */
export const NEWS_SUMMARY_COLUMNS = `id, slug, title_es, title_en, summary_es, summary_en, author_note_es, author_note_en,
  scope, source_name, published_at,
  category:news_categories!news_category_id_fkey(key, label_es, label_en)`

type CategoryEmbed = { key: string; label_es: string; label_en: string }

export type NewsSummaryRow = {
  id: string
  slug: string
  title_es: string
  title_en: string | null
  summary_es: string
  summary_en: string | null
  author_note_es: string | null
  author_note_en: string | null
  scope: NewsScope | null
  source_name: string
  published_at: string | null
  category: CategoryEmbed | CategoryEmbed[] | null
}

/** Empty or whitespace-only notes count as no note. */
function cleanNote(text: string | null): string | null {
  return text?.trim() ? text.trim() : null
}

export function toNewsSummary(row: NewsSummaryRow, locale: Locale): NewsSummary {
  const category = one(row.category)
  return {
    id: row.id,
    slug: row.slug,
    title: pick(locale, row.title_es, row.title_en) ?? row.title_es,
    summary: pick(locale, row.summary_es, row.summary_en) ?? row.summary_es,
    note: cleanNote(pick(locale, row.author_note_es, row.author_note_en)),
    categoryKey: category?.key ?? null,
    categoryName: category ? pick(locale, category.label_es, category.label_en) : null,
    scope: row.scope,
    sourceName: row.source_name,
    publishedAt: row.published_at ?? '',
  }
}

/** Published news; in English only those with a complete English version (D3). */
function publishedNews(db: GuideClient, columns: string, locale: Locale, count = false) {
  const query = db
    .from('news')
    .select(columns, count ? { count: 'exact' } : undefined)
    .eq('status', 'published')
    .not('published_at', 'is', null)
  return locale === 'en' ? query.eq('has_en', true) : query
}

export interface ListNewsOptions {
  categoryId?: string
  scope?: NewsScope
  /** 1-based page. */
  page: number
  pageSize: number
  excludeId?: string
}

/** One page of news, newest first, with the total for the pager. */
export async function listNews(
  db: GuideClient,
  locale: Locale,
  { categoryId, scope, page, pageSize, excludeId }: ListNewsOptions,
): Promise<NewsPage> {
  let query = publishedNews(db, NEWS_SUMMARY_COLUMNS, locale, true)
  if (categoryId) query = query.eq('category_id', categoryId)
  if (scope) query = query.eq('scope', scope)
  if (excludeId) query = query.neq('id', excludeId)
  const from = (page - 1) * pageSize
  const { data, error, count } = await query
    .order('published_at', { ascending: false })
    .range(from, from + pageSize - 1)
  if (error) throw new ServiceError(error.message, error.code)
  const rows = (data ?? []) as unknown as NewsSummaryRow[]
  return { items: rows.map((row) => toNewsSummary(row, locale)), total: count ?? rows.length }
}

/** The latest item with a "Nota de Xavi" published in the last `days` days (featured block). */
export async function getFeaturedNews(
  db: GuideClient,
  locale: Locale,
  days = 7,
): Promise<NewsSummary | null> {
  const since = new Date(Date.now() - days * 24 * 3600 * 1000).toISOString()
  const noteColumn = locale === 'en' ? 'author_note_en' : 'author_note_es'
  const rows = unwrap(
    await publishedNews(db, NEWS_SUMMARY_COLUMNS, locale)
      .not(noteColumn, 'is', null)
      .gte('published_at', since)
      .order('published_at', { ascending: false })
      .limit(5),
  ) as unknown as NewsSummaryRow[]
  const item = rows.map((row) => toNewsSummary(row, locale)).find((news) => news.note)
  return item ?? null
}

/** Latest news for the home block: the ones with a note first when they are from the last 7 days. */
export async function listHomeNews(db: GuideClient, locale: Locale, limit = 4): Promise<NewsSummary[]> {
  const rows = unwrap(
    await publishedNews(db, NEWS_SUMMARY_COLUMNS, locale)
      .order('published_at', { ascending: false })
      .limit(24),
  ) as unknown as NewsSummaryRow[]
  return pickHomeNews(rows.map((row) => toNewsSummary(row, locale)), limit)
}

type CategoryRow = {
  id: string
  key: string
  label_es: string
  label_en: string
  description_es: string | null
  description_en: string | null
}

function toCategory(row: CategoryRow, locale: Locale): NewsCategory {
  return {
    id: row.id,
    slug: row.key,
    name: pick(locale, row.label_es, row.label_en),
    description: pick(locale, row.description_es, row.description_en)?.trim() || null,
  }
}

export async function getNewsCategory(
  db: GuideClient,
  locale: Locale,
  key: string,
): Promise<NewsCategory | null> {
  const row = unwrapMaybe(
    await db
      .from('news_categories')
      .select('id, key, label_es, label_en, description_es, description_en')
      .eq('key', key)
      .maybeSingle(),
  )
  return row ? toCategory(row, locale) : null
}

/** Category chips: only the ones with news in this locale, with their count, plus the total ("Todo"). */
export async function listNewsCategoryNav(
  db: GuideClient,
  locale: Locale,
): Promise<{ items: NewsCategoryNavItem[]; total: number }> {
  const [categories, news] = await Promise.all([
    db
      .from('news_categories')
      .select('id, key, label_es, label_en, sort_order')
      .eq('active', true)
      .order('sort_order'),
    publishedNews(db, 'category_id', locale).limit(1000),
  ])
  const cats = unwrap(categories)
  const rows = unwrap(news) as unknown as { category_id: string }[]
  const counts = new Map<string, number>()
  for (const row of rows) counts.set(row.category_id, (counts.get(row.category_id) ?? 0) + 1)
  return {
    total: rows.length,
    items: cats.flatMap((cat) => {
      const count = counts.get(cat.id) ?? 0
      return count ? [{ slug: cat.key, name: pick(locale, cat.label_es, cat.label_en), count }] : []
    }),
  }
}

export interface NewsSearchParams {
  query: string
  categoryId?: string
  scope?: NewsScope
  limit: number
  offset: number
}

/** Full-text search over published news (`guide.search_news`); in English only the ones with an English version. */
export async function searchNews(
  db: GuideClient,
  locale: Locale,
  { query, categoryId, scope, limit, offset }: NewsSearchParams,
): Promise<{ hits: NewsSearchHit[]; total: number }> {
  const { data, error } = await db.rpc('search_news', {
    p_query: query,
    p_locale: locale,
    p_category_id: categoryId,
    p_limit: limit,
    p_offset: offset,
    p_scope: scope,
  })
  if (error) throw new ServiceError(error.message, error.code)
  const rows = (data ?? []) as unknown as {
    id: string
    slug: string | null
    title: string | null
    summary: string | null
    category_label: string | null
    scope: NewsScope | null
    has_note: boolean | null
    source_name: string | null
    published_at: string | null
    headline: string | null
    total_count: number | string | null
  }[]
  const hits = rows.flatMap((row): NewsSearchHit[] =>
    row.slug && row.title
      ? [
          {
            id: row.id,
            slug: row.slug,
            title: row.title,
            summary: row.summary ?? '',
            categoryName: row.category_label || null,
            scope: row.scope,
            hasNote: row.has_note === true,
            sourceName: row.source_name ?? '',
            publishedAt: row.published_at ?? '',
            headline: row.headline ?? '',
          },
        ]
      : [],
  )
  return { hits, total: Number(rows[0]?.total_count ?? 0) || hits.length }
}
