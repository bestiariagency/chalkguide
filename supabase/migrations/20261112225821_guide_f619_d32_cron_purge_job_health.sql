-- F6.19 punto 8 (D32, O1 y O2; docs/security/F6.19-panel-review.md). Idempotente.
-- O1: job semanal guide-cron-history-purge (domingo 04:00 UTC, como postgres) que borra de cron.job_run_details lo
--     terminado hace más de 30 días.
-- O2: «succeeded» en cron solo dice que la petición quedó encolada y pg_net borra sus respuestas a las 6 h, así que un
--     401 de review-photos-cleanup pasaba desapercibido. Ahora:
--     · guide.job_health (una fila por job): run_review_photos_cleanup guarda el request_id de net.http_post (null si
--       no hay secreto, y eso también avisa);
--     · guide.check_review_photos_cleanup() (INVOKER, solo postgres) copia a las 03:20 el status_code de
--       net._http_response para ese id (null si no hay respuesta: caducada, timeout o job sin ejecutar);
--     · admin_dashboard_stats añade cleanup_last_status y cleanup_checked_at (aditivo; resto sin cambios).
--     RLS en job_health: SELECT solo admin; ninguna escritura desde la API (solo postgres por las funciones del job).

-- ───────────── O1 ─────────────
-- cron.schedule con el mismo nombre actualiza el job (idempotente).
select cron.schedule('guide-cron-history-purge', '0 4 * * 0',
  $$delete from cron.job_run_details where end_time < now() - interval '30 days'$$);

-- ───────────── O2 ─────────────
create table if not exists guide.job_health (
  job         text primary key,
  request_id  bigint,
  checked_at  timestamptz,
  status_code integer
);
alter table guide.job_health enable row level security;
revoke all on guide.job_health from public, anon, authenticated, service_role;
grant select on guide.job_health to authenticated;
drop policy if exists job_health_select on guide.job_health;
create policy job_health_select on guide.job_health for select to authenticated using ((select guide.is_admin()));

create or replace function guide.run_review_photos_cleanup()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_id     bigint;
begin
  select ds.decrypted_secret into v_secret
  from vault.decrypted_secrets ds
  where ds.name = 'review_photos_cleanup_secret'
  limit 1;
  if v_secret is not null and char_length(v_secret) >= 32 then
    select net.http_post(
             url := 'https://eqtjlafxtrzbjazhhyin.supabase.co/functions/v1/review-photos-cleanup',
             body := '{}'::jsonb,
             headers := jsonb_build_object('Content-Type', 'application/json', 'x-cleanup-secret', v_secret),
             timeout_milliseconds := 60000)
      into v_id;
  end if;
  -- Sin secreto configurado no llama a nada y deja request_id null: la comprobación de las 03:20 lo marcará.
  insert into guide.job_health (job, request_id) values ('review-photos-cleanup', v_id)
  on conflict (job) do update set request_id = excluded.request_id;
  return v_id;
end;
$$;
revoke all on function guide.run_review_photos_cleanup() from public, anon, authenticated, service_role;

create or replace function guide.check_review_photos_cleanup()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_req    bigint;
  v_status integer;
begin
  select h.request_id into v_req from guide.job_health h where h.job = 'review-photos-cleanup';
  if v_req is not null then
    select r.status_code into v_status from net._http_response r where r.id = v_req;
  end if;
  insert into guide.job_health (job, request_id, checked_at, status_code)
  values ('review-photos-cleanup', v_req, now(), v_status)
  on conflict (job) do update set checked_at = excluded.checked_at, status_code = excluded.status_code;
  return v_status;
end;
$$;
revoke all on function guide.check_review_photos_cleanup() from public, anon, authenticated, service_role;

-- 03:20 UTC: 20 min después de la llamada de las 03:00 (timeout de 60 s), antes de que pg_net purgue la respuesta (6 h).
select cron.schedule('guide-review-photos-cleanup-check', '20 3 * * *', $$select guide.check_review_photos_cleanup()$$);

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
    -- D55 (7): borradores por aprobar marcados como posible duplicado de otro evento existente.
    'events_drafts_duplicates', (
      select count(*) from guide.admin_events_agent_info(array(
        select e.id from guide.events e
        where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)
      )) x
      where x.duplicate_of is not null
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
    -- F6.19 / D32 O2: última comprobación del job de limpieza de fotos (guide.job_health; RLS: solo admin).
    -- El panel avisa si cleanup_last_status no es 200 o si cleanup_checked_at es null o tiene más de 48 h.
    'cleanup_last_status', (select h.status_code from guide.job_health h where h.job = 'review-photos-cleanup'),
    'cleanup_checked_at', (select h.checked_at from guide.job_health h where h.job = 'review-photos-cleanup'),
    'recent_activity', (
      select coalesce(jsonb_agg((to_jsonb(l) - 'old_row' - 'actor_id')
                                || jsonb_build_object('entity_label', guide.activity_safe_label(l.entity_table, l.entity_label),
                                                      'details', guide.activity_safe_details(l.entity_table, l.details))
                                order by l.occurred_at desc), '[]'::jsonb)
      from (select * from guide.activity_log order by occurred_at desc limit 10) l
    )
  ) into v;
  return v;
end;
$function$;
