import type { LocaleRouteTo } from '~/types/ui'
import type { NewsRelatedKind, NewsScope, NewsSummary } from '~/types/news'
import { intlLocale } from './dates'

export const NEWS_PAGE_SIZE = 20
export const NEWS_SCOPES: readonly NewsScope[] = ['cat', 'es', 'intl']
const NEWS_TIME_ZONE = 'Europe/Madrid'
const DAY_MS = 24 * 3600 * 1000
const HOME_FRESH_DAYS = 7

/** `?pagina=` is untrusted: anything that is not a positive integer is page 1. */
export function parseNewsPage(raw: unknown): number {
  const value = Array.isArray(raw) ? raw[0] : raw
  const page = typeof value === 'string' && /^\d{1,4}$/.test(value) ? Number(value) : 1
  return page >= 1 ? page : 1
}

/** `?alcance=` is untrusted: an unknown value means "all" (null). */
export function parseNewsScope(raw: unknown): NewsScope | null {
  const value = Array.isArray(raw) ? raw[0] : raw
  return NEWS_SCOPES.find((scope) => scope === value) ?? null
}

/** Plain text split in paragraphs at blank lines; for the summary and the note, always interpolated. */
export function newsParagraphs(text: string): string[] {
  return text
    .split(/\n{2,}/)
    .map((part) => part.trim())
    .filter(Boolean)
}

/** D79: a source Xavi has not verified is cited with `nofollow`; it always opens outside with `noopener`. */
export function newsSourceRel(trusted: boolean): string {
  return trusted ? 'noopener' : 'nofollow noopener'
}

/** Host of a source URL for display; empty if it does not parse. */
export function sourceHost(url: string): string {
  try {
    return new URL(url).hostname.replace(/^www\./, '')
  } catch {
    return ''
  }
}

/** Only `https:` URLs are ever rendered as links (F8.1: no javascript: or data:). */
export function isHttpsUrl(url: string): boolean {
  try {
    return new URL(url).protocol === 'https:'
  } catch {
    return false
  }
}

/** Year, month and day of an instant in the site time zone. */
function localDay(iso: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: NEWS_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(iso))
  const get = (type: string) => Number(parts.find((part) => part.type === type)?.value)
  return Date.UTC(get('year'), get('month') - 1, get('day'))
}

/** UTC midnight of the Monday of the week (Monday to Sunday) of a UTC-midnight day. */
function mondayOf(day: number) {
  const weekday = (new Date(day).getUTCDay() + 6) % 7
  return day - weekday * DAY_MS
}

export interface NewsWeek {
  /** ISO date of the Monday. */
  key: string
  /** UTC midnight of Monday and Sunday, to format the range. */
  start: number
  end: number
  /** 0 = this week, 1 = the previous one, 2+ = older. */
  age: number
  items: NewsSummary[]
}

/** Groups news (newest first) by week, Monday to Sunday in Barcelona time. */
export function groupNewsByWeek(items: NewsSummary[], now = new Date()): NewsWeek[] {
  const currentMonday = mondayOf(localDay(now.toISOString()))
  const weeks: NewsWeek[] = []
  for (const item of items) {
    const start = mondayOf(localDay(item.publishedAt))
    const last = weeks[weeks.length - 1]
    if (last && last.start === start) {
      last.items.push(item)
      continue
    }
    weeks.push({
      key: new Date(start).toISOString().slice(0, 10),
      start,
      end: start + 6 * DAY_MS,
      age: Math.max(0, Math.round((currentMonday - start) / (7 * DAY_MS))),
      items: [item],
    })
  }
  return weeks
}

/** "16–22 nov" or "28 oct – 3 nov" when the week crosses a month. */
export function formatWeekRange(week: Pick<NewsWeek, 'start' | 'end'>, locale: string): string {
  const format = (options: Intl.DateTimeFormatOptions, day: number) =>
    new Intl.DateTimeFormat(intlLocale(locale), { timeZone: 'UTC', ...options }).format(day)
  const clean = (text: string) => text.replace('.', '')
  const startMonth = clean(format({ month: 'short' }, week.start))
  const endMonth = clean(format({ month: 'short' }, week.end))
  const startDay = format({ day: 'numeric' }, week.start)
  const endDay = format({ day: 'numeric' }, week.end)
  return startMonth === endMonth
    ? `${startDay}–${endDay} ${endMonth}`
    : `${startDay} ${startMonth} – ${endDay} ${endMonth}`
}

/**
 * Home block (D77, B): the latest `limit`, but the items with a note from the last 7 days go first.
 * `items` arrives newest first; both groups keep that order.
 */
export function pickHomeNews(items: NewsSummary[], limit = 4, now = new Date()): NewsSummary[] {
  const since = now.getTime() - HOME_FRESH_DAYS * DAY_MS
  const fresh = items.filter((item) => item.note && new Date(item.publishedAt).getTime() >= since)
  const ids = new Set(fresh.map((item) => item.id))
  return [...fresh, ...items.filter((item) => !ids.has(item.id))].slice(0, limit)
}

/** "15 nov" in mono (the date column of the rows). */
export function formatNewsDay(iso: string, locale: string): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: NEWS_TIME_ZONE,
    day: 'numeric',
    month: 'short',
  })
    .format(new Date(iso))
    .replace('.', '')
}

/** Page numbers of the pager: first, last, the current one and its neighbours; `null` = ellipsis. */
export function pagerItems(page: number, pages: number): (number | null)[] {
  const wanted = new Set([1, pages, page - 1, page, page + 1].filter((n) => n >= 1 && n <= pages))
  const sorted = [...wanted].sort((a, b) => a - b)
  const items: (number | null)[] = []
  sorted.forEach((n, i) => {
    if (i > 0 && n - sorted[i - 1]! > 1) items.push(null)
    items.push(n)
  })
  return items
}

/** Route of a related page (news_links): gym, resoler, shoe, article or the agenda. */
export function newsRelatedTo(kind: NewsRelatedKind, slug: string | null): LocaleRouteTo {
  switch (kind) {
    case 'gym':
      return { name: 'climbing-gyms-slug', params: { slug: slug ?? '' } }
    case 'resoler':
      return { name: 'climbing-shoe-resoling-slug', params: { slug: slug ?? '' } }
    case 'shoe':
      return { name: 'climbing-shoes-slug', params: { slug: slug ?? '' } }
    case 'article':
      return { name: 'blog-slug', params: { slug: slug ?? '' } }
    default:
      return { name: 'events' }
  }
}

/** Meta description of a news page: the first sentence of the note if there is one, otherwise the summary. */
export function newsSeoDescription(news: Pick<NewsSummary, 'note' | 'summary'>): string {
  const note = news.note?.replace(/\s+/g, ' ').trim()
  if (note) return note.split(/(?<=[.!?…])\s/)[0] ?? note
  return news.summary
}
