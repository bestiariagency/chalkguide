import { isAdminPath } from '~/utils/consent'

/**
 * Cookie consent (D69, D85, D86). Client only, never on the panel. The saved choice is read from
 * the cookie right after hydration (so /cookies shows it at once); the banner library loads in
 * idle time, after the LCP, with a 2 s timer as fallback for Safari (README §16.6).
 */
export default defineNuxtPlugin((nuxtApp) => {
  const router = useRouter()
  const consent = useConsent()
  const i18n = nuxtApp.$i18n

  const idle = (task: () => void) => {
    if (typeof window.requestIdleCallback === 'function') window.requestIdleCallback(task, { timeout: 2000 })
    else window.setTimeout(task, 2000)
  }

  let scheduled = false
  function start() {
    if (scheduled || isAdminPath(router.currentRoute.value.path)) return
    scheduled = true
    idle(() => void consent.init())
  }

  nuxtApp.hook('app:mounted', () => {
    consent.hydrate()
    start()
  })
  // Opening the site on the panel and moving to a public page later still gets the banner.
  router.afterEach(() => start())

  watch(
    () => i18n.locale.value,
    (code) => void consent.applyLocale(code),
    { flush: 'post' },
  )
})
