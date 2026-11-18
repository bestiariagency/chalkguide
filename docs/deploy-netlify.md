# Deploy en Netlify (F4.1) · checklist para Xavi

Config en git: `netlify.toml` (build, Node 24, `dist/`), `nuxt.config.ts` (preset `netlify`, `routeRules`,
cabeceras, robots por `CONTEXT`), `server/plugins/content-api-errors.ts` (errores de `/api/content/**` sin caché).
Detalle técnico: `.ai/devops.md`. Dominio decidido: `chalkguide.es` (D67), aún no comprado ni apuntado: la
primera preview usa la URL `*.netlify.app`.

## Qué hace el build de Netlify

Comando (de `netlify.toml`, no cambiarlo en la UI):
`npm run lint && npm run typecheck && npm run check:sanitizer && npm run build && npm run check:bundle`

- `check:sanitizer`: baterías del saneador de HTML editorial (sin red, segundos).
- `check:bundle`: ningún chunk público incluye el saneador (lee el resultado del build, por eso va después).
- `check:content-api` **no** va en Netlify: levanta un `nuxt dev` y habla con Supabase. Córrelo en local.
- Las herramientas (`tsx`) están en `devDependencies`; Netlify las instala (no pongas `NODE_ENV=production` ni `NPM_FLAGS=--omit=dev`).
- sharp: el lockfile trae los binarios de todas las plataformas como opcionales (`@img/sharp-linux-x64`, etc.).
  Netlify instala los de linux-x64 y `@nuxt/image` los empaqueta en la función. El aviso local
  «sharp binaries ... darwin-arm64» es solo de tu Mac. No hace falta `.npmrc`. No borres `package-lock.json`
  ni lo regeneres con `--omit=optional`.

## 1. Crear el sitio

1. Netlify -> Add new site -> Import an existing project -> GitHub -> repo de ChalkGuide, rama `main`.
2. Build settings: no cambiar nada, salen de `netlify.toml` (build command de arriba, publish `dist`, Node 24).
   No hay carpeta de funciones que configurar: Nitro genera la función SSR.
3. Antes del primer deploy, añade las variables (paso 2). Si el primer deploy arranca solo sin variables, fallará o saldrá vacío: relánzalo con "Clear cache and deploy".
4. Opcional: en Site configuration -> Build & deploy -> Deploy previews, deja activados los previews de PR y de branch deploys.

## 2. Variables de entorno (Site configuration -> Environment variables)

Lista completa. El código solo lee estas (`nuxt.config.ts`, `server/`, `app/`); `CONTEXT` lo pone Netlify.

| Variable | Valor | Production | Deploy preview | Branch deploy |
| --- | --- | --- | --- | --- |
| `NUXT_PUBLIC_SUPABASE_URL` | `https://eqtjlafxtrzbjazhhyin.supabase.co` | sí | sí | sí |
| `NUXT_PUBLIC_SUPABASE_KEY` | clave **publishable** (Supabase -> Settings -> API). Nunca `service_role` ni secret | sí | sí | sí |
| `NUXT_PUBLIC_SITE_URL` | URL sin barra final. Ahora `https://<nombre>.netlify.app`; con dominio `https://chalkguide.es` | sí | opcional (si no, usa el placeholder `chalkguide.example`, ya `noindex`) | opcional |
| `NUXT_SITE_INDEXABLE` | `false` | sí, **mientras no haya dominio** | no hace falta (ya `noindex` por `CONTEXT`) | no hace falta |

Notas:
- Son las únicas variables. Ningún secreto en Netlify ni con prefijo `NUXT_PUBLIC_`: Claude/Brevo/`service_role` viven en `supabase secrets`. Ninguna ruta de `server/` los necesita hoy (usa URL + clave publicable, sin sesión).
- Todas se leen en **build**: cambiarlas exige redeploy (Deploys -> Trigger deploy -> Clear cache and deploy).
- No definas `CONTEXT` ni `NODE_VERSION` (los pone Netlify / `netlify.toml`).
- `NUXT_SITE_INDEXABLE=false` evita que la producción en `*.netlify.app` sea indexable. Cuando compres y apuntes `chalkguide.es`: cambia `NUXT_PUBLIC_SITE_URL` a `https://chalkguide.es`, borra `NUXT_SITE_INDEXABLE` y redeploy. Solo `production` queda indexable; previews y branch deploys siempre salen `noindex`.
- Si pones `NUXT_PUBLIC_SITE_URL` de producción en las previews, el canonical apunta a producción; inocuo porque son `noindex`.

## 3. Supabase Auth (login con Google, 4.2)

Supabase -> Authentication -> URL Configuration:
- Site URL: `https://<nombre>.netlify.app` (luego `https://chalkguide.es`).
- Redirect URLs (el sitio redirige a `origin + ruta?...&opinar=1`, por eso con comodín de ruta):
  - `https://<nombre>.netlify.app/**`
  - `https://*--<nombre>.netlify.app/**` (deploy previews `deploy-preview-N--...` y branch deploys)
  - `http://localhost:3000/**`
  - cuando haya dominio: `https://chalkguide.es/**`
- Aviso: el proyecto es compartido con Chalk app; **añade** URLs, no sustituyas las existentes.
- Google Cloud (OAuth client): el redirect autorizado es el callback de Supabase
  (`https://eqtjlafxtrzbjazhhyin.supabase.co/auth/v1/callback`), ya configurado para Chalk app; no hace falta
  añadir dominios de Netlify. Comprueba que el proveedor Google está activo.

## 4. Primer deploy: qué mirar

1. Build en verde. En el log: lint, typecheck, `118/118`, `50/50`, `43/43` (sanitizer), `Build complete`, y `check-client-bundle: ... 0 with sanitizer`. Si falla, copia la última línea de error a osset-op.
2. Abre `/`, `/en`, una ficha (`/rocodromos/...`), `/agenda`, un artículo: cargan con datos de Supabase.
3. `/robots.txt`: `Disallow: /`; `/sitemap.xml` vacío (mientras `NUXT_SITE_INDEXABLE=false` y en toda preview).
4. Login con Google desde una ficha vuelve al sitio (también en una deploy preview).
5. Panel `/administrador` carga y entra (solo tú).
6. Avisa a osset-op para el smoke test 4.9 (abajo) con la URL de la preview.

## 5. Limpieza programada (sin relación con Netlify)

El cron de limpieza vive en Supabase y no depende de Netlify. Comprobación: panel -> Inicio -> fila `cleanup`
debe mostrar estado 200 y una comprobación de menos de 48 h (`cleanup_last_status = 200`). Si dice «nunca
comprobada», «más de 48 h» o un fallo, avisa a jabali-javi. Verifícalo tras el run del 2026-11-13.

## 6. Smoke test 4.9 (osset-op, en la preview)

Sustituye `$U` por la URL. Resultado -> anótalo en `docs/PLAN.md` (4.9).

1. Durable Cache: `curl -sI $U/` dos veces. Esperado: `Netlify-CDN-Cache-Control` con `durable`, `Cache-Control: public, max-age=0, must-revalidate`; segunda petición `Cache-Status` con `hit`. Tras un nuevo deploy, la caché se purga (primer hit vuelve a ser miss).
2. Query en listados: `curl -sI "$U/pies-de-gato?nivel=..."` con dos valores de query distintos. Si devuelven el mismo cuerpo/hit cruzado, añadir `Netlify-Vary: query` a esas rutas.
3. 404 en ruta `isr`: `curl -sI $U/en/transparency` (sin contenido en /en). Mirar si el 404 queda en caché (`Cache-Status` hit en la segunda). Si se cachea, vale como máximo el TTL; decidir si basta.
4. `_headers` de lo prerenderizado (`/newsletter`, `/entrar`): `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, CSP `frame-ancestors 'none'`. `/_nuxt/*.js`: `immutable`. `/api/__sitemap__/urls`: `private, no-store`.
5. robots por `CONTEXT`: en preview `/robots.txt` = `Disallow: /`, `<meta name="robots" content="noindex">`, `X-Robots-Tag` en rutas privadas, sitemap vacío.
6. **`/api/content/**` (D64, leona-lia obs 2 y 3):**
   - Cabeceras 200: `curl -sI "$U/api/content/page/about"` -> `Cache-Control: public, max-age=0, must-revalidate`, `Netlify-CDN-Cache-Control` con `durable`, `Netlify-Vary: query=locale`. Lo mismo en `/api/content/article/<slug>` e `/api/content/item/gym/<slug>`.
   - Idioma en la clave de caché: pide `"$U/api/content/page/about?locale=es"` y luego `"...?locale=en"` (dos veces cada una). El cuerpo `en` debe ser inglés (o 404 si no hay `/en`) y nunca el español cacheado. Si se mezclan, `Netlify-Vary` no basta: avisa a osset-op.
   - Errores sin caché: `curl -si "$U/api/content/page/about?x=1"` (400) y `"$U/api/content/page/nope"` (400) -> `Cache-Control: no-store` y `Netlify-CDN-Cache-Control: no-store`; repetida no da `Cache-Status: hit`. El 502 usa la misma ruta de error: no se puede provocar fácil en preview (para forzarlo: poner una `NUXT_PUBLIC_SUPABASE_KEY` inválida en un branch deploy y pedir un slug válido; esperado 502 sin caché; restaurar después). Si algún error queda en caché, avisar: habría que ajustar `server/plugins/content-api-errors.ts`.
   - Resto de `/api/**` (`/api/__sitemap__/urls`): `private, no-store`.
7. Edición: cambiar un dato en Supabase (p. ej. un texto de una ficha) y comprobar que la web lo refleja tras el TTL (10 min listados, 1 h fichas) sin rebuild.
