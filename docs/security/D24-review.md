# Revisión de seguridad D24 · última visita, redirecciones de slugs, bloqueo de borrado con opiniones (leona-lia, 2026-10-09)

Migraciones: `20261009075650_guide_d24_seen_redirects_delete_guard`, `20261009075721_guide_drafts_updated_by_cascade` (O5 de D23).

## Veredicto: **APROBADO** (sin vetos)

- Suite completa `guide_rls_leaks.sql` (F2.10 → D24 + O5): pasa.
- Un no admin no cambia slugs ni inserta en tablas con slug: no puede disparar `track_slug_redirects`; no ejecuta el trigger, no borra redirecciones ni fichas.
- `mark_reviews_seen`: solo la fila de quien llama; 42501 para no admin; nadie hace UPDATE directo de `admins`.
- `resolve_redirect` (anon): mismos filtros que la RLS pública (`article_is_live`, `published`, `has_en` en en); null para contenido programado o despublicado; nunca devuelve el propio slug. Enumerar slugs antiguos solo lleva a contenido ya público.
- Atajo O5: solo roles con bypass RLS; un admin por PostgREST sigue fijando `updated_by` con su uid.
- Restrict en `user_reviews_item_fk`: borrar un usuario de Chalk app con opiniones funciona (`user_id` sigue en cascade); el purge del seed borra antes las opiniones dummy.
- `public` sin tocar; RLS en `slug_redirects`. Advisors: solo los avisos previstos de `resolve_redirect` y `mark_reviews_seen`.

## Observaciones (no bloquean)

| # | Severidad | Observación | Estado |
|---|---|---|---|
| 1 | Info | Si un borrador reutiliza un slug antiguo, la redirección desaparece: revela que existe algo con ese slug (ya fue público), nunca su contenido. | Aceptado. |
| 2 | Info | `resolve_redirect` distingue categorías de ficha inactivas (null) de inexistentes (22023). | Opcional: filtrar `is_active`. |
| 3 | Baja · funcional | `ON UPDATE CASCADE` de `slug_redirects_item_fk` podría chocar con la clave única si una ficha cambiara de categoría; hoy imposible por las FK de detalle. | Anotar en `docs/data-model.md`. |
| 4 | Info | Regla O6 extendida: una función DEFINER de postgres que solo ponga `updated_by` a null en `content_drafts` pasaría por el atajo O5. | Anotado en `.ai/security-rls.md`. |
