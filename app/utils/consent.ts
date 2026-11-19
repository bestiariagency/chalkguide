/**
 * Cookie consent: pure types and helpers (D69, D85). Nothing here touches the CMP library, so the
 * tool can be swapped by editing composables/useConsent.ts and utils/consent-config.ts only.
 */
export type ConsentCategory = 'analytics' | 'ads'

export interface ConsentState {
  /** The person has made a choice (accept, reject or save). */
  chosen: boolean
  analytics: boolean
  ads: boolean
  /** ISO date of the last choice, for the "saved on" line. */
  date: string | null
}

export const CONSENT_COOKIE = 'cc_cookie'
/** Raise it whenever categories, providers or purposes change: everyone is asked again (leona-lia, D86 V3). */
export const CONSENT_REVISION = 1
/** Days a choice lasts: longer for a "yes", shorter for a "no" (max 24 months, AEPD). */
export const CONSENT_DAYS = { accepted: 365, rejected: 182 } as const
export const NO_CONSENT: ConsentState = { chosen: false, analytics: false, ads: false, date: null }

/** Cookies Google and Meta leave behind; erased when a category is withdrawn (AEPD: withdrawing is as easy as giving). */
export const ANALYTICS_COOKIES: (string | RegExp)[] = [/^_ga/]
export const ADS_COOKIES: (string | RegExp)[] = [/^_gcl_/, '_fbp', '_fbc']

/** Shape of the `cc_cookie` value that the app reads (the library writes more). */
interface StoredConsent {
  categories?: unknown
  lastConsentTimestamp?: unknown
  revision?: unknown
  expirationTime?: unknown
  consentTimestamp?: unknown
}

export function consentFromCookie(value: StoredConsent | null | undefined): ConsentState {
  if (!value || !Array.isArray(value.categories)) return { ...NO_CONSENT }
  // An old revision or an expired choice is no choice: nothing loads until the person answers again.
  if (value.revision !== CONSENT_REVISION) return { ...NO_CONSENT }
  if (typeof value.expirationTime === 'number' && value.expirationTime < Date.now()) return { ...NO_CONSENT }
  const categories = value.categories.filter((c): c is string => typeof c === 'string')
  const stamp = value.lastConsentTimestamp ?? value.consentTimestamp
  return {
    chosen: true,
    analytics: categories.includes('analytics'),
    ads: categories.includes('ads'),
    date: typeof stamp === 'string' && !Number.isNaN(Date.parse(stamp)) ? stamp : null,
  }
}

/** Reads the stored choice straight from `document.cookie` (no library, so it is ready right after hydration). */
export function readStoredConsent(cookieString: string): ConsentState {
  const raw = cookieString
    .split('; ')
    .find((part) => part.startsWith(`${CONSENT_COOKIE}=`))
    ?.slice(CONSENT_COOKIE.length + 1)
  if (!raw) return { ...NO_CONSENT }
  try {
    return consentFromCookie(JSON.parse(decodeURIComponent(raw)) as StoredConsent)
  } catch {
    return { ...NO_CONSENT }
  }
}

/** Pages where nothing is tracked and no banner is shown: panel, API and links with a token (D66, D69). */
const UNTRACKED_PATH = /^\/(en\/)?(administrador|api)(\/|$)|^\/(en\/)?newsletter\/(confirmada|confirmed|preferencias|preferences|baja|unsubscribed)(\/|$)|^\/(en\/)?(entrar|sign-in)(\/|$)/i

export const isUntrackedPath = (path: string) => UNTRACKED_PATH.test(path)
export const isAdminPath = (path: string) => /^\/administrador(\/|$)/i.test(path)

export interface AnalyticsIds {
  ga4Id: string
  gadsId: string
  metaPixelId: string
}

const GA4_ID = /^G-[A-Z0-9]{4,20}$/
const GADS_ID = /^AW-\d{6,15}$/
const META_ID = /^\d{6,20}$/

/** Only well-formed IDs count: anything else is treated as "not configured" and loads nothing. */
export function validIds(ids: Partial<AnalyticsIds>): AnalyticsIds {
  const clean = (value: string | undefined, re: RegExp) => (value && re.test(value.trim()) ? value.trim() : '')
  return {
    ga4Id: clean(ids.ga4Id, GA4_ID),
    gadsId: clean(ids.gadsId, GADS_ID),
    metaPixelId: clean(ids.metaPixelId, META_ID),
  }
}
