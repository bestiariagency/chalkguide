-- F6.15 (D36) · Exportar, parte 3 (aplicada 2026-10-29, el front ya usa admin_export). Cierra O1 y O2 de leona-lia.
-- Se aplica cuando el front use guide.admin_export. Hoy (2026-10-29) nada en app/ lee las vistas export_* ni llama a
-- log_export o export_events_rows (comprobado con grep).
-- · O1: nadie puede escribir líneas de exportación con filas declaradas por el cliente. log_export se conserva sin
--   EXECUTE para no perder el historial.
-- · O2: no se puede exportar sin registrar leyendo las vistas por REST. Las vistas y export_events_rows quedan solo
--   para el owner. admin_export/export_build corren como owner y siguen funcionando.
-- Al aplicarla:
--   1. Moverla a supabase/migrations/<timestamp>_guide_f615_retire_log_export.sql (con la versión que dé apply_migration).
--   2. Aplicar a la suite el parche supabase/pending/guide_f615_retire_log_export.suite.diff
--      (patch -p1 desde la raíz del repo) y volver a pasarla.
--   3. Regenerar los tipos (las vistas export_* y export_events_rows dejan de aparecer para authenticated).
-- Idempotente.

revoke all on function guide.log_export(text, text, jsonb, integer) from public, anon, authenticated, service_role;

revoke all on guide.export_articles, guide.export_items, guide.export_user_reviews, guide.export_events,
              guide.export_subscribers from public, anon, authenticated;

revoke all on function guide.export_events_rows() from public, anon, authenticated;
