-- D69 · Correcciones del veto de leona-lia (docs/security/D69-analytics-events-review.md). Idempotente.
-- V1: tope diario global en track_event (20 000/día UTC, fila reservada '*day' en analytics_event_rate); la purga solo
--     borra '*day' de más de 2 días y deja la señal de salud 'analytics' en job_health.
-- V2: occurred_at truncado a la hora en todos los eventos; source y device a null en newsletter_submit,
--     review_submitted y login_for_review (pueden casar con una fila identificable).

-- ───────────── V2: analytics_record ─────────────
create or replace function guide.analytics_record(
  p_name text, p_path text, p_locale text, p_content_type text, p_content_slug text, p_pillar text,
  p_partner text, p_source text, p_device text, p_at timestamptz default now())
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_path  text;
  v_ctype text := nullif(lower(btrim(p_content_type)), '');
  v_slug  text := nullif(lower(btrim(p_content_slug)), '');
  v_pill  text := nullif(lower(btrim(p_pillar)), '');
  v_part  text := nullif(lower(btrim(p_partner)), '');
  v_src   text := nullif(lower(btrim(p_source)), '');
  v_dev   text := nullif(lower(btrim(p_device)), '');
begin
  -- Tope de tamaño antes de cualquier expresión regular.
  if p_name is null or p_path is null or p_locale is null
     or char_length(p_name) > 40 or char_length(p_path) > 1000 or char_length(p_locale) > 5
     or coalesce(char_length(p_content_type), 0) > 40 or coalesce(char_length(p_content_slug), 0) > 120
     or coalesce(char_length(p_pillar), 0) > 80 or coalesce(char_length(p_partner), 0) > 40
     or coalesce(char_length(p_source), 0) > 20 or coalesce(char_length(p_device), 0) > 20 then
    return false;
  end if;
  if p_name not in ('page_view', 'newsletter_view', 'newsletter_submit', 'newsletter_confirmed', 'ficha_click',
                    'affiliate_click', 'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75',
                    'video_play', 'search_blog')
     or p_locale not in ('es', 'en') then
    return false;
  end if;

  v_path := lower(split_part(split_part(btrim(p_path), '?', 1), '#', 1));
  if char_length(v_path) > 1 then
    v_path := rtrim(v_path, '/');
  end if;
  if v_path = '' or char_length(v_path) > 200 or v_path !~ '^/[a-z0-9/_.~-]*$'
     or v_path ~ '^/(en/)?(administrador|api)(/|$)' or not guide.analytics_token_safe(v_path) then
    return false;
  end if;

  -- Tipo de contenido: artículo, agenda, página o cualquier categoría de fichas (sumar una es configuración).
  if v_ctype is not null and v_ctype not in ('article', 'event', 'page')
     and not exists (select 1 from guide.item_categories c where c.key = v_ctype) then
    return false;
  end if;
  if v_slug is not null and (v_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or not guide.analytics_token_safe(v_slug)) then
    return false;
  end if;
  if v_pill is not null and not exists (select 1 from guide.article_categories c where c.slug_es = v_pill) then
    return false;
  end if;
  if v_part is not null and v_part !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    return false;
  end if;
  if (v_src is not null and v_src not in ('organic', 'social', 'direct', 'referral', 'email', 'other'))
     or (v_dev is not null and v_dev not in ('mobile', 'desktop')) then
    return false;
  end if;

  -- Ignora lo que no toca a cada evento: socio solo en afiliados; la búsqueda no guarda nada del texto buscado.
  if p_name <> 'affiliate_click' then
    v_part := null;
  end if;
  if p_name = 'search_blog' then
    v_slug := null;
  end if;
  -- V2: estos tres casan en el tiempo con una fila identificable (alta, opinión, inicio de sesión): sin origen ni
  -- dispositivo solo aportan lo que ya consta en esa fila.
  if p_name in ('newsletter_submit', 'review_submitted', 'login_for_review') then
    v_src := null;
    v_dev := null;
  end if;

  -- V2: hora truncada para todos (las estadísticas son por día de Madrid; Madrid va en horas enteras respecto a UTC).
  insert into guide.analytics_events (occurred_at, name, path, locale, content_type, content_slug, pillar, partner,
                                      source, device)
  values (date_trunc('hour', coalesce(p_at, now())), p_name, v_path, p_locale::guide.locale, v_ctype, v_slug, v_pill,
          v_part, v_src, v_dev);
  return true;
end;
$$;
revoke all on function guide.analytics_record(text, text, text, text, text, text, text, text, text, timestamptz)
  from public, anon, authenticated, service_role;

-- ───────────── V1: tope diario en track_event ─────────────
-- Topes: 300/min por nombre, 1.000/min en total y 20.000/día UTC en total ('*day', bucket = inicio del día UTC).
create or replace function guide.track_event(
  p_name text, p_path text, p_locale text,
  p_content_type text default null, p_content_slug text default null, p_pillar text default null,
  p_partner text default null, p_source text default null, p_device text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_per_name constant integer := 300;
  c_total    constant integer := 1000;
  c_day      constant integer := 20000;
  v_bucket   timestamptz := date_trunc('minute', now());
  v_day      timestamptz := date_trunc('day', now(), 'UTC');
  v_n_name   integer;
  v_n_total  integer;
  v_n_day    integer;
begin
  if p_name is null or p_name = 'newsletter_confirmed' or char_length(p_name) > 40
     or p_name not in ('page_view', 'newsletter_view', 'newsletter_submit', 'ficha_click', 'affiliate_click',
                       'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75', 'video_play', 'search_blog') then
    return;
  end if;

  -- Primero los contadores (cuentan todo nombre válido aunque el resto no valide); el evento que supera un tope no
  -- se escribe. Orden fijo de filas (nombre, '*', '*day') para no crear interbloqueos. La validación completa la hace
  -- analytics_record.
  with u as (
    insert into guide.analytics_event_rate as r (bucket, name, n)
    values (v_bucket, p_name, 1), (v_bucket, '*', 1), (v_day, '*day', 1)
    on conflict (bucket, name) do update set n = r.n + 1
    returning r.name, r.n
  )
  select max(u.n) filter (where u.name = p_name), max(u.n) filter (where u.name = '*'),
         max(u.n) filter (where u.name = '*day')
  into v_n_name, v_n_total, v_n_day
  from u;

  if v_n_name > c_per_name or v_n_total > c_total or v_n_day > c_day then
    return;
  end if;

  begin
    perform guide.analytics_record(p_name, p_path, p_locale, p_content_type, p_content_slug, p_pillar, p_partner,
                                   p_source, p_device);
  exception when others then
    -- El cliente no debe romper la página por un evento.
    return;
  end;
end;
$$;
revoke all on function guide.track_event(text, text, text, text, text, text, text, text, text) from public, service_role;
grant execute on function guide.track_event(text, text, text, text, text, text, text, text, text) to anon, authenticated;

-- ───────────── V1: purga y señal de salud ─────────────
-- Contadores por minuto: fuera a la hora. '*day': fuera a los 2 días (el de hoy sigue contando). Señal 'analytics' en
-- job_health: 500 con alerta 'daily_cap_reached' si hoy o ayer (UTC) se superó el tope; las cifras de ese día no son
-- fiables. Solo recuentos en details.
create or replace function guide.purge_analytics_events()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_day    constant integer := 20000;
  v_moved  bigint;
  v_today  integer;
  v_yday   integer;
  v_alerts text[] := '{}';
begin
  with moved as (
    delete from guide.analytics_events e
    where e.occurred_at < now() - interval '90 days'
    returning e.occurred_at, e.name, e.path, e.locale, e.content_type, e.content_slug, e.pillar, e.partner, e.source,
              e.device
  ),
  ins as (
    insert into guide.analytics_events_daily as d (day, name, path, locale, content_type, content_slug, pillar, partner,
                                                   source, device, n)
    select (m.occurred_at at time zone 'Europe/Madrid')::date, m.name, m.path, m.locale, m.content_type, m.content_slug,
           m.pillar, m.partner, m.source, m.device, count(*)::integer
    from moved m
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    on conflict on constraint analytics_events_daily_key do update set n = d.n + excluded.n
    returning 1
  )
  select count(*) into v_moved from moved;

  delete from guide.analytics_events_daily d
  where d.day < ((now() at time zone 'Europe/Madrid') - interval '24 months')::date;

  delete from guide.analytics_event_rate r
  where (r.name <> '*day' and r.bucket < now() - interval '1 hour')
     or (r.name = '*day' and r.bucket < date_trunc('day', now(), 'UTC') - interval '2 days');

  select coalesce(max(r.n) filter (where r.bucket = date_trunc('day', now(), 'UTC')), 0),
         coalesce(max(r.n) filter (where r.bucket = date_trunc('day', now(), 'UTC') - interval '1 day'), 0)
  into v_today, v_yday
  from guide.analytics_event_rate r
  where r.name = '*day';
  if v_today > c_day or v_yday > c_day then
    v_alerts := v_alerts || 'daily_cap_reached'::text;
  end if;
  insert into guide.job_health (job, request_id, checked_at, status_code, details)
  values ('analytics', null, now(), case when cardinality(v_alerts) = 0 then 200 else 500 end,
          jsonb_build_object('alerts', to_jsonb(v_alerts), 'cap_per_day', c_day, 'today_attempts', v_today,
                             'yesterday_attempts', v_yday, 'moved_to_daily', v_moved))
  on conflict (job) do update
    set checked_at = excluded.checked_at, status_code = excluded.status_code, details = excluded.details;

  return v_moved;
end;
$$;
revoke all on function guide.purge_analytics_events() from public, anon, authenticated, service_role;

-- Las filas ya guardadas también, con la misma regla (hoy es una tabla de prueba casi vacía).
update guide.analytics_events set occurred_at = date_trunc('hour', occurred_at) where occurred_at <> date_trunc('hour', occurred_at);
update guide.analytics_events set source = null, device = null
where name in ('newsletter_submit', 'review_submitted', 'login_for_review') and (source is not null or device is not null);
