-- D32 · Job diario de limpieza de fotos de opiniones (F6.11b, condiciones C1/C2 de leona-lia).
-- El secreto NO está en esta migración: se lee de Vault por nombre ('review_photos_cleanup_secret') en cada
-- ejecución. Si no existe o es corto (< 32), el job no hace nada. Sin service key en cron: la Edge Function tiene
-- verify_jwt = false y su única puerta es la cabecera x-cleanup-secret. Idempotente.

-- pg_net: la cola de peticiones (net.http_request_queue) guarda las cabeceras unos segundos; anon/authenticated
-- no deben poder leerla ni lanzar peticiones. Nada en ChalkGuide ni en Chalk app usa pg_net desde clientes.
-- NOTA (comprobado tras aplicar): estos REVOKE no tienen efecto. supabase_admin concede esos privilegios a PUBLIC
-- y postgres no puede retirarlos. Mitigación: `net` no es un schema expuesto por la API y anon/authenticated no
-- tienen login directo. Riesgo residual anotado para leona-lia.
revoke all on all tables in schema net from anon, authenticated;
revoke all on all functions in schema net from anon, authenticated;
revoke usage on schema net from anon, authenticated;

create or replace function guide.run_review_photos_cleanup()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_id     bigint;
begin
  select ds.decrypted_secret into v_secret
  from vault.decrypted_secrets ds
  where ds.name = 'review_photos_cleanup_secret'
  limit 1;
  if v_secret is null or char_length(v_secret) < 32 then
    return null;  -- sin secreto configurado: no hace nada
  end if;
  select net.http_post(
           url := 'https://eqtjlafxtrzbjazhhyin.supabase.co/functions/v1/review-photos-cleanup',
           body := '{}'::jsonb,
           headers := jsonb_build_object('Content-Type', 'application/json', 'x-cleanup-secret', v_secret),
           timeout_milliseconds := 60000)
    into v_id;
  return v_id;
end;
$$;
revoke all on function guide.run_review_photos_cleanup() from public, anon, authenticated, service_role;

-- 03:00 UTC = 04:00 en Madrid en horario de invierno (CET) y 05:00 en verano (CEST). cron.timezone = GMT.
select cron.schedule('guide-review-photos-cleanup', '0 3 * * *', $$select guide.run_review_photos_cleanup()$$);
