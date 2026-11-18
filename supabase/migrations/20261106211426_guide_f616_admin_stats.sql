-- 6.16 · Estadísticas del panel: series agregadas por rango y granularidad, solo números (sin datos personales).
-- INVOKER + assert_admin: el admin ya lee por RLS todas las tablas fuente. Cubetas en hora de Madrid.
-- Suscriptores: transiciones de estado de guide.activity_log (subscribers_log_status, from/to), y total
-- reconstruido hacia atrás desde el recuento actual de activos. Artículos y fichas: estado actual con su
-- published_at (lo despublicado después no cuenta). Opiniones: por created_at y estado actual; las borradas no cuentan.
-- Visitas por página (D5): fuera hasta que exista la herramienta/tabla (page_views no existe).

drop function if exists guide.admin_stats(text, text);

create or replace function guide.admin_stats(
  p_range       text default '12m',   -- 30d | 90d | 12m | 24m
  p_granularity text default 'month'  -- day | week | month
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  c_tz      constant text := 'Europe/Madrid';
  v_now     timestamp := now() at time zone c_tz;
  v_step    interval;
  v_start   timestamp;
  v_last    timestamp;
  v_n       integer;
  v_active  bigint;
  v_series  jsonb;
  v_totals  jsonb;
  v_cats    jsonb;
begin
  perform guide.assert_admin();

  if p_range is null or p_range not in ('30d', '90d', '12m', '24m') then
    raise exception 'invalid range' using errcode = '22023';
  end if;
  if p_granularity is null or p_granularity not in ('day', 'week', 'month') then
    raise exception 'invalid granularity' using errcode = '22023';
  end if;

  v_step := case p_granularity when 'day' then interval '1 day' when 'week' then interval '1 week'
                                else interval '1 month' end;
  v_start := date_trunc(p_granularity, case p_range
    when '30d' then date_trunc('day', v_now) - interval '29 days'
    when '90d' then date_trunc('day', v_now) - interval '89 days'
    when '12m' then date_trunc('month', v_now) - interval '11 months'
    else date_trunc('month', v_now) - interval '23 months' end);
  v_last := date_trunc(p_granularity, v_now);
  select count(*) into v_n from generate_series(v_start, v_last, v_step);
  if v_n > 400 then
    raise exception 'too many buckets' using errcode = '22023';
  end if;

  select count(*) into v_active from guide.subscribers s where s.status = 'active';
  select coalesce(jsonb_agg(c.key order by c.key), '[]'::jsonb) into v_cats from guide.item_categories c;

  with b as (
    select gs as b_local,
           gs at time zone c_tz as b_from,
           (gs + v_step) at time zone c_tz as b_to
    from generate_series(v_start, v_last, v_step) gs
  ),
  subs as (
    select l.occurred_at,
           (l.details ->> 'to') = 'active' and (l.details ->> 'from') is distinct from 'active' as is_new,
           (l.details ->> 'from') = 'active' and (l.details ->> 'to') is distinct from 'active' as is_lost
    from guide.activity_log l
    where l.entity_table = 'subscribers' and l.action = 'update'
      and l.occurred_at >= (v_start at time zone c_tz)
  ),
  agg as (
    select b.b_local, b.b_from, b.b_to,
      (select count(*) from subs s where s.is_new and s.occurred_at >= b.b_from and s.occurred_at < b.b_to) as sub_new,
      (select count(*) from subs s where s.is_lost and s.occurred_at >= b.b_from and s.occurred_at < b.b_to) as sub_lost,
      v_active
        - (select count(*) from subs s where s.is_new and s.occurred_at >= b.b_to)
        + (select count(*) from subs s where s.is_lost and s.occurred_at >= b.b_to) as sub_total,
      (select count(*) from guide.articles a
        where a.status = 'published' and a.published_at >= b.b_from and a.published_at < b.b_to) as art_pub,
      (select count(*) from guide.user_reviews r
        where r.status = 'visible' and r.created_at >= b.b_from and r.created_at < b.b_to) as rev_visible,
      (select count(*) from guide.user_reviews r
        where r.status = 'hidden' and r.created_at >= b.b_from and r.created_at < b.b_to) as rev_hidden,
      (select count(*) from guide.user_reviews r
        where r.status = 'pending' and r.created_at >= b.b_from and r.created_at < b.b_to) as rev_pending,
      (select coalesce(jsonb_object_agg(c.key, (
          select count(*) from guide.items i
          where i.category = c.key and i.published and i.published_at >= b.b_from and i.published_at < b.b_to)),
        '{}'::jsonb) from guide.item_categories c) as items_pub
    from b
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'bucket', to_char(r.b_local, 'YYYY-MM-DD'),
      'subscribers_new', r.sub_new,
      'subscribers_lost', r.sub_lost,
      'subscribers_total', r.sub_total,
      'articles_published', r.art_pub,
      'reviews_visible', r.rev_visible,
      'reviews_hidden', r.rev_hidden,
      'reviews_pending', r.rev_pending,
      'items_published', r.items_pub,
      'items_published_total', (select coalesce(sum(v.value::bigint), 0) from jsonb_each_text(r.items_pub) v))
      order by r.b_local), '[]'::jsonb),
    jsonb_build_object(
      'subscribers_new', coalesce(sum(r.sub_new), 0),
      'subscribers_lost', coalesce(sum(r.sub_lost), 0),
      'subscribers_total_start', v_active
        - (select count(*) from subs s where s.is_new)
        + (select count(*) from subs s where s.is_lost),
      'subscribers_total_end', v_active,
      'articles_published', coalesce(sum(r.art_pub), 0),
      'reviews_visible', coalesce(sum(r.rev_visible), 0),
      'reviews_hidden', coalesce(sum(r.rev_hidden), 0),
      'reviews_pending', coalesce(sum(r.rev_pending), 0),
      'items_published', (select coalesce(jsonb_object_agg(z.k, z.n), '{}'::jsonb)
                          from (select v.key as k, sum(v.value::bigint) as n
                                from agg r2, jsonb_each_text(r2.items_pub) v group by v.key) z),
      'items_published_total', coalesce((select sum(v.value::bigint) from agg r2, jsonb_each_text(r2.items_pub) v), 0))
  into v_series, v_totals
  from agg r;

  return jsonb_build_object(
    'range', p_range,
    'granularity', p_granularity,
    'tz', c_tz,
    'from', to_char(v_start, 'YYYY-MM-DD'),
    'to', to_char(v_now, 'YYYY-MM-DD'),
    'generated_at', now(),
    'categories', v_cats,
    'series', v_series,
    'totals', v_totals);
end;
$function$;

revoke all on function guide.admin_stats(text, text) from public, anon, service_role;
grant execute on function guide.admin_stats(text, text) to authenticated;
