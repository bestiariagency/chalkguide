import { buildConsentConfig } from '~/utils/consent-config'
import { logCookieConsent } from '~/services/consent-log'
import { consentFromCookie, readStoredConsent, isAdminPath, CONSENT_REVISION, NO_CONSENT, type ConsentCategory, type ConsentState } from '~/utils/consent'
import { NEWS_VIEW_COOKIE } from '~/utils/hero-intro'

type CookieConsentApi = typeof import('vanilla-cookieconsent')
type Listener = (state: ConsentState) => void

// One CMP per page. Everything that names `vanilla-cookieconsent` lives in this file and in
// utils/consent-config.ts: swapping the tool means rewriting those two.
let cmp: CookieConsentApi | null = null
let starting: Promise<boolean> | null = null
const listeners = new Set<Listener>()
let resizeObserver: ResizeObserver | null = null

const rootEl = () => document.getElementById('cc-root')

/** Height the banner takes, published as `--cc-h` so the page can scroll above it (README §16.5). */
function reserveBannerSpace(on: boolean) {
  resizeObserver?.disconnect()
  resizeObserver = null
  const html = document.documentElement
  const banner = rootEl()?.querySelector<HTMLElement>('.cm')
  if (!on || !banner) return html.style.removeProperty('--cc-h')
  const measure = () => html.style.setProperty('--cc-h', `${Math.ceil(banner.getBoundingClientRect().height)}px`)
  measure()
  if (typeof ResizeObserver === 'undefined') return
  resizeObserver = new ResizeObserver(measure)
  resizeObserver.observe(banner)
}

/** Visually hidden `role="status"` line: announces the banner once and then "preferences saved". */
function say(text: string) {
  const root = rootEl()
  if (!root) return
  let region = root.querySelector<HTMLElement>('[data-cc-status]')
  if (!region) {
    region = document.createElement('p')
    region.setAttribute('role', 'status')
    region.setAttribute('aria-live', 'polite')
    region.setAttribute('data-cc-status', '')
    root.prepend(region)
  }
  region.textContent = ''
  window.setTimeout(() => region && (region.textContent = text), 50)
}

/**
 * Consent state and the only door to the consent tool (D85 `vanilla-cookieconsent`).
 * `state` is readable anywhere; `init()` loads the tool (idle, client only), `open()` shows the
 * preferences panel, `onChange(cb)` runs on every page load with a saved choice and on every change.
 */
export function useConsent() {
  const nuxtApp = useNuxtApp()
  const supabase = useRuntimeConfig().public.supabase
  const state = useState<ConsentState>('consent', () => ({ ...NO_CONSENT }))

  /** Reads the saved choice from the cookie. Call after hydration so server and client HTML agree. */
  function hydrate() {
    state.value = readStoredConsent(document.cookie)
  }

  const has = (category: ConsentCategory) => state.value[category]

  function sync() {
    if (!cmp) return
    const stored = cmp.validConsent()
    const next = stored ? consentFromCookie(cmp.getCookie()) : { ...NO_CONSENT }
    state.value = next
    listeners.forEach((listener) => listener(next))
  }

  function onChange(listener: Listener) {
    listeners.add(listener)
    return () => listeners.delete(listener)
  }

  function t(key: string, named?: Record<string, string>) {
    return String(named ? nuxtApp.$i18n.t(key, named) : nuxtApp.$i18n.t(key))
  }

  function afterChoice() {
    sync()
    say(t('cookies.prefs.saved'))
    // Focus inside a banner that just closed would be lost: hand it to <main> (README §16.2).
    window.setTimeout(() => {
      const active = document.activeElement
      if (active && active !== document.body && !rootEl()?.contains(active)) return
      document.getElementById('main')?.focus({ preventScroll: true })
    }, 0)
  }

  /** Server proof of the choice (D87). Legal duty: it does not depend on the analytics switch. */
  function logChoice(action: 'first' | 'change') {
    const cookie = cmp?.getCookie()
    if (!cookie?.consentId || isAdminPath(window.location.pathname)) return
    logCookieConsent({ supabaseUrl: String(supabase?.url ?? ''), publishableKey: String(supabase?.key ?? '') }, {
      consentId: cookie.consentId,
      action,
      categories: cookie.categories,
      revision: CONSENT_REVISION,
      locale: String(nuxtApp.$i18n.locale.value) === 'en' ? 'en' : 'es',
    })
  }

  function writeStatusLine() {
    const header = rootEl()?.querySelector('.pm__header')
    if (!header) return
    let line = header.querySelector<HTMLElement>('[data-cc-saved]')
    if (!line) {
      line = document.createElement('p')
      line.setAttribute('data-cc-saved', '')
      header.querySelector('.pm__title')?.after(line)
    }
    const { chosen, date } = consentFromCookie(cmp?.getCookie())
    line.textContent =
      chosen && date
        ? t('cookies.prefs.statusSaved', { date: formatDate(date, String(nuxtApp.$i18n.locale.value)) })
        : t('cookies.prefs.statusNone')
  }

  function init(): Promise<boolean> {
    if (starting) return starting
    starting = (async () => {
      try {
        // The CSS travels with the library chunk, not with the blocking site CSS (README §16.6).
        const [lib] = await Promise.all([import('vanilla-cookieconsent'), import('~/assets/css/consent.css')])
        cmp = (lib.default ?? lib) as CookieConsentApi
        const { locales, defaultLocale } = nuxtApp.$i18n
        await cmp.run(
          buildConsentConfig({
            t,
            locales: locales.value.map((l) => (typeof l === 'string' ? l : l.code)),
            defaultLocale: defaultLocale as string,
            policyHref: () => nuxtApp.$localePath({ name: 'cookies' }),
            newsViewCookie: NEWS_VIEW_COOKIE,
            handlers: {
              onConsent: sync,
              onFirstConsent: () => {
                logChoice('first')
                afterChoice()
              },
              onChange: () => {
                logChoice('change')
                afterChoice()
              },
              onModalReady: ({ modalName, modal }) => {
                if (modalName !== 'consentModal') return
                // Layer one is a non-modal dialog: it never traps focus or blocks the page.
                modal.setAttribute('role', 'dialog')
                modal.setAttribute('aria-modal', 'false')
              },
              onModalShow: ({ modalName }) => {
                if (modalName === 'preferencesModal') return writeStatusLine()
                reserveBannerSpace(true)
                say(t('cookies.banner.announce'))
              },
              onModalHide: ({ modalName }) => modalName === 'consentModal' && reserveBannerSpace(false),
            },
          }),
        )
        sync()
        return true
      } catch {
        // A blocked chunk must never break the page; the footer link falls back to /cookies#preferencias.
        starting = null
        return false
      }
    })()
    return starting
  }

  /** Opens the preferences panel. False if the tool could not load (the caller then navigates to /cookies). */
  async function open(): Promise<boolean> {
    if (!(await init()) || !cmp) return false
    cmp.showPreferences()
    return true
  }

  /** Re-applies the texts after a locale switch (the SPA navigates without reloading). */
  async function applyLocale(code: string) {
    if (cmp) await cmp.setLanguage(code, true)
  }

  return { state, hydrate, has, init, open, onChange, applyLocale }
}
