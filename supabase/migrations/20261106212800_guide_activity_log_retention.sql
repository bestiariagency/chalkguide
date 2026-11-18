-- D60 · Retención de guide.activity_log: se borran las filas de más de 24 meses. Idempotente.
-- SECURITY INVOKER: solo la ejecuta pg_cron como postgres (dueño de la tabla, con DELETE). activity_log no tiene
-- triggers, reglas ni FKs entrantes, así que no hace falta exención. Sin EXECUTE para ningún rol de la API.
create or replace function guide.purge_activity_log()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_deleted bigint;
begin
  delete from guide.activity_log l
  where l.occurred_at < now() - interval '24 months';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;
revoke all on function guide.purge_activity_log() from public, anon, authenticated, service_role;

-- 03:15 UTC = 04:15 en Madrid en invierno (CET) y 05:15 en verano (CEST); tras la limpieza de fotos (03:00).
-- cron.schedule con el mismo nombre actualiza el job (idempotente).
select cron.schedule('guide-activity-log-purge', '15 3 * * *', $$select guide.purge_activity_log()$$);
