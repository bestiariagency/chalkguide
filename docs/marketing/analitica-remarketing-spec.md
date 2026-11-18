# Spec de medición y remarketing · ChalkGuide (D69)

Autor: Lince-Max (SEO y marketing). Fecha: 2026-11-12. Estado: propuesta para Xavi y para el resto del equipo. No toca código, base de datos ni `docs/PLAN.md`.

Contexto: D69 fija dos capas desde el lanzamiento. La capa 1 no usa cookies y siempre está activa (Search Console y eventos propios en `guide.analytics_events`). La capa 2 solo se activa con consentimiento previo (banner con CMP certificada por Google, GA4 con Consent Mode v2 y píxel de Meta para listas de remarketing). Subir emails a Google o Meta (Customer Match) queda fuera: no hay consentimiento para ello. Dominio: `chalkguide.es` (D67).

## 0. Resumen y decisiones que necesito de Xavi

1. **CMP recomendada para el lanzamiento: CookieYes, plan gratuito** (socio CMP de Google, Consent Mode v2 incluido en el plan gratuito). Tiene tres límites que hay que aceptar a sabiendas: tope de 5.000 páginas vistas al mes (el tope se alcanzaría hacia el mes 4 a 6 según los objetivos de `seo-blog-research-2026-11.md` §6), un solo idioma de banner y marca de CookieYes visible. Ninguna alternativa gratuita certificada supera estos límites (sección 1). Plan B sin coste y sin tope, pero **no certificado por Google**: `vanilla-cookieconsent` autoalojado. Hay que elegir entre ambos antes de implementar (decisión 1 abajo).
2. **Consent Mode v2 en modo básico (Basic)**: no se carga ningún script de Google ni de Meta hasta que la persona acepta. Es más sencillo de defender ante la AEPD, protege el LCP y nuestros umbrales de tráfico no alcanzarían el modelado de conversiones que ofrece el modo avanzado de todos modos (sección 3).
3. **Sin Google Tag Manager en la v1**: `gtag.js` directo y el script de Meta, inyectados por un plugin solo de cliente tras el consentimiento. Menos peso, un contenedor menos que mantener. GTM se puede añadir después sin rehacer nada.
4. **Los eventos propios en `guide.analytics_events` no llevan IP, user agent, identificador de sesión ni de dispositivo.** Sin identificador, no hay "usuarios únicos" ni "sesiones" en la capa 1: se mide en páginas vistas y en eventos. Es el precio de no necesitar consentimiento.
5. **`newsletter_confirmed` vive solo en la capa propia** (webhook de Brevo, en servidor). No se envía a GA4 ni a Meta: eso exigiría relacionar una persona identificada con su navegación, que es justo lo que no tenemos consentido.

Decisiones para Xavi:

1. ¿CookieYes gratis (certificado, con tope y un idioma) o `vanilla-cookieconsent` (sin tope, es/en, pero sin certificación de Google)? Mi recomendación: CookieYes al lanzamiento, con la interfaz `useConsent` abstraída para poder cambiar. Aprobar de antemano la subida a plan de pago cuando se llegue al 80 % del tope, o migrar a la opción B.
2. Idioma del banner en el plan gratuito: un solo idioma. Opciones: texto bilingüe es/en en el único idioma, o español solo (las páginas `/en` son pocas hoy). Decisión de loro-lola y Xavi.
3. ¿Se acepta modo básico de Consent Mode (recomendado) aunque se pierdan los modelos de conversión de Google?

## 1. CMP recomendada

### Qué significa "certificada por Google"

Google mantiene un programa de socios CMP. Su lista oficial para Tag Manager incluye, entre otras, CookieYes, Cookiebot, CookieHub, Cookie-Script, Axeptio, Complianz, iubenda, Termly y Usercentrics ([lista de CMP socios de Google](https://support.google.com/tagmanager/answer/10718549)). La lista no usa la palabra "certificada": son socios con integración de Consent Mode. No he encontrado en la documentación de Consent Mode de Google (ni en su política de consentimiento de usuarios de la UE) que un anunciante que usa Google Ads y GA4 esté obligado a usar un CMP socio; la política exige consentimiento válido para cookies y para personalizar anuncios, registro del consentimiento y forma clara de revocarlo ([política de consentimiento de usuarios de la UE](https://www.google.com/about/company/user-consent-policy/)). Por eso la certificación es una comodidad (integración probada, registro de consentimientos) y no un requisito legal comprobado. Lo dejo explícito para que Xavi pondere si pagar o limitarse a la opción B. A confirmar por leona-lia.

### Comparativa (planes gratuitos, datos de las páginas de precios oficiales consultadas el 2026-11-12)

| | CookieYes (Free) | CookieHub (Free) | Cookiebot (Free) | Termly (Free) |
| --- | --- | --- | --- | --- |
| Socio CMP de Google | Sí | Sí | Sí | Sí |
| Consent Mode v2 en el plan gratuito | Sí, incluido | Sí, incluido | "Google Consent Mode support" (la página no dice "v2" por nombre) | Sí, a nivel básico |
| Límite de uso | 5.000 páginas vistas al mes (sitios creados desde el 1 de julio de 2025); 100 páginas por escaneo | 1.000 sesiones al mes (la página las equipara a unas 25.000 páginas vistas); 50 páginas escaneadas; si se supera, el banner deja de mostrarse | 1 dominio y hasta 50 subpáginas | 1 dominio; 10.000 vistas del banner al mes |
| Idiomas | Sin multilingüe en el plan gratuito | No consta en la página | 1 idioma | Sin multilingüe |
| Caducidad del consentimiento | No consta (verificar en el alta) | Hasta 1 mes | Hasta 1 mes | No consta |
| Registro de consentimientos | Sí | 1 mes | Hasta 12 meses | No consta |
| Personalización | Básica; sin colores ni CSS propios; marca visible | Marca visible probable | Sin botones ni marca propios | Marca de Termly visible |
| Bloqueo de scripts | Automático por categorías tras escaneo; también manual | No consta | Solo manual en Free | No consta |
| Soporte de Meta | Por categoría (nuestro plugin decide qué inyectar) | Idem | Idem | Idem |

Fuentes: [CookieYes precios](https://www.cookieyes.com/pricing.md), [CookieHub precios](https://www.cookiehub.com/pricing), [Cookiebot precios](https://www.cookiebot.com/en/pricing/), [Termly precios](https://termly.io/pricing/). Cookie-Script ofrece plan gratuito (1 sitio, 10 páginas escaneadas, 10.000 vistas al mes) pero su página no confirma Consent Mode v2 en ese plan; lo descarto por falta de confirmación ([Cookie-Script precios](https://cookie-script.com/pricing)). Axeptio: la página de precios no se pudo leer; no evaluado.

Lectura:

- **Cookiebot y CookieHub**: la caducidad máxima de un mes obliga a volver a preguntar a los lectores cada mes. Es más invasivo, justo lo que Xavi quiere evitar. Cookiebot además topa en 50 subpáginas, que ChalkGuide supera al publicar fichas y artículos.
- **Termly**: sin multilingüe y marca visible; tope de 10.000 vistas del banner.
- **CookieYes**: tope más bajo (5.000 páginas vistas) pero sin límite de subpáginas ni caducidad de un mes declarada, y con registro de consentimientos. Es la menos mala para un arranque. Verificar en el alta la caducidad real del consentimiento y el comportamiento al superar el tope (una fuente de terceros dice que el banner deja de mostrarse; sin confirmar en CookieYes). Si deja de mostrarse, el comportamiento seguro es **no cargar nada** (consentimiento por defecto denegado), pero se pierde el remarketing hasta pagar o migrar: cuenta como riesgo.
- **Peso y carga diferida**: los CMP externos cargan su script desde su CDN. Se inyecta tras la carga de la página y con la cola de inactividad (sección 3), de forma que no compite con el LCP. La consecuencia de privacidad: el CMP recibe la IP del visitante antes de que haya elegido (es inevitable para mostrar el banner). Hay que decirlo en `/privacidad` y `/cookies`, y firmar el contrato de encargado con el proveedor.

### Plan B (no certificado por Google): `vanilla-cookieconsent` v3 autoalojado

Licencia MIT, se sirve desde nuestro propio dominio (cero peticiones a terceros antes de elegir), sin tope de tráfico, multilingüe es/en, caducidad configurable (la AEPD considera buena práctica renovar a los 24 meses, ver sección 10) y documentación para Consent Mode v2 ([documentación](https://cookieconsent.orestbida.com/)). Contras: sin certificación de Google, sin registro de consentimientos en servidor (habría que diseñar una prueba propia, con consulta de leona-lia) y el mantenimiento lo asumimos nosotros. Es la salida natural cuando se supere el tope de CookieYes.

## 2. Categorías de consentimiento

| Categoría | Qué incluye | Base | Estado por defecto |
| --- | --- | --- | --- |
| Necesarias | Sesión de Supabase al iniciar sesión con Google (almacenamiento local, solo si inicias sesión); preferencia de idioma si se guarda; el propio registro de la elección de cookies | Estrictamente necesarias, no requieren consentimiento; se informan | Siempre activas, sin interruptor |
| Analítica | GA4 (`analytics_storage`) | Consentimiento | Desmarcada |
| Publicidad y remarketing | Píxel de Meta; etiqueta de Google Ads (`ad_storage`, `ad_user_data`, `ad_personalization`) | Consentimiento | Desmarcada |
| Vídeos externos | **No se añade como categoría** | D26: el clic en "Reproducir vídeo" ya es el acto afirmativo, sin recordarlo | n/a |

Decisión sobre vídeos: mantener D26 tal cual. La fachada ya cumple el requisito (cero peticiones a Google hasta el clic) y no memoriza nada. Una cuarta categoría añadiría una opción más al banner, otra casilla y un riesgo de contradicción (aceptar "publicidad" no debe cargar YouTube solo). Si más adelante hubiera embeds de otro tercero, se aplica el mismo patrón de fachada, no una categoría.

Mapa a Consent Mode v2: `analytics_storage` = Analítica; `ad_storage`, `ad_user_data` y `ad_personalization` = Publicidad y remarketing, los tres juntos (un solo interruptor; separarlos añadiría una capa que casi nadie usa). Los cuatro valores por defecto son `denied`. Los cuatro tipos de consentimiento están descritos en la [guía de Consent Mode para gtag.js](https://developers.google.com/tag-platform/security/guides/consent): `ad_user_data` y `ad_personalization` son los dos que añadió la v2.

Preferencias: no hay categoría de preferencias porque la preferencia de idioma, si existe, es técnica (la guía de la AEPD la trata como técnica cuando la elige el usuario, [nota de prensa de la AEPD](https://www.aepd.es/prensa-y-comunicacion/notas-de-prensa/aepd-actualiza-guia-cookies-para-adaptarla-a-nuevas-directrices-cepd)).

## 3. Cómo se cargan los scripts

### Principios

1. **Nada antes del consentimiento.** Antes de la elección: cero peticiones a Google, Meta ni dominios de publicidad. Solo el script del CMP (y nuestro endpoint propio de eventos, que no es un tercero).
2. **Consent Mode v2 en modo básico.** Google define el modo básico como el que bloquea las etiquetas hasta que se concede el consentimiento; el avanzado carga las etiquetas y envía pings sin cookies si se deniega ([resumen de Cookie Information](https://cookieinformation.com/?p=102082), [GA4: modelado de comportamiento](https://support.google.com/analytics/answer/11161109)). Razones para el básico:
   - Con el avanzado se contacta con Google antes de la elección: contradice D26 y el relato de privacidad del sitio.
   - El modelado de conversiones de GA4 exige al menos 1.000 eventos diarios con `analytics_storage` denegado durante 7 días y 1.000 usuarios diarios con consentimiento en 7 de los últimos 28 días. ChalkGuide no llegará a eso en el primer año (objetivo de 4.000 a 10.000 clics orgánicos al mes a 12 meses).
   - Es más ligero y no añade peso al LCP.
3. **Valores por defecto en línea, antes de cualquier otra cosa.** Google insiste en que las llamadas `default` van antes de cualquier medición y en el orden correcto, y en actualizar con `update` en cuanto la persona elige ([guía de gtag.js](https://developers.google.com/tag-platform/security/guides/consent)). Aunque en modo básico no cargamos `gtag.js` antes del permiso, el plugin define `dataLayer` y `gtag` con los cuatro valores `denied` en el primer instante y solo después inyecta el script cuando hay consentimiento.
4. **Meta**: se carga `fbevents.js` solo tras el consentimiento de Publicidad. Se llama a `fbq('consent','revoke')` antes de `init` en cada página y `fbq('consent','grant')` cuando hay opt-in ([guía de Meta sobre RGPD](https://developers.facebook.com/docs/meta-pixel/implementation/gdpr/)). La documentación de Meta dice que hay que llamar a `revoke` en cada página.
5. **Retirada.** Si la persona retira el consentimiento, se llama a `gtag('consent','update', {… 'denied'})`, `fbq('consent','revoke')` y se recarga la página o se bloquean los eventos siguientes. Hay que borrar las cookies propias de Google y Meta (`_ga*`, `_gcl_*`, `_fbp`) en el dominio, que el plugin puede hacer sobre `chalkguide.es`. Es un requisito de la AEPD que retirar sea tan fácil como dar (resolución AI/00289/2023, ver sección 10).

### Efecto en el LCP

Referencia: `docs/marketing/lcp-audit-2026-11.md`. El LCP de móvil de la home es la primera imagen del hero y, por contenido, el CMP no debería ser nunca el elemento LCP.

- **Script del CMP**: inyectado en `app:mounted` tras `requestIdleCallback` (con `setTimeout` de 2 s como respaldo en Safari) y con `async`. No bloquea el render. Peso aproximado a verificar con Lighthouse en el preview (no medido aquí).
- **Banner**: `position: fixed` en la parte inferior, sin reservar altura en el flujo, para no provocar CLS; texto corto y botones pequeños, de modo que no sea mayor que la imagen del hero (si lo fuera, pasaría a ser LCP).
- **GA4, Google Ads y Meta**: solo después del `grant`, nunca en la primera pintura. Los visitantes que rechazan no pagan nada de peso (media de lectores). Los que aceptan descargan `gtag.js` (peso no medido aquí; medir) y `fbevents.js` (peso no medido aquí; medir) una vez ya pintada la página.
- **Prerender/ISR**: sin impacto en la caché de Netlify. El plugin es solo de cliente y no cambia el HTML servido; el banner no se renderiza en servidor (si lo hiciera, cada página ISR variaría por visitante y rompería la caché).
- Las acciones de la auditoría de LCP (sacar Tiptap, `sanitize-html` y `admin.css` del grafo público) se hacen **antes** de este trabajo; si no, el JS del CMP y los pixeles se suman a unos 480 KB gzip ya excesivos.

### Integración en Nuxt 4

Esto es una propuesta para coneja-lucky; no se toca código aquí.

- `app/plugins/consent.client.ts`: solo cliente. Define `window.dataLayer` y `gtag` con los cuatro `default: denied`, lee el consentimiento guardado (el CMP lo expone) y, en idle, inyecta el CMP si `runtimeConfig.public.cmpKey` existe.
- `app/composables/useConsent.ts`: interfaz única (`state`, `has('analytics'|'ads')`, `open()`, `onChange(cb)`). Aísla al CMP elegido: cambiar de CookieYes a `vanilla-cookieconsent` toca solo este archivo.
- `app/plugins/analytics.client.ts`: escucha `onChange`; con `analytics` inyecta `gtag.js` y configura GA4; con `ads` inyecta Google Ads y Meta. Sin consentimiento no hace nada.
- `app/plugins/track.client.ts` y `app/composables/useTrack.ts`: eventos propios (siempre activos) y fan-out a GA4/Meta solo si hay consentimiento, desde un único punto `track(name, params)`. Así cada componente emite un evento una sola vez.
- Exclusiones: nada de esto se carga en `/administrador/**`, en preview ni en local (bandera `NUXT_PUBLIC_ANALYTICS_ENABLED` y detección de entorno de producción de `nuxt.config.ts`).
- Configuración de GA4 al inicializar: `send_page_view: false` (el plugin envía el `page_view` propio en cada navegación del router, porque Nuxt es SPA), Google Signals desactivado, retención de datos de eventos en 2 meses (mínimo) en la propiedad, Enhanced Measurement sin "Form interactions" ni "Site search" con parámetros que lleven datos personales, y sin envío de datos proporcionados por el usuario (enhanced conversions desactivado).
- Meta: `fbq('init', ID)` con **coincidencia avanzada automática desactivada** en el Administrador de Eventos (el formulario de newsletter lleva un email: si se dejase activa, Meta recogería el email con hash). Sin API de Conversiones en la v1.
- Enlace de pie "Preferencias de cookies" que llama a `useConsent().open()`.
- Los componentes de `app/components/ui` que emitan eventos reciben `data-track` o llaman a `useTrack`; los vídeos de D26 no se tocan.

## 4. Esquema propuesto para `guide.analytics_events` (para jabali-javi)

### Principios

Sin datos personales: nada de IP, user agent, identificador de sesión, de dispositivo ni de usuario, ni cookies, ni almacenamiento local. Con esto, la capa 1 queda fuera del alcance del art. 22.2 de la LSSI (que regula guardar o acceder a información en el equipo del usuario) y no trata datos personales. La AEPD, en su guía de medición de audiencias de enero de 2024, fija además condiciones para que la analítica con cookies propias quede exenta (finalidad solo estadística para el editor, sin cruce con otros tratamientos, sin cesión, sin seguimiento entre sitios, cookies de máximo 13 meses y datos conservados máximo 25 meses, [resumen de Finreg360](https://finreg360.com/alerta/la-aepd-publica-la-guia-uso-de-cookies-para-herramientas-de-medicion-de-audiencias/)). Nuestra capa propia ni siquiera necesita esa exención. **GA4 sí cede datos a Google y por tanto no entra en esa exención**: va con consentimiento.

### Columnas mínimas

| Columna | Tipo | Notas |
| --- | --- | --- |
| `id` | `bigint generated always as identity` | PK |
| `occurred_at` | `timestamptz not null default now()` | Servidor, no cliente. Truncado a la hora (veto V2 de D69) |
| `name` | `text not null` | `check (name in (...))` con la lista de la sección 5 |
| `path` | `text not null` | Ruta sin query ni hash, máximo 200 caracteres, sin `/administrador` |
| `locale` | `text not null` | `es` / `en` |
| `content_type` | `text null` | `article`, `gym`, `resoler`, `shoe`, `event`, `page` |
| `content_slug` | `text null` | Slug, máximo 120 caracteres; no UUID de usuario |
| `pillar` | `text null` | Categoría del artículo (los 6 pilares) |
| `partner` | `text null` | Solo para `affiliate_click` (`barrabes`, etc.) |
| `source` | `text null` | Clase de origen derivada: `organic`, `social`, `direct`, `referral`, `email`, `other`; calculada en cliente desde `document.referrer` y `utm_source`; nunca el referrer completo |
| `device` | `text null` | `mobile` / `desktop` por ancho de pantalla (cliente), no por user agent |

No se admite una columna `jsonb` libre: acota las claves y permite validar. Si hiciera falta, un `params jsonb` con tope de 512 bytes y lista de claves permitidas en el RPC.

Nada de `user_id`, `email`, `subscriber_id` ni `ip`. `origen_articulo` del suscriptor ya se guarda en `guide.subscribers` en el alta (consentido y con base legal) y eso es lo que cruza con las altas; no se enlaza con eventos individuales.

### Escritura: RPC con límite de tasa

- `guide.track_event(p_name text, p_path text, p_locale text, p_content_type text, p_content_slug text, p_pillar text, p_partner text, p_source text, p_device text) returns void`, `security definer`, `set search_path = ''`, `EXECUTE` solo para `anon` y `authenticated`; `INSERT` directo revocado (RLS activa y sin policies de escritura).
- Valida contra lista cerrada (`name`, `locale`, `content_type`, `source`, `device`), recorta longitudes, rechaza `path` que empiece por `/administrador` o `/api`, ignora el resto. Si algo no valida, no hace nada y no falla (el cliente no debe romper la página por un evento).
- **Límite de tasa sin guardar IP**: como no hay identificador, el límite es **global y por tipo de evento**: tabla mínima `guide.analytics_event_rate (bucket timestamptz, name text, n int)` por minuto; si `n` supera un tope (propuesta: 300 por minuto por nombre, 1.000 en total) el RPC descarta sin escribir. Protege el almacenamiento frente a inundaciones, no frente a un cliente concreto (sin IP no se puede). Se purga cada hora.
- **Límite por cliente en el borde**: la ruta de entrada `server/api/e.post.ts` (Nitro en Netlify) recibe `sendBeacon`, valida el tamaño (máximo 1 KB) y llama al RPC con la clave publishable. Netlify permite limitar la tasa por IP en la configuración de funciones; lo consulta osset-op ([documentación de Netlify](https://docs.netlify.com/)). La IP la ve Netlify en sus registros, como con cualquier petición, pero **no llega nunca a la base de datos**. Alternativa si osset-op desaconseja la ruta Nitro: `supabase.rpc('track_event')` directo desde el navegador con la misma lista cerrada, y sin límite por IP salvo el global.
- Recomendación: la ruta Nitro, porque filtra bots obvios (cabecera `User-Agent` vacía o de rastreador conocido) **sin almacenar el user agent**.
- Cobertura de leona-lia: confirmar que un `anon` no puede leer `guide.analytics_events`, ni la tabla de tasa, ni sobrescribir.

### Retención

- Filas brutas de `guide.analytics_events`: **90 días**. Purga diaria con `pg_cron` y una función de purga `security invoker` sin `EXECUTE` para roles de la API, igual que `guide.purge_activity_log()` (D60, `20261106212800_guide_activity_log_retention.sql`).
- Agregado diario `guide.analytics_events_daily (day date, name text, content_type text, content_slug text, pillar text, partner text, source text, locale text, device text, n int, primary key (...))`: se rellena con el trabajo de purga justo antes de borrar las filas, vía `insert … on conflict do update`. Solo recuentos, sin datos personales: **se conserva 24 meses** (alineado con el tope de 24 meses del panel de Estadísticas, D59).
- Cumple con holgura el máximo de 25 meses de la AEPD para datos de medición exenta.

### Vistas y RPC agregadas para el panel (Estadísticas, D59)

Hoy la tarjeta "Visitas por página" figura "Sin conectar" (`docs/design/admin/estadisticas.html`). Con `guide.analytics_events` se mostraría:

| Vista del panel | Origen | Nota |
| --- | --- | --- |
| Visitas (páginas vistas) por día, semana o mes, con comparación con el periodo anterior | `page_view` agregado | Mismos rangos y granularidades que `admin_stats` (30 días o 12 meses, rango personalizado, tope 24 meses) |
| Páginas más vistas (top 10 a 20) | `page_view` por `path` o `content_slug` | Con tipo de contenido |
| Artículos: páginas vistas, altas de newsletter y **tasa de conversión por artículo** | `page_view` y `newsletter_submit` por `content_slug` | KPI principal de `.ai/marketing-seo.md` |
| Altas por pilar | `newsletter_submit` por `pillar` | Cuadra con los segmentos del embudo |
| Clics a fichas desde artículos | `ficha_click` | |
| Clics de afiliado por socio y por ficha | `affiliate_click` | Independiente de GA4 |
| Origen del tráfico (orgánico, social, directo, referral, email) | `page_view` por `source` | Aproximación: sin sesiones |
| Opiniones: login para opinar y opinión enviada | `login_for_review`, `review_submitted` | Contraste con `guide.user_reviews` |
| Embudo de la newsletter | `newsletter_view` → `newsletter_submit` → `newsletter_confirmed` | Confirmados desde el webhook de Brevo |

Aviso de lectura en el panel: **páginas vistas, no visitantes únicos**; las tasas son "altas por página vista del artículo". Y que los datos de GA4 no aparecen aquí (viven en Google).

RPC propuestas: `guide.admin_events_stats(p_range, p_granularity, p_from, p_to)` (misma firma y reglas que `admin_stats`), `guide.admin_events_top(p_name, p_range, p_limit)` y `guide.admin_article_conversion(p_range)`. Todas `security definer`, solo para superadmin (`guide.is_superadmin()` o su equivalente en el proyecto), con `EXECUTE` revocado a `anon`.

## 5. Lista de eventos

Capa: P = propia (`guide.analytics_events`, sin consentimiento), G = GA4 (con consentimiento de Analítica), M = Meta (con consentimiento de Publicidad). Todos los eventos pasan por `useTrack`, un único punto. Los parámetros de P siguen las columnas de la sección 4; los de G y M no llevan texto libre ni datos personales.

Estructura de conversión: la única conversión de Google Ads y de Meta que usaremos al inicio es el alta en la newsletter, porque es el objetivo del negocio. El resto son eventos de audiencia o diagnóstico.

| Evento (nombre P) | Se dispara cuando | Parámetros | Capas | Nombre GA4 / Meta | Conversión de Google Ads / Meta |
| --- | --- | --- | --- | --- | --- |
| `page_view` | Cada carga y cada navegación del router (no en `/administrador`) | `path`, `locale`, `content_type`, `content_slug`, `pillar`, `source`, `device` | P, G, M | `page_view` / `PageView` | Ninguna. Alimenta audiencias de remarketing por pilar y por tipo de contenido |
| `newsletter_view` | El bloque naranja entra en pantalla (IntersectionObserver, una vez por carga de página) | `content_slug`, `pillar` | P | n/a | Ninguna. Solo para la tasa de visibilidad del bloque |
| `newsletter_submit` | El formulario se envía y el servidor responde con éxito (pendiente de confirmación) | `content_slug`, `pillar`, `locale` | P, G, M | `generate_lead` / `Lead` | **Conversión principal** en Google Ads (acción "Alta newsletter", valor 0) y en Meta (evento `Lead`). Sin email ni parámetros personales |
| `newsletter_confirmed` | Webhook de Brevo en servidor (doble opt-in confirmado) | `content_slug`, `pillar` | P (solo) | n/a | Ninguna: no se envía a Google ni Meta |
| `ficha_click` | Clic de artículo a ficha (rocódromo, resolador, comparador, agenda) | `content_slug` de origen, `content_type` de destino | P, G | `select_content` | Ninguna; sirve para audiencias "interesado en rocódromos / material" |
| `affiliate_click` | Clic en enlace con `rel="sponsored nofollow"` | `partner`, `content_slug` (ficha), `path` | P, G, M | `affiliate_click` (personalizado) / `AffiliateClick` (evento personalizado de Meta) | Conversión **secundaria** en Google Ads (solo observación) y personalizada en Meta; nunca el objetivo de optimización mientras no haya ingresos |
| `outbound_gym` | Clic a la web de un rocódromo | `content_slug` | P | n/a | Ninguna |
| `login_for_review` | Clic en "Iniciar sesión para opinar" | `content_slug` | P | n/a | Ninguna |
| `review_submitted` | Opinión enviada | `content_slug` | P | n/a | Ninguna |
| `scroll_75` | Scroll al 75 % en artículo (una vez por página) | `content_slug`, `pillar` | P, G | `scroll_75` (personalizado; no usar el 90 % automático de Enhanced Measurement) | Ninguna; audiencia "lector comprometido" |
| `video_play` | Clic en "Reproducir vídeo" (D26) | `content_slug` | P | n/a | Ninguna. No se envía a G ni M: es solo conteo propio; el vídeo ya contacta con YouTube por decisión de quien pulsa |
| `search_blog` | Búsqueda en el blog | Sin el texto buscado | P | n/a | Ninguna (el texto puede contener datos personales; no se guarda) |

Reglas:

- Un `affiliate_click` registrado en la capa propia es la fuente de verdad para liquidar con Barrabes; GA4 es un espejo con consentimiento.
- Ninguna conversión de Google Ads o Meta se alimenta con confirmaciones de Brevo ni con listas de emails (Customer Match fuera, D69).
- Google Ads importa la conversión de la propiedad GA4 (evento `generate_lead` marcado como conversión) o usa la etiqueta de conversión propia; recomiendo importar desde GA4 para no cargar dos mecanismos. Si hace falta más control, la etiqueta propia con `NUXT_PUBLIC_GADS_CONV_NEWSLETTER`.
- No enviar a Google ni a Meta ninguna URL con parámetros que contengan el token de confirmación del doble opt-in (la ruta de confirmación debe excluirse del `page_view` de G y M y quedar con `noindex`).

## 6. Audiencias de remarketing

### Umbrales verificados

- **Google Ads**: una lista de remarketing necesita al menos **100 usuarios activos en los últimos 30 días** para servir en la Red de Display, la de Búsqueda y YouTube. Duración de pertenencia: por defecto 30 días, máximo 540 días en Display y Búsqueda ([ayuda de Google Ads, tamaños y duración](https://support.google.com/google-ads/answer/2472738)). Hasta finales de 2025 el mínimo para Búsqueda era de 1.000; hoy es 100 (fuentes de prensa especializada: [Search Engine Land](https://searchengineland.com/google-lowers-audience-size-limits-across-ads-466816); la página de ayuda actual solo indica 100).
- **Meta**: un público personalizado necesita al menos **100 personas** antes de poder anunciarse; los públicos de web del píxel se conservan hasta **180 días** ([Centro de ayuda de Meta](https://www.facebook.com/business/help/170456843145568); la documentación de la API da `retention_days` de 1 a 180 y su FAQ menciona 365, [guía de la API](https://developers.facebook.com/docs/marketing-api/audiences/guides/website-custom-audiences)). Meta no publica el mínimo en la página de la API; confirmar el estado "público listo" en el Administrador de Anuncios antes de gastar.

### Efecto del consentimiento en el tamaño

Solo entran en las listas las personas que aceptan Publicidad y remarketing. Hipótesis (E, no medida): entre el 30 y el 50 % acepta con un banner donde rechazar pesa lo mismo que aceptar. Con los objetivos de tráfico de la investigación (800 a 2.500 clics orgánicos al mes a 6 meses), entrarían entre unos 250 y 1.200 usuarios al mes, repartidos entre los pilares. Un pilar con el 15 % del tráfico queda en torno a 40 a 180 usuarios al mes: **al límite de los 100**. Por eso se parte de audiencias amplias y se segmenta solo cuando el tamaño lo permite.

### Audiencias a crear

Reglas por URL de categoría del blog (el pilar es la categoría del artículo). Las mismas reglas en Google Ads (segmentos de datos de GA4 o de la etiqueta de Google Ads) y en Meta (público personalizado de web).

| # | Audiencia | Regla | Ventana | Tamaño mínimo | Cuándo crearla |
| --- | --- | --- | --- | --- | --- |
| A | Lectores del blog | Visitó cualquier artículo, excluyendo suscritos si es posible (ver nota) | 30 días en Google; 90 días en Meta | 100 | Desde el día 1 (acumula histórico) |
| B | Lectores comprometidos | `scroll_75` en ≥ 2 artículos | 90 días | 100 | Cuando A supere 400 |
| C | Material y pies de gato | Visitó el comparador o artículos del pilar Material | 30 días (Google), 60 (Meta) | 100 | Desde el día 1 (pico nov-dic); si no llega a 100, fusionar con A |
| D | Dónde escalar y rocódromos | Visitó fichas de rocódromo o el pilar Dónde escalar | 60 días | 100 | Cuando A supere 400 |
| E | Empezar y Costes | Visitó pilares Empezar a escalar o Costes | 60 días | 100 | Cuando A supere 400 |
| F | Familias | Visitó artículos de rocódromos con zona infantil | 90 días | 100 | Solo si supera 100 de forma natural |
| G | Compañero | Visitó "ir solo y encontrar compañero" | 90 días | 100 | Cerca del lanzamiento de Chalk app (F9) |
| H | Clic de afiliado | Hizo `affiliate_click` | 30 días | 100 | Solo para excluirla de campañas de captación |
| Exclusión | Suscriptores nuevos | Visitó la página de gracias del alta (`newsletter_submit`) | 540 días (Google) / 180 (Meta) | n/a | Desde el día 1, como exclusión |

Notas:

- **Pilar Progresión y cuidado (lesiones)**: no crear audiencia propia ni usar `pillar=progresion` en remarketing. Las políticas de publicidad personalizada de Google restringen el remarketing basado en información sensible, incluida la salud, y Meta restringe públicos basados en condiciones de salud. Los artículos de lesiones (poleas) quedan **fuera de las listas**; el artículo de calentamiento no es sensible pero se excluye por simplicidad. A confirmar contra las políticas vigentes antes de crear listas (leona-lia y Xavi).
- **Exclusión de suscritos**: es el uso legítimo más valioso: no gastar impresiones en quien ya está dentro. Se implementa con la audiencia de quienes llegaron a la página de gracias, **sin subir emails**. Quien se suscribió sin aceptar cookies no entra en la lista; es inevitable.
- Primera campaña razonable: captación de newsletter a audiencia A con una promesa concreta del embudo (sección 5 de la investigación SEO). Sin presupuesto de pago hay que decidirlo aparte: **Xavi no ha aprobado gasto publicitario**; esta spec solo crea las listas.

## 7. Lo que necesita Xavi

### Cuentas

1. **Google Search Console** (capa 1): propiedad de dominio `chalkguide.es`, verificada por DNS TXT (no requiere código). Enviar `/sitemap.xml`. Hacerlo el día del lanzamiento.
2. **Google Analytics 4**: propiedad nueva con flujo de datos web `chalkguide.es`. Ajustes: Google Signals desactivado, retención de datos de usuario y eventos en 2 meses, sin enhanced measurement de formularios, conservar solo la conversión `generate_lead`. Cuenta en la UE si se puede elegir; revisar la región de datos.
3. **Google Ads**: cuenta (puede estar sin campañas ni gasto; la etiqueta, la conversión y las listas de remarketing no cuestan). Vinculada a GA4. Sin Customer Match.
4. **Meta Business Manager**: cuenta de empresa, píxel en Administrador de Eventos, dominio `chalkguide.es` verificado (DNS TXT). **Desactivar la coincidencia avanzada automática**. Sin API de Conversiones.
5. **CMP**: cuenta de CookieYes (plan Free, sitio `chalkguide.es`). Firmar el acuerdo de tratamiento (DPA) del proveedor.
6. Aceptar en Google y Meta las condiciones de uso de datos que correspondan (datos del anunciante, condiciones de listas de remarketing, condiciones de públicos personalizados de Meta). Lo hace Xavi: son aceptaciones legales a su nombre.

### Variables `NUXT_PUBLIC_*` (para osset-op)

Todas públicas por naturaleza (aparecen en el navegador); ningún secreto. A configurar en Netlify solo en el contexto `production`; vacías en previews, así el plugin no carga nada.

| Variable | Contenido | Quién la da |
| --- | --- | --- |
| `NUXT_PUBLIC_ANALYTICS_ENABLED` | `true` solo en producción con dominio real | osset-op |
| `NUXT_PUBLIC_CMP_PROVIDER` | `cookieyes` (o `vanilla`) | Xavi, con esta spec |
| `NUXT_PUBLIC_COOKIEYES_KEY` | Clave del sitio de CookieYes (la del script del banner) | Xavi |
| `NUXT_PUBLIC_GA4_ID` | `G-XXXXXXXXXX` | Xavi |
| `NUXT_PUBLIC_GADS_ID` | `AW-XXXXXXXXXX` | Xavi |
| `NUXT_PUBLIC_GADS_CONV_NEWSLETTER` | Etiqueta de conversión (solo si se usa la etiqueta propia, no la importación desde GA4) | Xavi |
| `NUXT_PUBLIC_META_PIXEL_ID` | ID del píxel | Xavi |

La verificación de Search Console y de Meta se hace por DNS (registros TXT, osset-op o quien gestione el dominio) y no necesita variables. El ID de GA4 y el del píxel van también al `.env.example` como vacíos y comentados (lo toca osset-op / coneja-lucky, no yo).

## 8. Textos y diseño pendientes

### loro-lola (`/cookies`, `/privacidad`): puntos, no texto

`/cookies` (hoy dice que no hay banner y no usa cookies publicitarias; deja de ser cierto):

- Quitar «no hay banner» y «no uso cookies publicitarias ni de seguimiento»; ahora hay dos capas.
- Explicar la capa sin cookies: medición propia anónima (sin IP, sin cookies) y Search Console.
- Tabla por categoría (necesarias, analítica, publicidad y remarketing): proveedor, finalidad, nombres de cookies (`_ga`, `_ga_<id>`, `_gcl_*`, `_fbp` y las que se confirmen en el escaneo del CMP), duración y quién es responsable.
- Consentimiento: se pide al entrar, rechazar es tan fácil como aceptar, cómo cambiarlo (enlace «Preferencias de cookies» del pie) y cómo retirarlo; fecha del último cambio.
- Mantener sin cambios el párrafo de YouTube (D26) y decir que no depende del banner.
- Mencionar el CMP como tercero que recibe la IP al mostrar el banner.
- Pendientes del borrador actual: duración de la sesión de Supabase y si se guarda el idioma.
- Retirar la frase de «Cambios» que promete «actualizaré antes de activarlo»: la actualización es previa al lanzamiento.

`/privacidad`:

- Nuevo tratamiento «medición y publicidad»: responsable, finalidad, base legal (consentimiento, art. 6.1.a RGPD y art. 22.2 LSSI), destinatarios (Google LLC, Meta Platforms Ireland, proveedor del CMP), transferencias internacionales (EE. UU., y el marco de privacidad de datos UE-EE. UU. si el proveedor está adherido; confirmar con leona-lia), conservación (2 meses en GA4; listas de remarketing hasta 540 y 180 días).
- Capa propia: no personal, retención de 90 días brutos y 24 meses agregados.
- Derechos de acceso, supresión y retirada; cómo oponerse al remarketing en los ajustes de anuncios de Google y de Meta.
- Decir explícitamente que no se suben emails a Google ni a Meta.
- Reafirmar: login con Google no es consentimiento de newsletter ni de cookies (regla 8 del CLAUDE.md).

### buho-pixel (banner): puntos

- Barra inferior compacta (no modal, sin fondo oscuro, no bloquea el contenido ni la lectura de `/cookies` y `/privacidad`; sin interstitial, coherente con D22).
- Primera capa con **tres botones del mismo peso visual, tamaño y posición**: Aceptar, Rechazar y Configurar. Criterio AEPD: aceptar y rechazar al mismo nivel, en primera capa (sección 10).
- Segunda capa: categorías con interruptores desmarcados; «Necesarias» fija. Sin casillas premarcadas.
- Cerrar con la X equivale a rechazar; seguir navegando o hacer scroll no es consentimiento.
- Estados con `prefers-reduced-motion`, foco visible, orden de tabulación, `role="dialog"` no modal con etiqueta y retorno de foco; se anuncia sin robar el foco en la carga.
- Altura máxima en móvil (propuesta: ≤ 25 % del alto de pantalla), `position: fixed`, sin reservar espacio en el flujo (CLS cero), y que nunca sea el elemento LCP (más pequeño que el hero).
- Debe coexistir con el bloque naranja de newsletter (D48) y con el pie fijo si lo hubiera, sin taparlos.
- Enlace «Preferencias de cookies» en el pie para reabrir.
- Sin banner en `/administrador`.
- Marca del CMP: en el plan gratuito de CookieYes no se puede quitar; decidir si se acepta visualmente o se pasa a la opción B.
- Idioma: ver decisión 2 de la sección 0.

## 9. Orden de ejecución por agente y riesgos para leona-lia

### Orden

1. **Xavi**: aprueba decisiones de la sección 0; crea cuentas (sección 7) cuando haya dominio.
2. **buho-pixel**: propuesta de banner, para aprobación de Xavi (regla 2 del CLAUDE.md). En paralelo:
3. **jabali-javi**: migración `guide.analytics_events`, `guide.analytics_events_daily`, `guide.analytics_event_rate`, `guide.track_event`, purga con `pg_cron` y RPC de agregados del panel.
4. **leona-lia (veto obligatorio)**: revisión de tablas, RPC y GRANTs; verifica que `anon` no lee eventos y que no hay datos personales; revisa la lista cerrada y el límite de tasa. Revisión del flujo de consentimiento (sección 3) y de las políticas.
5. **loro-lola**: textos de banner (es y en, o bilingüe) y de `/cookies` y `/privacidad`. Sin estos textos publicados no se activa nada.
6. **coneja-lucky**: plugins `consent`, `analytics`, `track`; composables; banner; `server/api/e.post.ts`; enlace del pie. **Antes**, las acciones 1 a 3 de la auditoría de LCP.
7. **osset-op**: variables `NUXT_PUBLIC_*` en Netlify solo en `production`, límite de tasa de la ruta de eventos, cabeceras (`Content-Security-Policy` actual solo tiene `frame-ancestors 'none'`; ampliarla con los orígenes de Google, Meta y CMP si se decide una CSP), registros DNS (TXT de Search Console y Meta).
8. **lince-max (yo)**: configuración de GA4 y las conversiones, definición de audiencias, verificación de eventos en modo depuración, medición de LCP antes y después con Lighthouse sobre el preview, y actualización de `.ai/marketing-seo.md` si Xavi lo aprueba.
9. **buho-pixel**: revisión visual final (APROBADO o CAMBIOS). **zorro-foxter**: pasada final (`build`, `lint`, `typecheck`).
10. **Xavi**: aprueba y activa. Nada se publica solo.

### Riesgos para leona-lia

1. **Datos personales en la capa propia**: asegurar que ni el `path` (token de confirmación, query) ni el `content_slug` ni el `source` puedan contener datos personales. Hay que cortar la query en el cliente y validar en servidor; revisar rutas con token (confirmación y baja de newsletter) para que no emitan eventos.
2. **Contraste IP**: la ruta Nitro ve la IP (Netlify también); confirmar que no se guarda ni se reenvía y que el RPC no lee `request.headers`.
3. **Inundación de eventos**: sin IP no hay límite por cliente en la base de datos. Falsificar `affiliate_click` ensucia métricas de afiliados; mitigación: el recuento propio es una orientación y no una base de liquidación, que se concilia con el panel de afiliación del socio.
4. **El CMP recibe la IP antes de la elección**: base legal (interés legítimo para mostrar el aviso) y contrato de encargado. Con la opción B no ocurre.
5. **Coincidencia avanzada de Meta**: si se deja activa, el email del formulario de newsletter viaja con hash a Meta. Debe quedar desactivada y comprobada en el Administrador de Eventos; los eventos de formulario no deben llevar valores.
6. **Retirada de consentimiento**: probar que, tras retirar, se borran `_ga*`, `_gcl_*`, `_fbp` y que no se envían más eventos a G ni M.
7. **Fuga de cookies antes de la elección**: prueba automática (Network y Application) de 0 peticiones a Google y Meta y 0 cookies de terceros antes de la elección, en ES y EN, con y sin JS.
8. **Transferencias a EE. UU.** (Google, Meta, CMP): a revisar contra el estado vigente del marco UE-EE. UU.
9. **Contenido sensible en listas de remarketing** (lesiones): exclusión efectiva por regla de URL, verificada.
10. **Caché ISR**: el banner y los plugins no deben alterar el HTML cacheado ni meter estado de consentimiento en el payload (lección de F3.10 con las cookies de sesión de Supabase).
11. **Retención**: la purga de eventos debe tener prueba (como la de `activity_log`), y el agregado diario no puede reconstruir personas.
12. **Tope del plan gratuito del CMP**: qué hace el banner al superarlo; el fallo seguro es no cargar nada.
13. **Admin**: confirmar que `/administrador/**` no emite eventos ni carga el CMP (los lectores no son el equipo).
14. **Menores y datos sensibles**: no hay segmentación por edad ni por salud; no iniciar anuncios dirigidos a menores (pilar Familias) hasta revisar las políticas.

## 10. Verificación contra documentación oficial

Hecho en esta sesión (2026-11-12). Lo que no se pudo leer se declara.

### Consent Mode v2 (Google)

- Hay cuatro tipos: `ad_storage` y `analytics_storage` (originales), más `ad_user_data` y `ad_personalization` (v2). Por defecto no hay valores; hay que fijar los valores `default` antes de cualquier medición; el `update` se envía cuando la persona elige y debe persistirse entre páginas; si el código de consentimiento se llama en desorden, los valores por defecto no funcionan; `wait_for_update` es para banners cargados de forma asíncrona; los valores por región usan códigos ISO 3166-2 y gana la región más específica. Fuente: [guía de Consent Mode para gtag.js](https://developers.google.com/tag-platform/security/guides/consent).
- Modelado de comportamiento en GA4: mínimo de 1.000 eventos diarios con `analytics_storage='denied'` durante al menos 7 días y 1.000 usuarios diarios con consentimiento en 7 de los últimos 28 días; en la implementación avanzada las etiquetas de Google se cargan en todos los casos, no solo con consentimiento. Fuente: [ayuda de Google Analytics](https://support.google.com/analytics/answer/11161109).
- Política de consentimiento de usuarios de la UE: hay que obtener consentimiento válido para cookies y almacenamiento local, para personalizar anuncios, conservar registros del consentimiento y dar instrucciones claras para retirarlo, en el EEE, el Reino Unido y Suiza. Fuente: [Google](https://www.google.com/about/company/user-consent-policy/). La página no habla de CMP certificado ni distingue anunciantes de editores.
- Lista de CMP socios: [Google Tag Manager](https://support.google.com/tagmanager/answer/10718549).

### Mínimos de audiencia

- Google Ads: 100 usuarios activos en 30 días en Display, Búsqueda y YouTube; duración máxima de 540 días en Display y Búsqueda. Fuente: [ayuda de Google Ads](https://support.google.com/google-ads/answer/2472738). **Demand Gen no figura en la página**; no confirmado.
- Meta: 100 personas para anunciar; 180 días de retención del píxel (Centro de ayuda, [artículo](https://www.facebook.com/business/help/170456843145568)). La documentación de la API indica `retention_days` entre 1 y 180 y su FAQ cita 365 sin reconciliarlo ([API de públicos de web](https://developers.facebook.com/docs/marketing-api/audiences/guides/website-custom-audiences)). Contrastar en el Administrador de Anuncios.

### AEPD

- La AEPD actualizó su guía de cookies el 11 de julio de 2023 para alinearla con las directrices 03/2022 del CEPD sobre patrones engañosos: aceptar y rechazar deben presentarse en lugar y formato destacados, al mismo nivel, sin que rechazar sea más difícil; las cookies de personalización elegidas por el usuario (idioma) son técnicas; el muro de cookies es posible si se ofrece una alternativa, que no tiene por qué ser gratuita; plazo de adaptación hasta el 11 de enero de 2024. Fuente: [nota de prensa de la AEPD](https://www.aepd.es/prensa-y-comunicacion/notas-de-prensa/aepd-actualiza-guia-cookies-para-adaptarla-a-nuevas-directrices-cepd).
- Guía de medición de audiencias (11 de enero de 2024): condiciones de exención (sección 4). Fuente secundaria: [Finreg360](https://finreg360.com/alerta/la-aepd-publica-la-guia-uso-de-cookies-para-herramientas-de-medicion-de-audiencias/). El PDF oficial devolvió un error de servidor y no pude leerlo.
- Retirar el consentimiento debe ser tan fácil como darlo: resolución sancionadora [AI/00289/2023](https://www.aepd.es/documento/ai-00289-2023.pdf), según un resumen de buscador; no leí el documento íntegro.
- **No pude extraer el texto de la guía de cookies general** (el PDF de la AEPD se descargó como binario sin texto utilizable en este entorno). Criterios que cito de memoria o de segunda mano y que **leona-lia debe confirmar en el texto**: seguir navegando o hacer scroll no es consentimiento; renovación del consentimiento cada 24 meses como buena práctica; lista de cookies exentas. El PDF está en [aepd.es/guias/guia-cookies.pdf](https://www.aepd.es/guias/guia-cookies.pdf).

### Peso y precios de los CMP

Cifras de las páginas de precios oficiales tal como estaban el 2026-11-12; cambian a menudo. No he medido el peso del script de ningún CMP: hay que medirlo con Lighthouse en el preview antes de cerrar la elección.
