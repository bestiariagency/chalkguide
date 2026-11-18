-- D55 (Inicio v2, docs/design/admin/README.md §14.8): campos nuevos y opcionales en admin_dashboard_stats.
-- Se conservan todos los campos anteriores con la misma forma. Sigue siendo SECURITY INVOKER + assert_admin().
-- Los desgloses por categoría salen de guide.item_categories (todas las claves, con 0): sumar una categoría
-- es configuración. recent_activity no cambia (observación 6.19 pendiente de decisión).
create or replace function guide.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  v      jsonb;
  v_seen timestamptz;
begin
  perform guide.assert_admin();
  select a.reviews_seen_at into v_seen from guide.admins a where a.user_id = (select auth.uid());

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
    -- D55 (5): mismas reglas que admin_reviews_summary.new_since_seen, con nota global <= 2.
    'user_reviews_low_since', (
      select count(*) from guide.user_reviews r
      where r.overall_score <= 2
        and r.status <> 'hidden'
        and (v_seen is null or coalesce(r.edited_at, r.created_at) > v_seen)
        and (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at))
    ),
    -- D55 (3): mismo recuento que admin_reviews_summary.photos_pending.
    'review_photos_pending', (select count(*) from guide.user_review_photos where status = 'pending'),
    'items_stale', (select count(*) from guide.items
                    where published and (verified_at is null or verified_at < current_date - interval '6 months')),
    -- D55 (2)
    'items_stale_by_category', (
      select coalesce(jsonb_object_agg(c.key, coalesce(x.n, 0)), '{}'::jsonb)
      from guide.item_categories c
      left join (select category, count(*) as n from guide.items
                 where published and (verified_at is null or verified_at < current_date - interval '6 months')
                 group by category) x on x.category = c.key
    ),
    -- D55: KPI «Fichas publicadas» (sustituye a «Fichas por verificar»).
    'items_published', (select count(*) from guide.items where published),
    'items_published_by_category', (
      select coalesce(jsonb_object_agg(c.key, coalesce(x.n, 0)), '{}'::jsonb)
      from guide.item_categories c
      left join (select category, count(*) as n from guide.items where published group by category) x
        on x.category = c.key
    ),
    'items_total_by_category', (
      select coalesce(jsonb_object_agg(c.key, coalesce(x.n, 0)), '{}'::jsonb)
      from guide.item_categories c
      left join (select category, count(*) as n from guide.items group by category) x on x.category = c.key
    ),
    -- D55 (4): fichas creadas por un lote de importación (sin deshacer) que siguen sin publicar.
    'items_imported_unpublished', (
      select count(distinct i.id) from guide.import_batch_items bi
      join guide.items i on i.id = bi.item_id
      where bi.action = 'created' and bi.undone_at is null and not i.published
    ),
    'items_imported_unpublished_by_category', (
      select coalesce(jsonb_object_agg(c.key, coalesce(x.n, 0)), '{}'::jsonb)
      from guide.item_categories c
      left join (select i.category, count(distinct i.id) as n from guide.import_batch_items bi
                 join guide.items i on i.id = bi.item_id
                 where bi.action = 'created' and bi.undone_at is null and not i.published
                 group by i.category) x on x.category = c.key
    ),
    'events_drafts', (select count(*) from guide.events e
                      where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    -- D55 (1): fecha del primer evento por aprobar (null si no hay).
    'events_drafts_next_at', (select min(e.starts_at) from guide.events e
                              where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    -- D55 (7): borradores por aprobar con agent_meta.duplicate_of que apunta a otro evento existente
    -- (la misma regla que admin_list_events.duplicate_of).
    'events_drafts_duplicates', (
      select count(*) from guide.events e
      join guide.events d
        on (e.agent_meta ->> 'duplicate_of') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       and d.id = (e.agent_meta ->> 'duplicate_of')::uuid and d.id <> e.id
      where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)
    ),
    'events_drafts_expired', (select count(*) from guide.events e
                              where e.status = 'draft' and guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    'media_without_alt', (select count(*) from guide.media where alt_es is null or btrim(alt_es) = ''),
    -- D55 (6): de las fotos sin alt_es, cuántas tienen algún uso en media_usage (incluye borradores; D27 ya
    -- impide publicar sin alt_es, así que «en publicado» sería casi siempre 0).
    'media_without_alt_in_use', (
      select count(*) from guide.media m
      where (m.alt_es is null or btrim(m.alt_es) = '')
        and exists (select 1 from guide.media_usage u where u.media_id = m.id)
    ),
    'recent_activity', (
      select coalesce(jsonb_agg(to_jsonb(l) - 'old_row' order by l.occurred_at desc), '[]'::jsonb)
      from (select * from guide.activity_log order by occurred_at desc limit 10) l
    )
  ) into v;
  return v;
end;
$function$;
