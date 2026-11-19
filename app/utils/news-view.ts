import { NEWS_VIEW_COOKIE } from './hero-intro'

export type NewsLayout = 'grid' | 'list'

export const parseNewsView = (value: unknown): NewsLayout | null => (value === 'grid' || value === 'list' ? value : null)

/**
 * Remembers the choice (§18.6): technical cookie the person asks for with a click (no consent needed, listed in /cookies).
 * Only called from the switch, never by default. Readable by the client (no HttpOnly): the head script copies it to <html>.
 */
export function rememberNewsView(view: NewsLayout, secure = location.protocol === 'https:') {
  document.cookie = `${NEWS_VIEW_COOKIE}=${view}; Max-Age=31536000; Path=/; SameSite=Lax${secure ? '; Secure' : ''}`
  document.documentElement.setAttribute('data-news-view', view)
}
