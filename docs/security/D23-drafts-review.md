# Revisión de seguridad D23 · borradores de cambios y registro de exportaciones (leona-lia, 2026-10-09)

Migraciones: `20261009061809_guide_activity_log_drafts_exports`, `20261009062130_guide_content_drafts`.

## Veredicto: **APROBADO** (sin vetos)

- Suite `guide_rls_leaks.sql` completa (incluido bloque D23) y batería propia con un borrador real:
  anon, authenticated no admin, JWT forjado y authenticated sin `sub` no leen borradores (tabla,
  `media_usage`, `activity_log`, vistas), no pueden guardar/publicar/descartar/registrar (42501) ni
  borrar medios; el borrador queda intacto y no se escribe registro.
- Admin: claves fuera de lista blanca (`published`, `published_at`, `category`, `id`, `status`,
  `is_affiliate`…) e intentos de inyección en sección/columna → 22023; destino inmutable;
  `updated_by` no falsificable; `publish_draft` no publica en otra entidad ni cambia
  `published`/`published_at`; conflicto → PT409 salvo `p_force`; medio en borrador no borrable.
- `log_export`: rechaza emails, nombres, claves/vistas/formatos no permitidos; `q` solo booleano.
- SQL dinámico: tablas de un CASE cerrado, columnas de la lista blanca validadas contra catálogo y
  citadas con `%I`, valores como parámetros. Sin vector de inyección.
- La variable de transacción del registro no es manipulable por un no admin.
- Advisors: solo el aviso esperado de `log_export` (DEFINER con check de admin). `public` sin tocar.

## Observaciones (no bloquean)

| # | Severidad | Observación | Corrección sugerida |
|---|---|---|---|
| O1 | Baja | `content_drafts_before_write` valida el payload antes de que la RLS rechace a un no admin (CPU evitable, códigos de error distintos). | `perform guide.assert_admin();` al inicio del trigger. |
| O2 | Info | Por escritura directa el admin puede fijar `base_updated_at` o crear borrador sobre algo no publicado. | En INSERT, forzar `base_updated_at` desde `draft_entity_version` y exigir entidad publicada. |
| O3 | Info · integridad | Cambios directos en notas, galería o `article_items` no cuentan como versión: se pisan al publicar sin 409. | Triggers que actualicen el `updated_at` del padre. |
| O4 | Info | El registro de exportaciones es declarativo (lo llama el cliente). Aceptable con superadmin único. | Documentarlo como "no es auditoría a prueba de manipulación". |

## Apéndice · `20261009074253_guide_drafts_review_fixes` (leona-lia, 2026-10-09)

**Veredicto: APROBADO.** O1–O4 resueltas.

- Suite completa: ALL RLS TESTS PASSED. Anon/authenticated/JWT forjado no alteran tablas hijas ni padres; `touch_draft_parent()` no ejecutable por clientes; `draft_entity_is_live` no revela si algo oculto existe.
- La excepción por `rolbypassrls` no es aprovechable por clientes: `anon`/`authenticated` sin bypass; `set role service_role` → 42501; el trigger mira `current_user`, no claims; ninguna función DEFINER escribe en `content_drafts` ni cambia de rol. Las cascadas de FK (ej. `updated_by` al borrar un usuario) pasan correctamente por la vía del bypass.
- O3 no genera registros en `log_activity`; cascadas correctas. Advisors sin novedades. `public` sin tocar.

| # | Severidad | Observación | Estado |
|---|---|---|---|
| O5 | Info | En la vía del bypass (cascada al borrar un usuario) el trigger revalida el payload: si un borrador antiguo dejara de validar tras un cambio de esquema, borrar ese usuario fallaría. | Pedido a jabali-javi: en UPDATE que solo cambia `updated_by`, devolver `new` sin validar. |
| O6 | Info | Una futura función SECURITY DEFINER propiedad de postgres que escribiera en `content_drafts` se saltaría O1/O2. | Anotado en `.ai/security-rls.md`. |
