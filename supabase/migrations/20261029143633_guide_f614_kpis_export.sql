-- F6.14 (D35) · Suscriptores, parte 9: KPIs y exportación.
-- · admin_dashboard_stats: altas de 30 días por confirmed_at (solo cuenta quien confirmó); total sin suprimidos.
-- · admin_timeseries: subscribers_total desde subscriber_consent_events (último evento de estado antes del cierre de
--   cada tramo = confirm), porque confirmed_at/unsubscribed_at se limpian al re-suscribir; subscribers_new = eventos
--   confirm del tramo (misma definición que el KPI).
-- · export_subscribers excluye a los suprimidos.
-- Idempotente.

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
    'subscribers_total', (select count(*) from guide.subscribers where status <> 'erased'),
    'subscribers_new_30d', (select count(*) from guide.subscribers where confirmed_at >= now() - interval '30 days'),
    'subscribers_new_prev_30d', (select count(*) from guide.subscribers
                                 where confirmed_at >= now() - interval '60 days' and confirmed_at < now() - interval '30 days'),
    'unsubscribed_30d', (select count(*) from guide.subscribers where unsubscribed_at >= now() - interval '30 days'),
    'user_reviews_pending', (select count(*) from guide.user_reviews where status = 'pending'),
    'user_reviews_hidden', (select count(*) from guide.user_reviews where status = 'hidden'),
    'user_reviews_30d', (select count(*) from guide.user_reviews where created_at >= now() - interval '30 days'),
    'items_stale', (select count(*) from guide.items
                    where published and (verified_at is null or verified_at < current_date - interval '6 months')),
    'events_drafts', (select count(*) from guide.events e
                      where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    'events_drafts_expired', (select count(*) from guide.events e
                              where e.status = 'draft' and guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
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
        (select count(*) from guide.subscriber_consent_events e
          where e.event = 'confirm' and e.occurred_at >= bk.b and e.occurred_at < bk.b_end)
      when 'subscribers_total' then
        (select count(*) from (
           select distinct on (e.subscriber_id) e.event
           from guide.subscriber_consent_events e
           where e.occurred_at < bk.b_end
             and e.event in ('subscribe', 'confirm', 'unsubscribe', 'bounce', 'expire', 'erase')
           order by e.subscriber_id, e.occurred_at desc, e.id desc) last_ev
         where last_ev.event = 'confirm')
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

create or replace view guide.export_subscribers with (security_invoker = true) as
select s.id, s.email, s.status, s.locale, s.consent_at, s.consent_source, s.consent_version, s.consent_page,
       s.confirmed_at, s.unsubscribed_at, s.unsubscribe_source, s.created_at
from guide.subscribers s
where (select guide.is_admin()) and s.status <> 'erased';
revoke all on guide.export_subscribers from public, anon;
grant select on guide.export_subscribers to authenticated;
