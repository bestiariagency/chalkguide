# DevOps · ChalkGuide

## Netlify

- `netlify.toml`: `lint && typecheck && check:sanitizer && build && check:bundle` → `dist/`, Node 24 (`check:content-api` solo en local: levanta nuxt dev). Preset Nitro `netlify` (SSR en Netlify Functions).
- Render híbrido en `nuxt.config.ts` → `routeRules`: prerender para editorial, `isr` con TTL para
  páginas con datos vivos, `/api/**` nunca prerender ni indexado. Ver "Estrategia de render".

## Estrategia de render (F3.14)

Fuente única: `i18n/localized-routes.ts` (campo `render`, es y /en). Constantes `LIVE`/`DETAIL`/`SLOW`.

| Ruta | Modo | TTL | Por qué |
| --- | --- | --- | --- |
| Home, listados (rocódromos, pies de gato, resolados), blog, categorías, agenda y meses | `isr` | 10 min | Datos editables desde el panel; visibles sin rebuild en <= 10 min |
| Fichas (rocódromos, pies de gato, resoladores) y artículos | `isr` | 1 h | Cambian poco; coste de render amortizado |
| Sobre mí, transparencia, legales (`guide.pages`) | `isr` | 10 min | F6.13/D34: editables desde el panel; un publicar/despublicar se ve en <= 10 min sin deploy. `/en` sin contenido da 404 en runtime, no rompe el build |
| Newsletter, entrar | `prerender` | build | Estáticas, con versión /en real |
| `/newsletter/confirmada\|baja` (+ /en) | `ssr` | `private, no-store` | Token por visita |
| `/api/**` | `ssr` | `private, no-store`, `robots: false` | Nunca prerender ni indexado |
| `/sitemap.xml` | módulo sitemap | `s-maxage=600, swr=3600` (propio) | Lee `/api/__sitemap__/urls` (no-store, interno) |

Cómo lo soporta el preset `netlify` (nitropack 2.13.4, Netlify Functions, no edge):
- `isr: N` emite `Netlify-CDN-Cache-Control: public, max-age=N, stale-while-revalidate=31536000, durable`
  y `Cache-Control: public, max-age=0, must-revalidate` (navegador siempre revalida). Es la Durable
  Cache de Netlify: la función corre como mucho una vez por URL y TTL; pasado el TTL se sirve la copia
  vieja mientras se regenera en segundo plano. Cada deploy purga la caché.
- `swr` de Nitro NO se usa: cachea en el storage de la función (memoria por instancia, inútil en serverless).
- No existe `index.html` de la home en `dist/`: ahora sale de la función (la primera visita tras un
  deploy o tras expirar paga el render).
- Un 404 en una ruta `isr` también lleva el header (p. ej. `/en/transparency` sin contenido). Netlify
  decide qué códigos cachea; si se cacheara, tardaría <= TTL en aparecer el /en recién publicado.
- `/api/content/**`: `isr` + `Netlify-Vary: query=locale`; los errores (4xx/5xx) salen `no-store` (plugin `server/plugins/content-api-errors.ts`) para que un 502 no quede en la Durable Cache. Verificar en preview (smoke 4.9).
- Las rutas con filtros por query (`/pies-de-gato?nivel=...`): comprobar en deploy que la clave de caché
  incluye la query; si no, añadir `Netlify-Vary: query`.

### Cabeceras de seguridad

En `routeRules['/**']` (no en `netlify.toml`: `[[headers]]` no alcanza respuestas de funciones). Se
escriben en `dist/_headers` para lo prerenderizado y las aplica Nitro en SSR: `X-Content-Type-Options:
nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (cámara, micro,
geolocalización, pagos, usb desactivados), `X-Frame-Options: DENY` y CSP solo con `frame-ancestors 'none'`.
`/_nuxt/**` (JS, CSS y fuentes @fontsource con hash) ya recibe `immutable, 1 año` de Nuxt.

CSP completa (propuesta, no activada: Nuxt inyecta scripts inline de hidratación y payload y haría
falta `'unsafe-inline'` o nonces): `default-src 'self'; img-src 'self' data: https://eqtjlafxtrzbjazhhyin.supabase.co;
connect-src 'self' https://eqtjlafxtrzbjazhhyin.supabase.co; script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline'; font-src 'self'; frame-src https://www.youtube-nocookie.com; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`.
Vídeos (D26): con CSP/`Permissions-Policy`, permitir `autoplay` y `fullscreen` para `https://www.youtube-nocookie.com` (además de `frame-src`); si no, la reproducción automática tras el clic falla sin avisar.
Probar primero como `Content-Security-Policy-Report-Only` en un deploy preview (login con Google
añade accounts.google.com a `form-action`/`connect-src` según el flujo).

### Invalidación al publicar (propuesta, no implementada: F4/F6)

F6.13 (D34): las páginas de `guide.pages` pasaron a ISR de 10 min como el blog; el panel NO llama a nada
al publicar y el plazo real es «hasta 10 min» (sin purga, sin proveedor nuevo). La purga por tag de abajo
solo haría falta para publicación inmediata. En Netlify no hay que tocar nada: solo vale el deploy normal.

Sin hacer nada, el contenido publicado aparece al expirar el TTL (<= 10 min listados, 1 h fichas). Para
publicación inmediata:
1. Preferida: purga por URL o tag de Netlify (`POST https://api.netlify.com/api/v1/purge` con
   `site_id` y `cache_tags`, token `NETLIFY_PURGE_API_TOKEN`). Requiere emitir `Netlify-Cache-Tag`
   por ruta (p. ej. `gym:<slug>`, `listing:gyms`, `home`) desde un hook de Nitro `render:response`.
2. Al publicar, el panel llama a una Edge Function de Supabase (con el token como `supabase secret`,
   nunca en `NUXT_PUBLIC_*`) que purga los tags afectados (ficha + listado + home + sitemap).
3. Alternativa más simple: build hook de Netlify tras publicar (rebuild completo, purga todo; más lento).
4. `@netlify/functions` `purgeCache({ tags })` es equivalente dentro de una función Netlify.

## Variables de entorno

| Variable | Pública | Dónde |
| --- | --- | --- |
| `NUXT_PUBLIC_SUPABASE_URL` | sí | `.env` local + Netlify |
| `NUXT_PUBLIC_SUPABASE_KEY` | sí (publishable) | `.env` local + Netlify |
| `NUXT_PUBLIC_SITE_URL` | sí | `.env` local + Netlify (build time) |
| Claude API key, Brevo/Resend key, `service_role` | **no** | `supabase secrets` (Edge Functions) |

- Solo `NUXT_PUBLIC_*` llega al cliente. **Nunca** secretos con ese prefijo.
- `.env*` fuera de git (salvo `.env.example`, sin valores reales). Mantén `.env.example` y el README al día.

## Supabase

- Proyecto **`eqtjlafxtrzbjazhhyin`** (compartido con Chalk app). Schema `guide`.
- Secretos vía `supabase secrets set`, consumidos solo por Edge Functions.
- Tareas programadas (agente de novedades, Fase 2): `pg_cron` + `pg_net` o scheduler externo
  invocando la Edge Function con secreto; propuesta antes de activar.

## Proveedores pendientes

Email (Brevo o Resend) y dominio sin decidir: no introducir ninguno sin aprobación de Xavi.

## Checklist de deploy

1. `npm run lint`, `npm run typecheck`, `npm run build` en verde en local.
2. Variables en Netlify coinciden con `.env.example`.
3. Migraciones pendientes aplicadas y aprobadas por leona-lia.
4. Smoke test post-deploy: home es/en, una ficha, `/agenda`, sitemap.xml, robots.txt, login con Google.
5. Cabeceras (`curl -I`): home con `Netlify-CDN-Cache-Control ... durable` y segunda petición con
   `Cache-Status` hit; `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` presentes;
   `/_nuxt/*.js` immutable; `/api/__sitemap__/urls` no-store; una ruta inexistente da 404 con la página de error.
6. Cambiar un dato en Supabase y comprobar que la home lo refleja tras el TTL sin rebuild.
