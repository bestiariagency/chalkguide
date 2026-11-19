import { trackEvent } from '~/services/analytics'
import { sendAdsConversion, sendThirdParty } from '~/utils/analytics-tags'
import { isUntrackedPath, validIds } from '~/utils/consent'
import { THIRD_PARTY, classifySource, normalizePath, thirdPartyParams, type TrackExtra, type TrackName } from '~/utils/track'

/**
 * Single point for analytics events (D69, spec §5). Layer 1 (own `guide.track_event`) always runs,
 * with no cookies; GA4 and Meta get the few events they need only with consent. Non-blocking:
 * nothing here throws or waits. Does nothing on the panel, the API or token pages, and nothing at
 * all unless `NUXT_PUBLIC_ANALYTICS_ENABLED` is on (production with a real domain).
 */
export function useTrack() {
  const db = useGuideClient()
  const { currentContext } = useTrackContext()
  const consent = useConsent()
  const config = useRuntimeConfig().public
  const nuxtApp = useNuxtApp()
  const ids = validIds({ ga4Id: String(config.ga4Id), gadsId: String(config.gadsId), metaPixelId: String(config.metaPixelId) })
  let landing = true

  const locale = () => (String(nuxtApp.$i18n.locale.value) === 'en' ? 'en' : 'es')

  /** @param only `third`: resend to GA4/Meta alone (a tag that was just accepted), never to layer 1. */
  function track(name: TrackName, extra: TrackExtra = {}, only: 'third' | 'all' = 'all') {
    if (!config.analyticsEnabled || !import.meta.client) return
    const path = normalizePath(window.location.pathname)
    if (isUntrackedPath(path)) return
    const merged: TrackExtra = { ...currentContext(), ...extra }

    if (only === 'all') {
      const isView = name === 'page_view'
      void trackEvent(db, {
        name,
        path,
        locale: locale(),
        ...merged,
        // Origin and device only on the page view; only the landing page has an origin.
        source: isView && landing ? classifySource(document.referrer, window.location.hostname, window.location.search) : undefined,
        device: isView ? (window.matchMedia('(max-width: 767px)').matches ? 'mobile' : 'desktop') : undefined,
      })
      if (isView) landing = false
    }

    const target = THIRD_PARTY[name]
    if (!target) return
    const state = consent.state.value
    sendThirdParty(target, thirdPartyParams(merged, path, locale()), ids, state)
    if (name === 'newsletter_submit') sendAdsConversion(ids, String(config.gadsConvNewsletter), state)
  }

  return { track, ids }
}
