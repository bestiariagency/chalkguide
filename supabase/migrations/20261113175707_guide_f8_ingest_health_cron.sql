-- F8 (8.5) · J35: cron de salud de la ingesta (patrón de 20261112225821: SQL puro, función INVOKER sin EXECUTE para
-- ningún rol de la API, sin pg_net). Cada hora: cierra como 'abandoned' los runs abiertos de más de 2 h y escribe en
-- guide.job_health la fila 'ingest' (status_code 200 = sana, 500 = con alertas; details con los motivos).
-- Alertas: sin run OK real en 4 días, runs abandoned/error o con duplicate_rejected en 7 días, ningún token vigente
-- más allá de 5 días, runs fuera de la ventana lun/jue (R1) en 7 días. Idempotente.

create or replace function guide.ingest_health_check()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_last_ok   timestamptz;
  v_abandoned integer;
  v_error     integer;
  v_duprej    integer;
  v_outside   integer;
  v_tok_until timestamptz;
  v_alerts    text[] := '{}';
  v_status    integer;
begin
  if not coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)
     or coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ? 'role' then
    raise exception 'maintenance only' using errcode = '42501';
  end if;

  update guide.ingest_runs r set status = 'abandoned', finished_at = now()
  where r.status = 'open' and r.started_at <= now() - interval '2 hours';

  select max(r.finished_at) into v_last_ok from guide.ingest_runs r where r.status = 'ok' and not r.dry_run;
  select count(*) filter (where r.status = 'abandoned'),
         count(*) filter (where r.status = 'error'),
         coalesce(sum(r.duplicate_rejected), 0),
         count(*) filter (where r.outside_window)
  into v_abandoned, v_error, v_duprej, v_outside
  from guide.ingest_runs r where r.started_at > now() - interval '7 days';
  select max(t.expires_at) into v_tok_until from guide.ingest_tokens t where t.revoked_at is null and t.expires_at > now();

  if v_last_ok is null or v_last_ok < now() - interval '4 days' then
    v_alerts := v_alerts || 'no_ok_run_4d'::text;
  end if;
  if v_abandoned > 0 then
    v_alerts := v_alerts || 'abandoned'::text;
  end if;
  if v_error > 0 then
    v_alerts := v_alerts || 'error'::text;
  end if;
  if v_duprej > 0 then
    v_alerts := v_alerts || 'duplicate_rejected'::text;
  end if;
  if v_tok_until is null then
    v_alerts := v_alerts || 'no_active_token'::text;
  elsif v_tok_until <= now() + interval '5 days' then
    v_alerts := v_alerts || 'token_expiring'::text;
  end if;
  if v_outside > 0 then
    v_alerts := v_alerts || 'outside_window'::text;
  end if;

  v_status := case when cardinality(v_alerts) = 0 then 200 else 500 end;
  insert into guide.job_health (job, request_id, checked_at, status_code, details)
  values ('ingest', null, now(), v_status,
          jsonb_build_object('last_ok_at', v_last_ok, 'alerts', to_jsonb(v_alerts),
                             'abandoned_7d', v_abandoned, 'error_7d', v_error, 'duplicate_rejected_7d', v_duprej,
                             'outside_window_7d', v_outside, 'token_valid_until', v_tok_until))
  on conflict (job) do update
    set checked_at = excluded.checked_at, status_code = excluded.status_code, details = excluded.details;
  return v_status;
end;
$$;
revoke all on function guide.ingest_health_check() from public, anon, authenticated, service_role;

-- Cada hora a los 17 min. cron.schedule con el mismo nombre actualiza el job (idempotente).
select cron.schedule('guide-ingest-health', '17 * * * *', $$select guide.ingest_health_check()$$);
