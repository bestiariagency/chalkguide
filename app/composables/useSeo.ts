import type { LocalizedRouteName } from '~~/i18n/localized-routes'
import { countEnglish } from '~/services/seo'

type Locale = 'es' | 'en'

/** Public site URL without trailing slash (site config: NUXT_PUBLIC_SITE_URL / NUXT_SITE_URL). */
export function useSiteUrl(): string {
  const site = useSiteConfig()
  const config = useRuntimeConfig()
  return String(site.url || config.public.siteUrl || '').replace(/\/+$/, '')
}

/** Absolute URL from a path (query and hash removed, no trailing slash except the root). */
export function useAbsoluteUrl() {
  const base = useSiteUrl()
  return (path: string) => {
    if (/^https?:\/\//.test(path)) return path
    const clean = path.split(/[?#]/)[0] || '/'
    const trimmed = clean.length > 1 ? clean.replace(/\/+$/, '') : clean
    return `${base}${trimmed === '/' ? '' : trimmed}` || `${base}/`
  }
}

/** SEO copy from `seo.<name>` (e.g. `gymTitle`, `categoryDescription`) with its params. */
export function useSeoText() {
  const { t } = useI18n()
  return (name: string, params: Record<string, string | number> = {}) => t(`seo.${name}`, params)
}

export interface PageSeoInput {
  title?: string | null
  description?: string | null
  /** Absolute URL or path. Defaults to the site share image of the current locale. */
  image?: string | null
  imageAlt?: string | null
  imageWidth?: number | null
  imageHeight?: number | null
  type?: 'website' | 'article'
  /** e.g. 'noindex, follow'. Leave empty on indexable pages (the robots module decides). */
  robots?: string | null
  publishedTime?: string | null
  modifiedTime?: string | null
}

/**
 * Per-page metadata: title, description, Open Graph, Twitter card and robots in one call,
 * so og:* / twitter:* always follow the page (never the site default by accident).
 * The canonical and hreflang are not set here: `useSiteSeo()` (app.vue) derives them from the route.
 */
export function usePageSeo(source: MaybeRefOrGetter<PageSeoInput>) {
  const { locale, t } = useI18n()
  const absolute = useAbsoluteUrl()
  const input = computed(() => toValue(source))
  const isDefaultImage = computed(() => !input.value.image)
  const image = computed(() =>
    input.value.image
      ? absolute(input.value.image)
      : absolute(locale.value === 'en' ? '/og-default-en.png' : '/og-default.png'),
  )
  const imageAlt = computed(() => input.value.imageAlt || (isDefaultImage.value ? t('seo.ogImageAlt') : undefined))
  const title = computed(() => input.value.title || undefined)
  const description = computed(() => clampDescription(input.value.description))

  useSeoMeta({
    title,
    description,
    robots: () => input.value.robots || undefined,
    ogTitle: title,
    ogDescription: description,
    ogType: () => input.value.type ?? 'website',
    ogImage: image,
    ogImageAlt: imageAlt,
    ogImageWidth: () => (isDefaultImage.value ? 1200 : (input.value.imageWidth ?? undefined)),
    ogImageHeight: () => (isDefaultImage.value ? 630 : (input.value.imageHeight ?? undefined)),
    twitterCard: 'summary_large_image',
    twitterTitle: title,
    twitterDescription: description,
    twitterImage: image,
    twitterImageAlt: imageAlt,
    articlePublishedTime: () => input.value.publishedTime ?? undefined,
    articleModifiedTime: () => input.value.modifiedTime ?? undefined,
  })
}

interface HreflangState {
  path: string
  locales: Locale[]
}

/**
 * hreflang for listings (README §6, D3): the English listing exists but only counts for
 * hreflang/indexing with enough translated elements (>= 5 gyms, >= 3 others, >= 1 event).
 * - On /en: `count` is the length of the list already loaded; below the threshold the page is
 *   `noindex, follow` and emits no alternates.
 * - On /es: `englishCount()` is a light head count; the `en` alternate is emitted only if ready.
 *
 * Returns the robots value to pass to usePageSeo.
 */
export async function useListingSeo(kind: ListingKind, loadedCount: MaybeRefOrGetter<number>) {
  const { locale } = useI18n()
  const route = useRoute()
  const state = useState<HreflangState | null>('seo-hreflang', () => null)
  const isEnglish = locale.value === 'en'
  // Only the Spanish twin needs the extra count: /en already has its list loaded.
  const english = isEnglish
    ? null
    : await useGuideData(`en-count:${kind}`, (db) => countEnglish(db, kind))

  const count = isEnglish ? toValue(loadedCount) : (english?.data.value ?? 0)
  const ready = isEnglishListingReady(kind, count)
  state.value = { path: route.path, locales: ready ? ['es', 'en'] : ['es'] }
  return isEnglish && !ready ? ROBOTS_NOINDEX_FOLLOW : undefined
}

/**
 * Site-wide head, called once from app.vue: html lang, title template (brand only if it fits in
 * 60 characters), canonical without query, hreflang only between versions that exist (D3),
 * og:url / og:locale, and the robots rules that depend only on the route (legal, utility).
 */
export function useSiteSeo() {
  const { locale } = useI18n()
  const route = useRoute()
  const getBaseName = useRouteBaseName()
  const switchLocalePath = useSwitchLocalePath()
  const absolute = useAbsoluteUrl()
  const { current } = usePageLocales()
  const hreflang = useState<HreflangState | null>('seo-hreflang', () => null)
  const i18nHead = useLocaleHead({ seo: false })

  const baseName = computed(() => String(getBaseName(route) ?? ''))

  /** Locales in which this page really exists (and is worth an alternate). */
  const alternates = computed<Locale[]>(() => {
    const override = hreflang.value?.path === route.path ? hreflang.value.locales : null
    const declared = current.value?.available ?? ['es', 'en']
    const list = override ? declared.filter((code) => override.includes(code)) : declared
    return list.length ? list : ['es']
  })

  function urlFor(code: Locale) {
    const path = switchLocalePath(code)
    return path ? absolute(path) : null
  }

  useHead(() => {
    const code: Locale = locale.value === 'en' ? 'en' : 'es'
    // Panel: Spanish only, noindex, no canonical or hreflang (the admin layout sets robots).
    if (route.path.startsWith('/administrador')) {
      return { htmlAttrs: { lang: 'es', dir: 'ltr' as const }, titleTemplate: (title?: string) => title ?? null }
    }
    const canonical = urlFor(code) ?? absolute(route.path)
    // A page that is not in the alternates list (e.g. a thin /en listing) emits none.
    const alts = alternates.value.includes(code) ? alternates.value : []
    const links: { key: string; rel: string; href: string; hreflang?: string }[] = [
      { key: 'canonical', rel: 'canonical', href: canonical },
    ]
    for (const alt of alts) {
      const href = urlFor(alt)
      if (href) links.push({ key: `alt-${alt}`, rel: 'alternate', hreflang: alt, href })
    }
    if (alts.length) {
      links.push({ key: 'alt-x-default', rel: 'alternate', hreflang: 'x-default', href: urlFor('es') ?? canonical })
    }
    const otherLocales = alts.filter((alt) => alt !== code)
    return {
      htmlAttrs: { lang: i18nHead.value.htmlAttrs?.lang, dir: i18nHead.value.htmlAttrs?.dir },
      titleTemplate: (title?: string) => titleWithBrand(title) ?? null,
      // Plain strings for rel/hreflang: unhead's strict link union does not narrow them.
      link: links as never,
      meta: [
        { key: 'og:url', property: 'og:url', content: canonical },
        { key: 'og:locale', property: 'og:locale', content: code === 'en' ? 'en_GB' : 'es_ES' },
        ...otherLocales.map((alt) => ({
          key: `og:locale:${alt}`,
          property: 'og:locale:alternate',
          content: alt === 'en' ? 'en_GB' : 'es_ES',
        })),
      ],
    }
  })

  // Rules that depend only on the route (README §6: legal, entrar, newsletter states).
  // A page can still override them with its own robots value.
  useSeoMeta({
    robots: () => ROUTE_ROBOTS[baseName.value],
  })

  return { baseName }
}

/** Route name → localized absolute URL, for JSON-LD and breadcrumbs. */
export function useRouteUrl() {
  const localePath = useLocalePath()
  const absolute = useAbsoluteUrl()
  return (name: LocalizedRouteName, params?: Record<string, string>) =>
    absolute(localePath({ name, params }))
}

/**
 * Metadata of an item page (gym, resoler, shoe): editor overrides (`seo_title`, `seo_description`,
 * `noindex` in guide.items) first, then the template copy; the cover is the share image.
 */
export function useItemSeo(
  item: MaybeRefOrGetter<import('~/types/domain').ItemBase>,
  kind: 'gym' | 'resoler' | 'shoe',
) {
  const seoText = useSeoText()
  const mediaUrl = useMediaUrl()
  usePageSeo(() => {
    const data = toValue(item)
    return {
      title: data.seoTitle || seoText(`${kind}Title`, { name: data.name }),
      description:
        data.seoDescription || data.summary || seoText(`${kind}Description`, { name: data.name }),
      image: data.cover ? mediaUrl(data.cover.path) : null,
      imageAlt: data.cover?.alt,
      imageWidth: data.cover?.width,
      imageHeight: data.cover?.height,
      robots: data.noindex ? ROBOTS_NOINDEX_FOLLOW : undefined,
    }
  })
}

/** ItemList of the full (unfiltered) listing, e.g. gyms or shoes, for the index pages. */
export function useItemListJsonLd(
  items: MaybeRefOrGetter<{ name: string; slug: string }[]>,
  detailRoute: LocalizedRouteName,
) {
  const routeUrl = useRouteUrl()
  useJsonLd('list', () =>
    itemListLd(
      toValue(items).map((item) => ({
        name: item.name,
        url: routeUrl(detailRoute, { slug: item.slug }),
      })),
    ),
  )
}

/** URL of the author page (Person in JSON-LD): the Spanish one, which always exists once published. */
export function useAuthorUrl() {
  const localePath = useLocalePath()
  const absolute = useAbsoluteUrl()
  return { aboutUrl: absolute(localePath({ name: 'about' }, 'es')) }
}
