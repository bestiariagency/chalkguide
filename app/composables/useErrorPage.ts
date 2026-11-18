import type { NuxtError } from '#app'
import { localizedRoutes, type LocalizedRouteName } from '~~/i18n/localized-routes'

/**
 * State of the site error page: 404 vs generic, SEO (noindex) and the "ver en español" link.
 * The Spanish twin is offered only for static routes (no slug/month), where the pair is exact
 * without querying data; for detail pages the slug may differ, so no link is built.
 */
export function useErrorPage(error: MaybeRefOrGetter<NuxtError>) {
  const { t, locale } = useI18n()
  const route = useRoute()
  const getBaseName = useRouteBaseName()
  const switchLocalePath = useSwitchLocalePath()

  const isNotFound = computed(() => toValue(error).statusCode === 404)
  const code = computed(() => (isNotFound.value ? t('states.notFoundCode') : String(toValue(error).statusCode || 500)))
  const title = computed(() => t(isNotFound.value ? 'states.notFoundTitle' : 'states.errorTitle'))
  const body = computed(() => t(isNotFound.value ? 'states.notFoundBody' : 'states.errorBody'))

  usePageSeo(() => ({ title: title.value, description: body.value, robots: 'noindex, nofollow' }))

  const spanishPath = computed(() => {
    if (!isNotFound.value || locale.value !== 'en') return null
    const name = String(getBaseName(route) ?? '') as LocalizedRouteName
    const entry = localizedRoutes[name]
    if (!entry || entry.es.includes('[')) return null
    return switchLocalePath('es') || null
  })

  function retry() {
    return clearError({ redirect: route.fullPath })
  }

  return { isNotFound, code, title, body, spanishPath, retry }
}
