import type { Database } from '~/types/database.types'
import type { Locale } from '~/types/domain'
import { type GuideClient, guideSchema } from '~/services/client'

/** Read-only client for the `guide` schema (publishable key; RLS decides what is public). */
export function useGuideClient(): GuideClient {
  return guideSchema(useSupabaseClient<Database>())
}

export function useGuideLocale() {
  const { locale } = useI18n()
  return computed<Locale>(() => (locale.value === 'en' ? 'en' : 'es'))
}

/**
 * useAsyncData with a stable, localized key (`${key}:${locale}`): the SSR/prerender payload
 * is reused on hydration (no double fetch) and a new locale or slug is a new cache entry.
 */
export function useGuideData<T>(
  key: MaybeRefOrGetter<string>,
  fetcher: (db: GuideClient, locale: Locale) => Promise<T>,
) {
  const db = useGuideClient()
  const locale = useGuideLocale()
  return useAsyncData(
    () => `${toValue(key)}:${locale.value}`,
    () => fetcher(db, locale.value),
  )
}
