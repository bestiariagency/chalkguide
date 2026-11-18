import type { LocalizedRouteName } from '~~/i18n/localized-routes'
import { type RedirectKind, resolveRedirect } from '~/services/redirects'

/**
 * D24: when a detail record is missing, look for a retired slug and answer 301 to the current URL
 * (query and hash kept). Call it before `useDetailLocales`, which throws the 404. One lookup only;
 * a failed lookup falls through to the usual 404. SSR gives the real 301 (the render is skipped);
 * on the client the stale setup is parked once the navigation lands.
 */
export async function useSlugRedirect(
  record: unknown,
  kind: RedirectKind,
  routeName: LocalizedRouteName,
) {
  if (record) return
  const route = useRoute()
  const locale = useGuideLocale()
  const localePath = useLocalePath()
  const db = useGuideClient()

  let target: string | null
  try {
    target = await resolveRedirect(db, kind, locale.value, String(route.params.slug))
  } catch {
    return
  }
  if (!target || target === route.params.slug) return

  const to = localePath({ name: routeName, params: { slug: target }, query: route.query, hash: route.hash })
  await navigateTo(to, { redirectCode: 301 })
  if (import.meta.client) await new Promise<void>(() => {})
}
