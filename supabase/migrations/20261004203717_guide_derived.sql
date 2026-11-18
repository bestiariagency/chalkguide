-- F2.7 · Derivados: índices de gimnasio, promedios de usuarios (≥ N opiniones), notas del autor,
-- uso de medios, exportaciones y estadísticas del panel. Todas las vistas con security_invoker.

-- ───────────── Funciones ─────────────
create or replace function guide.item_is_en_ready(p_item_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select i.has_en and coalesce((select r.has_en from guide.author_reviews r where r.item_id = i.id), true)
  from guide.items i
  where i.id = p_item_id;
$$;
revoke execute on function guide.item_is_en_ready(uuid) from public;
grant execute on function guide.item_is_en_ready(uuid) to anon, authenticated, service_role;

-- ───────────── Vistas públicas ─────────────
-- Promedios de usuarios: solo con review_count >= site_settings.min_user_reviews_for_average (3).
create or replace view guide.item_user_ratings with (security_invoker = true) as
with settings as (
  select coalesce((select s.min_user_reviews_for_average from guide.site_settings s where s.id = 1), 3) as min_n
),
visible as (
  select ur.id, ur.item_id from guide.user_reviews ur where ur.status = 'visible'
),
counts as (
  select v.item_id, count(*)::integer as review_count from visible v group by v.item_id
),
overall as (
  select v.item_id, round(avg(sc.score), 2) as avg_overall
  from visible v join guide.user_review_scores sc on sc.review_id = v.id
  group by v.item_id
),
by_criterion as (
  select x.item_id, jsonb_object_agg(x.key, x.avg_score) as avg_by_criterion
  from (
    select v.item_id, c.key, round(avg(sc.score), 2) as avg_score
    from visible v
    join guide.user_review_scores sc on sc.review_id = v.id
    join guide.criteria c on c.id = sc.criterion_id
    group by v.item_id, c.key
  ) x
  group by x.item_id
)
select
  c.item_id,
  c.review_count,
  case when c.review_count >= s.min_n then o.avg_overall end as avg_overall,
  case when c.review_count >= s.min_n then b.avg_by_criterion end as avg_by_criterion
from counts c
cross join settings s
left join overall o on o.item_id = c.item_id
left join by_criterion b on b.item_id = c.item_id;

create or replace view guide.item_author_scores with (security_invoker = true) as
select
  r.item_id,
  c.id as criterion_id,
  c.key as criterion_key,
  c.name_es,
  c.name_en,
  c.sort_order,
  s.score,
  round(avg(s.score) over (partition by r.item_id), 2) as avg_overall
from guide.author_reviews r
join guide.author_review_scores s on s.review_id = r.id
join guide.criteria c on c.id = s.criterion_id;

-- Índices de rocódromo (fórmulas aprobadas en P3, docs/data-model.md §4).
create or replace view guide.gym_indices with (security_invoker = true) as
with base as (
  select
    g.item_id,
    least(
      g.price_monthly_eur + coalesce(g.price_registration_eur, 0) / 12,
      g.price_day_eur * (104.0 / 12),
      g.price_10_pass_eur / 10 * (104.0 / 12)
    ) as monthly_cost,
    g.has_beginner_courses, g.gear_rental, g.belay_test_required, g.has_boulder,
    g.has_kids_area, g.kids_min_age, g.has_cafe,
    (select s.score from guide.author_reviews r
       join guide.author_review_scores s on s.review_id = r.id
       join guide.criteria c on c.id = s.criterion_id
     where r.item_id = g.item_id and c.key = 'beginner_friendly') as beginner_score,
    (select s.score from guide.author_reviews r
       join guide.author_review_scores s on s.review_id = r.id
       join guide.criteria c on c.id = s.criterion_id
     where r.item_id = g.item_id and c.key = 'family_friendly') as family_score
  from guide.gyms g
  join guide.items i on i.id = g.item_id and i.published
),
weighted as (
  select
    b.*,
    0.50 * coalesce((b.beginner_score - 1) / 4.0, 0)
      + 0.20 * (coalesce(b.has_beginner_courses, false))::int
      + 0.15 * (coalesce(b.gear_rental, false))::int
      + 0.15 * (coalesce(not b.belay_test_required or b.has_boulder, false))::int as beginner_w,
    (0.40 * (coalesce(b.has_kids_area, false))::int
      + 0.20 * (coalesce(b.kids_min_age <= 6, false))::int
      + 0.20 * (coalesce(b.has_cafe, false))::int
      + 0.20 * coalesce((b.family_score - 1) / 4.0, 0))
      / case when b.family_score is null then 0.8 else 1.0 end as family_w
  from base b
)
select
  w.item_id,
  round(w.monthly_cost, 2) as monthly_cost_2pw_eur,
  case when w.monthly_cost is not null
       then (6 - ntile(5) over (partition by (w.monthly_cost is null) order by w.monthly_cost))::smallint
  end as price_index,
  round(1 + 4 * w.beginner_w, 1) as beginner_index,
  (w.beginner_score is not null and w.has_beginner_courses is not null and w.gear_rental is not null
     and w.belay_test_required is not null and w.has_boulder is not null) as beginner_index_complete,
  round(1 + 4 * w.family_w, 1) as family_index
from weighted w;

-- ───────────── Vistas del panel (admin) ─────────────
create or replace view guide.media_usage with (security_invoker = true) as
select u.media_id, u.usage_table, u.usage_id, u.usage_field, u.label
from (
  select a.cover_media_id as media_id, 'articles'::text as usage_table, a.id::text as usage_id, 'cover_media_id'::text as usage_field, a.title_es as label
  from guide.articles a where a.cover_media_id is not null
  union all
  select a.og_media_id, 'articles', a.id::text, 'og_media_id', a.title_es from guide.articles a where a.og_media_id is not null
  union all
  select p.og_media_id, 'pages', p.id::text, 'og_media_id', p.title_es from guide.pages p where p.og_media_id is not null
  union all
  select i.cover_media_id, 'items', i.id::text, 'cover_media_id', i.name from guide.items i where i.cover_media_id is not null
  union all
  select i.og_media_id, 'items', i.id::text, 'og_media_id', i.name from guide.items i where i.og_media_id is not null
  union all
  select im.media_id, 'item_media', im.item_id::text, 'gallery', i.name
  from guide.item_media im join guide.items i on i.id = im.item_id
  union all
  select s.default_og_media_id, 'site_settings', s.id::text, 'default_og_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.default_og_media_id is not null
  union all
  select r.media_id, r.owner_table, r.owner_id::text, 'body_' || r.locale::text,
         coalesce(a.title_es, p.title_es, i.name)
  from guide.content_media_refs r
  left join guide.articles a on r.owner_table = 'articles' and a.id = r.owner_id
  left join guide.pages p on r.owner_table = 'pages' and p.id = r.owner_id
  left join guide.author_reviews ar on r.owner_table = 'author_reviews' and ar.id = r.owner_id
  left join guide.items i on i.id = ar.item_id
) u
where (select guide.is_admin());

create or replace view guide.media_library with (security_invoker = true) as
select m.*,
  (select count(*) from guide.media_usage u where u.media_id = m.id)::integer as usage_count
from guide.media m
where (select guide.is_admin());

create or replace view guide.export_articles with (security_invoker = true) as
select a.id, a.status, a.published_at, c.name_es as category_es, a.title_es, a.title_en, a.slug_es, a.slug_en,
  a.excerpt_es, a.excerpt_en, a.is_featured, a.sort_order, a.reading_minutes_es, a.reading_minutes_en,
  a.seo_title_es, a.seo_title_en, a.seo_description_es, a.seo_description_en, a.noindex, a.has_en,
  a.created_at, a.updated_at
from guide.articles a
join guide.article_categories c on c.id = a.category_id
where (select guide.is_admin());

create or replace view guide.export_items with (security_invoker = true) as
select i.id, i.category, i.name, i.slug, i.published, i.published_at, i.verified_at, i.source, i.source_url,
  i.summary_es, i.summary_en, i.has_en,
  coalesce(to_jsonb(g), to_jsonb(r), to_jsonb(s), i.attributes) - 'item_id' - 'category' - 'created_at' - 'updated_at' as details,
  i.created_at, i.updated_at
from guide.items i
left join guide.gyms g on g.item_id = i.id
left join guide.resolers r on r.item_id = i.id
left join guide.shoes s on s.item_id = i.id
where (select guide.is_admin());

create or replace view guide.export_user_reviews with (security_invoker = true) as
select ur.id, ur.item_id, i.name as item_name, ur.category, p.display_name, ur.status, ur.locale, ur.body,
  (select jsonb_object_agg(c.key, sc.score)
     from guide.user_review_scores sc join guide.criteria c on c.id = sc.criterion_id
    where sc.review_id = ur.id) as scores,
  ur.created_at, ur.edited_at, ur.moderated_at
from guide.user_reviews ur
join guide.items i on i.id = ur.item_id
left join guide.user_profiles p on p.user_id = ur.user_id
where (select guide.is_admin());

create or replace view guide.export_subscribers with (security_invoker = true) as
select s.id, s.email, s.status, s.locale, s.consent_at, s.consent_source, s.consent_version, s.consent_page,
  s.confirmed_at, s.unsubscribed_at, s.unsubscribe_source, s.created_at
from guide.subscribers s
where (select guide.is_admin());

create or replace view guide.export_events with (security_invoker = true) as
select e.id, e.status, e.source, e.event_type, e.title_es, e.title_en, e.starts_at, e.ends_at, e.all_day,
  i.name as place_name, e.location_text, e.url, e.price_text, e.source_url, e.approved_at, e.created_at
from guide.events e
left join guide.items i on i.id = e.item_id
where (select guide.is_admin());

-- ───────────── Estadísticas del panel ─────────────
create or replace function guide.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform guide.assert_admin();
  select jsonb_build_object(
    'articles_by_status', (
      select coalesce(jsonb_object_agg(x.status, x.n), '{}'::jsonb)
      from (select status::text, count(*) as n from guide.articles group by status) x
    ),
    'articles_scheduled_next', (
      select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title_es', a.title_es, 'published_at', a.published_at)
                                order by a.published_at), '[]'::jsonb)
      from (select id, title_es, published_at from guide.articles
            where status = 'scheduled' and published_at > now() order by published_at limit 5) a
    ),
    'subscribers_active', (select count(*) from guide.subscribers where status = 'active'),
    'subscribers_pending', (select count(*) from guide.subscribers where status = 'pending'),
    'subscribers_total', (select count(*) from guide.subscribers),
    'subscribers_new_30d', (select count(*) from guide.subscribers where created_at >= now() - interval '30 days'),
    'subscribers_new_prev_30d', (select count(*) from guide.subscribers
                                 where created_at >= now() - interval '60 days' and created_at < now() - interval '30 days'),
    'unsubscribed_30d', (select count(*) from guide.subscribers where unsubscribed_at >= now() - interval '30 days'),
    'user_reviews_pending', (select count(*) from guide.user_reviews where status = 'pending'),
    'user_reviews_hidden', (select count(*) from guide.user_reviews where status = 'hidden'),
    'user_reviews_30d', (select count(*) from guide.user_reviews where created_at >= now() - interval '30 days'),
    'items_stale', (select count(*) from guide.items
                    where published and (verified_at is null or verified_at < current_date - interval '6 months')),
    'events_drafts', (select count(*) from guide.events where status = 'draft'),
    'media_without_alt', (select count(*) from guide.media where alt_es is null or btrim(alt_es) = ''),
    'recent_activity', (
      select coalesce(jsonb_agg(to_jsonb(l) - 'old_row' order by l.occurred_at desc), '[]'::jsonb)
      from (select * from guide.activity_log order by occurred_at desc limit 10) l
    )
  ) into v;
  return v;
end;
$$;

create or replace function guide.admin_timeseries(p_metric text, p_from date, p_to date, p_bucket text default 'day')
returns table (bucket date, value bigint)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_metric is null or p_metric not in ('subscribers_new', 'subscribers_total', 'articles_published', 'user_reviews') then
    raise exception 'invalid metric' using errcode = '22023';
  end if;
  if p_bucket not in ('day', 'week', 'month') then
    raise exception 'invalid bucket' using errcode = '22023';
  end if;
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid range' using errcode = '22023';
  end if;

  return query
  with buckets as (
    select gs::date as b,
           (gs + ('1 ' || p_bucket)::interval) as b_end
    from generate_series(date_trunc(p_bucket, p_from::timestamp), p_to::timestamp, ('1 ' || p_bucket)::interval) gs
  )
  select bk.b,
    case p_metric
      when 'subscribers_new' then
        (select count(*) from guide.subscribers s where s.created_at >= bk.b and s.created_at < bk.b_end)
      when 'subscribers_total' then
        (select count(*) from guide.subscribers s
          where s.confirmed_at < bk.b_end and (s.unsubscribed_at is null or s.unsubscribed_at >= bk.b_end))
      when 'articles_published' then
        (select count(*) from guide.articles a
          where a.status in ('scheduled', 'published') and a.published_at >= bk.b and a.published_at < bk.b_end
            and a.published_at <= now())
      when 'user_reviews' then
        (select count(*) from guide.user_reviews r where r.created_at >= bk.b and r.created_at < bk.b_end)
      else null
    end
  from buckets bk
  order by bk.b;
end;
$$;

-- ───────────── Grants ─────────────
grant select on guide.item_user_ratings, guide.item_author_scores, guide.gym_indices to anon, authenticated;
grant select on guide.media_usage, guide.media_library, guide.export_articles, guide.export_items,
  guide.export_user_reviews, guide.export_subscribers, guide.export_events to authenticated;
grant select on guide.item_user_ratings, guide.item_author_scores, guide.gym_indices, guide.media_usage,
  guide.media_library, guide.export_articles, guide.export_items, guide.export_user_reviews,
  guide.export_subscribers, guide.export_events to service_role;

revoke execute on function guide.admin_dashboard_stats() from public, anon;
grant execute on function guide.admin_dashboard_stats() to authenticated, service_role;
revoke execute on function guide.admin_timeseries(text, date, date, text) from public, anon;
grant execute on function guide.admin_timeseries(text, date, date, text) to authenticated, service_role;
