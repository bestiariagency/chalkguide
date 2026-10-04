// https://nuxt.com/docs/api/configuration/nuxt-config
import tailwindcss from '@tailwindcss/vite'

// Public site URL (canonical, hreflang, sitemap, robots, OG). Read at build time;
// the placeholder is only for local development until the domain is decided.
const siteUrl = process.env.NUXT_PUBLIC_SITE_URL || 'https://chalkguide.example'

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

  css: ['~/assets/css/main.css'],

  vite: {
    plugins: [tailwindcss()],
  },

  typescript: {
    strict: true,
  },

  app: {
    head: {
      charset: 'utf-8',
      viewport: 'width=device-width, initial-scale=1',
      // Provisional brand name until naming is final.
      titleTemplate: '%s · ChalkGuide',
      link: [{ rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' }],
    },
  },

  runtimeConfig: {
    public: {
      siteUrl,
    },
  },

  // Shared by @nuxtjs/sitemap and @nuxtjs/robots (nuxt-site-config).
  site: {
    url: siteUrl,
    name: 'ChalkGuide',
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
  },

  supabase: {
    // Public content site: no auth-gated routes, so never redirect to a login page.
    redirect: false,
    // No schema yet. Point this at generated types once the database exists.
    types: false,
  },

  // Hybrid rendering. Route names below are placeholders until the architecture step.
  routeRules: {
    // Static content pages (home, about, guides…): prerendered at build time and
    // served from Netlify's CDN. Add each new editorial page here (es + /en).
    '/': { prerender: true },
    '/en': { prerender: true },

    // Future dynamic pages (gym detail, area listings, reviews): server-rendered on
    // demand by a Netlify Function so new data is visible without a rebuild.
    // Consider `swr`/`isr` here once the acceptable staleness is decided.
    '/gyms/**': { ssr: true },
    '/en/gyms/**': { ssr: true },

    // Internal API endpoints: never prerendered, never indexed.
    '/api/**': { ssr: true, robots: false },
  },

  nitro: {
    preset: 'netlify',
  },
})
