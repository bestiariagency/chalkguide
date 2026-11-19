import type { MediaRef } from '~/types/domain'

/** Geographic scope of a news item (guide.news_scope). */
export type NewsScope = 'cat' | 'es' | 'intl'

/** News row of lists, home and search. Every text field is plain text: render it interpolated, never as HTML (F8.1 F1). */
export interface NewsSummary {
  id: string
  slug: string
  title: string
  summary: string
  /** «Aporte propio» (why it matters, plain text) or null. */
  insight: string | null
  categoryKey: string | null
  categoryName: string | null
  scope: NewsScope | null
  sourceName: string
  publishedAt: string
  /** Licensed photo of the item (list thumbnail), when there is one. */
  image?: MediaRef | null
}

export interface NewsCategory {
  id: string
  /** Stable key; it is also the URL slug in both languages. */
  slug: string
  name: string
  description: string | null
}

export interface NewsCategoryNavItem {
  slug: string
  name: string
  count: number
}

/** YouTube video of a news item (D84/D88). `title` and `channel` are third-party text: interpolate, never HTML. */
export interface NewsVideo {
  youtubeId: string
  title: string | null
  channel: string | null
  /** Two-letter language code of the video, when Xavi set it. */
  lang: string | null
}

export interface NewsDetail extends NewsSummary {
  /** At most 2, already revalidated (FV3). */
  videos: NewsVideo[]
  /** Optional override Xavi writes (<= 160); without it the SEO description comes from the insight. */
  metaDescription: string | null
  updatedAt: string
  hasEn: boolean
  sourceUrl: string
  sourceTitle: string | null
  sourcePublishedOn: string | null
  sourceLang: string | null
  /** Source verified by Xavi (news_sources.trusted): without it the link carries nofollow (D79). */
  sourceTrusted: boolean
  image: MediaRef | null
  imageLicense: string | null
  imageCredit: string | null
}

export type NewsRelatedKind = 'gym' | 'resoler' | 'shoe' | 'article' | 'event'

export interface NewsRelated {
  kind: NewsRelatedKind
  label: string
  slug: string | null
}

export interface NewsSearchHit {
  id: string
  slug: string
  title: string
  summary: string
  categoryName: string | null
  scope: NewsScope | null
  categoryKey: string | null
  sourceName: string
  publishedAt: string
  /** Plain text with the matches between U+0002 and U+0003. */
  headline: string
}

export interface NewsPage {
  items: NewsSummary[]
  total: number
}
