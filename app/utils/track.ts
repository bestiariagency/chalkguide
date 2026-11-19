/**
 * Own analytics events (D69, layer 1): names, payload and what also goes to GA4 and Meta.
 * Pure helpers; the browser work lives in composables/useTrack.ts. The list is closed on the server
 * (`guide.track_event`), and `newsletter_confirmed` is written by the server only: never sent from here.
 */
export const TRACK_EVENTS = [
  'page_view',
  'newsletter_view',
  'newsletter_submit',
  'ficha_click',
  'affiliate_click',
  'outbound_gym',
  'login_for_review',
  'review_submitted',
  'scroll_75',
  'video_play',
  'search_blog',
] as const
export type TrackName = (typeof TRACK_EVENTS)[number]

/** What the page being read is. Articles carry `slug_es` and the category's `slug_es` also under /en. */
export interface TrackContext {
  contentType?: string
  contentSlug?: string
  pillar?: string
}

export interface TrackExtra extends TrackContext {
  /** `affiliate_click` only. */
  partner?: string
  /** `page_view` only: where the visit came from. */
  source?: TrackSource
}

export type TrackSource = 'organic' | 'social' | 'direct' | 'referral' | 'email' | 'other'
export type TrackDevice = 'mobile' | 'desktop'

/** Lower case, no query, no fragment, no trailing slash: the shape the server stores. */
export function normalizePath(path: string): string {
  const clean = (path.split('#')[0] ?? '').split('?')[0]?.toLowerCase() ?? ''
  return clean.length > 1 ? clean.replace(/\/+$/, '') : clean || '/'
}

const SEARCH_HOST = /(^|\.)(google|bing|duckduckgo|ecosia|yahoo|brave|qwant|yandex|baidu|startpage)\./
const SOCIAL_HOST = /(^|\.)(facebook|instagram|t|twitter|x|linkedin|lnkd|pinterest|reddit|youtube|tiktok|threads|whatsapp)\.(com|co|in|me|net)$/

/** Origin of a visit from the referrer and `utm_medium`. Only the category is kept, never the referrer. */
export function classifySource(referrer: string, ownHost: string, search: string): TrackSource {
  const medium = new URLSearchParams(search).get('utm_medium')?.toLowerCase()
  if (medium === 'email' || medium === 'newsletter') return 'email'
  if (!referrer) return 'direct'
  let host: string
  try {
    host = new URL(referrer).hostname.toLowerCase()
  } catch {
    return 'other'
  }
  if (host === ownHost) return 'direct'
  if (SEARCH_HOST.test(host)) return 'organic'
  if (SOCIAL_HOST.test(host)) return 'social'
  return 'referral'
}

/** Item detail pages (es and en) → `item_categories.key`, for `ficha_click`. */
const FICHA_PATH = /^\/(?:en\/)?(rocodromos|climbing-gyms|pies-de-gato|climbing-shoes|resolar-pies-de-gato|climbing-shoe-resoling)\/[^/]+$/
const FICHA_TYPE: Record<string, string> = {
  rocodromos: 'gym',
  'climbing-gyms': 'gym',
  'pies-de-gato': 'shoe',
  'climbing-shoes': 'shoe',
  'resolar-pies-de-gato': 'resoler',
  'climbing-shoe-resoling': 'resoler',
}

export function fichaTypeOf(pathname: string): string | null {
  const match = FICHA_PATH.exec(normalizePath(pathname))
  return match?.[1] ? (FICHA_TYPE[match[1]] ?? null) : null
}

/** `https://www.barrabes.com/…` → `barrabes`: the partner column only takes `[a-z0-9-]`. */
export function partnerFromUrl(href: string): string | undefined {
  try {
    const parts = new URL(href).hostname.toLowerCase().replace(/^www\./, '').split('.')
    const name = (parts.length > 1 ? parts.slice(0, -1) : parts).join('-').replace(/[^a-z0-9-]/g, '-')
    return /^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) && name.length <= 40 ? name : undefined
  } catch {
    return undefined
  }
}

/** Events that also reach GA4 and Meta, only with consent (spec §5). Everything else is layer 1 only. */
export const THIRD_PARTY: Partial<Record<TrackName, { ga?: string; meta?: { event: string; custom?: boolean } }>> = {
  page_view: { ga: 'page_view', meta: { event: 'PageView' } },
  newsletter_submit: { ga: 'generate_lead', meta: { event: 'Lead' } },
  affiliate_click: { ga: 'affiliate_click', meta: { event: 'AffiliateClick', custom: true } },
  ficha_click: { ga: 'select_content' },
  scroll_75: { ga: 'scroll_75' },
}

/** Parameters for GA4 and Meta: no free text, no personal data, no query string. */
export function thirdPartyParams(extra: TrackExtra, path: string, locale: string): Record<string, string> {
  const params: Record<string, string> = { page_path: path, locale }
  if (extra.contentType) params.content_type = extra.contentType
  if (extra.contentSlug) params.content_id = extra.contentSlug
  if (extra.pillar) params.pillar = extra.pillar
  if (extra.partner) params.partner = extra.partner
  return params
}
