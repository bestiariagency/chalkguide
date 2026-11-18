-- F6.11b · La limpieza diaria la llama service_role, que no tiene grants de tabla en guide: DEFINER, ejecutable
-- solo por service_role (sin grants a anon/authenticated). Idempotente.
alter function guide.review_photos_cleanup_collect(integer) security definer;
revoke all on function guide.review_photos_cleanup_collect(integer) from public, anon, authenticated;
grant execute on function guide.review_photos_cleanup_collect(integer) to service_role;
