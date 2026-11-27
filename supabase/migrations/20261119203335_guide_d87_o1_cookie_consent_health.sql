-- D87 · O1 de leona-lia (docs/security/D87-cookie-consent-log-review.md): señal de salud cuando se agota el tope de
-- guide.log_cookie_consent. La purga horaria hace upsert de guide.job_health con job = 'cookie_consent', como 'analytics'
-- en D69. 500 con alertas si:
--   daily_cap_reached: hoy o ayer (UTC) el contador '*day' llegó a 5.000 (ese día hay consentimientos sin registrar);
--   minute_cap_hits:   en la última hora, más de 3 minutos llegaron al tope de 120 (ráfagas repetidas, no un pico suelto).
-- Si no, 200. details solo lleva recuentos y umbrales. La firma no cambia. Idempotente.
create or replace function guide.purge_cookie_consent_log()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_minute        constant integer := 120;
  c_day           constant integer := 5000;
  c_minute_hits   constant integer := 3;
  v_deleted       bigint;
  v_today         integer;
  v_yday          integer;
  v_min_hits      integer;
  v_alerts        text[] := '{}';
  v_day           timestamptz := date_trunc('day', now(), 'UTC');
begin
  delete from guide.cookie_consent_log l
  where l.created_at < now() - interval '36 months';
  get diagnostics v_deleted = row_count;

  -- Antes de borrar contadores (los de la última hora se conservan igualmente).
  select count(*) filter (where r.name = '*' and r.bucket >= now() - interval '1 hour' and r.n >= c_minute),
         coalesce(max(r.n) filter (where r.name = '*day' and r.bucket = v_day), 0),
         coalesce(max(r.n) filter (where r.name = '*day' and r.bucket = v_day - interval '1 day'), 0)
  into v_min_hits, v_today, v_yday
  from guide.cookie_consent_rate r;

  delete from guide.cookie_consent_rate r
  where (r.name = '*' and r.bucket < now() - interval '1 hour')
     or (r.name = '*day' and r.bucket < v_day - interval '2 days');

  if v_today >= c_day or v_yday >= c_day then
    v_alerts := v_alerts || 'daily_cap_reached'::text;
  end if;
  if v_min_hits > c_minute_hits then
    v_alerts := v_alerts || 'minute_cap_hits'::text;
  end if;

  insert into guide.job_health (job, request_id, checked_at, status_code, details)
  values ('cookie_consent', null, now(), case when cardinality(v_alerts) = 0 then 200 else 500 end,
          jsonb_build_object('alerts', to_jsonb(v_alerts), 'cap_per_day', c_day, 'cap_per_minute', c_minute,
                             'minute_hits_threshold', c_minute_hits, 'today_attempts', v_today,
                             'yesterday_attempts', v_yday, 'minute_cap_hits_last_hour', v_min_hits,
                             'purged_rows', v_deleted))
  on conflict (job) do update
    set checked_at = excluded.checked_at, status_code = excluded.status_code, details = excluded.details;

  return v_deleted;
end;
$$;
revoke all on function guide.purge_cookie_consent_log() from public, anon, authenticated, service_role;
