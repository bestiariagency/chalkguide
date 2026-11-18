# Revisión de seguridad · F6.15b O1 + D51 (datos del autor)

Revisora: leona-lia · 2026-11-05 · Veredicto: **APROBADO** (las dos migraciones; sin vetos; 4 observaciones no bloqueantes)

Proyecto `eqtjlafxtrzbjazhhyin`, schema `guide`. Solo lectura; pruebas en BEGIN…ROLLBACK, sin restos.

## 1. `20261105192307_guide_f615b_o1_import_row_reset_ops.sql` · APROBADO

- Diff contra `20261105190555`: solo la cabecera y dos líneas tras `perform guide.assert_admin();` (`set_config('guide.draft_op','',true)` y `set_config('guide.unpublish_op','',true)`).
- Desplegado: SECURITY INVOKER, `search_path=''`, EXECUTE solo `authenticated` y `postgres` (revoke `public` y `anon`), firma `(text, jsonb, boolean, boolean, uuid)` sin cambios.
- Sin regresión en `admin_import_items`.
- Pruebas: bloque O1 en verde; anon y no admin reciben `insufficient_privilege` en `import_row`.

## 2. `20261105192615_guide_d51_author_settings.sql` · APROBADO

- RLS en `site_settings`: `site_settings_select using (true)`; `site_settings_update` con `is_admin()` en `using` y `with check`; sin INSERT ni DELETE.
- Columnas nuevas públicas (nombre, rol, entradilla, bio, id de foto, `author_stats`): ninguna sensible. Nada sensible expuesto de rebote.
- 9 CHECK y FK `on delete set null` desplegados; índice presente.
- `author_stats_valid`: immutable, INVOKER, `search_path=''`, sin lectura de datos. Rechaza `null`, `{}`, no objetos (incluido `[null]`), claves fuera de lista, `value` no string o vacío, `label_es` no string, `label_en: null`, más de 2 elementos.
- Foto: PT422 sin `alt_en`; `media_is_public` solo añade `author_photo_media_id`; anon ve la foto elegida y no ve medios sin alt ni sin usar; al cambiar de foto la anterior deja de ser pública.
- Medio en uso: `media_usage` con `security_invoker` e `is_admin()`; `media_usages` con `role='author'` y sin acceso para anon y no admin; `delete_media` → 23503; vaciar un alt → PT422; DELETE directo deja la columna a NULL.
- `content_media_refs` no se usa: correcto (solo cuerpos Tiptap; igual que el hero, D41).
- Fugas: bloques a–d de D51 en verde, más pruebas extra de anon y no admin. Tras el ROLLBACK no queda nada.
- `public` intacto; `get_advisors` (security) sin avisos nuevos.

## Observaciones (no bloquean)

1. `label_en` acepta `''` y espacios (sin `btrim` ni mínimo). El front debe tratar el vacío como ausente; opcional: `char_length(btrim(e->>'label_en')) between 1 and 60`.
2. La foto del autor es pública en cuanto se elige (sin estado de publicación, como el hero). Ajustes → Autor debe avisarlo.
3. `grant execute` de `author_stats_valid` a `anon` sobra (inocuo, función pura).
4. Patrón previo de D41: un DELETE directo de `guide.media` por el admin deja el objeto de Storage huérfano. No es de seguridad.

## 3. Consentimiento en inglés · recomendación

Opción (a), versión 3 con el mismo texto en español y el inglés aprobado: mantiene `consent_texts` solo de inserción y cada versión como prueba del texto exacto (RGPD art. 7.1). La (b) haría que la v2 signifique dos textos según la fecha de alta. Sin coste antes del despliegue. Decide Xavi.

_Archivo guardado por SúperXavi a partir del informe de leona-lia (no tiene herramienta de escritura)._
