-- D41 · Fotos del carrusel del hero de la home: dos medios elegidos desde Ajustes.
-- Igual que default_og_media_id en lectura pública, "medio en uso" y alt obligatorio, salvo el borrado:
-- on delete set null (no restrict) para que guide_dummy_purge.sql pueda retirar las fotos de ejemplo sin tocar ajustes.
-- Desde el panel el borrado sigue bloqueado: delete_media rechaza cualquier medio presente en media_usage.

-- ───────────── Columnas ─────────────
alter table guide.site_settings
  add column if not exists hero_photo_1_media_id uuid references guide.media (id) on delete set null,
  add column if not exists hero_photo_2_media_id uuid references guide.media (id) on delete set null;

create index if not exists site_settings_hero_photo_1_media_id_idx on guide.site_settings (hero_photo_1_media_id);
create index if not exists site_settings_hero_photo_2_media_id_idx on guide.site_settings (hero_photo_2_media_id);

-- ───────────── Lectura pública ─────────────
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
                 where p_id in (s.default_og_media_id, s.hero_photo_1_media_id, s.hero_photo_2_media_id))
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
           when u.usage_field in ('og_media_id', 'default_og_media_id') then 'og'
           when u.usage_field in ('hero_photo_1_media_id', 'hero_photo_2_media_id') then 'hero'
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

-- ───────────── Alt obligatorio (D27) ─────────────
-- La home es bilingüe: alt_es y alt_en, como la OG por defecto. Solo se comprueba la columna que cambia.
create or replace function guide.site_settings_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ids     uuid[];
  v_reqs    text[];
  v_missing text[];
begin
  if guide.alt_guard_bypassed() then
    return new;
  end if;
  v_ids := array_remove(array[
    case when tg_op = 'INSERT' or new.default_og_media_id is distinct from old.default_og_media_id then new.default_og_media_id end,
    case when tg_op = 'INSERT' or new.hero_photo_1_media_id is distinct from old.hero_photo_1_media_id then new.hero_photo_1_media_id end,
    case when tg_op = 'INSERT' or new.hero_photo_2_media_id is distinct from old.hero_photo_2_media_id then new.hero_photo_2_media_id end
  ], null);
  if cardinality(v_ids) = 0 then
    return new;
  end if;
  select array_agg(l || ':' || x::text) into v_reqs
  from unnest(v_ids) x cross join (values ('es'), ('en')) as langs(l);
  v_missing := guide.alt_reqs_missing(v_reqs);
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('site_settings', null, v_missing, jsonb_build_object('setting_id', new.id));
  end if;
  return new;
end;
$$;

drop trigger if exists site_settings_require_alt on guide.site_settings;
create trigger site_settings_require_alt
  after insert or update of default_og_media_id, hero_photo_1_media_id, hero_photo_2_media_id on guide.site_settings
  for each row execute function guide.site_settings_require_alt();

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
    where p_id in (s.default_og_media_id, s.hero_photo_1_media_id, s.hero_photo_2_media_id) and p_lang in ('es', 'en')
  ) o;
$$;

-- ───────────── Fotos de ejemplo ─────────────
-- Por storage_path: si no existe queda NULL. coalesce: repetir la migración no pisa lo elegido en el panel.
update guide.site_settings s
set hero_photo_1_media_id = coalesce(s.hero_photo_1_media_id,
      (select m.id from guide.media m where m.storage_path = 'd0d0d0d0-000a-4000-8000-000000000002/1-pared-roja-desplomada.jpg')),
    hero_photo_2_media_id = coalesce(s.hero_photo_2_media_id,
      (select m.id from guide.media m where m.storage_path = 'd0d0d0d0-000a-4000-8000-000000000004/1-techo-roca-mar.jpg'))
where s.id = 1
  and (s.hero_photo_1_media_id is null or s.hero_photo_2_media_id is null);
