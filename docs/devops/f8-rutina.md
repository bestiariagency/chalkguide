# F8 · Rutina cloud de recolección (tarea 8.7)

Estado: preparada, **no creada** (falta el token de Xavi). Arranca en `dry_run` (D76, O7).
Cliente: `scripts/ingest/ingest-call`. Prompt: `docs/copy/f8/prompt-rutina.md` (v0.3). Spec: `docs/security/F8.1-ingest-spec.md` §4.

## Script `ingest-call`

- Uso: `ingest-call <rpc> < params.json` (objeto JSON sin token). Imprime la respuesta JSON en éxito.
- Lista blanca: `ingest_start_run`, `ingest_context`, `ingest_submit_event`, `ingest_submit_news`,
  `ingest_submit_newsletter_intro`, `ingest_finish_run`. Cualquier otra RPC sale con código 2.
- POST fijo a `${SUPABASE_URL}/rest/v1/rpc/<rpc>`, cabeceras `apikey` y `Authorization` con la
  publishable key y `Content-Profile: guide`. El token se añade como `p_token` con `jq --arg` y el cuerpo
  va por `--data @-` (no aparece en argv). `SUPABASE_URL` debe ser `https://*.supabase.co`.
- En error imprime solo `HTTP <código> <code> <message>` del servidor (sin cuerpo enviado, con el token
  redactado). Sin `set -x`, sin `curl -v`, sin eco del token.
- Códigos de salida: 0 ok, 1 error HTTP, 2 uso/entorno inválido, 3 red o JSON de entrada inválido.

## Variables de entorno de la rutina (O1, O8)

| Variable | Valor | Secreta |
| --- | --- | --- |
| `SUPABASE_URL` | `https://eqtjlafxtrzbjazhhyin.supabase.co` | No |
| `SUPABASE_PUBLISHABLE_KEY` | la misma publishable key de `NUXT_PUBLIC_SUPABASE_KEY` | No |
| `CHALKGUIDE_INGEST_TOKEN` | token `cgi_...` creado en `/administrador/ingesta` | **Sí** |
| `CHALKGUIDE_DRY_RUN` | `1` (piloto) | No |

Nunca `service_role`. El token no va en el prompt, repo, `.env*`, Netlify, chat ni issues. Un token
por entorno, con su `label` (por ejemplo `rutina-cloud`). Si algún día se prueba en local, token aparte.

## Configuración de la rutina (skill `schedule`)

- Nombre: `chalkguide-recoleccion`.
- Cron: `0 6 * * 1,4` con zona `Europe/Madrid` (lunes y jueves, 06:00; dentro de la ventana R1 03:00–12:00).
  Si la rutina solo admite UTC: `0 5 * * 1,4` en invierno y `0 4 * * 1,4` en verano; mejor fijar la zona.
- Prompt: el bloque entre las líneas `PROMPT` de `docs/copy/f8/prompt-rutina.md`, tal cual.
- Repositorio: el que contenga `scripts/ingest/ingest-call` (hay que commitearlo antes; yo no commiteo).
- Script de preparación del entorno (setup):
  `install -m 0755 scripts/ingest/ingest-call /usr/local/bin/ingest-call && command -v jq curl`
  (si falla `install`, `mkdir -p ~/bin && cp ... ~/bin/ingest-call` y añadir `~/bin` al PATH).
- Red (O6): limitar la salida de Bash a `*.supabase.co` si el entorno lo permite. WebSearch y WebFetch
  siguen abiertos por diseño (D72).
- Primer lanzamiento: manual, con `CHALKGUIDE_DRY_RUN=1`.

## Pasos para Xavi

1. En `/administrador/ingesta`, crear un token (`label` `rutina-cloud`, caducidad 30 días). Se muestra
   **una sola vez**: copiarlo.
2. En el entorno cloud de la rutina, definir las 4 variables de la tabla. Pegar el token solo ahí.
3. Crear la rutina con `/schedule` (o en claude.ai/code) con los datos de la sección anterior. Dime
   «crea rutina» y la preparo con la skill una vez exista el token; no la he creado.
4. Lanzar un run manual en `dry_run`. Comprobar en el panel: run `dry_run` cerrado, 0 filas insertadas,
   `would_insert` en el informe, `last_used_at` del token actualizado.
5. Revisar 2 runs (lunes y jueves). Solo entonces, con tu OK, poner `CHALKGUIDE_DRY_RUN=0` (O7).

## Runbook de rotación (O4, cada ≤ 30 días)

1. Crear el token nuevo en `/administrador/ingesta` (máximo 2 vigentes a la vez).
2. Actualizar `CHALKGUIDE_INGEST_TOKEN` en el entorno cloud.
3. Lanzar un `dry_run` y comprobar que termina OK.
4. Revocar el token anterior.
5. Comprobar en el panel que solo queda uno vigente.

Aviso de caducidad: poner un recordatorio a los 25 días.

## Runbook de revocación inmediata (O5)

Revocar si: el token aparece en un transcript, log o salida; hay runs fuera de lun/jue; hay borradores
con fuentes extrañas; salta `duplicate_rejected` o `queue_full` sin explicación.

1. Revocar el token en `/administrador/ingesta` (efecto inmediato; cierra como `revoked` los runs abiertos).
2. Pausar la rutina.
3. Revisar la cola de borradores y descartar lo sospechoso.
4. Crear un token nuevo, actualizar el entorno, hacer un `dry_run` y reactivar.
5. Si el token se filtró en un transcript, borrar ese transcript si es posible.

## Prueba local sin token real (2026-11-14)

Con un token falso válido en formato (`cgi_` + 64 `a`) y las variables de `.env`:

| Caso | Resultado |
| --- | --- |
| `ingest_start_run` token falso | `ingest-call: HTTP 401 42501 ingest_unauthorized`, salida 1 |
| `ingest_context` token malformado | igual (error uniforme J6) |
| RPC fuera de lista (`admin_list_subscribers`) | `rpc no permitida`, salida 2, sin red |
| Sin `CHALKGUIDE_INGEST_TOKEN` | error de variable, salida 1 |
| JSON de entrada inválido | `fallo de red o JSON de entrada invalido`, salida 3 |
| `SUPABASE_URL=https://evil.com` | `SUPABASE_URL no valida`, salida 2 |
| GET con token en query (sin script) | HTTP 401 (J8: las RPC son POST) |

No sale ni el token ni el cuerpo en ningún caso.

## Purga de `/noticias/**` al publicar (evaluación, no implementada)

Hoy: `news`, `news-slug` y categorías son `isr` de 10 min (`LIVE`). Publicar se ve en ≤ 10 min sin
hacer nada. Opción de coste cero si se quisiera inmediato:

- Marcar las páginas de noticias con la cabecera `Netlify-Cache-Tag: noticias` (en `routeRules`) y
  purgar por tag con la API de Netlify (`POST https://api.netlify.com/api/v1/purge`, cuerpo
  `{"site_id": "...", "cache_tags": ["noticias"]}`, token personal de Netlify). Sin coste en cualquier plan.
- Disparador: ruta Nitro `server/api/admin/purge-news.post.ts` que el panel llama tras publicar, con
  comprobación de admin y el token de Netlify solo en el servidor (variable sin prefijo `NUXT_PUBLIC_`).
  Alternativa sin código de servidor: `@netlify/functions` `purgeCache({ tags })` dentro de esa ruta,
  que usa el contexto de la función sin token propio.
- No toca BD, pero añade una variable secreta y una ruta nueva. Recomendación: **no hacerlo** mientras
  el TTL de 10 min sea aceptable (D34 ya lo asumió para páginas). Decisión de Xavi.
