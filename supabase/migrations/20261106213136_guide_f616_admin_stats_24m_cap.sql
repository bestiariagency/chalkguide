-- 6.16 · admin_stats: tope de 24 meses (opción A de Xavi). guide.activity_log se purga a los 24 meses
-- (20261106212800_guide_activity_log_retention), así que no se dan cifras de suscriptores sin registro detrás.
-- Rango personalizado: p_from >= hoy (Madrid) - 24 meses; si no, 22023. El tope de duración pasa a ser ese.
-- Granularidad: <= 62 días, day | week; más, week | month.
-- previous = null si su inicio cae antes del corte de 24 meses (también en 30d y 12m): la UI dice «sin datos
-- comparables». La comparación sigue siendo los mismos días justo antes. Firma y resto del contrato sin cambios.

create or replace function guide.admin_stats(
  p_range       text default '12m',   -- 30d | 12m (ignorado si llegan p_from y p_to)
  p_granularity text default 'month', -- 30d: day | week · 12m: week | month · custom: según duración
  p_from        date default null,    -- rango personalizado, incluido (hora de Madrid); >= hoy - 24 meses
  p_to          date default null     -- rango personalizado, incluido (hora de Madrid)
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
  v_custom  boolean := p_from is not null or p_to is not null;
  v_days    integer;
  v_step    interval;
  v_start   timestamp;          -- inicio del rango (local, incluido)
  v_end     timestamp;          -- fin del rango (local, excluido)
  v_pstart  timestamp;          -- inicio del periodo anterior (local, incluido); su fin es v_start
  v_cut     date := ((now() at time zone 'Europe/Madrid') - interval '24 months')::date;  -- purga de activity_log
  v_active  bigint;
  v_series  jsonb;
  v_extra   jsonb;
  v_cmp     jsonb;
begin
  perform guide.assert_admin();

  if p_granularity is null or p_granularity not in ('day', 'week', 'month') then
    raise exception 'invalid granularity' using errcode = '22023';
  end if;

  if v_custom then
    if p_from is null or p_to is null or p_from > p_to or p_to > v_today::date or p_from < v_cut then
      raise exception 'invalid custom range' using errcode = '22023';
    end if;
    v_days := p_to - p_from + 1;
    if not ((v_days <= 62 and p_granularity in ('day', 'week'))
         or (v_days > 62 and p_granularity in ('week', 'month'))) then
      raise exception 'invalid granularity for range' using errcode = '22023';
    end if;
    v_start := p_from::timestamp;
    v_end := (p_to + 1)::timestamp;
  else
    if p_range is null
       or not ((p_range = '30d' and p_granularity in ('day', 'week'))
            or (p_range = '12m' and p_granularity in ('week', 'month'))) then
      raise exception 'invalid range or granularity' using errcode = '22023';
    end if;
    v_end := v_today + interval '1 day';
    v_start := case
      when p_range = '30d' then v_today - interval '29 days'
      when p_granularity = 'week' then date_trunc('week', v_today) - interval '51 weeks'
      else date_trunc('month', v_today) - interval '11 months' end;
  end if;

  v_step := case p_granularity when 'day' then interval '1 day' when 'week' then interval '1 week'
                                else interval '1 month' end;
  v_pstart := v_start - (v_end::date - v_start::date) * interval '1 day';

  select count(*) into v_active from guide.subscribers s where s.status = 'active';

  with b as (
    select greatest(gs, v_start) as s_local,
           least(gs + v_step, v_end) as e_local,
           gs < v_start or gs + v_step > v_end or gs + v_step > v_now as partial
    from generate_series(date_trunc(p_granularity, v_start), date_trunc(p_granularity, v_end - interval '1 day'), v_step) gs
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
      and l.occurred_at >= (v_pstart at time zone c_tz)
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

  with p as (
    select k, s_local, e_local, s_local at time zone c_tz as t_from, e_local at time zone c_tz as t_to
    from (values ('current_totals', v_start, v_end), ('previous', v_pstart, v_start)) v(k, s_local, e_local)
  ),
  subs as (
    select l.occurred_at,
           (l.details ->> 'to') = 'active' and (l.details ->> 'from') is distinct from 'active' as is_in,
           (l.details ->> 'from') = 'active' and (l.details ->> 'to') is distinct from 'active' as is_out
    from guide.activity_log l
    where l.entity_table = 'subscribers' and l.action = 'update'
      and l.occurred_at >= (v_pstart at time zone c_tz)
  )
  select jsonb_object_agg(p.k, jsonb_build_object(
      'from', to_char(p.s_local, 'YYYY-MM-DD'),
      'to', to_char(p.e_local - interval '1 day', 'YYYY-MM-DD'),
      'subs_in', (select count(*) from subs s where s.is_in and s.occurred_at >= p.t_from and s.occurred_at < p.t_to),
      'subs_out', (select count(*) from subs s where s.is_out and s.occurred_at >= p.t_from and s.occurred_at < p.t_to),
      'subs_total_end', v_active
        - (select count(*) from subs s where s.is_in and s.occurred_at >= p.t_to)
        + (select count(*) from subs s where s.is_out and s.occurred_at >= p.t_to),
      'articles_published', (select count(*) from guide.articles a
        where a.status = 'published' and a.published_at >= p.t_from and a.published_at < p.t_to),
      'reviews_visible', (select count(*) from guide.user_reviews r
        where r.status = 'visible' and r.created_at >= p.t_from and r.created_at < p.t_to),
      'reviews_hidden', (select count(*) from guide.user_reviews r
        where r.status = 'hidden' and r.created_at >= p.t_from and r.created_at < p.t_to),
      'items_new_in_range', (
        select coalesce(jsonb_object_agg(c.key, (
          select count(*) from guide.items i
          where i.category = c.key and i.published and i.published_at >= p.t_from and i.published_at < p.t_to)), '{}'::jsonb)
        from guide.item_categories c)))
  into v_cmp
  from p;

  select jsonb_build_object(
    'items_published', (
      select coalesce(jsonb_object_agg(c.key, (
        select count(*) from guide.items i where i.category = c.key and i.published)), '{}'::jsonb)
      from guide.item_categories c),
    'items_new_in_range', v_cmp -> 'current_totals' -> 'items_new_in_range',
    'articles_published_total', (select count(*) from guide.articles a where a.status = 'published'))
  into v_extra;

  return jsonb_build_object(
    'range', case when v_custom then 'custom' else p_range end,
    'granularity', p_granularity,
    'tz', c_tz,
    'from', to_char(v_start, 'YYYY-MM-DD'),
    'to', to_char(v_end - interval '1 day', 'YYYY-MM-DD'),
    'generated_at', now(),
    'series', v_series) || v_extra || v_cmp
    || case when v_pstart::date < v_cut then jsonb_build_object('previous', null) else '{}'::jsonb end;
end;
$function$;

revoke all on function guide.admin_stats(text, text, date, date) from public, anon, service_role;
grant execute on function guide.admin_stats(text, text, date, date) to authenticated;
