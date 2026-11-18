# Backend · ChalkGuide (Supabase)

## Proyecto y aislamiento

- Proyecto **`eqtjlafxtrzbjazhhyin`**, solo vía `mcp__supabase_chalk__*`. Nunca otro servidor MCP
  de Supabase (`supabase_bigoti`, `claude_ai_Supabase`, etc.).
- Todo lo de ChalkGuide vive en el **schema `guide`**.
- **`public` pertenece a Chalk app** (`gyms`, `profiles`, `messages`, `availability`,
  `subscriptions`, `admin_roles`, `app_config`): prohibido crear, alterar, borrar o cambiar
  policies/GRANTs ahí. Leerlo es aceptable para inspeccionar; cualquier dependencia nueva hacia
  `public` (FK, vista, función) requiere aprobación de Xavi.
- Hallazgos en `public` o en Auth que afecten a Chalk app: **no se corrigen aquí**. Se anotan en
  `docs/chalk-app-pendientes.md` para llevarlos a ese proyecto.
- Usuarios: se referencia `auth.users(id)`. Datos de perfil propios de la guía, en `guide`.
- El schema `guide` debe estar en **Exposed schemas** de la API (Settings → API) y con
  `grant usage on schema guide to anon, authenticated`. Si no está expuesto, avisa a Xavi.

## Contenido y administración

- **Todo el contenido vive en `guide`**: artículos, categorías, páginas (Sobre mí, legales), fichas,
  agenda, medios y ajustes. El modelo detallado y su estado están en `docs/PLAN.md` (F2).
- Un único **superadmin** (Xavi) en `guide.admins`; `guide.is_admin()` decide todo acceso de escritura.
- Imágenes en Storage, bucket `media`: lectura pública, escritura/borrado solo admin; metadatos en
  `guide.media`. Borrar un medio en uso debe impedirse o avisarse.
- Ordenación manual (categorías, artículos dentro de categoría) con columna `sort_order`.
- Exportaciones y estadísticas del panel: preferir vistas/RPC de solo lectura para admin.

## Modelo (del plan)

Modelo genérico: `guide.items` es la base de todo lo evaluable (`category`, `name`, `slug`,
`summary`, `published`, `verified_at`, `source`). Detalle 1:1 por categoría: `guide.gyms`,
`guide.resolers`, `guide.shoes`. Además: `criteria` (por categoría, con orden), `author_reviews`
(nota por criterio, fecha de visita, `visit_type` pagada/invitada), `user_reviews` (una por usuario
e ítem, editable, estado de moderación), `subscribers` (email, consentimiento, fecha y origen,
idioma), `events` (borrador/aprobado), `gym_waitlist` (Fase 3).

Sumar una categoría nueva (cuerdas, arneses, sectores) debe ser configuración, no reconstrucción.
Puntajes derivados (índice principiante, precio a 2 visitas/semana, familia) se calculan
(vista o función), no se guardan como opinión. Contenido bilingüe: decidir columnas `_es`/`_en` o
tabla de traducciones en el primer diseño y mantenerlo consistente.

## Reglas

- Inspecciona primero (`list_tables` con `schemas: ['guide']`, `list_migrations`).
- Migraciones **idempotentes** vía `apply_migration`, con copia en `supabase/migrations/`
  (`<timestamp>_<nombre>.sql`).
- **RLS activado en toda tabla**, policy explícita por operación y rol. Detalle en `.ai/security-rls.md`.
- Admin: `guide.is_admin()` SECURITY DEFINER, `set search_path = ''`, sin recursión. Fuente del rol
  admin dentro de `guide` (no reutilizar `public.admin_roles` sin aprobación).
- Escrituras públicas sensibles (alta de newsletter) vía RPC SECURITY DEFINER validada o `with check`
  estricto; nunca expongas columnas internas.
- `service_role` y API keys (Claude, Brevo/Resend) solo en Edge Functions vía `supabase secrets`.
- Tras cambios de esquema: `get_advisors` (security y performance) y **regenerar tipos**. El
  `generate_typescript_types` del MCP solo emite `public`, así que los de `guide` se generan con
  `scripts/guide-types-meta.sql` (ejecutarlo con `execute_sql` y guardar el resultado) y
  `node scripts/gen-guide-types.mjs <resultado> app/types/database.types.ts`, y luego `npm run typecheck`.
- `execute_sql` para lecturas e inspección; nada destructivo sin confirmación de Xavi.
