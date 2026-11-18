-- D57 · Multiautor en el blog: guide.authors + guide.articles.author_id.
-- articles.author_id NULL = autor del sitio (columnas author_* de guide.site_settings, D51): el front no rompe y Xavi
-- sigue siendo el autor principal sin fila propia. Sobre mí sigue leyendo site_settings.
-- Lectura pública (anon/authenticated) como article_categories; escritura solo admin por RLS (insert/update/delete).
-- La foto sigue el patrón D41/D51: FK on delete set null, alt_es y alt_en obligatorios, pública mientras esté elegida
-- y «medio en uso» en media_usage/media_usages (role 'author', owner_table 'authors').
-- En artículos vivos author_id solo cambia por borrador (draft_allowed_columns → PT423 en directo). Borrar un autor
-- desasigna sus artículos (también los vivos, exención 'detach_author:<id>' solo para author_id → NULL) y sus borradores.

-- ───────────── Tabla ─────────────
create table if not exists guide.authors (
  id             uuid primary key default gen_random_uuid(),
  slug           guide.slug not null,
  name           text not null check (char_length(btrim(name)) between 1 and 80 and char_length(name) <= 80),
  role_es        text check (char_length(role_es) <= 80),
  role_en        text check (char_length(role_en) <= 80),
  bio_es         text check (char_length(bio_es) <= 160),
  bio_en         text check (char_length(bio_en) <= 160),
  photo_media_id uuid references guide.media (id) on delete set null,
  is_primary     boolean not null default false,
  sort_order     integer not null default 0,
  has_en         boolean generated always as (role_en is not null and bio_en is not null) stored,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint authors_slug_key unique (slug)
);

create unique index if not exists authors_one_primary on guide.authors ((true)) where is_primary;
create index if not exists authors_photo_media_id_idx on guide.authors (photo_media_id);
create index if not exists authors_sort_order_idx on guide.authors (sort_order, name);

alter table guide.authors enable row level security;

revoke all on guide.authors from public, anon, authenticated;
grant select on guide.authors to anon, authenticated;
grant insert, update, delete on guide.authors to authenticated;

drop policy if exists authors_select on guide.authors;
create policy authors_select on guide.authors for select to anon, authenticated using (true);
drop policy if exists authors_insert on guide.authors;
create policy authors_insert on guide.authors for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists authors_update on guide.authors;
create policy authors_update on guide.authors for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists authors_delete on guide.authors;
create policy authors_delete on guide.authors for delete to authenticated using ((select guide.is_admin()));

drop trigger if exists authors_set_updated_at on guide.authors;
create trigger authors_set_updated_at before update on guide.authors
  for each row execute function guide.set_updated_at();
drop trigger if exists authors_log_activity on guide.authors;
create trigger authors_log_activity after insert or delete or update on guide.authors
  for each row execute function guide.log_activity('id', 'name', 'true');

-- ───────────── articles.author_id ─────────────
alter table guide.articles
  add column if not exists author_id uuid references guide.authors (id) on delete set null;
create index if not exists articles_author_id_idx on guide.articles (author_id);

-- Borradores: author_id entra por save_draft/publish_draft (lo vivo no se edita en directo).
create or replace function guide.draft_allowed_columns(p_table text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case p_table
    when 'articles' then array[
      'category_id', 'title_es', 'title_en', 'slug_es', 'slug_en', 'excerpt_es', 'excerpt_en',
      'body_json_es', 'body_html_es', 'body_json_en', 'body_html_en', 'cover_media_id', 'is_featured',
      'seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en', 'og_media_id',
      'noindex', 'canonical_url', 'author_id']
    -- F6.13 (D34): sin slug_es/slug_en (rutas fijas en código); revised_on la fija la publicación, no el payload.
    when 'pages' then array[
      'title_es', 'title_en', 'body_json_es', 'body_html_es', 'body_json_en',
      'body_html_en', 'seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en',
      'og_media_id', 'noindex']
    when 'items' then array[
      'name', 'slug', 'summary_es', 'summary_en', 'cover_media_id', 'attributes', 'is_featured',
      'verified_at', 'source', 'source_url', 'seo_title_es', 'seo_title_en', 'seo_description_es',
      'seo_description_en', 'og_media_id', 'noindex']
    when 'gyms' then array[
      'address', 'city', 'district', 'postal_code', 'lat', 'lng', 'metro_stations', 'opening_hours',
      'opening_hours_note_es', 'opening_hours_note_en', 'website_url', 'instagram_url', 'phone',
      'price_registration_eur', 'price_day_eur', 'price_10_pass_eur', 'price_monthly_eur',
      'discounts_es', 'discounts_en', 'prices_verified_at', 'surface_m2', 'max_height_m', 'has_lead',
      'has_boulder', 'routes_count', 'autobelays_count', 'has_training_area', 'belay_test_required',
      'gear_rental', 'has_beginner_courses', 'has_cafe', 'serves_beer', 'has_kids_area', 'has_showers',
      'has_wifi', 'kids_min_age', 'grading_difficulty', 'setting_dynamism']
    when 'resolers' then array[
      'address', 'city', 'district', 'postal_code', 'lat', 'lng', 'website_url', 'instagram_url', 'phone',
      'price_per_pair_eur', 'price_rand_eur', 'turnaround_days_min', 'turnaround_days_max',
      'accepts_mail', 'mail_notes_es', 'mail_notes_en', 'rubber_brands', 'prices_verified_at', 'services']
    when 'shoes' then array[
      'brand', 'model', 'fit', 'profile', 'asymmetry', 'closure', 'rubber', 'rubber_thickness_mm',
      'stiffness', 'recommended_use', 'levels', 'price_min_eur', 'price_max_eur', 'price_checked_at',
      'affiliate_url', 'affiliate_program', 'owned_by_author', 'author_size_eu', 'author_street_size_eu',
      'author_size_note_es', 'author_size_note_en']
    when 'author_reviews' then array[
      'headline_es', 'headline_en', 'body_json_es', 'body_html_es', 'body_json_en', 'body_html_en',
      'visit_date', 'visit_type', 'disclosure_note_es', 'disclosure_note_en']
  end;
$$;

-- Guarda de lo vivo: añade la exención de borrar un autor (solo author_id → NULL de ese autor).
create or replace function guide.articles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_words   integer;
  v_op      text;
  v_changed text[];
begin
  if new.status = 'published' and (new.published_at is null or new.published_at > now()) then
    new.published_at := now();
  elsif new.status = 'scheduled' then
    if new.published_at is null then
      raise exception 'scheduled articles need published_at' using errcode = '23514';
    end if;
    if new.published_at <= now() then
      if tg_op = 'INSERT' or old.status is distinct from 'scheduled'
         or old.published_at is distinct from new.published_at then
        raise exception 'scheduled date must be in the future' using errcode = '23514';
      end if;
      new.status := 'published';
    end if;
  end if;

  -- Vivo antes y después (reloj del servidor): el contenido solo cambia vía borrador de cambios.
  if tg_op = 'UPDATE'
     and guide.article_is_live(old.status, old.published_at)
     and guide.article_is_live(new.status, new.published_at) then
    v_op := coalesce(current_setting('guide.draft_op', true), '');
    if v_op is distinct from 'apply:' || old.id::text and not (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
         and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)) then
      select array_agg(k order by k) into v_changed
      from unnest(guide.draft_allowed_columns('articles')) k
      where (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k);
      -- Reasignación al borrar una categoría: solo los artículos de esa categoría y solo category_id.
      -- Borrar un autor (D57): solo los artículos de ese autor y solo author_id → NULL.
      if v_changed is not null
         and not (v_op = 'reassign_category:' || old.category_id::text and v_changed = array['category_id'])
         and not (v_op = 'detach_author:' || old.author_id::text and v_changed = array['author_id']
                  and new.author_id is null) then
        raise exception 'article is live'
          using errcode = 'PT423',
                detail = 'changed: ' || array_to_string(v_changed, ', '),
                hint = 'Edit a live article through save_draft/publish_draft, or unpublish/reschedule it first.';
      end if;
    end if;
  end if;

  if tg_op = 'INSERT' or new.body_html_es is distinct from old.body_html_es then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_es := case when btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  if tg_op = 'INSERT' or new.body_html_en is distinct from old.body_html_en then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_en := case when btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  return new;
end;
$$;

-- Borrar un autor: desasigna sus artículos (vivos incluidos) y vacía author_id en los borradores que lo apuntan
-- (si no, publish_draft fallaría por FK). Invoker: solo el admin llega aquí (RLS de delete). Restaura draft_op.
create or replace function guide.authors_before_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_prev text := coalesce(current_setting('guide.draft_op', true), '');
begin
  perform set_config('guide.draft_op', 'detach_author:' || old.id::text, true);
  update guide.articles a set author_id = null where a.author_id = old.id;
  perform set_config('guide.draft_op', v_prev, true);
  update guide.content_drafts d
  set payload = jsonb_set(d.payload, '{article,author_id}', 'null'::jsonb)
  where d.entity = 'article' and d.payload -> 'article' ->> 'author_id' = old.id::text;
  return old;
end;
$$;

drop trigger if exists authors_before_delete on guide.authors;
create trigger authors_before_delete before delete on guide.authors
  for each row execute function guide.authors_before_delete();

-- ───────────── Alt obligatorio de la foto (D27, como D41/D51: es y en) ─────────────
create or replace function guide.authors_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
begin
  if guide.alt_guard_bypassed() or new.photo_media_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.photo_media_id is not distinct from old.photo_media_id then
    return new;
  end if;
  v_missing := guide.alt_reqs_missing(array['es:' || new.photo_media_id::text, 'en:' || new.photo_media_id::text]);
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('author', new.id, v_missing);
  end if;
  return new;
end;
$$;

drop trigger if exists authors_require_alt on guide.authors;
create trigger authors_require_alt
  after insert or update of photo_media_id on guide.authors
  for each row execute function guide.authors_require_alt();

-- ───────────── Lectura pública de la foto ─────────────
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
  select s.author_photo_media_id, 'site_settings', s.id::text, 'author_photo_media_id', 'Ajustes del sitio'
  from guide.site_settings s where s.author_photo_media_id is not null
  union all
  select au.photo_media_id, 'authors', au.id::text, 'photo_media_id', au.name
  from guide.authors au where au.photo_media_id is not null
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

-- owner_table 'authors', owner_id = id del autor, role 'author' (como la foto de site_settings).
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

-- Vaciar alt_es/alt_en de la foto de un autor → PT422 con used_by {entity:'author', entity_id}.
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
  ) o;
$$;

-- ───────────── Búsqueda pública: + author_id (al final; cambia el tipo de retorno → drop/create) ─────────────
drop function if exists guide.search_articles(text, guide.locale, uuid, integer, integer);
create function guide.search_articles(p_query text, p_locale guide.locale, p_category_id uuid default null,
                                      p_limit integer default 20, p_offset integer default 0)
returns table (id uuid, slug text, slug_es text, slug_en text, title text, excerpt text, category_id uuid,
               category_slug text, category_name text, published_at timestamptz, rank real, headline text,
               total_count bigint, author_id uuid)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
declare
  c_max_len constant integer := 200;
  c_headline_len constant integer := 20000;
  c_opts constant text :=
    E'StartSel=\u0002, StopSel=\u0003, MaxWords=30, MinWords=12, ShortWord=3, MaxFragments=2, FragmentDelimiter=" … "';
  v_q text;
  v_rest text;
  v_last text;
  v_cfg regconfig;
  v_tsq tsquery;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000);
begin
  if p_locale is null then
    raise exception 'invalid locale' using errcode = '22023';
  end if;
  if char_length(coalesce(p_query, '')) > c_max_len then
    raise exception 'query too long' using errcode = '22023';
  end if;

  v_q := btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'));
  if char_length(v_q) < 2 then
    return;
  end if;

  v_cfg := case p_locale when 'en' then 'guide.english_unaccent'::regconfig else 'guide.spanish_unaccent'::regconfig end;

  -- Búsqueda mientras se escribe: la última palabra (≥ 3 letras, sin comillas abiertas, no negada ni
  -- precedida de "or") se busca como prefijo de su raíz. El resto va por websearch_to_tsquery.
  v_last := substring(v_q from '(?:^|\s)([[:alnum:]]{3,})$');
  v_rest := left(v_q, char_length(v_q) - coalesce(char_length(v_last), 0));
  if v_last is not null
     and (char_length(v_q) - char_length(replace(v_q, '"', ''))) % 2 = 0
     and v_rest !~* '(^|\s)or\s*$' then
    v_tsq := websearch_to_tsquery(v_cfg, v_rest) && to_tsquery(v_cfg, lower(v_last) || ':*');
  else
    v_tsq := websearch_to_tsquery(v_cfg, v_q);
  end if;

  -- Sin término positivo indexable (solo negaciones, o "x or -y"): no es una búsqueda, 0 filas.
  if v_tsq is null or numnode(v_tsq) = 0 or querytree(v_tsq) = 'T' then
    return;
  end if;

  if p_locale = 'es' then
    return query
      with m as (
        select a.id as aid, ts_rank(a.search_es, v_tsq, 1) as r, count(*) over () as t
        from guide.articles a
        where a.search_es @@ v_tsq
          and guide.article_is_live(a.status, a.published_at)
          and (p_category_id is null or a.category_id = p_category_id)
        order by r desc, a.published_at desc, a.id
        limit v_limit offset v_offset
      )
      select a.id, a.slug_es::text, a.slug_es::text, a.slug_en::text, a.title_es, a.excerpt_es,
             c.id, c.slug_es::text, c.name_es, a.published_at, m.r,
             ts_headline(v_cfg, left(guide.search_plain_text(a.excerpt_es, a.body_html_es), c_headline_len), v_tsq, c_opts),
             m.t, a.author_id
      from m
      join guide.articles a on a.id = m.aid
      join guide.article_categories c on c.id = a.category_id
      order by m.r desc, a.published_at desc, a.id;
  else
    return query
      with m as (
        select a.id as aid, ts_rank(a.search_en, v_tsq, 1) as r, count(*) over () as t
        from guide.articles a
        where a.search_en @@ v_tsq
          and a.has_en
          and guide.article_is_live(a.status, a.published_at)
          and (p_category_id is null or a.category_id = p_category_id)
        order by r desc, a.published_at desc, a.id
        limit v_limit offset v_offset
      )
      select a.id, a.slug_en::text, a.slug_es::text, a.slug_en::text, a.title_en, a.excerpt_en,
             c.id, c.slug_en::text, coalesce(c.name_en, c.name_es), a.published_at, m.r,
             ts_headline(v_cfg, left(guide.search_plain_text(a.excerpt_en, a.body_html_en), c_headline_len), v_tsq, c_opts),
             m.t, a.author_id
      from m
      join guide.articles a on a.id = m.aid
      join guide.article_categories c on c.id = a.category_id
      order by m.r desc, a.published_at desc, a.id;
  end if;
end;
$$;
revoke all on function guide.search_articles(text, guide.locale, uuid, integer, integer) from public, service_role;
grant execute on function guide.search_articles(text, guide.locale, uuid, integer, integer) to anon, authenticated;

-- ───────────── Exportación: + author_id y author_name tras la categoría (orden de columnas = orden del CSV) ─────────────
drop view if exists guide.export_articles;
create view guide.export_articles with (security_invoker = true) as
select a.id, a.status, a.published_at, a.category_id, c.name_es as category_es,
       a.author_id, au.name as author_name,
       a.title_es, a.title_en, a.slug_es, a.slug_en, a.excerpt_es, a.excerpt_en, a.is_featured, a.sort_order,
       a.reading_minutes_es, a.reading_minutes_en, a.seo_title_es, a.seo_title_en, a.seo_description_es,
       a.seo_description_en, a.noindex, a.canonical_url, a.has_en,
       exists (select 1 from guide.content_drafts d where d.article_id = a.id) as has_pending_draft,
       a.created_at, a.updated_at, a.body_html_es, a.body_html_en
from guide.articles a
join guide.article_categories c on c.id = a.category_id
left join guide.authors au on au.id = a.author_id
where (select guide.is_admin());
-- Como tras F6.15 (retire_log_export): solo la lee export_build (SECURITY DEFINER), ningún rol de la API.
revoke all on guide.export_articles from public, anon, authenticated, service_role;

-- ───────────── Seed: autora Ana (idempotente; sin foto) ─────────────
insert into guide.authors (slug, name, role_es, role_en, bio_es, bio_en, sort_order)
values ('ana', 'Ana', 'Redactora', 'Writer',
        'Escribe sobre escalada en Barcelona para ChalkGuide.',
        'Writes about climbing in Barcelona for ChalkGuide.', 10)
on conflict (slug) do nothing;
