import type { LocalizedRouteName } from '~~/i18n/localized-routes'
import type { Locale } from '~/types/domain'

/**
 * D3 for detail pages: 404 when the record does not exist in this locale, and tell the
 * language switcher which versions exist (with translated slugs when they differ).
 */
export function useDetailLocales(
  record: { hasEn: boolean; slugs?: Partial<Record<Locale, string>> } | null | undefined,
  fallback: LocalizedRouteName,
) {
  if (!record) {
    throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true })
  }
  const { setPageLocales } = usePageLocales()
  setPageLocales(record.hasEn ? ['es', 'en'] : ['es'], { en: fallback })
  if (record.slugs) {
    const setI18nParams = useSetI18nParams()
    setI18nParams({
      es: { slug: record.slugs.es },
      ...(record.slugs.en ? { en: { slug: record.slugs.en } } : {}),
    })
  }
}
