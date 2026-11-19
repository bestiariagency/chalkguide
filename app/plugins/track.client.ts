import { applyConsent } from '~/utils/analytics-tags'
import { fichaTypeOf, normalizePath, partnerFromUrl, type TrackName } from '~/utils/track'
import { NO_CONSENT, isUntrackedPath } from '~/utils/consent'

/**
 * Analytics wiring (D69): consent → Google/Meta tags, page views on every navigation and the
 * click events (delegated, so components stay free of tracking code). Client only. The panel and
 * the API never send events (useTrack checks the path).
 */
export default defineNuxtPlugin((nuxtApp) => {
  const consent = useConsent()
  const { track, ids } = useTrack()
  const { currentContext } = useTrackContext()
  let previous = { ...NO_CONSENT }
  let lastViewed = ''

  function pageView() {
    const path = normalizePath(window.location.pathname)
    if (path === lastViewed) return // hash or query changes are not page views
    lastViewed = path
    track('page_view')
  }

  // Tags are never applied on the panel, the API or token pages, nor with analytics off (leona-lia D86 V1):
  // entering through such a route postpones them to the first navigation to a tracked one.
  const canApply = () => !!useRuntimeConfig().public.analyticsEnabled && !isUntrackedPath(normalizePath(window.location.pathname))
  let applied = false
  function applyIfAllowed(state = consent.state.value) {
    if (!canApply()) return
    applied = true
    applyConsent(ids, state)
  }

  nuxtApp.hook('app:mounted', () => {
    consent.hydrate()
    previous = { ...consent.state.value }
    applyIfAllowed(previous)
    useRouter().afterEach(() => {
      if (!applied) void nextTick(() => applyIfAllowed())
    })
    nuxtApp.hook('page:finish', pageView)
    pageView()
  })

  consent.onChange((state) => {
    applyIfAllowed(state)
    // A tag accepted just now missed the page already open: give it that one page view.
    if ((state.analytics && !previous.analytics) || (state.ads && !previous.ads)) track('page_view', {}, 'third')
    previous = { ...state }
  })

  document.addEventListener('click', (event) => {
    const target = event.target
    if (!(target instanceof Element)) return

    const sponsored = target.closest<HTMLAnchorElement>('a[rel~="sponsored"]')
    if (sponsored) {
      const partner = sponsored.dataset.trackPartner ?? partnerFromUrl(sponsored.href)
      return track('affiliate_click', partner ? { partner } : {})
    }
    const named = target.closest<HTMLElement>('[data-track]')?.dataset.track as TrackName | undefined
    if (named === 'outbound_gym' || named === 'login_for_review') return track(named)
    if (target.closest('button[data-video-play]')) return track('video_play')

    // Article → ficha: the origin is the article (its context), the type is the destination's.
    const link = target.closest<HTMLAnchorElement>('[data-prose] a[href]')
    if (link && link.origin === window.location.origin && currentContext().contentType === 'article') {
      const type = fichaTypeOf(link.pathname)
      if (type) track('ficha_click', { contentType: type })
    }
  })
})
