import type { AnalyticsIds, ConsentState } from './consent'
import { normalizePath } from './track'

/**
 * Google (GA4, Ads) and Meta tags, loaded only after consent (D69, Consent Mode v2 "basic").
 * Before a "yes" this file makes no request. With IDs configured it only defines `window.dataLayer`
 * and `window.gtag` (queued `denied` defaults, no network); `fbq` and every script wait for the "yes".
 * Without an ID the matching tag is never loaded. No Tag Manager. Browser only.
 */
type Gtag = (...args: unknown[]) => void
type Fbq = ((...args: unknown[]) => void) & { callMethod?: (...args: unknown[]) => void; queue: unknown[][]; loaded: boolean; version: string; push: unknown; disablePushState?: boolean }

declare global {
  interface Window {
    dataLayer?: unknown[]
    gtag?: Gtag
    fbq?: Fbq
    _fbq?: Fbq
  }
}

const GTAG_SRC = 'https://www.googletagmanager.com/gtag/js'
const META_SRC = 'https://connect.facebook.net/en_US/fbevents.js'

const loaded = { google: false, meta: false }
const configured = { ga4: false, gads: false }
let metaInitialised = false

function addScript(src: string) {
  const script = document.createElement('script')
  script.async = true
  script.src = src
  document.head.append(script)
}

/** Google reads the full address by default: tell it the clean one (origin + path, no query, no token). */
function setCleanLocation(gtag: Gtag) {
  gtag('set', { page_location: window.location.origin + normalizePath(window.location.pathname) })
}

const granted = (value: boolean) => (value ? 'granted' : 'denied')

function ensureGtag(): Gtag {
  if (!window.gtag) {
    window.dataLayer = window.dataLayer ?? []
    // gtag.js reads `arguments` objects from the data layer, so this cannot be an arrow function.
    window.gtag = function gtag() {
      // eslint-disable-next-line prefer-rest-params
      window.dataLayer!.push(arguments)
    }
    window.gtag('consent', 'default', {
      analytics_storage: 'denied',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied',
    })
  }
  return window.gtag
}

function applyGoogle(ids: AnalyticsIds, consent: ConsentState) {
  const wantsGa = !!ids.ga4Id && consent.analytics
  const wantsAds = !!ids.gadsId && consent.ads
  const gtag = ensureGtag()
  gtag('consent', 'update', {
    analytics_storage: granted(wantsGa),
    ad_storage: granted(wantsAds),
    ad_user_data: granted(wantsAds),
    ad_personalization: granted(wantsAds),
  })
  if (!wantsGa && !wantsAds) return
  if (!loaded.google) {
    loaded.google = true
    gtag('js', new Date())
    addScript(`${GTAG_SRC}?id=${encodeURIComponent(wantsGa ? ids.ga4Id : ids.gadsId)}`)
  }
  // The page view is sent by our own router hook (Nuxt is an SPA), so GA4 does not send its own.
  if (wantsGa && !configured.ga4) {
    configured.ga4 = true
    setCleanLocation(gtag)
    gtag('config', ids.ga4Id, { send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false })
  }
  if (wantsAds && !configured.gads) {
    configured.gads = true
    setCleanLocation(gtag)
    // Page view comes from our own hook; no enhanced conversions (the sign-up form holds an email).
    gtag('config', ids.gadsId, { send_page_view: false, allow_enhanced_conversions: false })
  }
}

function ensureFbq(): Fbq {
  if (window.fbq) return window.fbq
  const fbq = function (...args: unknown[]) {
    if (fbq.callMethod) fbq.callMethod(...args)
    else fbq.queue.push(args)
  } as Fbq
  fbq.push = fbq
  fbq.loaded = true
  fbq.version = '2.0'
  fbq.queue = []
  window.fbq = fbq
  window._fbq = fbq
  return fbq
}

function applyMeta(ids: AnalyticsIds, consent: ConsentState) {
  if (!ids.metaPixelId) return
  if (!consent.ads) {
    // Withdrawn: Meta asks for `revoke` on every page and until a new "yes".
    if (window.fbq) window.fbq('consent', 'revoke')
    return
  }
  const fbq = ensureFbq()
  if (!loaded.meta) {
    loaded.meta = true
    fbq('consent', 'revoke')
    // autoConfig off only stops Meta's automatic event and page reading. Advanced matching is another switch,
    // in Meta's Events Manager: it must be off there too (the sign-up form holds an email). Check: no `ud[...]` in the Lead request.
    fbq('set', 'autoConfig', false, ids.metaPixelId)
    fbq.disablePushState = true
    addScript(META_SRC)
  }
  if (!metaInitialised) {
    metaInitialised = true
    fbq('init', ids.metaPixelId)
  }
  fbq('consent', 'grant')
}

/** Brings the tags in line with the saved choice: loads what was accepted, switches off what was withdrawn. */
export function applyConsent(ids: AnalyticsIds, consent: ConsentState) {
  if (!ids.ga4Id && !ids.gadsId && !ids.metaPixelId) return
  applyGoogle(ids, consent)
  applyMeta(ids, consent)
}

/** Sends one event to the tags the person accepted. A no-op for everything else. */
export function sendThirdParty(
  target: { ga?: string; meta?: { event: string; custom?: boolean } },
  params: Record<string, string>,
  ids: AnalyticsIds,
  consent: ConsentState,
) {
  // Each tag gets the event only if its own category was accepted: GA4 with analytics, Ads with ads.
  const sendTo = [
    ...(consent.analytics && ids.ga4Id ? [ids.ga4Id] : []),
    ...(consent.ads && ids.gadsId ? [ids.gadsId] : []),
  ]
  if (target.ga && window.gtag && sendTo.length) {
    setCleanLocation(window.gtag)
    window.gtag('event', target.ga, { ...params, send_to: sendTo })
  }
  // Meta takes the address from the page and cannot be told otherwise: no event at all while the URL
  // carries a search, an OAuth code or a token (`q`, `code`, `token`, `t`).
  const query = new URLSearchParams(window.location.search)
  const sensitive = ['q', 'code', 'token', 't'].some((key) => query.has(key))
  if (target.meta && ids.metaPixelId && consent.ads && window.fbq && !sensitive) {
    window.fbq(target.meta.custom ? 'trackCustom' : 'track', target.meta.event, target.meta.custom ? { partner: params.partner } : {})
  }
}

/** Google Ads conversion of the newsletter sign-up, only with the ads choice and a configured label. */
export function sendAdsConversion(ids: AnalyticsIds, label: string, consent: ConsentState) {
  if (!ids.gadsId || !/^[\w-]{4,40}$/.test(label) || !consent.ads || !window.gtag) return
  window.gtag('event', 'conversion', { send_to: `${ids.gadsId}/${label}` })
}
