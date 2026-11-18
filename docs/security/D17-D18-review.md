# Revisión de seguridad D17/D18 (leona-lia, 2026-10-08)

Migraciones revisadas (aplicadas en `eqtjlafxtrzbjazhhyin`):
`20261008124416_guide_display_name_short`, `20261008124521_guide_user_reviews_overall_ratelimit`,
`20261008124536_guide_resolers_services`, `20261008124844_guide_item_user_ratings_criterion_min`.

## Veredicto: **APROBADO**

Sin vetos. B1 conviene corregirlo antes de abrir la edición de perfil en el frontend.

## Comprobaciones

- `supabase/tests/guide_rls_leaks.sql` completo (BEGIN…ROLLBACK): `ALL RLS TESTS PASSED`.
- Funciones (owner `postgres`, `search_path=''`):
  - `short_display_name(text)` y `sanitize_display_name(text)`: anon/authenticated reciben 42501.
  - `user_profiles_short_name()`: SECURITY DEFINER, no ejecutable desde la API; justificado porque
    `short_display_name` no es ejecutable por los roles API. Solo toca `NEW`.
  - `submit_user_review` y `get_my_review`: solo authenticated y service_role; anon 42501.
- Sobrecargas: solo `submit_user_review(uuid,integer,jsonb,text,guide.locale)` y `get_my_review(uuid)`.
- Escrituras de un usuario no admin (todas 0 filas o error): UPDATE de su opinión cambiando
  `overall_score`/`status`/`user_id`; UPDATE de opinión ajena; INSERT directo en `user_reviews`
  (42501); UPDATE/DELETE de `user_review_scores`; perfil con `user_id` ajeno (42501); UPDATE de
  `item_categories` o `resolers`.
- Validación de la RPC (22023): `overall` null/0/6/INT_MIN; criterio de otra categoría, inactivo,
  decimal, en texto o con clave no UUID; `p_scores` no objeto o `null`; `body` > 1000; ítem no
  publicado. La sexta opinión nueva en 24 h da PT429 `rate_limited`; editar no cuenta. Una opinión
  oculta sigue `hidden` aunque se edite.
- Vistas: `user_reviews_public` (security_invoker) sin `user_id` ni email; anon solo ve `visible`.
  `export_user_reviews`: anon 42501, authenticated no admin 0 filas. `item_user_ratings`: con 2
  opiniones las medias son null; con 3, `avg_overall` = 3.33 y los criterios con < 3 notas no salen.
- D17 nombre: "Pedro Martínez Ruiz" → "Pedro M." (INSERT y UPDATE); NBSP → "Ana R."; bidi en la
  segunda palabra se descarta; bidi/ancho cero/etiquetas en la primera siguen rechazados por CHECK.
- D18: `services` fuera de la lista o con NULL → 23514; escritura solo admin (RLS).
- `public`: ninguna de las 4 migraciones lo toca (solo `revoke … from public` sobre funciones de
  `guide`); sin migraciones nuevas en `public` desde `20261005052654`; RLS en todas sus tablas.
- `guide`: RLS en todas las tablas. Sin filas con `overall_score` null ni perfiles con '@'.
- Advisors (security): nada nuevo. En `guide` solo los lints 0028/0029 de RPC públicas a propósito;
  el resto es de `public` (Chalk app) y Auth, anterior.

## Respuesta a jabali-javi

1. Trigger y `short_display_name`: correcto.
2. Cambio de N2: aceptable; el CHECK `user_profiles_display_name_safe` sigue de respaldo.
3. Límite de frecuencia: suficiente para el MVP, sin log (ver B2). El lock por usuario impide
   saltarlo en paralelo.
4. Firma, grants y vistas: correcto; el grant nuevo es solo SELECT(`overall_score`) (ver I3).
5. Pies de gato: aceptable; solo por RPC, ítems `shoe` publicados y criterios de `shoe`.
6. `services`: correcto.

## Hallazgos

| # | Severidad | Hallazgo | Corrección sugerida |
|---|---|---|---|
| B1 | Baja | Si `display_name` contiene '@', `short_display_name` devuelve null y el trigger conserva el valor original: por PostgREST un usuario puede guardar "Marta García López@" (salta D17) o un email propio o ajeno, que se publica como `author_name`. La RPC no lo sufre (cae a "Escalador/a"). | Rechazar '@' (23514) en el trigger o en el CHECK de perfil y de `author_name`; añadir el caso a `guide_rls_leaks.sql`. |
| B2 | Baja (aceptado MVP) | El límite cuenta opiniones vivas: publicar → borrar → publicar en bucle, máx. 5 vivas/24 h; no frena multicuenta. | Si hay abuso: contar intentos en tabla append-only y avisar en el panel. |
| I1 | Info | El umbral de `avg_by_criterion` es cosmético: las notas por criterio de opiniones visibles son públicas por diseño. | Ninguna. |
| I2 | Info | `user_reviews_public` expone `status`; anon solo ve `visible`. | Ninguna. |
| I3 | Info | `authenticated` tiene UPDATE de tabla en `user_reviews` (para moderar) y hereda `overall_score`; la RLS lo limita al admin (verificado). | Opcional: grant de columna (`status`, `moderated_at`). |

## Apéndice · Re-revisión de `20261008125749_guide_display_name_no_at_reviews_column_grant` (leona-lia, 2026-10-08)

**Veredicto: APROBADO.** B1 e I3 cerrados; sin vetos.

- B1: INSERT/UPDATE de perfil con `@`, `＠`, `﹫` o `@` + combinante → 23514; CHECKs `*_no_at` presentes.
- I3: `authenticated` conserva DELETE de tabla y UPDATE (`status`, `moderated_at`). Usuario normal:
  42501 al cambiar `body`/`overall_score`/`author_name`; 0 filas al cambiar `status`; 42501 en
  `moderate_user_review`. El admin modera y queda en `activity_log`.
- RPC `submit_user_review`: crea y reedita (mismo id); límite, H1 y H4 siguen pasando.
- `guide_rls_leaks.sql` completo: `ALL RLS TESTS PASSED`. `public` sin tocar. Advisors sin novedades.

| # | Severidad | Hallazgo | Corrección sugerida |
|---|---|---|---|
| B1-bis | Baja | El trigger hace `coalesce(short_display_name(x), x)`: si devuelve null se guarda el texto tal cual ("M 612345678", "pepe(at)gmail.com"). No salta D17 con un nombre completo. | Rechazar con 23514 cuando `short_display_name` devuelva null; añadir casos al test. |

## Apéndice 2 · `20261008130540_guide_display_name_reject_unshortenable` (leona-lia, 2026-10-08)

**Veredicto: APROBADO.** B1-bis cerrado; sin vetos. Lo desplegado coincide con el archivo.

- El trigger lanza 23514 si `short_display_name` da null (INSERT y UPDATE OF display_name).
- Bypass rechazados: dígitos no ASCII (`６１２`, `𝟔𝟏𝟐`, `٠١٢`, `ⅿⅰⅹ`, `²`, `①`), puntos raros
  (`．`, `。`, `﹒`, `‧`, `∙`), bidi/ZWJ/ZWSP, `@`/`＠`/`﹫` (también con homógrafos), vacíos y una letra.
- La RPC cae a "Escalador/a" con nombres de Google raros; nombres reales en varios alfabetos pasan.
- `guide_rls_leaks.sql`: `ALL RLS TESTS PASSED`. Advisors sin novedades. `public` intacto.

Residuales de severidad baja (aceptados):
1. `/`, `-` y `·` dentro de la primera palabra permiten `Pepe-Gmail-Com` escrito por el propio usuario.
   Endurecible si hace falta (permitir `/` solo en "Escalador/a").
2. Usabilidad: nombres con marcas combinantes no componibles (devanagari) o CJK de un carácter caen a
   "Escalador/a" o dan 23514 al editar el perfil. Cuando exista la edición de perfil en el frontend,
   mapear ese 23514 a un mensaje claro (coneja-lucky + loro-lola).
