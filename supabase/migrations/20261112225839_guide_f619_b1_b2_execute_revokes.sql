-- F6.19 B1 y B2 (docs/security/F6.19-panel-review.md). Idempotente.
-- B1 (D57 O1): items_publish_ready() es función de trigger; nadie de la API necesita EXECUTE.
-- B2 (D55): service_role no ejecuta admin_dashboard_stats, mark_reviews_seen, get_my_review ni submit_user_review.
--     Comprobado: ningún server/ ni Edge Function los usa (review-photos-cleanup solo llama a
--     review_photos_cleanup_collect; create-admin-user es de Chalk app y no toca guide). authenticated conserva EXECUTE.
revoke execute on function guide.items_publish_ready() from public, anon, authenticated, service_role;

revoke execute on function guide.admin_dashboard_stats() from service_role;
revoke execute on function guide.mark_reviews_seen() from service_role;
revoke execute on function guide.get_my_review(uuid) from service_role;
revoke execute on function guide.submit_user_review(uuid, integer, jsonb, text, guide.locale) from service_role;
