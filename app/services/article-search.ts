import type { Locale } from '~/types/domain'
import { type GuideClient, ServiceError } from './client'

export interface ArticleSearchHit {
  id: string
  slug: string
  title: string
  excerpt: string | null
  category: { slug: string; name: string } | null
  publishedAt: string | null
  /** Plain text with the matches between U+0002 and U+0003 (see headlineParts). */
  headline: string
}

export interface ArticleSearchPage {
  hits: ArticleSearchHit[]
  total: number
}

export interface ArticleSearchParams {
  query: string
  categoryId?: string
  limit: number
  offset: number
}

/**
 * Full-text search over live articles (`guide.search_articles`). The RPC only returns what is
 * published, and in English only articles with an English version. Several returned columns can
 * be null even though the generated type says otherwise, so they are read defensively.
 */
export async function searchArticles(
  db: GuideClient,
  locale: Locale,
  { query, categoryId, limit, offset }: ArticleSearchParams,
): Promise<ArticleSearchPage> {
  const { data, error } = await db.rpc('search_articles', {
    p_query: query,
    p_locale: locale,
    p_category_id: categoryId,
    p_limit: limit,
    p_offset: offset,
  })
  if (error) throw new ServiceError(error.message, error.code)

  const rows = (data ?? []) as unknown as {
    id: string
    slug: string | null
    slug_es: string | null
    slug_en: string | null
    title: string | null
    excerpt: string | null
    category_slug: string | null
    category_name: string | null
    published_at: string | null
    headline: string | null
    total_count: number | string | null
  }[]

  const hits = rows.flatMap((row): ArticleSearchHit[] => {
    const slug = row.slug ?? (locale === 'en' ? row.slug_en : row.slug_es) ?? row.slug_es
    if (!slug || !row.title) return []
    return [
      {
        id: row.id,
        slug,
        title: row.title,
        excerpt: row.excerpt || null,
        category:
          row.category_slug && row.category_name
            ? { slug: row.category_slug, name: row.category_name }
            : null,
        publishedAt: row.published_at,
        headline: row.headline ?? '',
      },
    ]
  })
  return { hits, total: Number(rows[0]?.total_count ?? 0) || hits.length }
}
