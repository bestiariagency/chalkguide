/**
 * Localized routes (README de diseño §6, aprobado). Single source of truth for:
 *  - @nuxtjs/i18n `customRoutes: 'config'` → `pages` (keys = Nuxt route names from app/pages),
 *  - `routeRules` in nuxt.config.ts (es without prefix, en under /en).
 *
 * Why 'config' instead of definePageMeta/defineI18nRoute: the slug table lives in one place,
 * and routeRules/sitemap can be derived from it without parsing every page.
 *
 * `render` (F3.14, see .ai/devops.md "Estrategia de render"):
 *  - 'prerender': static at build, never changes between deploys (needs a real /en version).
 *  - { isr: seconds }: Netlify Durable Cache. Nitro's netlify preset sends
 *    `Netlify-CDN-Cache-Control: public, max-age=<s>, stale-while-revalidate=1y, durable`: the
 *    function runs at most once per TTL per URL and stale content is served while revalidating.
 *    Rendered on demand, so an /en without content only 404s at request time (never breaks the build).
 *  - 'ssr': no cache, per visit (token pages).
 *  - 'spa': `ssr: false`, no cache. For pages whose URL carries a secret token that must never
 *    pass through the server render (D66 preferences). Always sent with `Referrer-Policy: no-referrer`.
 */
export type RenderMode = 'prerender' | 'ssr' | 'spa' | { isr: number }

const MIN = 60
const HOUR = 60 * MIN
/** Live listings, home and agenda: new content visible within ~10 min. */
const LIVE = { isr: 10 * MIN } as const
/** Detail pages and articles: change rarely. */
const DETAIL = { isr: 1 * HOUR } as const
/** Editorial and legal text kept in guide.pages (F6.13, D34): editable from the panel, so as fresh as listings. */
const PAGES = LIVE

type Path = `/${string}`

export interface LocalizedRoute {
  es: Path
  en: Path
  render: RenderMode
  /** Token in the URL: send `Referrer-Policy: no-referrer` so it never leaks through a link. */
  noReferrer?: boolean
}

export const localizedRoutes = {
  index: { es: '/', en: '/', render: LIVE },

  // Guides (first level, no /guias hub)
  'climbing-gyms': { es: '/rocodromos', en: '/climbing-gyms', render: LIVE },
  'climbing-gyms-slug': { es: '/rocodromos/[slug]', en: '/climbing-gyms/[slug]', render: DETAIL },
  'climbing-shoes': { es: '/pies-de-gato', en: '/climbing-shoes', render: LIVE },
  'climbing-shoes-slug': {
    es: '/pies-de-gato/[slug]',
    en: '/climbing-shoes/[slug]',
    render: DETAIL,
  },
  'climbing-shoe-resoling': {
    es: '/resolar-pies-de-gato',
    en: '/climbing-shoe-resoling',
    render: LIVE,
  },
  'climbing-shoe-resoling-slug': {
    es: '/resolar-pies-de-gato/[slug]',
    en: '/climbing-shoe-resoling/[slug]',
    render: DETAIL,
  },

  // Blog (flat articles, translated slugs)
  blog: { es: '/blog', en: '/blog', render: LIVE },
  'blog-slug': { es: '/blog/[slug]', en: '/blog/[slug]', render: DETAIL },
  'blog-category-slug': {
    es: '/blog/categoria/[slug]',
    en: '/blog/category/[slug]',
    render: LIVE,
  },

  // News (F8, D73): live data, 10 min ISR. The page is a detail route whose English version exists
  // only with an English title and summary (D3); a note or a correction must show up within minutes.
  news: { es: '/noticias', en: '/news', render: LIVE },
  'news-category-slug': {
    es: '/noticias/categoria/[slug]',
    en: '/news/category/[slug]',
    render: LIVE,
  },
  'news-slug': { es: '/noticias/[slug]', en: '/news/[slug]', render: LIVE },

  // Events
  events: { es: '/agenda', en: '/events', render: LIVE },
  'events-month': { es: '/agenda/[month]', en: '/events/[month]', render: LIVE },

  // Editorial
  about: { es: '/sobre-mi', en: '/about', render: PAGES },
  // isr (not prerender, F6.13): content comes from guide.pages, a publish from the panel must show
  // up in minutes without a deploy, and /en 404s until it has an English
  // version (D3), which would fail the prerender.
  transparency: { es: '/transparencia', en: '/transparency', render: PAGES },

  // Newsletter (the two token pages are per-visit: never prerendered)
  newsletter: { es: '/newsletter', en: '/newsletter', render: 'prerender' },
  'newsletter-confirmed': {
    es: '/newsletter/confirmada',
    en: '/newsletter/confirmed',
    render: 'spa',
    noReferrer: true,
  },
  // D66: both read ?t=<token> on the client only (ssr:false), strip it from the URL.
  'newsletter-preferences': {
    es: '/newsletter/preferencias',
    en: '/newsletter/preferences',
    render: 'spa',
    noReferrer: true,
  },
  'newsletter-unsubscribed': {
    es: '/newsletter/baja',
    en: '/newsletter/unsubscribed',
    render: 'ssr',
  },

  // Utility and legal
  'sign-in': { es: '/entrar', en: '/sign-in', render: 'prerender' },
  privacy: { es: '/privacidad', en: '/privacy', render: PAGES },
  cookies: { es: '/cookies', en: '/cookies', render: PAGES },
  'legal-notice': { es: '/aviso-legal', en: '/legal-notice', render: PAGES },
} as const satisfies Record<string, LocalizedRoute>

export type LocalizedRouteName = keyof typeof localizedRoutes

/** @nuxtjs/i18n `pages` option: `{ routeName: { es, en } }`. */
export function i18nPages(): Record<string, { es: Path; en: Path }> {
  return Object.fromEntries(
    Object.entries(localizedRoutes).map(([name, r]) => [name, { es: r.es, en: r.en }]),
  )
}

/** Nitro route pattern: `[param]` → `**` (whole subtree); `/en` prefix for English. */
function toPattern(path: Path, locale: 'es' | 'en'): string {
  const base = path.replace(/\/\[[^\]]+\]$/, '/**')
  if (locale === 'es') return base
  return base === '/' ? '/en' : `/en${base}`
}

/** routeRules for every localized route, es and en. */
export type LocalizedRouteRule =
  | { prerender: true }
  | { ssr: boolean; headers: Record<string, string> }
  | { isr: number }

export function localizedRouteRules(): Record<string, LocalizedRouteRule> {
  const rules: Record<string, LocalizedRouteRule> = {}
  for (const r of Object.values<LocalizedRoute>(localizedRoutes)) {
    for (const locale of ['es', 'en'] as const) {
      const headers: Record<string, string> = { 'cache-control': 'private, no-store' }
      if (r.noReferrer) headers['referrer-policy'] = 'no-referrer'
      rules[toPattern(r[locale], locale)] =
        r.render === 'prerender'
          ? { prerender: true }
          : r.render === 'ssr' || r.render === 'spa'
            ? { ssr: r.render === 'ssr', headers }
            : { isr: r.render.isr }
    }
  }
  return rules
}
