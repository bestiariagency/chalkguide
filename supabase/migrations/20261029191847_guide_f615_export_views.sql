-- F6.15 (D36) · Exportar, parte 1: vistas export_* al día con el modelo (F6.4–F6.14).
-- · export_articles: + category_id, canonical_url, has_pending_draft y el cuerpo (body_html_es/en) al final.
--   El cuerpo solo sale con with_body en JSON (lo decide admin_export, D-A).
-- · export_items: + SEO, destacado, noindex, borrador pendiente, reseña de autor (fecha y tipo de visita, aviso,
--   notas por criterio activo y media), agregados de opiniones visibles, cuerpo de la reseña al final (D-A).
-- · export_user_reviews: + item_slug, updated_at y número de fotos por estado (sin rutas ni URLs). Sigue sin
--   user_id ni email: display_name es el nombre público.
-- · export_events: + description_*, item_id, reject_reason, has_en, updated_at. Sigue en export_events_rows()
--   DEFINER porque source/source_url no se pueden leer por columna desde authenticated (F6.12). agent_meta y
--   dedupe_key no salen nunca.
-- · export_subscribers: primero las 5 columnas mínimas (§12.3) y luego la prueba de consentimiento. Sin suprimidos,
--   tokens, cuenta ni Brevo.
-- Todas: security_invoker + is_admin(), solo SELECT para authenticated. Al reordenar columnas hay que hacer drop y create.
-- Idempotente.

drop view if exists guide.export_articles;
drop view if exists guide.export_items;
drop view if exists guide.export_user_reviews;
drop view if exists guide.export_events;
drop view if exists guide.export_subscribers;
drop function if exists guide.export_events_rows();

create view guide.export_articles with (security_invoker = true) as
select a.id, a.status, a.published_at, a.category_id, c.name_es as category_es,
       a.title_es, a.title_en, a.slug_es, a.slug_en, a.excerpt_es, a.excerpt_en,
       a.is_featured, a.sort_order, a.reading_minutes_es, a.reading_minutes_en,
       a.seo_title_es, a.seo_title_en, a.seo_description_es, a.seo_description_en,
       a.noindex, a.canonical_url, a.has_en,
       exists (select 1 from guide.content_drafts d where d.article_id = a.id) as has_pending_draft,
       a.created_at, a.updated_at,
       a.body_html_es, a.body_html_en
from guide.articles a
join guide.article_categories c on c.id = a.category_id
where (select guide.is_admin());

create view guide.export_items with (security_invoker = true) as
select i.id, i.category, i.name, i.slug, i.published, i.published_at, i.is_featured, i.verified_at,
       i.source, i.source_url, i.summary_es, i.summary_en,
       i.seo_title_es, i.seo_title_en, i.seo_description_es, i.seo_description_en, i.noindex, i.has_en,
       exists (select 1 from guide.content_drafts d where d.item_id = i.id) as has_pending_draft,
       ar.visit_date, ar.visit_type, ar.disclosure_note_es, ar.disclosure_note_en,
       (select jsonb_object_agg(cr.key, s.score order by cr.sort_order)
        from guide.author_review_scores s join guide.criteria cr on cr.id = s.criterion_id
        where s.review_id = ar.id and cr.is_active) as author_scores,
       (select round(avg(s.score), 2)
        from guide.author_review_scores s join guide.criteria cr on cr.id = s.criterion_id
        where s.review_id = ar.id and cr.is_active) as author_avg,
       coalesce(ur.review_count, 0) as user_reviews_visible,
       ur.avg_overall as user_avg_overall,
       coalesce(to_jsonb(g.*), to_jsonb(r.*), to_jsonb(s.*), i.attributes)
         - 'item_id' - 'category' - 'created_at' - 'updated_at' as details,
       i.created_at, i.updated_at,
       ar.body_html_es as author_body_html_es, ar.body_html_en as author_body_html_en
from guide.items i
left join guide.gyms g on g.item_id = i.id
left join guide.resolers r on r.item_id = i.id
left join guide.shoes s on s.item_id = i.id
left join guide.author_reviews ar on ar.item_id = i.id
left join guide.item_user_ratings ur on ur.item_id = i.id
where (select guide.is_admin());

create view guide.export_user_reviews with (security_invoker = true) as
select ur.id, ur.item_id, i.name as item_name, i.slug as item_slug, ur.category,
       ur.author_name as display_name, ur.status, ur.locale, ur.overall_score,
       (select jsonb_object_agg(c.key, sc.score order by c.sort_order)
        from guide.user_review_scores sc join guide.criteria c on c.id = sc.criterion_id
        where sc.review_id = ur.id) as scores,
       ur.body,
       (select count(*)::int from guide.user_review_photos p where p.review_id = ur.id and p.status = 'approved') as photos_approved,
       (select count(*)::int from guide.user_review_photos p where p.review_id = ur.id and p.status = 'pending') as photos_pending,
       ur.created_at, ur.edited_at, ur.moderated_at, ur.updated_at
from guide.user_reviews ur
join guide.items i on i.id = ur.item_id
where (select guide.is_admin());

create function guide.export_events_rows()
returns table (id uuid, status guide.event_status, source guide.event_source, event_type text,
               title_es text, title_en text, description_es text, description_en text,
               starts_at timestamptz, ends_at timestamptz, all_day boolean,
               item_id uuid, place_name text, location_text text, url text, price_text text, source_url text,
               reject_reason text, has_en boolean, approved_at timestamptz, created_at timestamptz, updated_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.status, e.source, e.event_type, e.title_es, e.title_en, e.description_es, e.description_en,
         e.starts_at, e.ends_at, e.all_day, e.item_id, i.name, e.location_text, e.url, e.price_text, e.source_url,
         e.reject_reason, e.has_en, e.approved_at, e.created_at, e.updated_at
  from guide.events e
  left join guide.items i on i.id = e.item_id
  where (select guide.is_admin());
$$;
revoke all on function guide.export_events_rows() from public, anon;
grant execute on function guide.export_events_rows() to authenticated;

create view guide.export_events with (security_invoker = true) as
select * from guide.export_events_rows();

create view guide.export_subscribers with (security_invoker = true) as
select s.email, s.locale, s.status, s.consent_at, s.confirmed_at,
       s.id, s.consent_source, s.consent_version, s.consent_page, s.unsubscribed_at, s.unsubscribe_source, s.created_at
from guide.subscribers s
where (select guide.is_admin()) and s.status <> 'erased';

revoke all on guide.export_articles, guide.export_items, guide.export_user_reviews, guide.export_events,
              guide.export_subscribers from public, anon, authenticated;
grant select on guide.export_articles, guide.export_items, guide.export_user_reviews, guide.export_events,
                guide.export_subscribers to authenticated;
