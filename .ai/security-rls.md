# Seguridad y RLS · ChalkGuide

Cliente hostil: la publishable/anon key es pública. **RLS es la única fuente de verdad de permisos.**
Proyecto `eqtjlafxtrzbjazhhyin`, schema `guide`. `public` (Chalk app) no se modifica.

## Matriz de permisos esperada

| Tabla | anon | authenticated (no admin) | admin |
| --- | --- | --- | --- |
| items, gyms, resolers, shoes, criteria | SELECT solo `published` | igual que anon | todo |
| author_reviews | SELECT de ítems publicados | igual que anon | todo |
| user_reviews | SELECT solo visibles (no ocultas) | + INSERT/UPDATE propias (`user_id = auth.uid()`), 1 por ítem, sin tocar estado de moderación | todo (ocultar) |
| subscribers | sin SELECT; alta solo por RPC/`with check` | igual; puede ver/darse de baja de su propia fila si se implementa | todo |
| events | SELECT `approved` y `cancelled` (también pasados); sin columnas de procedencia (`source`, `source_url`, `dedupe_key`, `agent_meta`) | igual que anon | todo |
| gym_waitlist | nada | INSERT/DELETE/SELECT propias | todo |
| articles, article_categories, pages, media, site_settings | SELECT solo publicado/público | igual que anon | todo |
| admins, registro de actividad, page_views | nada (page_views: solo inserción controlada) | nada | SELECT |
| Storage `media` | lectura | lectura | subir/reemplazar/borrar |

Superadmin único: solo los `user_id` de `guide.admins`. Iniciar sesión (Google o email) **nunca**
da permisos de admin por sí solo.

## Checklist

- RLS activado en toda tabla de `guide`; ninguna sin policies por accidente.
- Policy por operación y rol; nada de `using (true)` salvo lectura de contenido publicado.
- `with check` en todo INSERT/UPDATE: el usuario no puede escribir `user_id` ajeno, estado de
  moderación, `published`, `visit_type` ni columnas internas.
- `guide.is_admin()` SECURITY DEFINER, `search_path` fijado, sin recursión.
- Funciones SECURITY DEFINER: `search_path` fijado, validación de entradas, `revoke execute from public`
  y grant solo al rol que corresponde.
- GRANTs mínimos en schema `guide`; nada concedido sobre `public` desde trabajo de ChalkGuide.
- Secretos (`service_role`, Claude, Brevo/Resend) fuera del cliente: solo `NUXT_PUBLIC_SUPABASE_URL`
  y `NUXT_PUBLIC_SUPABASE_KEY` (publishable) son públicas.
- Edge Functions: verifican JWT o secreto de cron; no aceptan escritura arbitraria.
- Triggers que solo validan para roles sujetos a RLS (`rolbypassrls`, p. ej. `content_drafts_before_write`):
  ninguna función SECURITY DEFINER propiedad de postgres debe escribir en esas tablas, o se saltaría
  la validación en silencio (D23, O6). Tampoco una que solo ponga `updated_by` a null en `content_drafts`:
  pasaría por el atajo de cascada y borraría la autoría sin rastro (D24, obs. 4).
  - **Excepción única a O6** (F6.5, obs. 1): `guide.delete_article_category` (DEFINER) reescribe en
    `content_drafts` la categoría de los borradores que apuntan a la que se borra. Condiciones, que no
    se amplían a otras funciones sin nueva revisión de leona-lia: `perform guide.assert_admin()` es su
    primera sentencia; el UPDATE solo hace `SET payload` (con `jsonb_set` sobre `{article,category_id}`),
    nunca `base_updated_at`, `updated_by`, `created_at` ni el destino. `content_drafts_before_write`
    sigue validando el payload; `updated_by` lo fija ese trigger a `auth.uid()` del admin que borra
    (nunca null). Lo comprueba `supabase/tests/guide_rls_leaks.sql` (F6.5, paso 5d).
- GUC `guide.draft_op` con exenciones: siempre atada a la fila (`apply:<article_id>`,
  `reassign_category:<category_id>` comprobado contra `old.category_id`,
  `detach_author:<author_id>` comprobado contra `old.author_id` y solo `author_id` pasa a NULL);
  nunca un valor genérico.
- Los CHECK de las tablas de `guide` son expresiones puras (sin funciones que lean datos, y menos
  DEFINER): `draft_check_payload` los evalúa con la fila guardada + el parche de quien llama (F6.8, O1).
  Un CHECK nuevo que llame a una función necesita revisión de leona-lia.
- RGPD: consentimiento con fecha y origen; emails de suscriptores nunca legibles por `anon`/`authenticated`.
- `get_advisors` (security) sin avisos nuevos.

## Pruebas de fuga

En transacción con `ROLLBACK`, simulando rol (`set local role anon` / `authenticated` +
`set local request.jwt.claims`):
- anon: leer `subscribers`, borradores (`published = false`, `events` draft, opiniones ocultas),
  UPDATE/DELETE de cualquier fila → 0 filas o error.
- authenticated no admin: mismo resultado + no puede editar opiniones ajenas, ni crear una segunda
  opinión del mismo ítem, ni cambiar su estado de moderación.

## Veredicto

**APROBADO**, o **VETADO** + motivo + corrección sugerida. Con veto abierto la tarea no se cierra.
