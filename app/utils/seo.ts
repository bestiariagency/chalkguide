/**
 * SEO rules shared by the app (head) and the server (sitemap). Pure functions, no auto-imports:
 * `server/` imports this file with a relative path, so both sides apply the exact same rule
 * (README de diseño §6 / §6.x).
 */
export type SeoLocale = 'es' | 'en'

export const SEO_BRAND = 'ChalkGuide'
export const SEO_BRAND_SUFFIX = ` · ${SEO_BRAND}`
export const MAX_TITLE_LENGTH = 60
export const MAX_DESCRIPTION_LENGTH = 158

export const ROBOTS_NOINDEX_FOLLOW = 'noindex, follow'
export const ROBOTS_NOINDEX_NOFOLLOW = 'noindex, nofollow'

/**
 * Brand suffix only when the whole title still fits in 60 characters; a long descriptive title
 * is better served without the brand (it is still in og:site_name and the header).
 */
export function titleWithBrand(title: string | undefined | null): string | undefined {
  if (!title) return undefined
  // The home title already carries the brand: do not repeat it.
  if (title.includes(SEO_BRAND)) return title
  return title.length + SEO_BRAND_SUFFIX.length <= MAX_TITLE_LENGTH ? title + SEO_BRAND_SUFFIX : title
}

/** Plain text cut at a word boundary, ending in an ellipsis if shortened. */
export function clampDescription(text: string | null | undefined, max = MAX_DESCRIPTION_LENGTH) {
  const clean = (text ?? '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
  if (!clean) return undefined
  if (clean.length <= max) return clean
  const cut = clean.slice(0, max - 1)
  return `${cut.slice(0, Math.max(cut.lastIndexOf(' '), max / 2))}…`
}

/** Routes that are never indexed, by Nuxt route base name (§6: legal, utility, newsletter states). */
export const ROUTE_ROBOTS: Record<string, string> = {
  'newsletter-confirmed': ROBOTS_NOINDEX_NOFOLLOW,
  'newsletter-unsubscribed': ROBOTS_NOINDEX_NOFOLLOW,
  'newsletter-preferences': ROBOTS_NOINDEX_NOFOLLOW,
  'sign-in': ROBOTS_NOINDEX_NOFOLLOW,
  privacy: ROBOTS_NOINDEX_FOLLOW,
  cookies: ROBOTS_NOINDEX_FOLLOW,
  'legal-notice': ROBOTS_NOINDEX_FOLLOW,
}

/** Blog category: indexable only with >= 3 live articles and its own introductory text. */
export const MIN_CATEGORY_ARTICLES = 3
export function isCategoryIndexable(articleCount: number, description: string | null | undefined) {
  return articleCount >= MIN_CATEGORY_ARTICLES && !!description?.trim()
}

/**
 * An /en listing is indexable (and gets hreflang) with enough translated elements:
 * >= 5 gyms, >= 3 of everything else, >= 1 upcoming event for the agenda hub.
 */
export type ListingKind = 'gym' | 'resoler' | 'shoe' | 'article' | 'event' | 'news'
export const MIN_ENGLISH_LISTING: Record<ListingKind, number> = {
  gym: 5,
  resoler: 3,
  shoe: 3,
  article: 3,
  event: 1,
  news: 3,
}
export function isEnglishListingReady(kind: ListingKind, count: number) {
  return count >= MIN_ENGLISH_LISTING[kind]
}

/** `yyyy-mm` key of a date (local time of the server/browser, like the agenda pages). */
export function monthKeyOf(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

/** Agenda month: indexable only for the current or a future month with at least one event. */
export function isMonthIndexable(key: string, eventCount: number, now = new Date()) {
  return eventCount > 0 && key >= monthKeyOf(now)
}

/** Query keys that turn a listing into a filtered view: `noindex, follow` with the clean canonical. */
export const LISTING_QUERY_KEYS = [
  'q', 'sort', 'f', 'nivel', 'perfil', 'cierre', 'rigidez', 'uso', 'min', 'max', 'mios', 'comparar',
  'pagina', 'alcance',
] as const

/** Words an «Aporte propio» needs for its news page to be indexable (D92; the DB `indexable` column counts the same way). */
export const MIN_NEWS_INSIGHT_WORDS = 80
/** The /noticias index is indexable from this many published news items (D79). */
export const MIN_NEWS_INDEX = 6

export function insightWordCount(text: string | null | undefined) {
  const clean = (text ?? '').trim()
  return clean ? clean.split(/\s+/).length : 0
}

/**
 * News page: indexable only when published and carrying an «Aporte propio» of >= 80 words (D92);
 * a page that only summarises someone else's source adds nothing and goes `noindex, follow`.
 * Shared by the page head and (8.11) the sitemap, so they never disagree.
 */
export function isNewsIndexable({ insight, published = true }: { insight: string | null | undefined; published?: boolean }) {
  return published && insightWordCount(insight) >= MIN_NEWS_INSIGHT_WORDS
}

/** /noticias index (page 1, no query): indexable from 6 published items. */
export function isNewsIndexIndexable(count: number) {
  return count >= MIN_NEWS_INDEX
}

/** News category: same rule as the blog (>= 3 items and its own text). */
export function isNewsCategoryIndexable(count: number, description: string | null | undefined) {
  return isCategoryIndexable(count, description)
}
