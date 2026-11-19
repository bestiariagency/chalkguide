# D86 · Revisión de seguridad y privacidad del consentimiento de cookies y la analítica (front)

Revisora: leona-lia (informe dictado, sin herramienta de escritura; guardado por el orquestador). Fecha: 2026-11-19. Alcance: front de D69/D86, implementado por coneja-lucky. No hay cambios de base de datos.

Archivos revisados:
- `app/composables/useConsent.ts`
- `app/plugins/consent.client.ts`
- `app/utils/consent.ts`
- `app/utils/consent-config.ts`
- `app/utils/analytics-tags.ts`
- `app/plugins/track.client.ts`
- `app/composables/useTrack.ts`, `useTrackContext.ts`, `useTrackScroll.ts`, `useTrackNewsletterView.ts`
- `app/services/analytics.ts`
- `app/utils/track.ts`
- `nuxt.config.ts` (runtimeConfig)
- Contexto: `app/composables/useConsentToken.ts`, `app/composables/useNewsletterUnsubscribe.ts`, `app/composables/useAuth.ts`
- Librería: `vanilla-cookieconsent` 3.3.0 (`dist/cookieconsent.mjs`)

Método: revisión estática del código y de la librería. **No se han hecho pruebas dinámicas** (`npm run dev` con Network y Application): esta revisión no tenía shell. El protocolo de pruebas está al final y **es obligatorio antes de activar** `NUXT_PUBLIC_ANALYTICS_ENABLED` y los IDs.

`get_advisors` (security): sin avisos nuevos atribuibles a este trabajo. Los avisos de `public.*` son anteriores y de Chalk app; no se tocan.

## Veredicto

**VETADO.** Tres vetos (V1 a V3). Todos se corrigen en el front con poco código. Las observaciones (O1 a O7) no bloquean, salvo que se indique otra cosa.

## Lo que está bien

1. **Antes de consentir o al rechazar no hay ninguna petición a Google ni a Meta.**
   - `applyConsent` con `NO_CONSENT` solo define `window.dataLayer` y `window.gtag` y encola `consent default` y `consent update` en `denied`.
   - No inyecta `gtag.js`. No define `fbq`.
   - Sin IDs válidos (`validIds`) no hace nada.
   - El CMP se sirve desde nuestro propio dominio (chunk dinámico).
   - Es Consent Mode v2 en modo básico, con los cuatro valores en `denied` antes de cualquier `config`. Sin GTM.
2. **Al aceptar, solo se carga lo aceptado.**
   - GA4 solo con `analytics` y Ads/Meta solo con `ads`.
   - GA4 va con `send_page_view: false`, `allow_google_signals: false` y `allow_ad_personalization_signals: false`.
3. **Meta.**
   - Llama a `fbq('consent','revoke')` antes de cargar.
   - Llama a `fbq('set','autoConfig',false,id)` antes de `init`, que es el orden correcto.
   - `init` va sin datos de coincidencia avanzada manual.
   - `disablePushState = true` evita los `PageView` automáticos en la navegación SPA.
   - Al retirar, llama a `revoke`.
4. **Ningún email, token ni dato de formulario llega a `gtag` ni a `fbq` desde nuestro código.**
   - Los parámetros son una lista cerrada (`thirdPartyParams`): `page_path` normalizado, `locale`, `content_*`, `pillar` y `partner`.
   - `Lead` y `generate_lead` no llevan payload personal.
5. **Borrado de cookies al retirar.**
   - `autoClear` cubre `/^_ga/`, `/^_gcl_/`, `_fbp` y `_fbc`.
   - La librería borra cada cookie con el dominio configurado, con el hostname y con la variante sin `www.`. Esto cubre las cookies de GA, que se escriben en el eTLD+1, tanto en el apex como en `www`.
6. **`track_event` (capa propia).**
   - El path va sin query ni hash, en minúsculas y sin barra final.
   - `isUntrackedPath` excluye `/administrador`, `/api`, las páginas con token de la newsletter (es y en) y `/entrar` (`/sign-in`).
   - `source` es una clase; nunca el referrer.
   - `device` sale del ancho de pantalla, no del user agent.
   - Estado solo en memoria (`landing`, `lastViewed`). Sin cookies, `localStorage` ni `sessionStorage` en la capa de eventos.
   - El servidor vuelve a validar (ver `D69-analytics-events-review.md`).
7. **`hideFromBots: true`.**
   - En un bot o con `navigator.webdriver`, la librería solo deja de pintar el banner. No acepta nada.
   - Los tags dependen únicamente de `cc_cookie`, así que un bot nunca los carga.
   - `manageScriptTags` está activo, pero no hay ningún `<script data-category>`.
8. **Plazo.** `expiresAfterDays` vale 182 por defecto, es decir, unos 6 meses: dentro del máximo de 24.
9. Primera capa con `equalWeightButtons`, sin X y en `mode: 'opt-in'`. YouTube va aparte, con la fachada de D26 y `youtube-nocookie`.

## Vetos

### V1 · URLs con token y del panel enviadas a Google (Ads) con consentimiento previo

**Motivo.**
- `track.client.ts`, en `app:mounted`, llama a `applyConsent(ids, previous)` sin mirar la ruta ni `config.analyticsEnabled`.
- Con `ads` aceptado y `NUXT_PUBLIC_GADS_ID` configurado, `gtag('config', AW-…)` envía por defecto un hit de página (remarketing). Ese hit lleva `document.location.href` completo.
- Rutas afectadas:
  - `/newsletter/baja?token=<uuid>`: `useNewsletterUnsubscribe` lee `route.query.token` y **nunca lo quita de la URL**. Ese token permite dar de baja a la persona.
  - Las páginas con `?t=`: el token se quita en `onMounted`, en carrera con la carga asíncrona de `gtag.js`. No es una garantía.
  - `/administrador/**`, con parámetros internos como `?noticia=` o `?evento=`, si Xavi aceptó en el sitio público.
- Además, en cualquier página con consentimiento, GA4 y Meta toman `dl` de `location.href`. Así viajan queries como `?q=<texto libre>` del buscador de listados y `?code=` del retorno OAuth. El código PKCE no sirve sin el verifier, pero no debe salir del sitio.
- Esto incumple la spec §5 ("No enviar a Google ni a Meta ninguna URL con parámetros que contengan el token"), la spec §3 ("nada de esto se carga en `/administrador/**`… bandera `NUXT_PUBLIC_ANALYTICS_ENABLED`") y el comentario de `useTrack.ts` ("nothing at all unless `NUXT_PUBLIC_ANALYTICS_ENABLED` is on").

**Corrección.**
1. En `track.client.ts`, no llamar a `applyConsent` (ni en `app:mounted` ni en `onChange`) si `!config.analyticsEnabled` o si `isUntrackedPath(normalizePath(location.pathname))`. Si se entra por una ruta excluida, aplazarlo al primer `router.afterEach` hacia una ruta rastreada.
2. En `analytics-tags.ts`:
   - Configurar Ads con `send_page_view: false` y enviar su page view por nuestro hook, como ya se hace con GA4.
   - Fijar `page_location` saneado (`location.origin + normalizePath(location.pathname)`) con `gtag('set', { page_location })` antes de cada `config` y de cada evento.
   - Añadir `allow_enhanced_conversions: false` al `config` de Ads (ver O2).
3. En `useNewsletterUnsubscribe.ts`, quitar el token de la barra de direcciones con `history.replaceState` nada más leerlo, como en `useConsentToken`. Recomendado también: unificar con `useConsentToken`.
4. Meta no permite sobrescribir `dl`. Con el punto 1, Meta no recibe nada en las rutas excluidas. Lo que queda es `?q=` en listados públicos. Dos opciones: no enviar `PageView` a Meta mientras la URL lleve `q`, o aceptar el riesgo por escrito (lo decide Xavi).

### V2 · Retirar el consentimiento no garantiza que se deje de enviar

**Motivo.**
- Tras retirar en la misma página, `gtag.js` ya está cargado. `consent update denied` lo deja funcionando como en el modo avanzado.
- Las mediciones automáticas de GA4 (Enhanced Measurement: historial, scroll 90 %, clics salientes, descargas, formularios) y el linker de Ads pueden seguir mandando pings sin cookies a Google hasta recargar.
- Esto contradice el modo básico y la spec §3.5 ("se recarga la página o se bloquean los eventos siguientes").
- Nuestro `sendThirdParty` sí se corta. Lo que no se corta son los listeners internos de Google.

**Corrección.** En `consent-config.ts`, `analytics: { autoClear: { cookies, reloadPage: true } }` e igual en `ads`. La librería recarga solo cuando se rechaza una categoría que antes estaba aceptada. Así se borran las cookies, la página vuelve sin `gtag.js` y Meta queda revocado.

### V3 · No se vuelve a preguntar si cambian las categorías o la política

**Motivo.**
- `vanilla-cookieconsent` solo invalida el consentimiento guardado si `revision` está configurada (es mayor o igual que 0 y distinta de la guardada). No vuelve a preguntar cuando se añade una categoría.
- Hoy no hay `revision`.
- `readStoredConsent`, que aplica los tags antes de que arranque la librería, tampoco mira la revisión. Aunque se configure, cargaría los tags con una elección caducada hasta que la librería la invalide.
- El plazo depende de un valor por defecto implícito (182 días), mientras los textos legales dicen "se propone 24 meses". Puede desalinearse en silencio.

**Corrección.**
1. `revision: 1` en `buildConsentConfig`, exportada como constante desde `utils/consent.ts`. Regla de proceso: se sube cada vez que cambian las categorías, los proveedores o la finalidad.
2. Usar `{{revisionMessage}}` en la descripción de la primera capa, con un texto de loro-lola.
3. En `consentFromCookie`, tratar como `NO_CONSENT` cualquier cookie con `revision !== CONSENT_REVISION`. Comprobar también `expirationTime` si viene.
4. `cookie.expiresAfterDays` explícito y menor o igual que 730. Propuesta: 365 para "aceptar" y 182 para "rechazar" (función por `acceptType`) o un valor único. Las tablas de `docs/copy/legal-cookies.md` y `legal-privacidad.md` deben llevar el mismo valor.

## Observaciones (no bloquean salvo indicación)

- **O1 · Coincidencia avanzada de Meta.**
  - `autoConfig: false` desactiva la detección automática de eventos y la lectura de la página. La coincidencia avanzada automática es otro interruptor, del Administrador de Eventos.
  - El comentario de `applyMeta` exagera lo que hace el código: corregirlo.
  - Condición de activación: Xavi la desactiva, y en la prueba de red el `Lead` no lleva parámetros `ud[...]`.
- **O2 · Conversiones mejoradas de Google.**
  - `sendAdsConversion` se dispara con el email todavía en el DOM. Si alguien activa en Google Ads las conversiones mejoradas automáticas, `gtag` podría tomar el email con hash.
  - Medidas: `allow_enhanced_conversions: false` en código (incluido en V1), no aceptar las condiciones de datos de clientes y dejar desactivada la recogida de datos proporcionados por el usuario en GA4.
- **O3 · Propiedad GA4.** Desactivar en Enhanced Measurement: "cambios de página por historial" (dobles page views y URL sin sanear), "interacciones con formularios" y "búsqueda en el sitio" (enviaría el texto de `?q=`). Esta configuración es de lince-max y Xavi.
- **O4 · `_fbc`.** Meta lo escribe al llegar con `fbclid`, y ya se borra. Falta en las tablas de cookies (`legal-cookies.md` y la tabla del panel de preferencias).
- **O5 · `hideFromBots`.** Con `navigator.webdriver`, Playwright no verá el banner. En las pruebas automáticas hay que pasar `hideFromBots: false` (solo en test) o simular el clic con la API.
- **O6 · Comentario inexacto.** `analytics-tags.ts` dice "defines nothing on `window`" antes del sí, pero con IDs configurados define `gtag` y `dataLayer` (sin red). Ajustar el comentario.
- **O7 · `cookies.table.tbc`** en la columna de duración del panel: hay que poner las duraciones reales antes del lanzamiento (tras el escaneo).

## Pregunta 6 · ¿Basta `cc_cookie` como prueba del consentimiento?

**Respuesta corta: no basta por sí sola.**
- Art. 7.1 RGPD: el responsable debe poder demostrar el consentimiento.
- Guía de cookies de la AEPD: el editor debe poder acreditarlo. Ni el RGPD ni la AEPD imponen un registro en servidor por cookie.
- Política de consentimiento de usuarios de la UE de Google: exige "conservar registros del consentimiento" a quien usa Google Ads y GA4.

`cc_cookie` (categorías, `consentId`, `consentTimestamp`, `lastConsentTimestamp`, `revision`) vive en el navegador de la persona. El responsable no la conserva, se puede editar y desaparece al borrar cookies. Sirve como estado, no como prueba.

**Mínimo exigido (bloquea la activación, no este cambio):** registro versionado del mecanismo en el repositorio. Para cada `revision` se guarda:
- la fecha de entrada en vigor;
- los textos del banner y del panel en es y en;
- la configuración (categorías, valores por defecto, plazo);
- capturas de las dos capas.

Así se prueba **cómo** se pidió el consentimiento y que no había casillas premarcadas.

**Recomendado antes de activar Google Ads o Meta:** registro mínimo en servidor, sin datos identificativos.
- Tabla `guide.cookie_consent_log`:
  - `id bigint identity`
  - `consent_id uuid not null` (el `consentId` aleatorio de la librería)
  - `action text check (action in ('first','change'))`
  - `categories text[]` (validadas contra `analytics` y `ads`)
  - `revision int not null`
  - `locale text check (locale in ('es','en'))`
  - `created_at timestamptz default now()`, truncado al minuto
  - Sin IP, sin user agent, sin `user_id` y sin path.
- RLS activada sin policies. `INSERT` directo revocado. `SELECT` solo para el superadmin, por RPC.
- RPC `guide.log_cookie_consent(p_consent_id uuid, p_action text, p_categories text[], p_revision int, p_locale text) returns void`:
  - `security definer` y `set search_path = ''`;
  - `revoke execute from public` y `grant` a `anon` y `authenticated`;
  - valida contra la lista cerrada y, si algo no valida, no hace nada y no falla;
  - límite de tasa global, como en `track_event`, más un máximo de N filas por `consent_id` y día.
- Cliente: llamada sin bloquear desde `onFirstConsent` y `onChange` en `useConsent.ts`, con `cmp.getCookie()`. Nunca bloquea el banner.
- Conservación: la vida del consentimiento más el plazo de prescripción de las infracciones de la LSSI (art. 45: hasta 2 años las graves). Propuesta: 36 meses, con purga por `pg_cron`. Lo decide Xavi con revisión legal.
- Base legal: obligación legal de acreditar (art. 6.1.c RGPD). Hay que mencionarlo en `/privacidad`.
- `consent_id` es un seudónimo. Solo se puede ligar a una persona si ella aporta su cookie, que es justo el caso en que hace falta probar.
- La migración necesita a jabali-javi y después revisión de leona-lia.

## Pregunta 7 · Plazo

Hoy son 182 días por defecto: cumple con el máximo de 24 meses. Lo de volver a preguntar si cambian las categorías no se cumple: ver V3.

## Protocolo de pruebas obligatorio antes de activar

Se hace en un preview con IDs de prueba y `NUXT_PUBLIC_ANALYTICS_ENABLED=true`. Navegador limpio, en es y en, con DevTools en Network y Application.

1. Sin elegir:
   - 0 peticiones a `googletagmanager.com`, `google-analytics.com`, `googleadservices.com`, `google.com/ccm`, `doubleclick.net`, `facebook.com` y `connect.facebook.net`;
   - 0 cookies que no sean `cc_cookie` y la sesión;
   - solo llamadas a `rpc/track_event`.
2. Rechazar: lo mismo, y `cc_cookie` con `categories: ["necessary"]`.
3. Aceptar solo analítica: solo `gtag.js?id=G-…` y `collect`. Ninguna petición de Meta ni de Ads. `_ga*` creadas.
4. Aceptar todo:
   - se cargan `fbevents.js` y Ads;
   - el `PageView` de Meta no lleva `ud[...]`;
   - en los hits de Google, `dl`/`url` llevan el path sin query.
5. Con todo aceptado, abrir `/newsletter/baja?token=<uuid>`, `/newsletter/preferencias?t=…`, `/administrador` y una ficha con `?code=…&opinar=1`: 0 peticiones a Google y Meta que contengan `token`, `t=`, `code=` o `/administrador`.
6. Retirar desde "Preferencias de cookies": la página se recarga, las cookies `_ga*`, `_gcl_*`, `_fbp` y `_fbc` desaparecen (apex y `www`), y al navegar hay 0 peticiones a Google y Meta.
7. Subir `revision`: el banner reaparece y no se carga ningún tag hasta la nueva elección.
8. Enviar la newsletter con todo aceptado: ninguna petición lleva el email, en claro ni con hash (buscar `em=`, `ud[em]` y `sha256`).

Las correcciones V1 a V3 son de coneja-lucky. Las de configuración de cuentas (O1 a O3) son de Xavi y lince-max. Tras las correcciones y el protocolo de pruebas, leona-lia vuelve a revisar.

## Anexo · Re-revisión tras las correcciones (2026-11-19)

Revisora: leona-lia. Revisión estática del código corregido por coneja-lucky. Las pruebas dinámicas siguen pendientes (ver el protocolo de pruebas).

### Veredicto

**APROBADO.** V1, V2 y V3 están cerrados. No quedan vetos abiertos. Las condiciones de activación siguen en vigor: el protocolo de pruebas completo, O1 a O3 configurados en las cuentas de Google y Meta, y la decisión sobre el registro de consentimiento (pregunta 6).

### V1 · Cerrado

- `app/plugins/track.client.ts`: `canApply()` exige `analyticsEnabled` y que la ruta no esté excluida (`isUntrackedPath`). Si se entra por el panel, la API o una página con token, los tags esperan al primer `afterEach` hacia una ruta rastreada. `onChange` usa la misma comprobación.
- `app/utils/analytics-tags.ts`: `setCleanLocation()` fija `page_location = origin + normalizePath(pathname)` antes de cada `config` (GA4 y Ads) y de cada evento de `sendThirdParty`, incluida la conversión de Ads de `newsletter_submit`. Ads con `send_page_view: false` y `allow_enhanced_conversions: false`. Meta no envía `PageView` mientras la URL lleve `q`.
- `app/composables/useNewsletterUnsubscribe.ts`: guarda el token en memoria y lo quita de la barra con `history.replaceState` en `onMounted`. En `/newsletter/baja` no se aplica ningún tag, así que no hay carrera con `gtag.js`.

### V2 · Cerrado

`app/utils/consent-config.ts`: `reloadPage: true` en `autoClear` de `analytics` y de `ads`. Al retirar una categoría aceptada, la librería borra las cookies y recarga la página, que vuelve sin `gtag.js`.

### V3 · Cerrado

- `app/utils/consent.ts`: `CONSENT_REVISION = 1`; `CONSENT_DAYS` 365 al aceptar y 182 al rechazar; `consentFromCookie` devuelve `NO_CONSENT` si la revisión no coincide o si `expirationTime` venció.
- `app/utils/consent-config.ts`: `revision` y `expiresAfterDays` según `acceptType`; `{{revisionMessage}}` en la primera capa con la clave `cookies.banner.revision`.
- Regla de proceso: subir `CONSENT_REVISION` cada vez que cambien las categorías, los proveedores o la finalidad.

### O1, O4 y O6

- O1 y O6: comentarios corregidos. O4: `_fbc` en la tabla del panel y en los textos legales (loro-lola).
- O2: cerrado en código con `allow_enhanced_conversions: false`; no activar las conversiones mejoradas en la cuenta de Google Ads.
- O3: pendiente en la propiedad de GA4.

### Observaciones nuevas (no bloquean)

- **O8 · Funcional.** Con solo «Publicidad» aceptada, Google Ads no recibe `page_view` y no entra en las listas de remarketing. Corrección: enviar el evento con `send_to` según el consentimiento (`ga4Id` con `analytics`, `gadsId` con `ads`), manteniendo `setCleanLocation` antes.
- **O9 · Meta sigue leyendo la URL completa.** El corte por `q` solo se aplica al `PageView`: `Lead` y `AffiliateClick` en una página con `?q=`, y el `PageView` de vuelta del login con `?code=…&opinar=1`, siguen enviando parámetros. Recomendación: cortar todos los eventos de Meta con `q`, `code`, `token` o `t`.
- **O10 · Texto.** `cookies.banner.revision` en plural; la voz de la política es en singular (loro-lola).
- **O11 · Navegación SPA con tags cargados.** Hacia `/administrador` o páginas con token, nuestros eventos no salen, pero Enhanced Measurement por historial podría. Refuerza O3: desactivar «cambios de página por historial» en GA4 antes de activar.

### Condiciones de activación (sin cambios)

1. Protocolo de pruebas completo (1 a 8), en es y en, sobre el preview. En el punto 4, comprobar además que `url` en los hits de Ads y `dl` en los de GA4 llevan la URL saneada.
2. O1 a O3 configurados y comprobados en las cuentas de Google y Meta (Xavi y lince-max).
3. Registro de consentimiento (pregunta 6): como mínimo, el registro versionado por `revision` en el repositorio. Antes de activar Google Ads o Meta, el log en servidor propuesto (jabali-javi y después leona-lia).
