# D27 · Texto alternativo obligatorio — revisión de seguridad (leona-lia)

Fecha: 2026-10-16 · Proyecto `eqtjlafxtrzbjazhhyin`
Migraciones: `20261016065315_guide_d27_alt_required.sql` + corrección `20261016085031_guide_d27_unpublish_bypass_role.sql`

## Veredicto: APROBADO

Primera revisión: VETADO por V1. Segunda revisión, tras `20261016085031`: V1 levantado y O1 resuelto. No hay vetos abiertos.

## Comprobado
- **Desplegado = fichero.** Funciones D27, `publish_draft` y los 6 triggers AFTER ROW (`media`: `AFTER UPDATE OF alt_es`). Todas de postgres, invoker, `search_path=''`; ninguna con permisos para anon ni PUBLIC.
- **`publish_draft`.** Solo cambia el bloque D27 (tras aplicar, antes de borrar el borrador). Siguen `assert_admin()` primero, `draft_check_payload`, PT409 salvo `p_force`, `apply:<id>` acotado, invoker, `{postgres, authenticated}`. Con PT422 el borrador se conserva. D23, F6.4 y PT409/PT423 intactas.
- **Exenciones por GUC.** `maintenance` (`alt_guard_bypassed`) exige `rolbypassrls`; admin con `maintenance` o `apply:<id>` → PT422. `unpublish_op` (`alt_unpublish_bypassed`) exige el GUC con el id **y** `rolbypassrls`, combinación que solo se da dentro de `unpublish_article` (DEFINER de postgres); en `articles_require_alt` solo para UPDATE de algo ya publicado o programado.
- **Fuga por `details`.** Un no admin no llega a los triggers (0 filas / 42501); helpers para `authenticated` limitados por RLS; anon 42501. PT422 solo lo ve el admin con ids que ya puede ver.
- **Adversariales de admin bloqueados con PT422:** reseña con imagen sin alt movida a ficha publicada; `item_media` de ficha publicada; OG o ruta pegada en página publicada; "Publicar cambios" de ficha con galería sin alt; portada nueva sin alt por `publish_draft`; alt vacío o invisible.
- **`content_alt_check`.** Invoker, `assert_admin()` primero, `{postgres, authenticated}`.
- `public` sin tocar; advisors sin avisos nuevos; pruebas revertidas sin residuos.

## V1 · RESUELTO (era VETO)
Un admin con `guide.unpublish_op` falsificado podía publicar imágenes sin alt (update directo o `publish_draft`). Corregido con `guide.alt_unpublish_bypassed(p_id)`. Verificado: X1 y X8b → PT422; X1c → PT423; 7b (despublicar con borrador sin alt) funciona sin dejar GUC abiertos y volver a publicar → PT422. Tests en el bloque D27 de `supabase/tests/guide_rls_leaks.sql`.

## O1 · RESUELTO
`alt_is_missing` trata como vacío un alt solo con espacios o invisibles (U+200B, U+200C, U+200D, U+2060, U+FEFF); un texto real que incluya alguno sigue siendo válido.

## Observaciones abiertas (no bloquean)
- **O2.** `site_settings.default_og_media_id` fuera de D27: decisión de Xavi.
- **O3.** Coste aceptable hoy (`media_committed_owners` ~160 ms, solo al vaciar un alt); prefiltrar con `content_media_refs` si crece.
- **O4.** En "Publicar cambios" de una ficha, `details.media_ids` lleva solo la primera imagen que falla: el panel debe llamar a `content_alt_check` antes de publicar.

## D27 ampliado: alt_en en cuerpos EN y OG por defecto (2026-10-16, leona-lia) · APROBADO

Migración: `20261016135244_guide_d27_alt_en_og_default.sql`.

- **Reglas comprobadas como admin:** cuerpo EN de un artículo publicado con `has_en` y un medio sin `alt_en` → PT422 `details.missing=[{media_id, lang:"en"}]`; `site_settings.default_og_media_id` hacia un medio sin `alt_en` → PT422 con `entity:"site_settings"`, `entity_id:null`, `setting_id`; vaciar `alt_en` del medio que es OG por defecto → PT422 con `used_by:[{entity:"site_settings"}]`; `draft_op='maintenance'` falsificado por el admin no salta la guarda.
- **Sin fugas:** guardas y helpers INVOKER con `search_path=''`, sin EXECUTE para anon; `content_alt_check` con `assert_admin`; `entity_alt_missing` y `media_committed_owners` respetan RLS; las guardas solo se disparan en escrituras de admin.
- **`site_settings`:** policies sin cambios (SELECT público, UPDATE solo admin); no admin UPDATE → 0 filas, INSERT → 42501; trigger `site_settings_require_alt` no es DEFINER.
- **Funciones borradas** (`entity_missing_alt`, `raise_missing_alt`, `item_alt_media_ids`, `content_alt_media_ids`, `media_missing_alt`): sin referencias.
- **Datos actuales:** nada publicado incumple; OG por defecto null.
- Advisors sin avisos nuevos atribuibles a D27. `public` sin tocar. Pruebas en BEGIN…ROLLBACK, sin residuos.
