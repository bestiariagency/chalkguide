# Marketing y SEO · ChalkGuide

## Objetivo

Audiencia propia: **suscriptores de newsletter** obtenidos de forma orgánica (búsqueda + Instagram).
Toda propuesta se justifica por su impacto en visibilidad orgánica o en altas de newsletter.
Sin ingresos en los primeros 12 meses; afiliados desde el comparador de pies de gato.

## SEO técnico

- `useSeoMeta` / `useHead` por página: `title` y `description` únicos por idioma, OG y Twitter cards
  con imagen, canonical.
- i18n: `hreflang` es/en + `x-default` (gestionado por `@nuxtjs/i18n` con `baseUrl`), `lang` correcto.
- `@nuxtjs/sitemap` y `@nuxtjs/robots`; `/api/**` no indexado; borradores nunca en sitemap.
- Prerender o SSR para que todo contenido indexable llegue en HTML.
- `NUXT_PUBLIC_SITE_URL` define el dominio (pendiente: chalkguide.com o .es).

## Indexación por entorno y sitemap

- Solo el deploy `production` de Netlify con dominio real (`NUXT_PUBLIC_SITE_URL`) es indexable. `nuxt.config.ts`
  lee `CONTEXT` (previews y branch deploys también tienen `NODE_ENV=production`) y un dominio `*.example`
  nunca es indexable. `NUXT_SITE_INDEXABLE=true|false` fuerza el valor. No indexable → `Disallow: /` y sitemap vacío.
- `robots.txt` indexable: `Disallow: /api/` y `/administrador/` (sin bloquear URLs con query: Google debe leer el canonical).
- Metadatos por página: `usePageSeo()` / `useItemSeo()`; canonical, hreflang y `og:url` salen de `useSiteSeo()` (app.vue).
  hreflang solo entre versiones que existen (D3); listados `/en` con umbral (≥ 5 rocódromos, ≥ 3 el resto, ≥ 1 evento).
- Sitemap: `server/api/__sitemap__/urls.ts` (Supabase REST con la clave publishable); las fuentes de app del módulo están apagadas.
  Las reglas de indexación compartidas viven en `app/utils/seo.ts` (la usan la app y el servidor).

## Schema.org (JSON-LD)

- Rocódromos: `SportsActivityLocation` (`LocalBusiness`) con dirección, horarios, precios.
- Resoladores: `LocalBusiness`.
- Pies de gato: `Product` con `offers` (rango de precio, fecha).
- Artículos: `Article` con autor (`Person`, Xavi).
- Reseña del autor: `Review`. `AggregateRating` solo con ≥ 3 opiniones de usuarios reales.
- `Organization`/`WebSite` en el layout.

## Analítica y privacidad

- Analítica respetuosa con la privacidad; ningún script de terceros sin aprobación de Xavi.
- Sin tracking de datos personales sin consentimiento (RGPD/LSSI).
- Eventos de conversión: alta de newsletter, login para opinar, opinión enviada, clic de afiliado.

## Afiliados

Deporvillage, Barrabes, Decathlon cuando haya programas activos. Enlaces marcados y con
`rel="sponsored nofollow"`. Ninguna vía compra una reseña.

## Alcance

Tocas metadatos, JSON-LD, config de sitemap/robots/i18n SEO y analítica. Cambios de componentes →
propuesta para coneja-lucky; textos → loro-lola.
