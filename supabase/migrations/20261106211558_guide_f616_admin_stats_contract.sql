-- 6.16 · admin_stats ajustada al contrato de buho-pixel (docs/design/admin/README.md §16.2 y §16.8).
-- Rangos: 30d (día | semana) y 12m (semana | mes). Semanas en lunes, hora de Madrid.
--   30d = hoy y los 29 días anteriores. 12m por mes = 11 meses cerrados + el actual. 12m por semana = 52 semanas
--   que terminan en la actual.
-- Por periodo: bucket_start, bucket_end (fechas locales, ambas incluidas), partial (en curso o recortado por el
-- rango), subs_in, subs_out, subs_total (activos al cierre del periodo; el actual, a ahora), articles_published,
-- reviews_visible, reviews_hidden. Aparte: items_published (publicadas hoy por tipo), items_new_in_range (publicadas
-- dentro del rango por tipo) y articles_published_total (publicados hoy).
-- Solo recuentos. Suscriptores: transiciones from/to de guide.activity_log (subscribers_log_status). Artículos y
-- fichas: estado actual + published_at (lo despublicado después no cuenta). Opiniones: created_at + estado actual
-- (las borradas no cuentan). Visitas por página (D5): fuera, page_views no existe.

drop function if exists guide.admin_stats(text, text);

create or replace function guide.admin_stats(
  p_range       text default '12m',   -- 30d | 12m
  p_granularity text default 'month'  -- 30d: day | week · 12m: week | month
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  c_tz      constant text := 'Europe/Madrid';
  v_now     timestamp := now() at time zone c_tz;
  v_today   timestamp := date_trunc('day', now() at time zone c_tz);
  v_step    interval;
  v_start   timestamp;          -- inicio del rango (local, incluido)
  v_end     timestamp;          -- fin del rango (local, excluido): mañana a las 00:00
  v_active  bigint;
  v_series  jsonb;
  v_extra   jsonb;
begin
  perform guide.assert_admin();

  if p_range is null or p_granularity is null
     or not ((p_range = '30d' and p_granularity in ('day', 'week'))
          or (p_range = '12m' and p_granularity in ('week', 'month'))) then
    raise exception 'invalid range or granularity' using errcode = '22023';
  end if;

  v_step := case p_granularity when 'day' then interval '1 day' when 'week' then interval '1 week'
                                else interval '1 month' end;
  v_end := v_today + interval '1 day';
  v_start := case
    when p_range = '30d' then v_today - interval '29 days'
    when p_granularity = 'week' then date_trunc('week', v_today) - interval '51 weeks'
    else date_trunc('month', v_today) - interval '11 months' end;

  select count(*) into v_active from guide.subscribers s where s.status = 'active';

  with b as (
    select greatest(gs, v_start) as s_local,
           least(gs + v_step, v_end) as e_local,
           gs < v_start or gs + v_step > v_end or gs + v_step > v_now as partial
    from generate_series(date_trunc(p_granularity, v_start), date_trunc(p_granularity, v_today), v_step) gs
  ),
  bz as (
    select b.*, b.s_local at time zone c_tz as b_from, b.e_local at time zone c_tz as b_to from b
  ),
  subs as (
    select l.occurred_at,
           (l.details ->> 'to') = 'active' and (l.details ->> 'from') is distinct from 'active' as is_in,
           (l.details ->> 'from') = 'active' and (l.details ->> 'to') is distinct from 'active' as is_out
    from guide.activity_log l
    where l.entity_table = 'subscribers' and l.action = 'update'
      and l.occurred_at >= (v_start at time zone c_tz)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'bucket_start', to_char(bz.s_local, 'YYYY-MM-DD'),
      'bucket_end', to_char(bz.e_local - interval '1 day', 'YYYY-MM-DD'),
      'partial', bz.partial,
      'subs_in', (select count(*) from subs s where s.is_in and s.occurred_at >= bz.b_from and s.occurred_at < bz.b_to),
      'subs_out', (select count(*) from subs s where s.is_out and s.occurred_at >= bz.b_from and s.occurred_at < bz.b_to),
      'subs_total', v_active
        - (select count(*) from subs s where s.is_in and s.occurred_at >= bz.b_to)
        + (select count(*) from subs s where s.is_out and s.occurred_at >= bz.b_to),
      'articles_published', (select count(*) from guide.articles a
        where a.status = 'published' and a.published_at >= bz.b_from and a.published_at < bz.b_to),
      'reviews_visible', (select count(*) from guide.user_reviews r
        where r.status = 'visible' and r.created_at >= bz.b_from and r.created_at < bz.b_to),
      'reviews_hidden', (select count(*) from guide.user_reviews r
        where r.status = 'hidden' and r.created_at >= bz.b_from and r.created_at < bz.b_to))
    order by bz.s_local), '[]'::jsonb)
  into v_series
  from bz;

  select jsonb_build_object(
    'items_published', (
      select coalesce(jsonb_object_agg(c.key, (
        select count(*) from guide.items i where i.category = c.key and i.published)), '{}'::jsonb)
      from guide.item_categories c),
    'items_new_in_range', (
      select coalesce(jsonb_object_agg(c.key, (
        select count(*) from guide.items i
        where i.category = c.key and i.published
          and i.published_at >= (v_start at time zone c_tz) and i.published_at < (v_end at time zone c_tz))), '{}'::jsonb)
      from guide.item_categories c),
    'articles_published_total', (select count(*) from guide.articles a where a.status = 'published'))
  into v_extra;

  return jsonb_build_object(
    'range', p_range,
    'granularity', p_granularity,
    'tz', c_tz,
    'from', to_char(v_start, 'YYYY-MM-DD'),
    'to', to_char(v_today, 'YYYY-MM-DD'),
    'generated_at', now(),
    'series', v_series) || v_extra;
end;
$function$;

revoke all on function guide.admin_stats(text, text) from public, anon, service_role;
grant execute on function guide.admin_stats(text, text) to authenticated;
