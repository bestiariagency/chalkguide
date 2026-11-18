# Revisión de seguridad · D66 `p_related` y D69 analítica propia

- **Revisora:** leona-lia (informe dictado, sin herramienta de escritura; guardado por el orquestador)
- **Fecha:** 2026-11-14
- **Proyecto:** `eqtjlafxtrzbjazhhyin`, schema `guide`
- **Migraciones:**
  - `supabase/migrations/20261113180245_guide_d66_admin_list_subscribers_related.sql`
  - `supabase/migrations/20261113180726_guide_d69_analytics_events.sql`
- **Referencias:** `.ai/security-rls.md`, `docs/marketing/analitica-remarketing-spec.md` §4–§5, `supabase/tests/guide_rls_leaks.sql` (bloque «D66 p_related y D69», línea 10053)

## Veredicto

- **D66 (`admin_list_subscribers` + `p_related`): APROBADO.**
- **D69 (analítica propia): VETADO**, con 2 vetos abiertos (V1 y V2). La tarea no se cierra hasta corregirlos y pasar una nueva revisión.

## D66 · `admin_list_subscribers(p_related)`

- Solo queda una sobrecarga, la de 13 argumentos. La firma vieja de 12 está borrada.
- `SECURITY DEFINER`, `search_path = ''` y dueño `postgres`. `perform guide.assert_admin()` es la primera sentencia.
- EXECUTE solo para `postgres` y `authenticated`. Está revocado a `public`, `anon` y `service_role`.
- Valida entradas. `cardinality(p_related) <= 4`. El enum tipado impide valores arbitrarios.
- `related_counts` es una faceta: aplica el resto de filtros y no `p_related`. Solo devuelve recuentos y no expone filas fuera del filtro. Es correcto.
- Pruebas:
  - Como `anon`: 42501.
  - Como `authenticated` no admin: 42501.
  - Como admin: devuelve la estructura esperada.

## D69 · Analítica propia

### Lo que está bien

- **Sin datos personales en columnas.** Las tablas no tienen columnas de IP, user agent, sesión, usuario ni email. Ni el RPC ni `analytics_record` leen `request.headers`. Los CHECK de tabla repiten la validación del RPC:
  - lista cerrada de `name`;
  - `path` en minúsculas y sin query;
  - `path` sin `/administrador` ni `/api`;
  - sin UUID, sin hex de 24 caracteres o más y sin 7 dígitos seguidos;
  - `source` y `device` cerrados;
  - `partner` solo en `affiliate_click`.
- **CHECK con función.** `guide.analytics_token_safe` es `immutable`, pura, `INVOKER` y no lee datos. La acepto según la regla de CHECK de `.ai/security-rls.md`.
- **RLS y GRANTs:**
  - Las 3 tablas tienen RLS activado.
  - `analytics_events` y `analytics_events_daily`: solo `SELECT` para `authenticated`, con policy `(select guide.is_admin())`. Nadie de la API tiene INSERT, UPDATE ni DELETE.
  - Las secuencias no tienen grants para roles de la API.
- **Tabla de tasa sin policy: correcta.** `analytics_event_rate` tiene RLS activado, ningún GRANT y ninguna policy. Solo la toca `track_event`, que es DEFINER con dueño `postgres` y propietario de la tabla. El aviso INFO `rls_enabled_no_policy` del advisor es intencionado.
- **`track_event`:**
  - `SECURITY DEFINER` y `search_path = ''`.
  - EXECUTE solo para `anon` y `authenticated`.
  - Rechaza `newsletter_confirmed`.
  - Un `name` no válido no crea filas de tasa. Las filas de tasa quedan acotadas a 12 nombres más `*` por minuto.
  - Si algo falla, el error se captura y no rompe la página.
- **Funciones internas.** `analytics_record`, `analytics_range`, `analytics_rows` y `purge_analytics_events` son `INVOKER` y no tienen EXECUTE para la API.
- **RPC de admin.** `admin_analytics_stats`, `admin_analytics_top` y `admin_analytics_article_conversion` son DEFINER con `search_path = ''`. Su primera sentencia es `assert_admin()`. EXECUTE solo para `authenticated` y revocado a `anon`. Validan los parámetros contra listas cerradas y aplican el tope de 24 meses.
- **`confirm_newsletter`:**
  - Conserva el cuerpo de D66.
  - Escribe el evento en un sub-bloque con `exception when others`, así que un fallo de analítica no impide confirmar.
  - El evento solo lleva datos que ya están en la fila del suscriptor: `consent_page`, locale, artículo y pilar.
  - La hora va truncada a la hora.
  - Ahora también revoca `service_role`. Ningún código del repo lo llama con esa clave, así que no rompe nada.
- **Cron `guide-analytics-purge`:**
  - Corre a `40 * * * *` como `postgres`.
  - El comando es fijo: `select guide.purge_analytics_events()`.
  - La función es `INVOKER` y no tiene EXECUTE para la API.
  - El bruto se mueve al agregado y se borra en un solo statement, así que cada fila cuenta una vez.
- **`public` no se toca.** Ninguna de las dos migraciones referencia `public.`, `on schema` ni `alter default`. Los avisos del advisor sobre `public` son anteriores y ajenos a este cambio.

### Pruebas de fuga

Todas se hicieron en transacción con ROLLBACK. Después se verificó que `analytics_events` y `analytics_event_rate` siguen con 0 filas.

| Prueba | Resultado |
| --- | --- |
| anon: SELECT `analytics_events` / `_daily` / `_event_rate` | 42501 en las tres |
| anon: INSERT en `analytics_events` y en la tabla de tasa (contador negativo) | 42501 |
| anon: UPDATE `analytics_events`, DELETE `_daily` | 42501 |
| anon: `analytics_record` (fecha falsa), `purge_analytics_events`, `analytics_rows` | 42501 |
| anon: las 3 RPC de admin y `admin_list_subscribers` | 42501 |
| anon: `track_event('newsletter_confirmed', …)` | No escribe |
| anon: `track_event` con ruta `/administrador/...`, `/en/api/...`, hex de 32, UUID, teléfono o `@` | No escribe |
| anon: `track_event` con locale `fr`, `content_type` `user` o `source` URL | No escribe |
| anon: `track_event` con `name` o `path` de 100 000 caracteres | No escribe, sin error |
| anon: ruta `/Blog/Mi-Articulo/?email=a@b.com#x` | Guarda `/blog/mi-articulo`; descarta `partner` |
| anon: `search_blog` con slug | Guarda `content_slug` null |
| anon: 4 × 320 eventos en un minuto | 300 por nombre; total exacto de 1 000 |
| authenticated no admin: SELECT `analytics_events` / `_daily` | 0 filas (con filas sembradas) |
| authenticated no admin: tabla de tasa, INSERT, UPDATE, DELETE | 42501 |
| authenticated no admin: funciones internas, RPC de admin y `admin_list_subscribers` | 42501 («admin only») |
| admin: las 3 RPC y `admin_list_subscribers` con y sin `p_related` | OK |
| Purga (como postgres) | Mueve las filas de más de 90 días al agregado diario (2 filas pasan a `n = 2`). Conserva las recientes. Borra el agregado de más de 24 meses y la tasa de más de 1 hora |

### Advisors (security)

- Avisos nuevos:
  - `rls_enabled_no_policy` en `analytics_event_rate` (INFO, intencionado).
  - `anon_security_definer_function_executable` en `track_event` (intencionado).
  - `authenticated_security_definer_function_executable` en las 3 RPC de admin. Es el patrón aceptado, protegido por `assert_admin`.
- Ningún aviso inesperado.

## Vetos

### V1 · Inundación de almacenamiento en la base compartida con Chalk app

**Motivo.** El tope solo es por minuto, así que un cliente hostil con la clave publishable puede sostener 1 000 eventos/min:

- 1 000 eventos/min son 1,44 millones de filas al día.
- Cada fila ocupa unos 220 bytes, contando heap y 3 índices.
- Eso suma unos 285 MB al día y unos 25 GB en los 90 días de retención.

La base pesa hoy 24 MB y la comparte Chalk app. Si se llena el disco, Supabase pone la base en solo lectura y caen las dos aplicaciones, o el coste se dispara con el autoescalado. La spec dice que el tope «protege el almacenamiento frente a inundaciones», pero con esos valores no lo hace.

**Corrección sugerida:**

1. Añadir en `track_event` un **tope diario global**, por ejemplo 20 000 eventos/día. Puede usar la misma tabla de tasa, con `bucket = date_trunc('day', now())` y un `name` reservado tipo `*day`. Con ese tope, el bruto queda en menos de 1,8 millones de filas y unos 400 MB como máximo.
2. Ajustar la purga para que los buckets diarios no se borren antes de que termine el día. Por ejemplo, borrar solo las filas `*day` de más de 2 días.
3. Opcional: añadir una señal de salud (como `ingest_health_check`) cuando se alcance el tope, para que Xavi sepa que las cifras del día no son fiables.
4. Añadir al bloque de tests el caso «tope diario alcanzado: no escribe».

### V2 · Reidentificación por hora exacta

**Motivo.** `occurred_at` se guarda con precisión de microsegundos, y el admin puede leer el bruto directamente (`SELECT` en `analytics_events`). Tres eventos coinciden en el tiempo con filas que identifican a una persona:

- `review_submitted` con `user_reviews.created_at`, que va ligada a `user_id` y al nombre visible;
- `newsletter_submit` con `subscribers.consent_at` y `consent_page`, que van ligados al email;
- `login_for_review` con el inicio de sesión en `auth`.

Al cruzarlos, se asignan `device` y `source` a una persona identificada. Además, con poco tráfico, los `page_view` de los segundos anteriores con el mismo `device` y `source` permiten reconstruir su recorrido. Esto contradice la spec (§4: «no se enlaza con eventos individuales»; capa «no personal») y la verificación pedida («sin forma de reidentificar combinando ruta, hora y dispositivo»).

**Corrección sugerida:**

1. En `guide.analytics_record`, guardar `date_trunc('hour', coalesce(p_at, now()))` para **todos** los eventos. Las estadísticas trabajan por día de Madrid y la purga de 90 días no cambia, así que no se pierde nada.
2. En `newsletter_submit`, `review_submitted` y `login_for_review`, poner `source` y `device` a null. Esos tres eventos pueden casar con una fila identificable incluso con la hora truncada, si es el único de esa hora. Así solo aportarían lo que ya consta en esa fila. El panel no usa el desglose por origen ni por dispositivo de esos eventos.
3. Añadir tests:
   - `occurred_at` sale truncado a la hora;
   - `source` y `device` son null en esos 3 eventos.
4. Actualizar `docs/data-model.md` con la regla de truncado.

## Observaciones (no bloquean)

1. **Texto libre en `path`.** Un atacante puede guardar cadenas arbitrarias que cumplan el patrón, por ejemplo `/juan.perez`. No hay datos de terceros: ninguna ruta pública del sitio lleva datos personales (revisado `app/pages/`) y lo único que se puede inyectar es basura propia. Opcional: validar contra una lista de prefijos de rutas conocidos para reducir el ruido.
2. **Supresión de eventos reales.** Una inundación consume el tope y tapa los eventos reales, y puede falsear `affiliate_click`. Es un riesgo aceptado en la spec: esas cifras orientan y no sirven de base de liquidación, que se concilia con el panel del socio. El tope diario de V1 lo agrava ligeramente, a cambio de proteger la base.
3. **Doble recuento de `newsletter_confirmed` en F4.6.** Si el webhook de Brevo también registra el evento, contará dos veces. Hay que elegir una sola fuente (recomendado: `confirm_newsletter`). Requiere revisión de leona-lia en F4.6.
4. **`confirm_newsletter` busca artículos no publicados.** Busca por `slug_es`/`slug_en` sin filtrar `published`. Solo afecta a datos que ve el admin, así que no hay fuga.
5. **Contador consumido por payloads no válidos.** El contador por minuto cuenta también los eventos con `name` válido que luego no pasan la validación. Es el comportamiento correcto para frenar inundaciones.

## Cierre

Para levantar el veto hacen falta tres cosas:

1. jabali-javi aplica V1 y V2 en una migración nueva.
2. jabali-javi amplía el bloque de tests en `supabase/tests/guide_rls_leaks.sql`.
3. leona-lia repite la revisión.

D66 puede cerrarse por su parte.

## Anexo · Re-revisión de los vetos (2026-11-14)

- **Migración:** `supabase/migrations/20261114090515_guide_d69_veto_fixes.sql`, aplicada en `eqtjlafxtrzbjazhhyin`.
- **Tests:** bloque «Veto D69» en `supabase/tests/guide_rls_leaks.sql` (línea 10407).
- **Veredicto: APROBADO.** V1 y V2 cerrados. D69 puede cerrarse.

### V1 · Inundación de almacenamiento: cerrado

- `track_event` suma tres contadores en un solo INSERT … ON CONFLICT y en orden fijo: el del nombre por minuto, `*` por minuto y `*day` con bucket en el inicio del día UTC.
- Descarta el evento si se supera cualquiera de los topes: 300/min por nombre, 1 000/min en total o 20 000/día. El bruto queda en un máximo de unos 1,8 millones de filas en 90 días.
- Prueba: con `*day` sembrado a 19 999, el primer evento se escribe y los dos siguientes se descartan (contador final 20 002, 1 fila escrita).
- La purga borra los contadores por minuto de más de 1 hora y los `*day` de más de 2 días. Probado: conserva hoy y ayer y borra el de hace 3 días.
- Señal de salud: la purga hace upsert de `guide.job_health` con `job = 'analytics'`. Devuelve 500 con `alerts: ["daily_cap_reached"]` si hoy o ayer (UTC) se pasó el tope, y 200 si no. `details` solo lleva recuentos y respeta el CHECK de 2 000 bytes. Probado.

### V2 · Reidentificación por hora exacta: cerrado

- `analytics_record` guarda `date_trunc('hour', coalesce(p_at, now()))` en todos los eventos, también en los de `confirm_newsletter`.
- `newsletter_submit`, `review_submitted` y `login_for_review` guardan `source` y `device` a null; `newsletter_confirmed` también sale con null. `page_view` y `newsletter_view` los conservan.
- Datos existentes: la migración trunca y limpia las filas previas. Hay 0 filas sin truncar.
- `analytics_record` y `purge_analytics_events` siguen `INVOKER`, con `search_path = ''` y sin EXECUTE para la API. `track_event` sigue DEFINER con EXECUTE solo para `anon` y `authenticated`.

### `job_health` no expone nada

- RLS activado. GRANT `SELECT` solo para `authenticated`, con policy `(select guide.is_admin())`.
- Pruebas: `anon` 42501; `authenticated` no admin 0 filas; `admin_news_summary` y `admin_dashboard_stats` como no admin 42501.
- Solo la purga (pg_cron como `postgres`) escribe la fila `analytics`.

### `public` sin tocar

- La migración no referencia `public.`, `on schema` ni `alter default`. `public` sigue con 7 tablas, todas con RLS, y 19 policies.

### Riesgos aceptados que se mantienen

- Una inundación puede agotar el tope diario y tapar los eventos reales del resto del día; queda señalado en `job_health`. El recuento propio orienta y no sirve de base de liquidación.
- Elegir una sola fuente para `newsletter_confirmed` antes de F4.6 (webhook de Brevo), con revisión de leona-lia.

### Fuera de alcance

- Tres migraciones F8 del 2026-11-14 (`guide_f86_veto_fixes`, `guide_f8_sources_root_domain`, `guide_f8_backend_gaps`) no se revisaron aquí.
