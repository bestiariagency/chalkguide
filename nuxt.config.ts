// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from '@tailwindcss/vite'
import { i18nPages, localizedRouteRules, localizedRoutes } from './i18n/localized-routes'
import { ROUTE_ROBOTS } from './app/utils/seo'
import { heroIntroHeadScript } from './app/utils/hero-intro'

// Public site URL (canonical, hreflang, sitemap, robots, OG). Read at build time;
// the placeholder is only for local development until the domain is decided.
const siteUrl = process.env.NUXT_PUBLIC_SITE_URL || 'https://chalkguide.example'

// Indexing switch (robots.txt, <meta robots>, X-Robots-Tag, sitemap). Only the Netlify
// *production* deploy is indexable: previews (`deploy-preview`) and branch deploys
// (`branch-deploy`) have NODE_ENV=production too, so NODE_ENV alone is not enough. Netlify sets
// CONTEXT at build time. A placeholder domain (`.example`) is never indexable either.
// NUXT_SITE_INDEXABLE=true|false overrides everything (e.g. to test robots locally).
// Without CONTEXT (local dev/build) the module default applies: indexable only if NODE_ENV=production.
const netlifyContext = process.env.CONTEXT
const placeholderDomain = /\.example$/.test(new URL(siteUrl).hostname)
const indexable = process.env.NUXT_SITE_INDEXABLE
  ? process.env.NUXT_SITE_INDEXABLE === 'true'
  : netlifyContext
    ? netlifyContext === 'production' && !placeholderDomain
    : placeholderDomain
      ? false
      : undefined

// X-Robots-Tag for routes that are never indexed (legal, entrar, newsletter states, §6), so the
// header agrees with the <meta robots> that useSiteSeo() emits. Pages decided by data (past
// agenda months, thin categories, noindex records) only carry the meta tag.
const routeRobotsRules = Object.fromEntries(
  Object.entries(ROUTE_ROBOTS).flatMap(([name, robots]) => {
    const route = localizedRoutes[name as keyof typeof localizedRoutes]
    return [route.es, `/en${route.en}`].map((path) => [path, { robots }])
  }),
)

// Basic security headers. CSP: only `frame-ancestors` is enforced (equivalent to X-Frame-Options).
// A full CSP is a proposal in .ai/devops.md: Nuxt's inline hydration/payload scripts would need
// 'unsafe-inline' or per-request nonces, so it is not enforced blindly.
const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'permissions-policy':
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()',
  'x-frame-options': 'DENY',
  'content-security-policy': "frame-ancestors 'none'",
}

// `/api/content/**` (sanitized HTML for articles, pages and item reviews) follows the TTL of the
// page that consumes it. The explicit `cache-control` replaces the generic `no-store` of `/api/**`
// (same value the Netlify preset sends for `isr`). Error responses are forced to `no-store` by
// server/plugins/content-api-errors.ts.
function contentApiRules() {
  const ttl = (route: keyof typeof localizedRoutes) => {
    const render = localizedRoutes[route].render
    if (typeof render !== 'object') throw new Error(`/api/content: ${route} must be isr`)
    return render.isr
  }
  const rule = (route: keyof typeof localizedRoutes) => ({
    isr: ttl(route),
    headers: {
      'cache-control': 'public, max-age=0, must-revalidate',
      // Cache key per `locale` (the only query parameter the routes accept): without it a cached
      // `?locale=es` could be served for `?locale=en`. F4.1, leona-lia D64 obs 3.
      'netlify-vary': 'query=locale',
    },
  })
  return {
    '/api/content/article/**': rule('blog-slug'),
    '/api/content/page/**': rule('about'),
    '/api/content/item/**': rule('climbing-gyms-slug'),
  }
}

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },

  modules: [
    '@nuxt/eslint',
    '@nuxt/image',
    '@nuxtjs/i18n',
    '@nuxtjs/sitemap',
    '@nuxtjs/robots',
    '@nuxtjs/supabase',
  ],

  // Self-hosted fonts (@fontsource): no Google Fonts CDN (GDPR). Only the weights the design
  // system uses, latin subset only (covers es/ca/en).
  css: [
    '@fontsource/inter/latin-400.css',
    '@fontsource/inter/latin-500.css',
    '@fontsource/jetbrains-mono/latin-400.css',
    '@fontsource/jetbrains-mono/latin-500.css',
    '@fontsource/caveat/latin-500.css',
    // Archivo (H1 of the home hero + event date) is declared in assets/css/hero.css: latin only.
    // Public Tailwind root. The panel's CSS (admin.css) and Inter 600 load from layouts/admin.vue only.
    '~/assets/css/site.css',
  ],

  vite: {
    plugins: [tailwindcss()],
  },

  typescript: {
    strict: true,
  },

  // app/spa-loading-template.html: panel background, avoids the paper flash before the SPA mounts.
  spaLoadingTemplate: true,

  app: {
    head: {
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1',
      // The title template (brand only if the title still fits in 60 characters) lives in
      // useSiteSeo() (app/composables/useSeo.ts).
      meta: [{ name: 'theme-color', content: '#0f0f0f' }],
      link: [
        { rel: 'icon', href: '/favicon.ico', sizes: '48x48' },
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        { rel: 'manifest', href: '/site.webmanifest' },
      ],
      // Motion initial states (reveal, chalk strokes) only exist with JS, so content is
      // complete without it (design system: reduced motion and no-JS rules). The same script
      // decides the home intro before first paint (no flash): only on the home, once per
      // session, never with reduced motion. The CSP does not restrict inline scripts (see above).
      script: [
        {
          innerHTML: heroIntroHeadScript(),
        },
      ],
    },
  },

  runtimeConfig: {
    // F4.6: server-only, never `public`. Same value as the Supabase EF secret. Netlify env: NEWSLETTER_RELAY_SECRET
    // (read at runtime by server/utils/newsletter-relay.ts) or NUXT_NEWSLETTER_RELAY_SECRET.
    newsletterRelaySecret: '',
    public: {
      siteUrl,
      // Optional https URL of the repository (admin runbook link in Ingesta). Empty = the panel shows the path as text.
      repoUrl: '',
      // Analytics (D69). Public by nature, all empty by default: without an ID nothing is loaded.
      // Netlify sets them in the production context only (docs/marketing/analitica-remarketing-spec.md §7).
      analyticsEnabled: false, // NUXT_PUBLIC_ANALYTICS_ENABLED: own events (layer 1) on/off
      ga4Id: '', // NUXT_PUBLIC_GA4_ID  G-XXXXXXXXXX
      gadsId: '', // NUXT_PUBLIC_GADS_ID  AW-XXXXXXXXXX
      gadsConvNewsletter: '', // NUXT_PUBLIC_GADS_CONV_NEWSLETTER  only if the own conversion tag is used
      metaPixelId: '', // NUXT_PUBLIC_META_PIXEL_ID
    },
  },

  // Shared by @nuxtjs/sitemap and @nuxtjs/robots (nuxt-site-config).
  site: {
    url: siteUrl,
    name: 'ChalkGuide',
    indexable,
  },

  robots: {
    // Only what must not be crawled. Do NOT block URLs with query: Google must be able to read
    // their canonical (README §6). Pages that must stay out of the index use `noindex`, which
    // needs to be crawlable. `/api/` also gets X-Robots-Tag via routeRules.
    disallow: ['/api/', '/administrador/'],
  },

  // Dynamic sitemap: every URL (static pages, items, articles, categories, agenda months) comes
  // from the server source, which knows what is published, what has an English version and what
  // is noindex. The module's own page/route sources are off (they would add /en URLs that 404).
  sitemap: {
    excludeAppSources: true,
    autoI18n: false,
    sources: ['/api/__sitemap__/urls'],
    exclude: ['/administrador/**'],
  },

  i18n: {
    defaultLocale: 'es',
    strategy: 'prefix_except_default',
    baseUrl: siteUrl,
    locales: [
      { code: 'es', language: 'es-ES', name: 'Español', file: 'es.json' },
      { code: 'en', language: 'en-GB', name: 'English', file: 'en.json' },
    ],
    detectBrowserLanguage: false,
    // Translated slugs live in i18n/localized-routes.ts (single table → i18n pages + routeRules).
    customRoutes: 'config',
    pages: i18nPages(),
  },

  // Covers live in the public Supabase `media` bucket: allow @nuxt/image to optimize them.
  image: {
    domains: process.env.NUXT_PUBLIC_SUPABASE_URL
      ? [new URL(process.env.NUXT_PUBLIC_SUPABASE_URL).host]
      : [],
  },

  supabase: {
    // Public content site: no auth-gated routes, so never redirect to a login page.
    redirect: false,
    // Session lives in the browser only (localStorage). With SSR cookies the server would put the
    // visitor's session in the payload of ISR-cached pages and serve it to everyone (F3.10).
    useSsrCookies: false,
    // `guide` schema types, generated by scripts/gen-guide-types.mjs (regenerate after migrations).
    types: '~/types/database.types.ts',
  },

  // Hybrid rendering (F3.14, .ai/devops.md). Every localized route (es + /en) comes from
  // i18n/localized-routes.ts: static pages → prerender; live-data pages → `isr: <seconds>`
  // (Netlify Durable Cache, stale-while-revalidate, flushed on every deploy); token pages → ssr
  // without cache. Nitro merges every matching rule, so the generic ones below apply to all.
  routeRules: {
    // Security headers on every response (prerendered → dist/_headers, SSR → set by Nitro).
    // netlify.toml [[headers]] would not reach function responses, hence routeRules.
    '/**': { headers: SECURITY_HEADERS },
    // /_nuxt/** (hashed JS/CSS and @fontsource fonts): Nuxt already sets `immutable, max-age=1y`;
    // do not override it (builds/meta has its own short TTL).

    ...localizedRouteRules(),
    ...Object.fromEntries(
      Object.entries(routeRobotsRules).map(([path, rule]) => [
        path,
        { ...(localizedRouteRules()[path] ?? {}), ...rule },
      ]),
    ),

    // Internal API endpoints: never prerendered, never indexed.
    '/api/**': { ssr: true, robots: false, headers: { 'cache-control': 'private, no-store' } },
    // F4.6 newsletter relay (sign-up, ALTCHA challenge, confirm, resend): never prerendered, never indexed, no referrer.
    '/api/newsletter/**': {
      ssr: true,
      robots: false,
      headers: {
        'cache-control': 'no-store',
        'x-robots-tag': 'noindex, nofollow',
        'referrer-policy': 'no-referrer',
      },
    },
    // Sanitized editorial content (D64, F6.19 C5): anon-only data (the routes never read the visitor's
    // session), so it is shared and cached with the same TTL as the page that uses it. Must come after
    // `/api/**`: it replaces that rule's `no-store`. Nothing else under /api is cached.
    ...contentApiRules(),
    // Panel (F6.1, D7): SPA, Spanish only (pages opt out of i18n with `i18n: false`), never indexed
    // (X-Robots-Tag + meta), never cached or shared. Not in the sitemap (its source ignores it).
    '/administrador/**': {
      ssr: false,
      robots: false,
      headers: { 'cache-control': 'private, no-store', 'x-robots-tag': 'noindex, nofollow' },
    },
  },

  nitro: {
    preset: 'netlify',
    // sanitize-html (CJS) does `require('htmlparser2')`, which is ESM-only since v12. Netlify Functions
    // run a Node without require(esm) (< 22.12), so loading it from node_modules crashed every
    // `/api/content/*` route with ERR_REQUIRE_ESM. Bundled, Rollup resolves the require at build time.
    externals: {
      inline: ['sanitize-html', 'htmlparser2', 'domhandler', 'domutils', 'dom-serializer', 'domelementtype', 'entities'],
    },
  },
})
