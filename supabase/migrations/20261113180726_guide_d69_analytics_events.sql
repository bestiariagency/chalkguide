-- D69 / D71 · Analítica propia sin cookies (docs/marketing/analitica-remarketing-spec.md §4 y §5).
-- guide.events ya es la agenda, así que la capa propia se llama guide.analytics_events (PLAN, 8.3).
-- Sin IP, user agent, sesión, dispositivo, usuario ni email: ninguna columna lo admite y el RPC no lee request.headers.
-- Escritura solo por guide.track_event (anon y authenticated); newsletter_confirmed solo desde el servidor
-- (guide.confirm_newsletter, y en F4.6 el webhook de Brevo). Retención: bruto 90 días, agregado diario 24 meses.
-- Idempotente.

-- ───────────── Tablas ─────────────
-- Rechaza tokens que no deben llegar nunca a analítica: UUID, cadenas hex largas (tokens de confirmación y baja)
-- y series largas de dígitos (teléfonos). Se usa en CHECK y en la validación del RPC.
create or replace function guide.analytics_token_safe(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is null
      or (p !~ '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
          and p !~ '[0-9a-f]{24,}'
          and p !~ '[0-9]{7,}');
$$;
revoke all on function guide.analytics_token_safe(text) from public, anon, authenticated, service_role;

create table if not exists guide.analytics_events (
  id           bigint generated always as identity primary key,
  occurred_at  timestamptz not null default now(),
  name         text not null,
  path         text not null,
  locale       guide.locale not null,
  content_type text,
  content_slug text,
  pillar       text,
  partner      text,
  source       text,
  device       text,
  constraint analytics_events_name_check check (name in (
    'page_view', 'newsletter_view', 'newsletter_submit', 'newsletter_confirmed', 'ficha_click', 'affiliate_click',
    'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75', 'video_play', 'search_blog')),
  constraint analytics_events_path_check check (
    char_length(path) <= 200 and path ~ '^/[a-z0-9/_.~-]*$'
    and path !~ '^/(en/)?(administrador|api)(/|$)' and guide.analytics_token_safe(path)),
  constraint analytics_events_content_type_check check (
    content_type is null or (char_length(content_type) <= 40 and content_type ~ '^[a-z][a-z0-9_]*$')),
  constraint analytics_events_content_slug_check check (
    content_slug is null or (char_length(content_slug) <= 120 and content_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'
                             and guide.analytics_token_safe(content_slug))),
  constraint analytics_events_pillar_check check (
    pillar is null or (char_length(pillar) <= 80 and pillar ~ '^[a-z0-9]+(-[a-z0-9]+)*$')),
  constraint analytics_events_partner_check check (
    partner is null or (name = 'affiliate_click' and char_length(partner) <= 40 and partner ~ '^[a-z0-9]+(-[a-z0-9]+)*$')),
  constraint analytics_events_source_check check (
    source is null or source in ('organic', 'social', 'direct', 'referral', 'email', 'other')),
  constraint analytics_events_device_check check (device is null or device in ('mobile', 'desktop'))
);
create index if not exists analytics_events_occurred_at_idx on guide.analytics_events (occurred_at);
create index if not exists analytics_events_name_occurred_at_idx on guide.analytics_events (name, occurred_at);

-- Agregado diario (día de Madrid). Solo recuentos por combinación de columnas; ninguna permite reconstruir personas.
-- Incluye path (validado, sin query) para el top de páginas más allá de 90 días.
create table if not exists guide.analytics_events_daily (
  id           bigint generated always as identity primary key,
  day          date not null,
  name         text not null,
  path         text not null,
  locale       guide.locale not null,
  content_type text,
  content_slug text,
  pillar       text,
  partner      text,
  source       text,
  device       text,
  n            integer not null check (n > 0),
  constraint analytics_events_daily_key unique nulls not distinct
    (day, name, path, locale, content_type, content_slug, pillar, partner, source, device)
);
create index if not exists analytics_events_daily_name_day_idx on guide.analytics_events_daily (name, day);

-- Límite de tasa global por minuto y por nombre (name = '*' es el total). Sin identificador de cliente.
create table if not exists guide.analytics_event_rate (
  bucket timestamptz not null,
  name   text not null,
  n      integer not null default 0,
  primary key (bucket, name)
);

alter table guide.analytics_events enable row level security;
alter table guide.analytics_events_daily enable row level security;
alter table guide.analytics_event_rate enable row level security;

revoke all on table guide.analytics_events, guide.analytics_events_daily, guide.analytics_event_rate
  from public, anon, authenticated, service_role;
revoke all on sequence guide.analytics_events_id_seq, guide.analytics_events_daily_id_seq
  from public, anon, authenticated, service_role;
-- Lectura directa solo para el admin (el panel usa las RPC agregadas). Sin INSERT/UPDATE/DELETE para nadie de la API.
-- analytics_event_rate: sin GRANT ni policies (solo la toca track_event como dueño).
grant select on table guide.analytics_events, guide.analytics_events_daily to authenticated;

drop policy if exists analytics_events_select_admin on guide.analytics_events;
create policy analytics_events_select_admin on guide.analytics_events
  for select to authenticated using ((select guide.is_admin()));
drop policy if exists analytics_events_daily_select_admin on guide.analytics_events_daily;
create policy analytics_events_daily_select_admin on guide.analytics_events_daily
  for select to authenticated using ((select guide.is_admin()));

comment on table guide.analytics_events is
  'D69. Eventos propios sin cookies ni identificadores (sin IP, UA, sesión ni usuario). Escritura: guide.track_event. Bruto 90 días.';
comment on table guide.analytics_events_daily is
  'D69. Agregado diario (día de Madrid) de analytics_events, relleno por guide.purge_analytics_events. 24 meses.';
comment on table guide.analytics_event_rate is
  'D69. Contador por minuto y nombre para el límite de tasa global de guide.track_event. Se purga cada hora.';

-- ───────────── Escritura ─────────────
-- Valida y escribe un evento. Devuelve false (sin error) si algo no valida. SECURITY INVOKER y sin EXECUTE para la API:
-- solo la llaman track_event y confirm_newsletter (SECURITY DEFINER, dueño postgres).
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

  insert into guide.analytics_events (occurred_at, name, path, locale, content_type, content_slug, pillar, partner,
                                      source, device)
  values (coalesce(p_at, now()), p_name, v_path, p_locale::guide.locale, v_ctype, v_slug, v_pill, v_part, v_src, v_dev);
  return true;
end;
$$;
revoke all on function guide.analytics_record(text, text, text, text, text, text, text, text, text, timestamptz)
  from public, anon, authenticated, service_role;

-- RPC pública. Nunca falla: si no valida o se supera el tope, no escribe nada. newsletter_confirmed no se acepta aquí.
-- Topes por minuto: 300 por nombre y 1.000 en total (global: sin IP no hay límite por cliente).
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
  v_bucket   timestamptz := date_trunc('minute', now());
  v_n_name   integer;
  v_n_total  integer;
begin
  if p_name is null or p_name = 'newsletter_confirmed' or char_length(p_name) > 40
     or p_name not in ('page_view', 'newsletter_view', 'newsletter_submit', 'ficha_click', 'affiliate_click',
                       'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75', 'video_play', 'search_blog') then
    return;
  end if;

  -- Primero el contador (cuenta todo nombre válido aunque el resto no valide); el evento que supera el tope no se
  -- escribe. La validación completa la hace analytics_record.
  with u as (
    insert into guide.analytics_event_rate as r (bucket, name, n)
    values (v_bucket, p_name, 1), (v_bucket, '*', 1)
    on conflict (bucket, name) do update set n = r.n + 1
    returning r.name, r.n
  )
  select max(u.n) filter (where u.name = p_name), max(u.n) filter (where u.name = '*')
  into v_n_name, v_n_total
  from u;

  if v_n_name > c_per_name or v_n_total > c_total then
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

-- ───────────── newsletter_confirmed desde el servidor ─────────────
-- Mismo cuerpo que la versión D66; añade el evento tras activar. El origen sale de consent_page (sin query): si es un
-- artículo, content_slug = slug_es y pillar = slug_es de su categoría. Hora truncada a la hora para que el evento no
-- case con confirmed_at de una fila concreta. Un fallo de analítica nunca impide confirmar.
create or replace function guide.confirm_newsletter(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_status  guide.subscriber_status;
  v_expires timestamptz;
  v_locale  guide.locale;
  v_page    text;
  v_slug    text;
  v_art     text;
  v_pillar  text;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return 'invalid';
  end if;
  select s.id, s.status, s.confirm_expires_at, s.locale, s.consent_page
  into v_id, v_status, v_expires, v_locale, v_page
  from guide.subscribers s
  where s.confirm_token_hash = pg_catalog.sha256(convert_to(p_token, 'UTF8'))
  for update;
  if v_id is null then
    return 'invalid';
  end if;
  if v_status = 'active' then
    return 'ok';                       -- segundo clic en el mismo enlace
  end if;
  if v_status <> 'pending' then
    return 'invalid';
  end if;
  if v_expires < now() then
    return 'expired';
  end if;
  update guide.subscribers
  set status = 'active', confirmed_at = now(),
      related_status       = case when related_status = 'pending' then 'granted' else related_status end,
      related_confirmed_at = case when related_status = 'pending' then now() else related_confirmed_at end
  where id = v_id;

  -- D69: newsletter_confirmed (solo capa propia; nunca a Google ni Meta).
  begin
    v_slug := substring(lower(coalesce(v_page, '')) from '^(?:/en)?/blog/([a-z0-9-]+)/?$');
    if v_slug is not null then
      select a.slug_es, c.slug_es into v_art, v_pillar
      from guide.articles a
      left join guide.article_categories c on c.id = a.category_id
      where a.slug_es = v_slug or a.slug_en = v_slug
      limit 1;
    end if;
    perform guide.analytics_record('newsletter_confirmed', coalesce(v_page, '/newsletter/confirmed'), v_locale::text,
                                   case when v_art is not null then 'article' end, v_art, v_pillar, null, null, null,
                                   date_trunc('hour', now()));
  exception when others then
    null;
  end;
  return 'ok';
end;
$$;
revoke all on function guide.confirm_newsletter(text) from public, service_role;
grant execute on function guide.confirm_newsletter(text) to anon, authenticated;

-- ───────────── Retención ─────────────
-- Mueve al agregado diario y borra el bruto de más de 90 días (en un mismo statement: cada fila se cuenta una vez),
-- borra el agregado de más de 24 meses y los contadores de tasa de más de 1 hora. SECURITY INVOKER: solo pg_cron
-- como postgres. Sin EXECUTE para la API (como guide.purge_activity_log, D60).
create or replace function guide.purge_analytics_events()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_moved bigint;
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

  delete from guide.analytics_event_rate r where r.bucket < now() - interval '1 hour';

  return v_moved;
end;
$$;
revoke all on function guide.purge_analytics_events() from public, anon, authenticated, service_role;

-- Cada hora a los :40 (tasa: hora; bruto: lo que cruce los 90 días). Mismo nombre = actualiza el job (idempotente).
select cron.schedule('guide-analytics-purge', '40 * * * *', $$select guide.purge_analytics_events()$$);

-- ───────────── Lectura agregada para Estadísticas (D59), solo admin ─────────────
-- Rango como admin_stats: '30d' (day/week), '12m' (week/month) o personalizado (≤ 62 días: day/week; más: week/month),
-- tope 24 meses. Granularidad null = sin comprobar (top y conversión). Fechas de Madrid; r_to excluido.
create or replace function guide.analytics_range(
  p_range text, p_granularity text, p_from date, p_to date,
  out r_from date, out r_to date, out r_prev date, out r_custom boolean)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Europe/Madrid')::date;
  v_cut   date := ((now() at time zone 'Europe/Madrid') - interval '24 months')::date;
  v_days  integer;
begin
  r_custom := p_from is not null or p_to is not null;
  if p_granularity is not null and p_granularity not in ('day', 'week', 'month') then
    raise exception 'invalid granularity' using errcode = '22023';
  end if;
  if r_custom then
    if p_from is null or p_to is null or p_from > p_to or p_to > v_today or p_from < v_cut then
      raise exception 'invalid custom range' using errcode = '22023';
    end if;
    v_days := p_to - p_from + 1;
    if p_granularity is not null
       and not ((v_days <= 62 and p_granularity in ('day', 'week'))
             or (v_days > 62 and p_granularity in ('week', 'month'))) then
      raise exception 'invalid granularity for range' using errcode = '22023';
    end if;
    r_from := p_from;
    r_to := p_to + 1;
  else
    if p_range is null or p_range not in ('30d', '12m')
       or (p_granularity is not null
           and not ((p_range = '30d' and p_granularity in ('day', 'week'))
                 or (p_range = '12m' and p_granularity in ('week', 'month')))) then
      raise exception 'invalid range or granularity' using errcode = '22023';
    end if;
    r_to := v_today + 1;
    r_from := case
      when p_range = '30d' then v_today - 29
      when p_granularity = 'week' then (date_trunc('week', v_today) - interval '51 weeks')::date
      else (date_trunc('month', v_today) - interval '11 months')::date end;
  end if;
  r_prev := r_from - (r_to - r_from);
end;
$$;
revoke all on function guide.analytics_range(text, text, date, date) from public, anon, authenticated, service_role;

-- Bruto (agrupado por día de Madrid) + agregado diario, sin solaparse: cada evento está en una sola de las dos.
create or replace function guide.analytics_rows(p_from date, p_to date)
returns table (day date, name text, path text, locale guide.locale, content_type text, content_slug text,
               pillar text, partner text, source text, device text, n bigint)
language sql
stable
set search_path = ''
as $$
  select (e.occurred_at at time zone 'Europe/Madrid')::date, e.name, e.path, e.locale, e.content_type, e.content_slug,
         e.pillar, e.partner, e.source, e.device, count(*)
  from guide.analytics_events e
  where e.occurred_at >= (p_from::timestamp at time zone 'Europe/Madrid')
    and e.occurred_at < (p_to::timestamp at time zone 'Europe/Madrid')
  group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
  union all
  select d.day, d.name, d.path, d.locale, d.content_type, d.content_slug, d.pillar, d.partner, d.source, d.device,
         d.n::bigint
  from guide.analytics_events_daily d
  where d.day >= p_from and d.day < p_to;
$$;
revoke all on function guide.analytics_rows(date, date) from public, anon, authenticated, service_role;

-- Serie por periodo con recuento de cada evento, totales del rango y del anterior, y desgloses del rango.
create or replace function guide.admin_analytics_stats(
  p_range text default '30d', p_granularity text default 'day', p_from date default null, p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_names constant text[] := array['page_view', 'newsletter_view', 'newsletter_submit', 'newsletter_confirmed',
    'ficha_click', 'affiliate_click', 'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75',
    'video_play', 'search_blog'];
  v_today date := (now() at time zone 'Europe/Madrid')::date;
  v_cut   date := ((now() at time zone 'Europe/Madrid') - interval '24 months')::date;
  r       record;
  v_step  interval;
  v       jsonb;
begin
  perform guide.assert_admin();
  if p_granularity is null then
    raise exception 'invalid granularity' using errcode = '22023';
  end if;
  select * into r from guide.analytics_range(p_range, p_granularity, p_from, p_to);
  v_step := case p_granularity when 'day' then interval '1 day' when 'week' then interval '1 week'
                               else interval '1 month' end;

  with t as materialized (
    select x.day, x.name, x.locale, x.content_type, x.pillar, x.partner, x.source, x.device, sum(x.n) as n
    from guide.analytics_rows(greatest(r.r_prev, v_cut), r.r_to) x
    group by 1, 2, 3, 4, 5, 6, 7, 8
  ),
  cur as (
    select * from t where t.day >= r.r_from
  ),
  b as (
    select greatest(gs::date, r.r_from) as s, least((gs + v_step)::date, r.r_to) as e,
           gs::date < r.r_from or (gs + v_step)::date > r.r_to or (gs + v_step)::date > v_today as partial
    from generate_series(date_trunc(p_granularity, r.r_from::timestamp),
                         date_trunc(p_granularity, (r.r_to - 1)::timestamp), v_step) gs
  )
  select jsonb_build_object(
    'series', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'bucket_start', to_char(b.s, 'YYYY-MM-DD'),
          'bucket_end', to_char(b.e - 1, 'YYYY-MM-DD'),
          'partial', b.partial,
          'counts', (select jsonb_object_agg(k.name, coalesce((select sum(c.n) from cur c
                                                               where c.name = k.name and c.day >= b.s and c.day < b.e), 0))
                     from unnest(c_names) k(name)))
        order by b.s), '[]'::jsonb)
      from b),
    'current_totals', (
      select jsonb_object_agg(k.name, coalesce((select sum(c.n) from cur c where c.name = k.name), 0))
      from unnest(c_names) k(name)),
    'previous', case when r.r_prev >= v_cut then jsonb_build_object(
      'from', to_char(r.r_prev, 'YYYY-MM-DD'), 'to', to_char(r.r_from - 1, 'YYYY-MM-DD'),
      'totals', (select jsonb_object_agg(k.name, coalesce((select sum(p.n) from t p
                                                           where p.name = k.name and p.day < r.r_from), 0))
                 from unnest(c_names) k(name))) end,
    'breakdowns', jsonb_build_object(
      'page_view_by_source', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select coalesce(c.source, 'unknown') k, sum(c.n) n from cur c where c.name = 'page_view' group by 1) x),
      'page_view_by_device', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select coalesce(c.device, 'unknown') k, sum(c.n) n from cur c where c.name = 'page_view' group by 1) x),
      'page_view_by_locale', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select c.locale::text k, sum(c.n) n from cur c where c.name = 'page_view' group by 1) x),
      'page_view_by_content_type', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select coalesce(c.content_type, 'other') k, sum(c.n) n from cur c where c.name = 'page_view' group by 1) x),
      'newsletter_submit_by_pillar', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select coalesce(c.pillar, 'none') k, sum(c.n) n from cur c where c.name = 'newsletter_submit' group by 1) x),
      'affiliate_click_by_partner', (select coalesce(jsonb_object_agg(x.k, x.n), '{}'::jsonb) from (
        select coalesce(c.partner, 'unknown') k, sum(c.n) n from cur c where c.name = 'affiliate_click' group by 1) x)))
  into v;

  return jsonb_build_object(
    'range', case when r.r_custom then 'custom' else p_range end,
    'granularity', p_granularity,
    'tz', 'Europe/Madrid',
    'from', to_char(r.r_from, 'YYYY-MM-DD'),
    'to', to_char(r.r_to - 1, 'YYYY-MM-DD'),
    'generated_at', now()) || v;
end;
$$;

-- Top por ruta o por contenido (content_type + content_slug) de un evento.
create or replace function guide.admin_analytics_top(
  p_name text default 'page_view', p_group text default 'path', p_range text default '30d',
  p_from date default null, p_to date default null, p_limit integer default 10)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r      record;
  v_rows jsonb;
begin
  perform guide.assert_admin();
  if p_name is null or p_name not in ('page_view', 'newsletter_view', 'newsletter_submit', 'newsletter_confirmed',
       'ficha_click', 'affiliate_click', 'outbound_gym', 'login_for_review', 'review_submitted', 'scroll_75',
       'video_play', 'search_blog') then
    raise exception 'invalid name' using errcode = '22023';
  end if;
  if p_group is null or p_group not in ('path', 'content') then
    raise exception 'invalid group' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  select * into r from guide.analytics_range(p_range, null, p_from, p_to);

  if p_group = 'path' then
    select coalesce(jsonb_agg(jsonb_build_object('path', x.path, 'n', x.n) order by x.n desc, x.path), '[]'::jsonb)
    into v_rows
    from (select t.path, sum(t.n) n from guide.analytics_rows(r.r_from, r.r_to) t
          where t.name = p_name group by t.path order by 2 desc, 1 limit p_limit) x;
  else
    select coalesce(jsonb_agg(jsonb_build_object('content_type', x.content_type, 'content_slug', x.content_slug,
                                                 'n', x.n) order by x.n desc, x.content_type, x.content_slug), '[]'::jsonb)
    into v_rows
    from (select t.content_type, t.content_slug, sum(t.n) n from guide.analytics_rows(r.r_from, r.r_to) t
          where t.name = p_name and t.content_slug is not null
          group by t.content_type, t.content_slug order by 3 desc, 1, 2 limit p_limit) x;
  end if;

  return jsonb_build_object('name', p_name, 'group', p_group,
    'range', case when r.r_custom then 'custom' else p_range end,
    'from', to_char(r.r_from, 'YYYY-MM-DD'), 'to', to_char(r.r_to - 1, 'YYYY-MM-DD'), 'rows', v_rows);
end;
$$;

-- Conversión por artículo: páginas vistas (page_view con content_type article) y embudo de la newsletter con el mismo
-- content_slug (content_type article o sin tipo). rate = altas / páginas vistas. Título y pilar actuales del artículo.
create or replace function guide.admin_analytics_article_conversion(
  p_range text default '30d', p_from date default null, p_to date default null,
  p_sort text default 'page_views', p_limit integer default 20)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r      record;
  v_rows jsonb;
begin
  perform guide.assert_admin();
  if p_sort is null or p_sort not in ('page_views', 'submits', 'rate') then
    raise exception 'invalid sort' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  select * into r from guide.analytics_range(p_range, null, p_from, p_to);

  with t as (
    select * from guide.analytics_rows(r.r_from, r.r_to) x
    where x.content_slug is not null
      and ((x.name = 'page_view' and x.content_type = 'article')
        or (x.name in ('newsletter_view', 'newsletter_submit', 'newsletter_confirmed')
            and (x.content_type is null or x.content_type = 'article')))
  ),
  g as (
    select t.content_slug,
           sum(t.n) filter (where t.name = 'page_view') as page_views,
           sum(t.n) filter (where t.name = 'newsletter_view') as views,
           sum(t.n) filter (where t.name = 'newsletter_submit') as submits,
           sum(t.n) filter (where t.name = 'newsletter_confirmed') as confirmed
    from t group by t.content_slug
  ),
  s as (
    select g.content_slug, coalesce(g.page_views, 0) pv, coalesce(g.views, 0) nv, coalesce(g.submits, 0) ns,
           coalesce(g.confirmed, 0) nc,
           case when coalesce(g.page_views, 0) > 0 then round(coalesce(g.submits, 0)::numeric / g.page_views, 4) end rate
    from g where coalesce(g.page_views, 0) > 0
  ),
  top as (
    select s.* from s
    order by case p_sort when 'page_views' then s.pv when 'submits' then s.ns else null end desc nulls last,
             case when p_sort = 'rate' then s.rate end desc nulls last,
             s.pv desc, s.content_slug
    limit p_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'content_slug', top.content_slug,
      'title_es', a.title_es,
      'pillar', c.slug_es,
      'page_views', top.pv, 'newsletter_views', top.nv, 'newsletter_submits', top.ns,
      'newsletter_confirmed', top.nc, 'rate', top.rate)
    order by case p_sort when 'page_views' then top.pv when 'submits' then top.ns else null end desc nulls last,
             case when p_sort = 'rate' then top.rate end desc nulls last, top.pv desc, top.content_slug), '[]'::jsonb)
  into v_rows
  from top
  left join guide.articles a on a.slug_es = top.content_slug
  left join guide.article_categories c on c.id = a.category_id;

  return jsonb_build_object('range', case when r.r_custom then 'custom' else p_range end,
    'from', to_char(r.r_from, 'YYYY-MM-DD'), 'to', to_char(r.r_to - 1, 'YYYY-MM-DD'), 'sort', p_sort, 'rows', v_rows);
end;
$$;

revoke all on function guide.admin_analytics_stats(text, text, date, date) from public, anon, service_role;
revoke all on function guide.admin_analytics_top(text, text, text, date, date, integer) from public, anon, service_role;
revoke all on function guide.admin_analytics_article_conversion(text, date, date, text, integer)
  from public, anon, service_role;
grant execute on function guide.admin_analytics_stats(text, text, date, date) to authenticated;
grant execute on function guide.admin_analytics_top(text, text, text, date, date, integer) to authenticated;
grant execute on function guide.admin_analytics_article_conversion(text, date, date, text, integer) to authenticated;
