import type { LocalizedRouteName } from '~~/i18n/localized-routes'

type Locale = 'es' | 'en'

interface PageLocalesState {
  /** Path the declaration belongs to: a stale value from the previous page is ignored. */
  path: string
  available: Locale[]
  /** Nearest index per locale when this page has no version in it (e.g. en → 'blog'). */
  fallback: Partial<Record<Locale, LocalizedRouteName>>
}

/**
 * D3 (§6): a /en URL exists only if there is a real English version. Pages with
 * per-record translations declare what exists so the language switcher never links to a 404:
 *
 *   const { setPageLocales } = usePageLocales()
 *   setPageLocales(article.locales, { en: 'blog' })
 *
 * For translated slugs, also call useSetI18nParams() so switchLocalePath builds the pair.
 * Pages that declare nothing are assumed to exist in every locale.
 */
export function usePageLocales() {
  const state = useState<PageLocalesState | null>('page-locales', () => null)
  const route = useRoute()

  function setPageLocales(
    available: Locale[],
    fallback: Partial<Record<Locale, LocalizedRouteName>> = {},
  ) {
    state.value = { path: route.path, available, fallback }
  }

  const current = computed(() => (state.value?.path === route.path ? state.value : null))

  return { setPageLocales, current }
}

export interface LanguageOption {
  code: Locale
  short: string
  /** Accessible name, e.g. "Cambiar a inglés". */
  label: string
  isCurrent: boolean
  /** null → no version and no fallback: rendered disabled. */
  to: string | null
}

/**
 * Index route of a detail route (`climbing-gyms-slug` → `climbing-gyms`, `blog-category-slug`
 * → `blog`). Used while the page's locales are still unknown.
 */
/** Editorial pages (guide.pages) that may lack an English version: same pre-mount rule. */
const EDITORIAL_PAGES = new Set(['about', 'transparency', 'privacy', 'cookies', 'legal-notice'])

function detailIndex(name: string): LocalizedRouteName | null {
  if (EDITORIAL_PAGES.has(name)) return 'index'
  if (name === 'blog-category-slug') return 'blog'
  const match = name.match(/^(.+)-(slug|month)$/)
  return match ? (match[1] as LocalizedRouteName) : null
}

/**
 * Options for every language switcher (header, mobile sheet, footer).
 *
 * The header renders before a detail page has fetched its record, so on SSR and during
 * hydration a detail route links to the index of the other language (never a 404, and the
 * same markup on server and client). Once mounted it links to the exact pair if it exists.
 * Crawlers get the exact pairs from the hreflang links in <head>.
 */
export function useLanguageSwitch() {
  const { locale, t } = useI18n()
  const switchLocalePath = useSwitchLocalePath()
  const localePath = useLocalePath()
  const getRouteBaseName = useRouteBaseName()
  const route = useRoute()
  const { current } = usePageLocales()

  const mounted = ref(false)
  onMounted(() => (mounted.value = true))

  function targetFor(code: Locale): string | null {
    const index = detailIndex(String(getRouteBaseName(route) ?? ''))
    if (index && !mounted.value) return localePath({ name: index }, code)
    const declared = current.value
    if (declared && !declared.available.includes(code)) {
      const fallback = declared.fallback[code]
      return fallback ? localePath({ name: fallback }, code) : null
    }
    return switchLocalePath(code) || null
  }

  const options = computed<LanguageOption[]>(() =>
    (['es', 'en'] as const).map((code) => {
      const isCurrent = locale.value === code
      const to = isCurrent ? switchLocalePath(code) || null : targetFor(code)
      return {
        code,
        short: code.toUpperCase(),
        label: isCurrent
          ? t(code === 'es' ? 'nav.languageEs' : 'nav.languageEn')
          : t(code === 'es' ? 'nav.switchToEs' : 'nav.switchToEn'),
        isCurrent,
        to,
      }
    }),
  )

  return { options }
}
