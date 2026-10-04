# ChalkGuide

Sitio público de contenido del directorio de rocódromos (con reseñas) del área metropolitana de Barcelona. Bilingüe: español (por defecto) e inglés.

## Stack

- [Nuxt 4](https://nuxt.com) (directorio `app/`, TypeScript estricto), renderizado híbrido (`routeRules`)
- [Tailwind CSS v4](https://tailwindcss.com) vía `@tailwindcss/vite`, tokens en `app/assets/css/main.css` (provisionales)
- `@nuxtjs/i18n` (`es` por defecto, `en`, estrategia `prefix_except_default`), traducciones en `i18n/locales/`
- `@nuxt/image`, `@nuxtjs/sitemap`, `@nuxtjs/robots`
- `@nuxtjs/supabase` (solo configurado, `redirect: false`)
- `@nuxt/eslint` + Prettier (`prettier-plugin-tailwindcss`, `eslint-config-prettier`)
- Despliegue en Netlify (preset `netlify`, ver `netlify.toml`)

## Requisitos

- Node 24 LTS (`nvm use`)
- npm

## Puesta en marcha

```bash
nvm use
npm install
cp .env.example .env   # y rellena los valores
npm run dev            # http://localhost:3000 y http://localhost:3000/en
```

## Variables de entorno

| Variable                   | Descripción                                                                                                              |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `NUXT_PUBLIC_SUPABASE_URL` | URL del proyecto Supabase. **Obligatoria**: sin ella el SSR/prerender devuelve 500.                                      |
| `NUXT_PUBLIC_SUPABASE_KEY` | Clave _publishable_ (antes "anon") de Supabase. Nunca la `secret`/`service_role`.                                        |
| `NUXT_PUBLIC_SITE_URL`     | URL pública del sitio, sin barra final. Se usa para canonical/hreflang, sitemap, robots y OG. Se lee en tiempo de build. |

En Netlify, define las mismas variables en _Site configuration → Environment variables_.

## Scripts

| Script                 | Qué hace                                        |
| ---------------------- | ----------------------------------------------- |
| `npm run dev`          | Servidor de desarrollo                          |
| `npm run build`        | Build de producción (preset Netlify) en `dist/` |
| `npm run generate`     | Build 100 % estático (prerender de todo)        |
| `npm run preview`      | Previsualiza el build                           |
| `npm run lint`         | ESLint                                          |
| `npm run lint:fix`     | ESLint con autocorrección                       |
| `npm run format`       | Prettier (escribe)                              |
| `npm run format:check` | Prettier (solo comprueba)                       |
| `npm run typecheck`    | `nuxt typecheck` (vue-tsc)                      |
