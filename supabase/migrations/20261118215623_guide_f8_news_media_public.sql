-- F8 · La foto de una noticia publicada es pública y cuenta como uso del medio.
-- Bug: guide.media_is_public no tenía rama para guide.news, así que anon no leía la fila de guide.media
-- de la foto de una noticia publicada. Se añade news de forma coherente en todo lo que enumera usos:
--   · media_is_public: noticia publicada (status = 'published').
--   · media_usage (vista del panel: contador, filtros in_use/unused, «usado en», delete_media): owner 'news'.
--   · media_usages: owner_table 'news', role 'cover'.
--   · media_committed_owners (guarda D27 al vaciar alt): noticia publicada exige alt_es (no alt_en),
--     igual que news_before_write al publicar con foto (news_media_alt).
-- No aplica: content_media_refs (news no tiene cuerpo enriquecido), policies de storage (bucket media
-- público; ninguna policy usa media_is_public) y media_before_delete (news.media_id ya es FK RESTRICT).
-- Idempotente: create or replace + grants explícitos.

create or replace function guide.media_is_public(p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from guide.articles a
                 where (a.cover_media_id = p_id or a.og_media_id = p_id)
                   and guide.article_is_live(a.status, a.published_at))
      or exists (select 1 from guide.items i
                 where (i.cover_media_id = p_id or i.og_media_id = p_id) and i.published)
      or exists (select 1 from guide.item_media im join guide.items i on i.id = im.item_id
                 where im.media_id = p_id and i.published)
      or exists (select 1 from guide.pages p where p.og_media_id = p_id and p.published)
      or exists (select 1 from guide.site_settings s
                 where p_id in (s.default_og_media_id, s.hero_photo_1_media_id, s.hero_photo_2_media_id,
                              s.author_photo_media_id))
      or exists (select 1 from guide.authors au where au.photo_media_id = p_id)
      or exists (select 1 from guide.news n where n.media_id = p_id and n.status = 'published')
      or exists (select 1 from guide.content_media_refs r
                 where r.media_id = p_id
                   and case r.owner_table
                         when 'articles' then exists (select 1 from guide.articles a
                                                      where a.id = r.owner_id and guide.article_is_live(a.status, a.published_at))
                         when 'pages' then exists (select 1 from guide.pages p where p.id = r.owner_id and p.published)
                         when 'author_reviews' then exists (select 1 from guide.author_reviews ar
                                                            join guide.items i on i.id = ar.item_id
                                                            where ar.id = r.owner_id and i.published)
                         else false
                       end);
$$;
revoke all on function guide.media_is_public(uuid) from public;
grant execute on function guide.media_is_public(uuid) to anon, authenticated;

-- ───────────── Medio en uso ─────────────
-- with (security_invoker = true) es obligatorio: create or replace view sustituye las opciones de la vista.
create or replace view guide.media_usage with (security_invoker = true) as
select distinct media_id, usage_table, usage_id, usage_field, label
from (
  select a.cover_media_id as media_id, 'articles'::text as usage_table, a.id::text as usage_id,
         'cover_media_id'::text as usage_field, a.title_es as label
  from guide.articles a where a.cover_media_id is not null
  union all
  select a.og_media_id, 'articles', a.id::text, 'og_media_id', a.title_es
  from guide.articles a where a.og_media_id is not null
  union all
  select p.og_media_id, 'pages', p.id::text, 'og_media_id', p.title_es
  from guide.pages p where p.og_media_id is not null
  union all
  select i.cover_media_id, 'items', i.id::text, 'cover_media_id', i.name
  from guide.items i where i.cover_media_id is not null
  union all
  select i.og_media_id, 'items', i.id::text, 'og_media_id', i.name
  from guide.items i where i.og_media_id is not null
  union all
  select im.media_id, 'item_media', im.item_id::text, 'gallery', i.name
  from guide.item_media im join guide.items i on i.id = im.item_id
  union all
  select s.default_og_media_id, 'site_settings', s.id::text, 'default_og_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.default_og_media_id is not null
  union all
  select s.hero_photo_1_media_id, 'site_settings', s.id::text, 'hero_photo_1_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.hero_photo_1_media_id is not null
  union all
  select s.hero_photo_2_media_id, 'site_settings', s.id::text, 'hero_photo_2_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.hero_photo_2_media_id is not null
  union all
  select s.author_photo_media_id, 'site_settings', s.id::text, 'author_photo_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.author_photo_media_id is not null
  union all
  select au.photo_media_id, 'authors', au.id::text, 'photo_media_id', au.name
  from guide.authors au where au.photo_media_id is not null
  union all
  select n.media_id, 'news', n.id::text, 'media_id', n.title_es
  from guide.news n where n.media_id is not null
  union all
  select r.media_id, r.owner_table, r.owner_id::text, 'body_' || r.locale::text,
         coalesce(a.title_es, p.title_es, i.name)
  from guide.content_media_refs r
  left join guide.articles a on r.owner_table = 'articles' and a.id = r.owner_id
  left join guide.pages p on r.owner_table = 'pages' and p.id = r.owner_id
  left join guide.author_reviews ar on r.owner_table = 'author_reviews' and ar.id = r.owner_id
  left join guide.items i on i.id = ar.item_id
  union all
  select m.id, 'articles', a.id::text, l.field, a.title_es
  from guide.media m
  join guide.articles a on true
  cross join lateral (values ('body_es', a.body_html_es), ('body_en', a.body_html_en)) as l(field, html)
  where strpos(l.html, m.storage_path) > 0
  union all
  select m.id, 'pages', p.id::text, l.field, p.title_es
  from guide.media m
  join guide.pages p on true
  cross join lateral (values ('body_es', p.body_html_es), ('body_en', p.body_html_en)) as l(field, html)
  where strpos(l.html, m.storage_path) > 0
  union all
  select m.id, 'author_reviews', ar.id::text, l.field, i.name
  from guide.media m
  join guide.author_reviews ar on true
  join guide.items i on i.id = ar.item_id
  cross join lateral (values ('body_es', ar.body_html_es), ('body_en', ar.body_html_en)) as l(field, html)
  where strpos(l.html, m.storage_path) > 0
  union all
  select dm.media_id,
         case d.entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end,
         d.entity_id::text, 'draft', coalesce(a.title_es, p.title_es, i.name)
  from guide.content_drafts d
  cross join lateral (
    select x from unnest(guide.draft_media_ids(d.payload)) as x
    union
    select m.id from guide.media m where strpos(d.payload::text, m.storage_path) > 0
  ) as dm(media_id)
  left join guide.articles a on a.id = d.article_id
  left join guide.pages p on p.id = d.page_id
  left join guide.items i on i.id = d.item_id
) u
where (select guide.is_admin());

revoke all on guide.media_usage from public, anon;
grant select on guide.media_usage to authenticated, service_role;

-- owner_table 'news', owner_id = id de la noticia, role 'cover' (la foto de la noticia).
create or replace function guide.media_usages(p_id uuid)
returns table (owner_table text, owner_id uuid, item_category text, label text, role text)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  return query
  select distinct
         case when u.usage_table in ('item_media', 'author_reviews') then 'items' else u.usage_table end,
         case when u.usage_table = 'site_settings' then null else coalesce(ar.item_id, u.usage_id::uuid) end,
         i.category::text,
         coalesce(i.name, u.label),
         case
           when u.usage_table = 'author_reviews' then 'review_' || u.usage_field
           when u.usage_field = 'cover_media_id' then 'cover'
           when u.usage_table = 'news' and u.usage_field = 'media_id' then 'cover'
           when u.usage_field in ('og_media_id', 'default_og_media_id') then 'og'
           when u.usage_field in ('hero_photo_1_media_id', 'hero_photo_2_media_id') then 'hero'
           when u.usage_field = 'author_photo_media_id' then 'author'
           when u.usage_table = 'authors' and u.usage_field = 'photo_media_id' then 'author'
           else u.usage_field
         end
  from guide.media_usage u
  left join guide.author_reviews ar on u.usage_table = 'author_reviews' and ar.id::text = u.usage_id
  left join guide.items i on i.id::text = case
                                            when u.usage_table = 'author_reviews' then ar.item_id::text
                                            when u.usage_table in ('items', 'item_media') then u.usage_id
                                          end
  where u.media_id = p_id
  order by 1, 4, 2, 5;
end;
$$;
revoke all on function guide.media_usages(uuid) from public, anon;
grant execute on function guide.media_usages(uuid) to authenticated;

-- D27: una noticia publicada con foto exige alt_es (news_media_alt). Solo 'es': news no exige alt_en.
create or replace function guide.media_committed_owners(p_id uuid, p_lang text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('entity', o.entity, 'entity_id', o.id) order by o.entity, o.id::text), '[]'::jsonb)
  from (
    select 'article'::text as entity, to_jsonb(a.id) as id
    from guide.articles a
    where a.status in ('scheduled', 'published')
      and (p_lang || ':' || p_id::text) = any (guide.content_alt_reqs(a.cover_media_id, a.og_media_id, a.body_json_es,
                                                 a.body_html_es, a.body_json_en, a.body_html_en, a.has_en, a.has_en))
    union all
    select 'page', to_jsonb(p.id)
    from guide.pages p
    where p.published
      and (p_lang || ':' || p_id::text) = any (guide.content_alt_reqs(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                                 p.body_json_en, p.body_html_en, p.has_en, p.has_en))
    union all
    select 'item', to_jsonb(i.id)
    from guide.items i
    where i.published
      and (p_lang || ':' || p_id::text) = any (guide.item_alt_reqs(i.id, i.cover_media_id, i.og_media_id, i.has_en))
    union all
    select 'site_settings', to_jsonb(s.id)
    from guide.site_settings s
    where p_id in (s.default_og_media_id, s.hero_photo_1_media_id, s.hero_photo_2_media_id, s.author_photo_media_id)
      and p_lang in ('es', 'en')
    union all
    select 'author', to_jsonb(au.id)
    from guide.authors au
    where au.photo_media_id = p_id
      and p_lang in ('es', 'en')
    union all
    select 'news', to_jsonb(n.id)
    from guide.news n
    where n.media_id = p_id
      and n.status = 'published'
      and p_lang = 'es'
  ) o;
$$;
revoke all on function guide.media_committed_owners(uuid, text) from public, anon;
grant execute on function guide.media_committed_owners(uuid, text) to authenticated, service_role;
