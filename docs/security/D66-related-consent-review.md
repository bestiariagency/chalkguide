# D66 Consentimiento de comunicaciones afines · revisión de seguridad (leona-lia)

Fecha: 2026-11-12 · Proyecto `eqtjlafxtrzbjazhhyin`, schema `guide` · Decisión D66.
(Informe dictado por leona-lia, sin herramienta de escritura; guardado por el orquestador.)

## Alcance

Migraciones `20261112223800_guide_d66_related_consent_schema`, `20261112223927_guide_d66_related_consent_triggers`,
`20261112224206_guide_d66_related_consent_rpc`, `20261112224927_guide_d66_related_consent_log_fix`; bloque D66 de
`supabase/tests/guide_rls_leaks.sql` (l. 9091-9463); `docs/copy/consentimiento-comunicaciones-afines.md`.
Pruebas propias en dos bloques DO (unas 60 comprobaciones), terminados en excepción forzada (rollback). La tabla
`subscribers` tenía 0 filas reales antes y después. La suite completa no se ha ejecutado.

## Resultados

- **anon:** SELECT de `subscribers`, `subscriber_consent_events` y `consent_texts`, UPDATE de `site_settings`,
  `subscriber_by_token` y `admin_list_subscribers` → 42501. `subscribe_newsletter` con `p_consent=false` → 22023.
  `get_consent_preferences` con token inválido → null. `set_related_consent` con token inexistente → `invalid`;
  con `'link'` + dar, o con un canal fuera de lista → 22023.
- **Compatibilidad del front:** la llamada con 5 argumentos con nombre (`app/services/newsletter.ts`) funciona y deja
  afines en `none`. Con la casilla: `pending`, origen y versión 1.
- **Flujo:** con afines `pending`, dar → `unconfirmed`. El doble opt-in pasa newsletter a `active` y afines a `granted`.
  Retirar con `'link'` → `withdrawn`. Volver a dar desde preferencias → `granted` (origen `preferences`, versión
  vigente). La baja de la newsletter no toca afines. Una re-suscripción sin la casilla conserva un `granted` y no lo
  re-sella. El historial por finalidad es correcto y lleva página solo en las altas desde formulario.
- **Caducidad:** el alta caducada descarta el afines `pending` (evento `expire/timeout`, actor `service`).
- **Retención:** `granted` → nunca se anonimiza. Baja + retirada hace 1 año → retirada + 3 años. Newsletter activa
  con afines retirado → no se anonimiza (ver O4).
- **authenticated no admin:** lecturas → 0 filas. UPDATE de `site_settings` → 0 filas: la policy `site_settings_update`
  exige `is_admin()`, lo que cubre el riesgo (c). Escrituras en `subscribers`, `consent_texts` y `consent_events` →
  42501. `admin_get_subscriber`, `admin_timeseries` y `export_subscribers` → 42501. Iniciar sesión no da afines
  (queda `none`) y no hay vía sin token.
- **admin:** sin escritura directa ni `select *` (42501). Cambiar el texto sin subir versión, o bajar la versión →
  22023. Subir la versión cierra la v1 y abre la v2 solo para `related_products`; la newsletter no cambia. La ficha no
  incluye `token`, `user_id` ni `brevo_contact`, y trae `related_consent_texts`. La supresión de una fila con afines
  `granted` funciona.
- **`get_consent_preferences`:** devuelve solo `newsletter`, `related_products`, `can_grant_related` y `locale`. Sin
  email ni fechas, y null con el token de una fila suprimida. Sin fuga.
- **DEFINER:** todas con `search_path=""` y propiedad de postgres. Los helpers (`subscriber_by_token`,
  `subscriber_anonymize_at`, `subscribers_related_guard`, `expire_pending_subscribers`) solo tienen EXECUTE de
  postgres. `admin_timeseries` sigue como INVOKER (ya lo era) bajo la RLS de admin.
- **`public`:** no se toca. Ninguna referencia en las migraciones D66.
- **`get_advisors` (security):** los únicos avisos nuevos son DEFINER intencionados para anon/authenticated
  (`set_related_consent`, `get_consent_preferences`, `subscribe_newsletter`, con firma nueva). Los avisos de `public`
  son anteriores y pertenecen a Chalk app.

## Vetos

1. **V1 · Rotación del token rompe la retirada en un clic.** `subscribe_newsletter` hace
   `unsubscribe_token = gen_random_uuid()` en toda re-suscripción. Hoy una fila puede tener la newsletter dada de baja
   y afines `granted`, y esa persona recibe emails de afines con su token. Un tercero anónimo que re-suscriba el email
   rota el token, y el enlace de baja de los emails ya enviados devuelve `invalid` (probado). Puede repetirlo cada
   24 h. Así se rompe la retirada «tan fácil como darlo» (art. 7.3 RGPD) y el medio de oposición de cada envío
   (art. 22 LSSI).
   **Corrección:** en el `on conflict`,
   `unsubscribe_token = case when guide.subscribers.related_status = 'granted' then guide.subscribers.unsubscribe_token else gen_random_uuid() end`.
   Añadir a la suite: re-suscripción de una fila `unsubscribed` + `granted`; el token antiguo sigue retirando.
2. **V2 · Guardas de la suite.** Los DO de la l. 9361 (`expire_pending_subscribers()`) y de la l. 9448 (subida de
   `related_consent_version`, que deja un texto en `consent_texts`, append-only) no repiten la comprobación
   `guide.rls_suite = 'running'` como primera sentencia, como exige el cierre de F6.14 V1. Si se pegan como
   fragmento, anonimizan filas reales o publican un texto legal falso.
   **Corrección:** añadir el `if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then raise ...`
   al inicio de ambos DO.

## Observaciones y condiciones

1. **(a) Dar con `unsubscribe_token`** y **(b) token de confirmación válido 48 h:** aceptables. Tener el token prueba
   el acceso al buzón, igual que el doble opt-in. Condiciones para el front: la página de preferencias solo da con un
   clic explícito del usuario (POST a la RPC), nunca al cargar ni por GET, porque los escáneres de enlaces del correo
   abren las URL. Además, `noindex` y `Referrer-Policy: no-referrer` en las páginas con token en la URL.
2. **Email de confirmación (F4.6):** si afines está `pending`, el email de doble opt-in debe nombrar las dos
   finalidades. Si no, el clic confirmaría un consentimiento sin informar. Probado: un tercero puede marcar la casilla
   sobre un email dado de baja y el clic del titular la activa. Esto es aceptable solo si el email lo explica.
3. **Supresión con afines vigente:** `subscriber_anonymize` deja `related_status='granted'` en la fila suprimida
   (sin email). La audiencia de afines de F4.6 debe filtrar `status <> 'erased' and email is not null`. Alternativa:
   normalizar los campos `related_*` al anonimizar (exige revisar el guard).
4. **(d) Retención:** con la newsletter activa, la prueba de la retirada de afines se conserva mientras dure la
   suscripción. Es aceptable, porque el email ya se guarda por la newsletter. Pero el texto de privacidad dice
   «3 años». Ajuste para loro-lola: «durante 3 años desde la retirada o, si sigues suscrito a la newsletter, mientras
   dure la suscripción y 3 años más».
5. **(e) El admin no puede retirar afines:** quien lo pide por email solo puede ser suprimido, lo que también le da de
   baja de la newsletter: es desproporcionado. Condición antes del primer envío de afines: RPC
   `admin_withdraw_related(p_id, p_reason)` con `assert_admin()` y `related_withdraw_source = 'admin'` (ampliar el
   check).
6. **(f) EXECUTE de `service_role` en `subscribe_newsletter`:** es nuevo frente a F6.14 O4 (solo anon/authenticated)
   y va contra O3. Revocarlo; puede ir en la migración de V1.
7. **Formulario con la casilla para un suscriptor activo:** no cambia nada, sin error ni registro. Es la dirección
   segura, pero el front debe remitir al centro de preferencias.
8. Un afines `pending` cuya newsletter se da de baja antes de confirmar queda `pending` sin salida. Es inocuo: nunca
   recibe envíos y se anonimiza con la baja.
9. **Condiciones de entrada de F4.6 que siguen abiertas:** O2a (token en claro solo desde servidor), O2b (borrar o
   encolar en Brevo antes de anonimizar), O3 (recortar los grants de `service_role`), O5 (rate limit o captcha en el
   alta). Además: segmento o lista de Brevo separado para afines, alimentado solo desde `related_status='granted'`,
   y las bajas de Brevo vuelven como `withdraw_source='brevo'`.

## Respuestas §5 (preguntas para leona-lia)

1. **Base 6.1.a:** válida. El consentimiento es libre (opcional e independiente de la newsletter), específico,
   informado (texto ampliado con responsable, contenido, retirada y base) e inequívoco (casilla desmarcada). La
   finalidad es lo bastante concreta: avisos de un responsable identificado sobre productos propios de una temática
   cerrada (escalada). Recomendación: usar «productos propios» también en la casilla, en vez de «productos de
   ChalkGuide», para que coincida con el texto ampliado.
2. **Lista de productos:** basta con la categoría, siempre que el responsable sea el mismo y la temática, la escalada.
   Nombrar cada producto nuevo en la política de privacidad cuando exista. Un producto fuera de la temática exige
   nueva versión del texto y nuevo consentimiento.
3. **Casilla tras el doble opt-in:** permitida. Condiciones: la newsletter ya está confirmada sea cual sea la
   respuesta, la casilla va desmarcada, sin incentivo ni «recomendado», y el «no, gracias» tiene la misma
   prominencia.
4. **Plazo:** 3 años desde la retirada, en línea con la prescripción de infracciones de la LOPDGDD (art. 72) y con
   D35. Ver O4 para el caso de la newsletter activa.
5. **Chalk app enviando por su cuenta:** cubierto solo mientras el responsable sea el mismo (Xavier Pilasi, persona
   física) y el envío use encargados con contrato (Brevo u otro). Chalk app debe leer el estado de
   `guide.subscribers.related_status` como única fuente. Si Chalk app pasa a otra entidad (p. ej. una SL), es otro
   responsable: haría falta un consentimiento nuevo y la casilla de terceros de la «Nota para el futuro».
6. **Emails de servicio de Chalk app:** quedan fuera (art. 6.1.b), siempre que sean transaccionales y pedidos por el
   usuario, sin contenido promocional mezclado.
7. **RPC:** entradas validadas (token, canal, booleano), sin fechas ni versión desde el cliente y sin IP ni
   user-agent. Sin rate limit en `set_related_consent` y `get_consent_preferences`: aceptable, porque el token es
   imposible de adivinar (UUID v4 o hash de 256 bits). El rate limit del alta sigue pendiente (O5).

## Veredicto

**VETADO por V1 y V2.** El resto (RLS, grants, triggers, RPC, versionado, retención, exportación, `public`) queda
APROBADO. Se cierra con la migración de V1 (y la revocación de O6) y la guarda de V2, revisadas por leona-lia.
Pendiente: que Xavi ejecute la suite completa (`ALL RLS TESTS PASSED`).

## Re-revisión tras vetos (2026-11-13, leona-lia)

Alcance: `supabase/migrations/20261112230518_guide_d66_veto_fixes.sql` (aplicada) y bloque D66 de `supabase/tests/guide_rls_leaks.sql` (l. 9095-9615). Pruebas propias en un bloque DO con unas 25 comprobaciones, terminado en excepción forzada (rollback). La tabla `subscribers` tiene 0 filas antes y después.

- **V1 · cerrado.** Una fila con la newsletter dada de baja y afines `granted` conserva el `unsubscribe_token` cuando un anónimo la re-suscribe. El enlace antiguo retira afines (`ok`, origen `link`). Con afines `pending` o `none`, el token rota. Es aceptable: un `pending` nunca recibe envíos.
- **V2 · cerrado.** La guarda `guide.rls_suite` abre los DO de `expire_pending_subscribers()` (l. 9433), del versionado (l. 9600) y todos los DO nuevos (R6-R8, O5, O3).
- **O5 · `admin_withdraw_related`.** Es DEFINER, con `search_path=""` y propiedad de postgres. EXECUTE solo para postgres y authenticated. Resultado 42501 para anon, para un usuario no admin (también con motivo nulo o un id inexistente, porque `assert_admin` va antes de validar y no revela si la fila existe), para un JWT con `role: service_role` falsificado y para el rol `service_role`. Como admin: motivo fuera de lista → 22023; segunda retirada → 22023; la newsletter no cambia; el evento queda con `purpose=related_products`, `source=admin`, `actor=admin` y el motivo.
- **CHECK ampliado (`admin`, `erase`).** Ninguna vía pública permite falsear el origen. `set_related_consent` con canal `admin` o `erase` → 22023, porque solo admite `preferences` y `link`. UPDATE directo de `subscribers` → 42501 para anon, authenticated y admin. `subscriber_anonymize` → 42501 para clientes. Un `guide.consent_reason` fijado por un anónimo no llega al historial (motivo nulo, actor `anon`).
- **O3.** La supresión deja `granted` y `pending` en `withdrawn` con origen `erase`. Ninguna fila suprimida queda vigente, así que la condición de filtro de O3 para F4.6 deja de ser obligatoria. Sigue recomendada.
- **O6.** `subscribe_newsletter` (firma de 6 argumentos) solo es ejecutable por anon y authenticated; `service_role` → 42501. La firma antigua ya no existe.
- **`public`:** no se toca (0 referencias en la migración).
- **`get_advisors` (security):** el único aviso nuevo es `admin_withdraw_related` ejecutable por authenticated, intencionado y protegido por `assert_admin()`. Los avisos de `public` son anteriores y pertenecen a Chalk app.

**Veredicto: APROBADO.** D66 no tiene vetos abiertos. Pendiente: que Xavi ejecute la suite completa (`ALL RLS TESTS PASSED`). Las condiciones de entrada de F4.6 (O1, O2, O4, O7 y O9) siguen vigentes.
