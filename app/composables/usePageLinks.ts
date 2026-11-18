import type { LocalizedRouteName } from '~~/i18n/localized-routes'
import { getPageAvailability } from '~/services/pages'

const PAGE_KEYS: Partial<Record<LocalizedRouteName, string>> = {
  about: 'about',
  transparency: 'transparency',
  privacy: 'privacy',
  cookies: 'cookies',
  'legal-notice': 'legal_notice',
}

/**
 * Links to editorial pages that never end in a 404: under /en, a page without an English
 * version links to the Spanish one (`locale="es"`, `hreflang` es; the link component appends the
 * "(in Spanish)" hint). If it is not published at all, that Spanish URL shows the "en preparación"
 * notice. One shared query (same `useAsyncData` key, deduplicated across components).
 */
export function usePageLinks() {
  const db = useGuideClient()
  const { locale } = useI18n()
  const { data } = useAsyncData('pages-availability', () => getPageAvailability(db))

  function linkFor(name: LocalizedRouteName) {
    const key = PAGE_KEYS[name]
    const spanish = locale.value === 'en' && !!key && data.value?.[key]?.en !== true
    return spanish
      ? { locale: 'es' as const, hreflang: 'es' }
      : { locale: undefined, hreflang: undefined }
  }

  /** False only under /en for a page without English version (hide optional links). */
  function isAvailable(name: LocalizedRouteName) {
    const key = PAGE_KEYS[name]
    return locale.value !== 'en' || !key || data.value?.[key]?.en === true
  }
  return { linkFor, isAvailable }
}
