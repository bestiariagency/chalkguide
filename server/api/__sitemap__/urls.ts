import { localizedRoutes, type LocalizedRouteName } from '../../../i18n/localized-routes'
import { isCategoryIndexable, isEnglishListingReady, isMonthIndexable } from '../../../app/utils/seo'

/**
 * Sitemap source (@nuxtjs/sitemap, `sitemap.sources`). Lists only what is published and indexable,
 * with an `en` alternate only when the English version really exists (D3, README §6):
 *   - static pages (home, listings, blog, agenda, about, transparency, newsletter),
 *   - item pages (gyms, resolers, shoes), articles, indexable categories, current/future agenda months.
 * Excluded: drafts, `noindex` records, legal/utility pages, past or empty months, anything with query.
 *
 * Read-only against Supabase REST with the public publishable key (RLS decides what is public;
 * never service_role). Rules shared with the app live in app/utils/seo.ts.
 */
type Locale = 'es' | 'en'

interface SitemapEntry {
  loc: string
  lastmod?: string
  alternatives?: { hreflang: string; href: string }[]
}

function routePath(name: LocalizedRouteName, locale: Locale, params: Record<string, string> = {}) {
  const raw = localizedRoutes[name][locale].replace(/\[(\w+)\]/g, (_, key: string) => params[key] ?? '')
  if (locale === 'es') return raw
  return raw === '/' ? '/en' : `/en${raw}`
}

/** One entry per indexable locale; alternates only when both locales are indexable. */
function entries(
  site: string,
  name: LocalizedRouteName,
  versions: Partial<Record<Locale, { params?: Record<string, string> }>>,
  lastmod?: string,
): SitemapEntry[] {
  const locales = (['es', 'en'] as const).filter((locale) => versions[locale])
  const href = (locale: Locale) => `${site}${routePath(name, locale, versions[locale]?.params)}`
  const both = locales.length === 2
  return locales.map((locale) => ({
    loc: href(locale),
    lastmod,
    ...(both
      ? {
          alternatives: [
            { hreflang: 'es', href: href('es') },
            { hreflang: 'en', href: href('en') },
            { hreflang: 'x-default', href: href('es') },
          ],
        }
      : {}),
  }))
}

const latest = (...dates: (string | null | undefined)[]) =>
  dates.filter((d): d is string => !!d).sort().at(-1)

interface ItemRow {
  slug: string
  category: 'gym' | 'resoler' | 'shoe'
  has_en: boolean | null
  updated_at: string
  verified_at: string | null
  author_review: { has_en: boolean | null }[] | null
}
interface ArticleRow {
  slug_es: string
  slug_en: string | null
  has_en: boolean | null
  updated_at: string
  category_id: string
}
interface CategoryRow {
  id: string
  slug_es: string
  slug_en: string | null
  has_en: boolean | null
  description_es: string | null
  description_en: string | null
  updated_at: string
}
interface PageRow {
  key: string
  has_en: boolean | null
  updated_at: string
}
interface EventRow {
  starts_at: string
  has_en: boolean | null
}

const ITEM_ROUTE = {
  gym: { list: 'climbing-gyms', detail: 'climbing-gyms-slug' },
  resoler: { list: 'climbing-shoe-resoling', detail: 'climbing-shoe-resoling-slug' },
  shoe: { list: 'climbing-shoes', detail: 'climbing-shoes-slug' },
} as const satisfies Record<string, { list: LocalizedRouteName; detail: LocalizedRouteName }>

export default defineEventHandler(async (event) => {
  const config = useRuntimeConfig(event)
  const supabaseUrl = String(config.public.supabase?.url ?? '').replace(/\/$/, '')
  const key = String(config.public.supabase?.key ?? '')
  const site = String(getSiteConfig(event).url || config.public.siteUrl || '').replace(/\/+$/, '')
  if (!supabaseUrl || !key) {
    throw createError({ statusCode: 500, statusMessage: 'Supabase public config missing' })
  }

  const rest = <T>(table: string, query: string) =>
    $fetch<T[]>(`${supabaseUrl}/rest/v1/${table}?${query}`, {
      headers: { apikey: key, 'Accept-Profile': 'guide' },
    })

  const now = new Date()
  const nowIso = now.toISOString()
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  const windowEnd = new Date(now.getTime() + 60 * 24 * 3600 * 1000).toISOString()

  const [items, articles, categories, pages, events] = await Promise.all([
    rest<ItemRow>(
      'items',
      'select=slug,category,has_en,updated_at,verified_at,author_review:author_reviews(has_en)&published=eq.true&noindex=eq.false',
    ),
    rest<ArticleRow>(
      'articles',
      `select=slug_es,slug_en,has_en,updated_at,category_id&status=in.(published,scheduled)&published_at=lte.${nowIso}&noindex=eq.false`,
    ),
    rest<CategoryRow>(
      'article_categories',
      'select=id,slug_es,slug_en,has_en,description_es,description_en,updated_at',
    ),
    rest<PageRow>('pages', 'select=key,has_en,updated_at&published=eq.true&noindex=eq.false'),
    rest<EventRow>(
      'events',
      `select=starts_at,has_en&status=eq.approved&starts_at=gte.${monthStart}`,
    ),
  ])

  const out: SitemapEntry[] = []

  // Same rule as the app (fetchItems): an English item also needs its author review translated.
  const itemHasEn = (item: ItemRow) =>
    item.has_en === true && (item.author_review ?? []).every((review) => review.has_en === true)

  // Items: detail pages and the three listings.
  for (const kind of ['gym', 'resoler', 'shoe'] as const) {
    const ofKind = items.filter((item) => item.category === kind)
    const english = ofKind.filter(itemHasEn)
    const listLastmod = latest(...ofKind.map((item) => latest(item.updated_at, item.verified_at)))
    out.push(
      ...entries(
        site,
        ITEM_ROUTE[kind].list,
        { es: {}, ...(isEnglishListingReady(kind, english.length) ? { en: {} } : {}) },
        listLastmod,
      ),
    )
    for (const item of ofKind) {
      const params = { slug: item.slug }
      out.push(
        ...entries(
          site,
          ITEM_ROUTE[kind].detail,
          { es: { params }, ...(itemHasEn(item) ? { en: { params } } : {}) },
          latest(item.updated_at, item.verified_at),
        ),
      )
    }
  }

  // Blog index, articles (translated slugs) and categories.
  const englishArticles = articles.filter((article) => article.has_en && article.slug_en)
  out.push(
    ...entries(
      site,
      'blog',
      { es: {}, ...(isEnglishListingReady('article', englishArticles.length) ? { en: {} } : {}) },
      latest(...articles.map((article) => article.updated_at)),
    ),
  )
  for (const article of articles) {
    out.push(
      ...entries(
        site,
        'blog-slug',
        {
          es: { params: { slug: article.slug_es } },
          ...(article.has_en && article.slug_en ? { en: { params: { slug: article.slug_en } } } : {}),
        },
        article.updated_at,
      ),
    )
  }
  for (const category of categories) {
    const inCategory = articles.filter((article) => article.category_id === category.id)
    const esIndexable = isCategoryIndexable(inCategory.length, category.description_es)
    const enCount = inCategory.filter((article) => article.has_en && article.slug_en).length
    const enIndexable =
      category.has_en === true &&
      !!category.slug_en &&
      isCategoryIndexable(enCount, category.description_en)
    const lastmod = latest(category.updated_at, ...inCategory.map((article) => article.updated_at))
    out.push(
      ...entries(
        site,
        'blog-category-slug',
        {
          ...(esIndexable ? { es: { params: { slug: category.slug_es } } } : {}),
          ...(enIndexable ? { en: { params: { slug: category.slug_en as string } } } : {}),
        },
        lastmod,
      ),
    )
  }

  // Agenda: hub (perennial URL) and current/future months with at least one event.
  const upcomingEnglish = events.filter(
    (e) => e.has_en && e.starts_at >= nowIso && e.starts_at < windowEnd,
  ).length
  out.push(
    ...entries(site, 'events', {
      es: {},
      ...(isEnglishListingReady('event', upcomingEnglish) ? { en: {} } : {}),
    }),
  )
  const months = new Map<string, { es: number; en: number }>()
  for (const e of events) {
    const monthKey = e.starts_at.slice(0, 7)
    const count = months.get(monthKey) ?? { es: 0, en: 0 }
    count.es++
    if (e.has_en) count.en++
    months.set(monthKey, count)
  }
  for (const [monthKey, count] of months) {
    // Months have no cross-locale alternates (the English month may be empty): each is its own page.
    for (const locale of ['es', 'en'] as const) {
      if (isMonthIndexable(monthKey, count[locale], now)) {
        out.push({ loc: `${site}${routePath('events-month', locale, { month: monthKey })}` })
      }
    }
  }

  // Editorial pages published in guide.pages (legal pages are noindex: not listed).
  const pageByKey = new Map(pages.map((page) => [page.key, page]))
  for (const [pageKey, route] of [
    ['about', 'about'],
    ['transparency', 'transparency'],
  ] as const) {
    const page = pageByKey.get(pageKey)
    if (!page) continue
    out.push(
      ...entries(site, route, { es: {}, ...(page.has_en ? { en: {} } : {}) }, page.updated_at),
    )
  }

  // Home and the newsletter landing exist in both languages.
  const siteLastmod = latest(
    ...items.map((item) => item.updated_at),
    ...articles.map((article) => article.updated_at),
  )
  out.push(...entries(site, 'index', { es: {}, en: {} }, siteLastmod))
  out.push(...entries(site, 'newsletter', { es: {}, en: {} }))

  return out
})
