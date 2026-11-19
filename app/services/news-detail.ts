import type { Locale } from '~/types/domain'
import type { NewsDetail, NewsRelated, NewsRelatedKind } from '~/types/news'
import { type GuideClient, one, pick, unwrap, unwrapMaybe } from './client'
import { toMediaRef } from './media'
import { toNewsVideos } from '~/utils/news-videos'
import { NEWS_SUMMARY_COLUMNS, type NewsSummaryRow, toNewsSummary } from './news'

const DETAIL_COLUMNS = `${NEWS_SUMMARY_COLUMNS}, meta_description_es, meta_description_en, updated_at, has_en, source_url, source_title, source_published_on,
  source_lang, source:news_sources!news_source_id_fkey(trusted), image_license, image_credit,
  videos:news_videos(position, youtube_id, title, channel, lang)`

type VideoRow = { position: number; youtube_id: string; title: string | null; channel: string | null; lang: string | null }

type DetailRow = NewsSummaryRow & {
  meta_description_es: string | null
  meta_description_en: string | null
  updated_at: string
  has_en: boolean | null
  source_url: string
  source_title: string | null
  source_published_on: string | null
  source_lang: string | null
  source: { trusted: boolean } | { trusted: boolean }[] | null
  image: unknown
  image_license: string | null
  image_credit: string | null
  videos: VideoRow[] | null
}

/** News by slug; null if missing, not published, or (under /en) without an English version (D3). */
export async function getNewsBySlug(
  db: GuideClient,
  locale: Locale,
  slug: string,
): Promise<NewsDetail | null> {
  let query = db
    .from('news')
    .select(DETAIL_COLUMNS)
    .eq('status', 'published')
    .eq('slug', slug)
    .order('position', { referencedTable: 'videos' })
  if (locale === 'en') query = query.eq('has_en', true)
  const row = unwrapMaybe(await query.maybeSingle()) as unknown as DetailRow | null
  if (!row || !row.published_at) return null
  return {
    ...toNewsSummary(row, locale),
    metaDescription: pick(locale, row.meta_description_es, row.meta_description_en)?.trim() || null,
    updatedAt: row.updated_at,
    hasEn: row.has_en === true,
    sourceUrl: row.source_url,
    sourceTitle: row.source_title?.trim() || null,
    sourcePublishedOn: row.source_published_on,
    sourceLang: row.source_lang,
    // A manual or unknown source is not "verified": nofollow by default (D79).
    sourceTrusted: one(row.source)?.trusted === true,
    image: toMediaRef(one(row.image as Parameters<typeof toMediaRef>[0]), locale),
    imageLicense: row.image_license,
    imageCredit: row.image_credit,
    videos: toNewsVideos(row.videos),
  }
}

type LinkRow = {
  position: number
  item: { slug: string; name: string; category: 'gym' | 'resoler' | 'shoe'; has_en: boolean | null } | null
  article: {
    slug_es: string
    slug_en: string | null
    title_es: string
    title_en: string | null
    has_en: boolean | null
  } | null
  event: { title_es: string; title_en: string | null; has_en: boolean | null } | null
}

/** Up to 3 related pages chosen by Xavi (news_links): gym, article or event. Only what is public in this locale. */
export async function listNewsRelated(
  db: GuideClient,
  locale: Locale,
  newsId: string,
): Promise<NewsRelated[]> {
  const rows = unwrap(
    await db
      .from('news_links')
      .select(
        `position,
        item:items!news_links_item_id_fkey(slug, name, category, has_en),
        article:articles!news_links_article_id_fkey(slug_es, slug_en, title_es, title_en, has_en),
        event:events!news_links_event_id_fkey(title_es, title_en, has_en)`,
      )
      .eq('news_id', newsId)
      .order('position')
      .limit(3),
  ) as unknown as LinkRow[]
  const english = locale === 'en'
  return rows.flatMap((row): NewsRelated[] => {
    const item = one(row.item)
    if (item && (!english || item.has_en)) {
      return [{ kind: item.category as NewsRelatedKind, label: item.name, slug: item.slug }]
    }
    const article = one(row.article)
    const slug = article && pick(locale, article.slug_es, article.slug_en)
    if (article && slug && (!english || article.has_en)) {
      return [{ kind: 'article', label: pick(locale, article.title_es, article.title_en) ?? article.title_es, slug }]
    }
    const event = one(row.event)
    const title = event && pick(locale, event.title_es, event.title_en)
    if (event && title) return [{ kind: 'event', label: title, slug: null }]
    return []
  })
}
