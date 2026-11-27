# D87 · Revisión de seguridad del registro de consentimientos de cookies

Revisora: leona-lia (informe dictado, sin herramienta de escritura; guardado por el orquestador). Fecha: 2026-11-19. Migración: `20261119172728_guide_d87_cookie_consent_log` (proyecto `eqtjlafxtrzbjazhhyin`, schema `guide`). Origen del diseño: `docs/security/D86-cookie-consent-front-review.md`, pregunta 6.

## Veredicto

**APROBADO.** No hay fugas ni vías de reidentificación, y `public` no cambia. Las observaciones no bloquean este cambio. O1 es condición **antes de activar** Google Ads o Meta en producción.

## Qué se ha comprobado

### Estructura y permisos (en la base de datos)

- `guide.cookie_consent_log` y `guide.cookie_consent_rate`:
  - RLS activada y 0 policies.
  - Ningún GRANT a `anon`, `authenticated` ni `public`.
  - La secuencia de `id` también está revocada.
- Columnas del registro: `id, consent_id, action, categories, revision, locale, created_at`. No hay IP, user agent, `user_id`, path ni referrer. `log_cookie_consent` no lee `request.headers`.
- CHECK de la tabla, todos con expresiones puras:
  - `action` solo puede valer `first` o `change`;
  - `categories` es un subconjunto de `{analytics, ads}`, sin nulos y con 2 elementos como máximo;
  - `revision` va de 0 a 100000;
  - `created_at` está truncado al minuto.
- `log_cookie_consent(uuid, text, text[], integer, text)`:
  - SECURITY DEFINER con `search_path=''`;
  - ACL: `postgres`, `anon` y `authenticated`;
  - no está concedida a `public` ni a `service_role`.
- `admin_cookie_consent_lookup(uuid)` y `admin_cookie_consent_counts(date, date)`:
  - SECURITY DEFINER con `search_path=''`;
  - `perform guide.assert_admin()` es su primera sentencia;
  - ACL: `postgres` y `authenticated`.
- `purge_cookie_consent_log()`:
  - SECURITY INVOKER con `search_path=''`;
  - ACL: solo `postgres`.
- Cron `guide-cookie-consent-purge`: `50 * * * *`, activo, se ejecuta como `postgres`. Borra el registro de más de 36 meses, los contadores por minuto de más de 1 hora y los contadores por día de más de 2 días.

### Copia del repositorio frente a lo aplicado

- El `prosrc` de las cuatro funciones aplicadas coincide con `supabase/migrations/20261119172728_guide_d87_cookie_consent_log.sql`, comentarios internos incluidos.
- La diferencia que declara jabali-javi (2 comentarios) queda fuera del cuerpo de las funciones.

### `public` intacto

Las sentencias registradas en `supabase_migrations.schema_migrations` para esta versión no mencionan `public.` en ningún momento. El único GRANT que contienen es sobre `guide.log_cookie_consent`.

### Pruebas de fuga (transacción con ROLLBACK)

| Prueba | anon | authenticated no admin |
| --- | --- | --- |
| SELECT en `cookie_consent_log` y `cookie_consent_rate` | 42501 | 42501 |
| INSERT, UPDATE y DELETE directos | 42501 | 42501 |
| `admin_cookie_consent_lookup` y `admin_cookie_consent_counts` | 42501 | 42501 |
| `purge_cookie_consent_log` | 42501 | 42501 |

Comportamiento de `log_cookie_consent` (llamada como anon):

| Entrada | Resultado |
| --- | --- |
| Categoría desconocida (`marketing`) | No escribe, no falla |
| Acción desconocida | No escribe, no falla |
| Locale `fr` | No escribe, no falla |
| Categoría `null` | No escribe, no falla |
| Array con una categoría repetida (4 elementos) | No escribe: lo corta el tope de `cardinality > 3`. Es correcto; el cliente nunca repite |
| Válida, `{necessary, ads, analytics}` | Escribe `{ads, analytics}`, ordenado y sin `necessary` |
| Válida, `{necessary}` | Escribe `{}`, es decir, un rechazo |
| 12 llamadas con el mismo `consent_id` en el día | Escribe 10 filas: el tope por id funciona |

Con el JWT de un admin, el lookup devuelve el historial en orden cronológico y `counts` devuelve los recuentos agregados.

### Reidentificación

- `consent_id` es un UUID aleatorio generado en el navegador. Solo se liga a una persona si ella aporta su cookie, que es justo el caso en que hace falta probar el consentimiento.
- El registro se puede cruzar con `analytics_events` (hora truncada, sin identificador) y con `subscribers` (sin `consent_id`). Ninguno de los dos tiene una clave común con el registro ni datos con los que reidentificar a nadie.
- La precisión al minuto con poco tráfico solo es visible para el superadmin, por RPC.
- `counts` solo devuelve agregados por revisión, acción, categorías y locale.

### Topes

- 120 por minuto y 5.000 por día UTC en total, más 10 por `consent_id` y día.
- Con el tráfico previsto (miles de visitas al mes, y elecciones solo en la primera visita, en los cambios y en las subidas de revisión) quedan muy holgados para el uso legítimo.
- También limitan el almacenamiento: como máximo unos 5,5 millones de filas en 36 meses.
- Los contadores se escriben en orden fijo (`*` y después `*day`), así que no hay interbloqueos.
- Un fallo de inserción se traga sin error y el banner no se rompe.

## Observaciones

- **O1 · Agotamiento del tope sin aviso (condición antes de activar Ads o Meta).**
  - Problema: el tope es global y sin identificador de cliente, así que con la clave publishable un atacante agota el cupo diario en unos 42 minutos (120 por minuto). Desde ese momento no se registran consentimientos reales hasta las 00:00 UTC, y nadie se entera.
  - Es pérdida de prueba, no fuga de datos.
  - Corrección: que `job_health` (o la comprobación horaria de la purga) marque una alerta cuando `cookie_consent_rate` con `name='*day'` llegue a `c_day` en el día actual, o cuando `*` llegue a `c_minute` más de N veces en una hora. Debe verse en el panel.
  - Opcional: limitar por IP en el borde si se canaliza por la ruta Nitro (osset-op), sin guardar la IP.
- **O2 · Naturaleza de la prueba.**
  - El registro recoge lo que declara el cliente. Prueba qué se eligió, con qué revisión y cuándo, pero no impide que alguien registre elecciones falsas para UUIDs inventados.
  - Esas filas falsas no afectan a ninguna persona real (su `consent_id` es secreto). Solo meten ruido en los recuentos agregados.
  - La prueba completa es este registro más el archivo versionado de cada `revision` del banner (textos, configuración y capturas), que sigue siendo obligatorio.
- **O3 · Contrato con el cliente.** El front debe enviar las categorías de `cmp.getCookie().categories`, que vienen sin repetir. Un array con repeticiones de más de 3 elementos se descarta en silencio. Es correcto, pero conviene que coneja-lucky lo sepa.
- **O4 · Textos legales (loro-lola).** Añadir a `/privacidad` (es y en):
  - el tratamiento «registro de tus elecciones de cookies»;
  - base legal: obligación de acreditar el consentimiento (art. 6.1.c RGPD en relación con el art. 7.1);
  - datos: identificador aleatorio de la elección, categorías, versión del aviso, idioma y fecha al minuto;
  - sin IP ni navegador;
  - conservación: 36 meses.
- **O5 · Front pendiente de revisión.** La llamada desde `onFirstConsent` y `onChange` en `app/composables/useConsent.ts` debe cumplir esto:
  - no bloquear y tragarse los errores;
  - no ejecutarse en `/administrador`;
  - enviar `CONSENT_REVISION` y el `consentId` de la librería, nunca un id propio persistente.

  leona-lia lo revisa cuando esté implementado.
- **O6 · Advisors.** `get_advisors` incluirá `rls_enabled_no_policy` (INFO) para las dos tablas, y `log_cookie_consent` en los avisos de SECURITY DEFINER ejecutable por anon. Los dos avisos son intencionados y se aceptan.

## Condiciones de activación (se suman a las de D86)

1. O1 implementado y probado: una alerta visible en el panel cuando se agota el tope.
2. O5 revisado por leona-lia.
3. O4 publicado.

## Anexo · O5 (front) y O1 (alerta de tope) · 2026-11-19

Revisora: leona-lia. Revisión estática del front y pruebas en la base de datos con transacciones revertidas.

### Veredicto

- **O1: cerrada. APROBADO.**
- **O5: VETADO** por el punto V-O5-1. Las demás condiciones de O5 y la O3 se cumplen.

### O5 · Front de `log_cookie_consent`

Archivos: `app/services/consent-log.ts` y `app/composables/useConsent.ts` (`logChoice`, `onFirstConsent`, `onChange`).

Condiciones que se cumplen:

1. **No bloquea y no rompe el banner.** `void logCookieConsent(...)` con `try/catch` que se traga los errores.
2. **No en el panel.** `logChoice` corta con `isAdminPath(window.location.pathname)`, y el CMP nunca arranca en `/administrador`.
3. **Ids correctos.** `consentId` de `cmp.getCookie()` (nunca uno propio) y `CONSENT_REVISION`. Locale `es` o `en`. Sin `consentId` no se envía nada.
4. **O3.** `categories` sale de `cmp.getCookie().categories`, sin repeticiones y con 3 elementos como máximo.
5. Una sola llamada por acción: en una primera elección se dispara `onFirstConsent` y no `onChange`; en un cambio, solo `onChange`; `onConsent` no registra nada. Pendiente la comprobación en el navegador.
6. No depende de `NUXT_PUBLIC_ANALYTICS_ENABLED`: acreditar el consentimiento es una obligación legal.

**V-O5-1 · La retirada no se registra (veto).**

- **Motivo.** Con `reloadPage: true` (D86 V2), al retirar una categoría aceptada la librería ejecuta `onChange` y acto seguido `location.reload()` en la misma tarea. `logCookieConsent` usa `db.rpc()`, cuyo `fetch` sale después de esperar a `auth.getSession()` y sin `keepalive`, así que la descarga lo cancela. Justo las retiradas quedan sin registro.
- **Corrección.** En `app/services/consent-log.ts`, `fetch` directo con `keepalive: true` a `POST ${NUXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/log_cookie_consent`, con cabeceras `apikey` y `Authorization: Bearer` con la clave publishable, `Content-Type: application/json` y `Content-Profile: guide`, y `.catch(() => {})`. Sin el JWT del usuario, para no ligar la elección a una cuenta. Alternativa más frágil: `reloadPage: false` y recargar desde `onChange` tras esperar al registro.
- **Prueba de cierre.** Aceptar todo, recargar y retirar «Publicidad»: una única `rpc/log_cookie_consent` con `p_action: "change"` que no quede `(canceled)`, y una fila `change` sin `ads` en el lookup del admin.

### O1 · Alerta de agotamiento del tope

Migración `20261119203335_guide_d87_o1_cookie_consent_health`. Solo cambia `guide.purge_cookie_consent_log()`, con la misma firma.

- `prosrc` aplicado idéntico a la copia del repositorio.
- SECURITY INVOKER con `search_path=''`; ACL solo `postgres`; el cron se ejecuta como `postgres`.
- `daily_cap_reached` si el contador de hoy o de ayer (UTC) llega a 5.000; `minute_cap_hits` si en la última hora más de 3 minutos llegan a 120. Upsert en `job_health` con `job='cookie_consent'`: 500 con alertas o 200.
- Prueba revertida: `500` con las dos alertas; `details` solo con topes y recuentos.
- `job_health` sigue solo para el admin: anon 42501, authenticated no admin 0 filas. `public` intacto.
- La alerta llega con hasta 1 hora de retraso, y el panel aún no la muestra: condición de activación.

### Estado de las condiciones de activación de D87

1. O1: backend cerrado. Falta mostrarla en el panel (diseño de buho-pixel, implementación y revisión).
2. O5: **veto abierto** (V-O5-1).
3. O4: texto de `/privacidad` hecho por loro-lola (`[D87]` en `docs/copy/legal-privacidad.md`), pendiente de publicar con el contenido real.
