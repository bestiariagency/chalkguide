import type { H3Event } from 'h3'
import { localizedRoutes } from '../../i18n/localized-routes'

/** F4.6 §15: every newsletter route is same-origin only, no-store, noindex, no-referrer, body <= 4 KB. */
export const NEWSLETTER_MAX_BODY = 4096

type Fields = Record<string, unknown>
type RouteName = 'newsletter-confirm' | 'newsletter-confirmed'

/** Headers + CSRF check (Origin / Sec-Fetch-Site). `strict` (POST) also refuses requests with neither header. */
export function guardNewsletterRequest(event: H3Event, strict: boolean) {
  setResponseHeaders(event, {
    'cache-control': 'no-store',
    'x-robots-tag': 'noindex, nofollow',
    'referrer-policy': 'no-referrer',
  })
  const site = getRequestHeader(event, 'sec-fetch-site')
  // A form posted from a `Referrer-Policy: no-referrer` page (the confirm page) carries `Origin: null`: treat it as
  // absent. Sec-Fetch-Site (set by the browser, not forgeable by a page) still decides; without it the POST is refused.
  const rawOrigin = getRequestHeader(event, 'origin')
  const origin = rawOrigin && rawOrigin !== 'null' ? rawOrigin : undefined
  let ok: boolean
  if (site) ok = site === 'same-origin'
  else if (origin) ok = originMatches(event, origin)
  else ok = !strict
  if (ok && site && origin && !originMatches(event, origin)) ok = false
  if (!ok) throw createError({ statusCode: 403, statusMessage: 'Forbidden' })
}

/** Origin must be the public site (O1). The request host is used only in dev while siteUrl is empty/placeholder. */
function originMatches(event: H3Event, origin: string): boolean {
  try {
    const site = String(useRuntimeConfig(event).public.siteUrl ?? '')
    const siteHost = site ? new URL(site).host : ''
    const useRequestHost = import.meta.dev && (!siteHost || siteHost.endsWith('.example'))
    const expected = useRequestHost ? getRequestURL(event).host : siteHost
    return !!expected && new URL(origin).host === expected
  } catch {
    return false
  }
}

/** Secret and EF base. Server only: the env var is read at runtime so it is never baked into the build. */
export function newsletterRelay(event: H3Event) {
  const config = useRuntimeConfig(event)
  const secret = String(config.newsletterRelaySecret || process.env.NEWSLETTER_RELAY_SECRET || '')
  const base = String(config.public.supabase?.url ?? '').replace(/\/$/, '')
  if (secret.length < 32 || !base) throw createError({ statusCode: 503, statusMessage: 'Unavailable' })
  return { secret, url: `${base}/functions/v1/newsletter-subscribe` }
}

/** Reads a form (`application/x-www-form-urlencoded`) or JSON body of at most 4 KB. */
export async function readNewsletterBody(event: H3Event): Promise<{ fields: Fields; isForm: boolean }> {
  const length = Number(getRequestHeader(event, 'content-length') ?? 0)
  if (length > NEWSLETTER_MAX_BODY) throw createError({ statusCode: 413, statusMessage: 'Too large' })
  const type = (getRequestHeader(event, 'content-type') ?? '').toLowerCase()
  const raw = await readRawBody(event, 'utf8')
  if ((raw?.length ?? 0) > NEWSLETTER_MAX_BODY) throw createError({ statusCode: 413, statusMessage: 'Too large' })
  if (type.startsWith('application/x-www-form-urlencoded')) {
    return { fields: Object.fromEntries(new URLSearchParams(raw ?? '')), isForm: true }
  }
  if (type.startsWith('application/json')) {
    try {
      const parsed: unknown = JSON.parse(raw || '{}')
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) return { fields: parsed as Fields, isForm: false }
    } catch {
      /* falls through */
    }
  }
  throw createError({ statusCode: 400, statusMessage: 'Bad request' })
}

export const fieldText = (value: unknown, max: number): string =>
  typeof value === 'string' ? value.slice(0, max) : ''
export const fieldFlag = (value: unknown): boolean => value === true || value === 'on' || value === 'true'
export const fieldLocale = (value: unknown): 'es' | 'en' => (value === 'en' ? 'en' : 'es')

/** Localized path of a newsletter page (es without prefix, en under /en), with an optional query. */
export function newsletterPath(name: RouteName, locale: 'es' | 'en', query?: Record<string, string>): string {
  const path = localizedRoutes[name][locale]
  const base = locale === 'en' ? `/en${path}` : path
  return query ? `${base}?${new URLSearchParams(query).toString()}` : base
}

/** Same-site path only (no scheme, no `//`), query and hash dropped. Falls back to the home. */
export function safeReturnPath(value: unknown, locale: 'es' | 'en'): string {
  const path = fieldText(value, 300).split(/[?#]/)[0] ?? ''
  if (!path.startsWith('/') || path.startsWith('//') || path.includes('\\') || [...path].some((c) => c.charCodeAt(0) < 32)) {
    return locale === 'en' ? '/en' : '/'
  }
  return path
}

export function seeOther(event: H3Event, location: string) {
  return sendRedirect(event, location, 303)
}
