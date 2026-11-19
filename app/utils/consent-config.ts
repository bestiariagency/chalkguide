import type { CookieConsentConfig, Translation } from 'vanilla-cookieconsent'
import { ADS_COOKIES, ANALYTICS_COOKIES, CONSENT_COOKIE, CONSENT_DAYS, CONSENT_REVISION } from './consent'

type Translate = (key: string) => string

export interface ConsentConfigInput {
  /** Current-locale translator; read when the language is (re)applied, so a locale switch re-renders. */
  t: Translate
  locales: string[]
  defaultLocale: string
  policyHref: () => string
  newsViewCookie: string
  handlers: Pick<CookieConsentConfig, 'onFirstConsent' | 'onConsent' | 'onChange' | 'onModalShow' | 'onModalHide' | 'onModalReady'>
}

const escapeHtml = (text: string) =>
  text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

function cookieRows(t: Translate, rows: [name: string, provider: string, purposeKey: string][]) {
  return rows.map(([name, provider, purposeKey]) => ({
    name,
    domain: provider,
    desc: t(`cookies.purpose.${purposeKey}`),
    exp: t('cookies.table.tbc'),
  }))
}

function translation(input: ConsentConfigInput): Translation {
  const { t, policyHref } = input
  const link = (key: string) => `<a href="${escapeHtml(policyHref())}">${escapeHtml(t(key))}</a>`
  const headers = {
    name: t('cookies.table.cookie'),
    domain: t('cookies.table.provider'),
    desc: t('cookies.table.purpose'),
    exp: t('cookies.table.duration'),
  }
  return {
    consentModal: {
      title: t('cookies.banner.title'),
      // Shown only when the revision changed (consent.ts CONSENT_REVISION); provisional copy, loro-lola reviews.
      revisionMessage: ` ${escapeHtml(t('cookies.banner.revision'))}`,
      // No close icon on purpose (README §16.2): "Rechazar" is already visible and a X reads as "later".
      description: `${escapeHtml(t('cookies.banner.description'))} ${link('cookies.banner.policyLink')}{{revisionMessage}}`,
      acceptAllBtn: t('cookies.banner.accept'),
      acceptNecessaryBtn: t('cookies.banner.reject'),
      showPreferencesBtn: t('cookies.banner.settings'),
    },
    preferencesModal: {
      title: t('cookies.prefs.title'),
      acceptAllBtn: t('cookies.prefs.acceptAll'),
      acceptNecessaryBtn: t('cookies.prefs.rejectAll'),
      savePreferencesBtn: t('cookies.prefs.save'),
      closeIconLabel: t('cookies.prefs.close'),
      sections: [
        { description: `${escapeHtml(t('cookies.prefs.intro'))} ${link('cookies.prefs.policyLink')}` },
        {
          title: t('cookies.category.necessary.title'),
          description: t('cookies.category.necessary.description'),
          linkedCategory: 'necessary',
          cookieTable: {
            headers,
            body: cookieRows(t, [
              [CONSENT_COOKIE, 'ChalkGuide', 'consent'],
              ['sb-…-auth-token', 'ChalkGuide (Supabase)', 'session'],
              [input.newsViewCookie, 'ChalkGuide', 'newsView'],
            ]),
          },
        },
        {
          title: t('cookies.category.analytics.title'),
          description: t('cookies.category.analytics.description'),
          linkedCategory: 'analytics',
          cookieTable: { headers, body: cookieRows(t, [['_ga, _ga_<id>', 'Google', 'ga']]) },
        },
        {
          title: t('cookies.category.ads.title'),
          description: t('cookies.category.ads.description'),
          linkedCategory: 'ads',
          cookieTable: {
            headers,
            body: cookieRows(t, [
              ['_gcl_*', 'Google', 'gcl'],
              ['_fbp, _fbc', 'Meta', 'fbp'],
            ]),
          },
        },
        { description: t('cookies.prefs.videosNote') },
      ],
    },
  }
}

/** Library config for the approved design (README §16.7): bar at the bottom, equal-weight buttons, no X in layer one. */
export function buildConsentConfig(input: ConsentConfigInput): CookieConsentConfig {
  const build = () => translation(input)
  const translations = Object.fromEntries(input.locales.map((code) => [code, build]))
  return {
    root: '#cc-root',
    mode: 'opt-in',
    autoClearCookies: true,
    disablePageInteraction: false,
    hideFromBots: true,
    revision: CONSENT_REVISION,
    cookie: {
      name: CONSENT_COOKIE,
      sameSite: 'Lax',
      expiresAfterDays: (acceptType) => (acceptType === 'necessary' ? CONSENT_DAYS.rejected : CONSENT_DAYS.accepted),
    },
    guiOptions: {
      consentModal: { layout: 'bar inline', position: 'bottom', equalWeightButtons: true, flipButtons: false },
      preferencesModal: { layout: 'box', equalWeightButtons: true, flipButtons: false },
    },
    categories: {
      necessary: { enabled: true, readOnly: true },
      // reloadPage: after a withdrawal Google's own listeners must stop too (basic mode), so the page reloads without gtag.js.
      analytics: { autoClear: { cookies: ANALYTICS_COOKIES.map((name) => ({ name })), reloadPage: true } },
      ads: { autoClear: { cookies: ADS_COOKIES.map((name) => ({ name })), reloadPage: true } },
    },
    language: { default: input.defaultLocale, translations },
    ...input.handlers,
  }
}
