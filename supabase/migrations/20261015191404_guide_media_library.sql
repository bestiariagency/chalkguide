-- F6.6 · Biblioteca de medios del panel: subir, reemplazar, borrar con usos, buscador.
--
-- Convención de ruta (bucket media): '<media_id>/<version>-<slug>.<ext>'
--   media_id  uuid en minúsculas (= guide.media.id, lo genera el cliente)
--   version   entero ≥ 1 (= guide.media.version); reemplazar = objeto nuevo con version + 1
--   slug      [a-z0-9]+(-[a-z0-9]+)*, derivado del nombre del archivo
--   ext       jpg | png | webp | avif | gif, coherente con mime_type
-- Los objetos son inmutables (sin UPDATE en Storage): nada se sobrescribe y cada versión tiene URL propia.
-- Orden seguro: subir objeto → alta/reemplazo de fila; borrar fila → borrar objeto. Lo que quede a medias
-- (objetos sin fila) lo lista guide.media_storage_orphans() para limpiarlo desde el panel.

-- ───────────── Validación de rutas ─────────────
create or replace function guide.media_path_is_wellformed(p_path text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    char_length(p_path) <= 160
    and p_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[1-9][0-9]{0,8}-[a-z0-9]+(-[a-z0-9]+)*\.(jpg|png|webp|avif|gif)$',
    false);
$$;

create or replace function guide.media_path_matches(p_path text, p_id uuid, p_version integer, p_mime text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    guide.media_path_is_wellformed(p_path)
    and split_part(p_path, '/', 1) = p_id::text
    and split_part(split_part(p_path, '/', 2), '-', 1) = p_version::text
    and substring(p_path from '\.([a-z]+)$') = case p_mime
          when 'image/jpeg' then 'jpg' when 'image/png' then 'png' when 'image/webp' then 'webp'
          when 'image/avif' then 'avif' when 'image/gif' then 'gif' end,
    false);
$$;

-- Las filas existentes ya cumplen la convención (comprobado antes de aplicar).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'media_storage_path_convention'
                 and conrelid = 'guide.media'::regclass) then
    alter table guide.media add constraint media_storage_path_convention
      check (guide.media_path_matches(storage_path, id, version, mime_type));
  end if;
end $$;

-- Storage: solo se sube a una ruta bien formada de un medio nuevo (versión 1) o de la versión siguiente.
create or replace function guide.media_object_insertable(p_name text)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id      uuid;
  v_version integer;
  v_current integer;
begin
  if not guide.media_path_is_wellformed(p_name) then
    return false;
  end if;
  v_id := split_part(p_name, '/', 1)::uuid;
  v_version := split_part(split_part(p_name, '/', 2), '-', 1)::integer;
  select m.version into v_current from guide.media m where m.id = v_id;
  return (v_current is null and v_version = 1) or v_version = v_current + 1;
end;
$$;

-- Storage: no se borra el objeto vigente de una fila (primero se borra o reemplaza la fila).
create or replace function guide.media_object_deletable(p_name text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select not exists (select 1 from guide.media m where m.storage_path = p_name);
$$;

-- ───────────── Coherencia fila ↔ objeto ─────────────
-- mime_type y size_bytes salen siempre de los metadatos del objeto (no de lo que declare el cliente).
-- version/storage_path/mime/size solo cambian juntos (reemplazo), con version + 1 y objeto existente.
create or replace function guide.media_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_meta jsonb;
  v_size text;
begin
  if not guide.is_admin()
     and not coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false) then
    raise exception 'admin only' using errcode = '42501';
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id then
      raise exception 'media id is immutable' using errcode = '22023';
    end if;
    if new.storage_path is not distinct from old.storage_path then
      if new.version is distinct from old.version or new.mime_type is distinct from old.mime_type
         or new.size_bytes is distinct from old.size_bytes then
        raise exception 'media file changes only with a new object' using errcode = '22023';
      end if;
      return new;
    end if;
    if new.version is distinct from old.version + 1 then
      raise exception 'media version must be the next one' using errcode = '22023';
    end if;
  elsif new.version is distinct from 1 then
    raise exception 'new media starts at version 1' using errcode = '22023';
  end if;

  select o.metadata into v_meta
  from storage.objects o
  where o.bucket_id = 'media' and o.name = new.storage_path;
  if not found then
    raise exception 'media object not found' using errcode = '22023';
  end if;
  v_size := v_meta ->> 'size';
  if v_meta ->> 'mimetype' is null or v_size is null or v_size !~ '^[0-9]{1,12}$' then
    raise exception 'media object metadata missing' using errcode = '22023';
  end if;
  new.mime_type := v_meta ->> 'mimetype';
  new.size_bytes := least(v_size::bigint, 2147483647)::integer;
  return new;
end;
$$;

drop trigger if exists media_before_write on guide.media;
create trigger media_before_write
  before insert or update on guide.media
  for each row execute function guide.media_before_write();

-- ───────────── Usos ─────────────
-- Además de FKs, content_media_refs (attrs.mediaId) y borradores, cuenta imágenes pegadas en el HTML
-- de cuerpos o borradores que apuntan a la ruta vigente sin data-media-id.
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

-- Respaldo de borrado directo: borradores (ids o ruta) y HTML con la ruta. Las FKs (restrict) cubren el resto.
create or replace function guide.media_before_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from guide.content_drafts d
             where old.id = any (guide.draft_media_ids(d.payload))
                or strpos(d.payload::text, old.storage_path) > 0)
     or exists (select 1 from guide.articles a
                where strpos(a.body_html_es, old.storage_path) > 0 or strpos(a.body_html_en, old.storage_path) > 0)
     or exists (select 1 from guide.pages p
                where strpos(p.body_html_es, old.storage_path) > 0 or strpos(p.body_html_en, old.storage_path) > 0)
     or exists (select 1 from guide.author_reviews ar
                where strpos(ar.body_html_es, old.storage_path) > 0 or strpos(ar.body_html_en, old.storage_path) > 0) then
    raise exception 'media in use' using errcode = '23503';
  end if;
  return old;
end;
$$;

drop trigger if exists media_draft_guard on guide.media;
drop trigger if exists media_before_delete on guide.media;
create trigger media_before_delete
  before delete on guide.media
  for each row execute function guide.media_before_delete();
drop function if exists guide.media_draft_guard();

-- ───────────── Lectura pública acotada ─────────────
-- anon/no admin solo ven filas de medios usados por contenido visible (no se enumeran imágenes de
-- borradores ni de fichas ocultas). Replica las reglas de visibilidad de cada dueño.
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
      or exists (select 1 from guide.site_settings s where s.default_og_media_id = p_id)
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

drop policy if exists media_select on guide.media;
create policy media_select on guide.media for select to anon, authenticated
  using ((select guide.is_admin()) or guide.media_is_public(id));

-- ───────────── RPC del panel (SECURITY INVOKER: RLS + triggers siguen aplicando) ─────────────
create or replace function guide.media_clean_text(p_value text, p_max integer)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare v text;
begin
  v := nullif(btrim(regexp_replace(coalesce(p_value, ''), '[[:cntrl:]]+', ' ', 'g')), '');
  if v is not null and char_length(v) > p_max then
    raise exception 'text too long' using errcode = '22023';
  end if;
  return v;
end;
$$;

create or replace function guide.create_media(
  p_id uuid,
  p_storage_path text,
  p_original_filename text,
  p_width integer,
  p_height integer,
  p_dominant_color text default null,
  p_alt_es text default null,
  p_alt_en text default null,
  p_caption_es text default null,
  p_caption_en text default null,
  p_credit text default null
)
returns setof guide.media
language plpgsql
set search_path = ''
as $$
declare
  v_name text;
begin
  perform guide.assert_admin();
  if p_id is null or p_storage_path is null or coalesce(p_width, 0) <= 0 or coalesce(p_height, 0) <= 0 then
    raise exception 'invalid media' using errcode = '22023';
  end if;
  if not guide.media_path_is_wellformed(p_storage_path) or split_part(p_storage_path, '/', 1) <> p_id::text
     or split_part(split_part(p_storage_path, '/', 2), '-', 1) <> '1' then
    raise exception 'invalid storage path' using errcode = '22023';
  end if;
  v_name := guide.media_clean_text(p_original_filename, 255);
  if v_name is null then
    raise exception 'invalid media' using errcode = '22023';
  end if;

  return query
  insert into guide.media (id, storage_path, version, original_filename, mime_type, size_bytes, width, height,
                           dominant_color, alt_es, alt_en, caption_es, caption_en, credit)
  values (p_id, p_storage_path, 1, v_name, 'image/jpeg', 1, p_width, p_height,  -- mime/size: los fija el trigger
          lower(nullif(btrim(p_dominant_color), '')),
          guide.media_clean_text(p_alt_es, 300), guide.media_clean_text(p_alt_en, 300),
          guide.media_clean_text(p_caption_es, 500), guide.media_clean_text(p_caption_en, 500),
          guide.media_clean_text(p_credit, 200))
  returning *;
end;
$$;

create or replace function guide.replace_media(
  p_id uuid,
  p_expected_version integer,
  p_storage_path text,
  p_original_filename text,
  p_width integer,
  p_height integer,
  p_dominant_color text default null
)
returns table (id uuid, version integer, storage_path text, previous_storage_path text, mime_type text,
               size_bytes integer, updated_at timestamptz)
language plpgsql
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_old  text;
  v_ver  integer;
  v_name text;
begin
  perform guide.assert_admin();
  if p_id is null or p_expected_version is null or coalesce(p_width, 0) <= 0 or coalesce(p_height, 0) <= 0 then
    raise exception 'invalid media' using errcode = '22023';
  end if;
  v_name := guide.media_clean_text(p_original_filename, 255);
  if v_name is null then
    raise exception 'invalid media' using errcode = '22023';
  end if;

  select m.storage_path, m.version into v_old, v_ver from guide.media m where m.id = p_id for update;
  if not found then
    raise exception 'media not found' using errcode = 'P0002';
  end if;
  if v_ver <> p_expected_version then
    raise exception 'media version conflict' using errcode = 'PT409';
  end if;
  if not guide.media_path_is_wellformed(p_storage_path) or split_part(p_storage_path, '/', 1) <> p_id::text
     or split_part(split_part(p_storage_path, '/', 2), '-', 1) <> (v_ver + 1)::text then
    raise exception 'invalid storage path' using errcode = '22023';
  end if;

  return query
  update guide.media m
  set storage_path = p_storage_path,
      version = v_ver + 1,
      original_filename = v_name,
      width = p_width,
      height = p_height,
      dominant_color = lower(nullif(btrim(p_dominant_color), ''))
  where m.id = p_id
  returning m.id, m.version, m.storage_path, v_old, m.mime_type, m.size_bytes, m.updated_at;
end;
$$;

-- Usos para la UI: owner_table ∈ articles | pages | items | site_settings; los cuerpos de reseñas del autor
-- se atribuyen a su ficha (role review_body_*); owner_id es null para site_settings. item_category (gym, shoe, resoler, …) para enlazar la ficha.
-- role ∈ cover | og | gallery | body_es | body_en | review_body_es | review_body_en | draft.
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
           else u.usage_field
         end
  from guide.media_usage u
  left join guide.author_reviews ar on u.usage_table = 'author_reviews' and ar.id::text = u.usage_id
  left join guide.items i on i.id::text = case
                                            when u.usage_table = 'author_reviews' then ar.item_id::text
                                            when u.usage_table in ('items', 'item_media') then u.usage_id
                                          end
  order by 1, 4, 2, 5;
end;
$$;

-- Contadores de la biblioteca (bytes reales de Storage, incluidos huérfanos).
create or replace function guide.media_stats()
returns table (total_count bigint, in_use_count bigint, unused_count bigint, missing_alt_count bigint,
               missing_en_count bigint, rows_bytes bigint, storage_bytes bigint, storage_objects bigint)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  return query
  with used as (select distinct u.media_id from guide.media_usage u)
  select count(*),
         count(*) filter (where used.media_id is not null),
         count(*) filter (where used.media_id is null),
         count(*) filter (where m.alt_es is null or btrim(m.alt_es) = ''),
         count(*) filter (where m.alt_en is null or btrim(m.alt_en) = ''),
         coalesce(sum(m.size_bytes), 0)::bigint,
         (select coalesce(sum(case when o.metadata ->> 'size' ~ '^[0-9]{1,12}$' then (o.metadata ->> 'size')::bigint end), 0)::bigint
          from storage.objects o where o.bucket_id = 'media'),
         (select count(*) from storage.objects o where o.bucket_id = 'media')
  from guide.media m
  left join used on used.media_id = m.id;
end;
$$;

-- La vista de la biblioteca incluye dominant_color (añadido después de crearla).
drop view if exists guide.media_library;
create view guide.media_library with (security_invoker = true) as
select m.id, m.storage_path, m.version, m.original_filename, m.mime_type, m.size_bytes, m.width, m.height,
       m.alt_es, m.alt_en, m.caption_es, m.caption_en, m.credit, m.has_en, m.dominant_color,
       m.created_at, m.updated_at,
       (select count(*) from guide.media_usage u where u.media_id = m.id)::integer as usage_count
from guide.media m
where (select guide.is_admin());
revoke all on guide.media_library from anon, public;
grant select on guide.media_library to authenticated, service_role;

create or replace function guide.delete_media(p_id uuid, p_expected_version integer)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_path text;
  v_ver  integer;
  v_uses integer;
begin
  perform guide.assert_admin();
  select m.storage_path, m.version into v_path, v_ver from guide.media m where m.id = p_id for update;
  if not found then
    raise exception 'media not found' using errcode = 'P0002';
  end if;
  if p_expected_version is null or v_ver <> p_expected_version then
    raise exception 'media version conflict' using errcode = 'PT409';
  end if;
  select count(*) into v_uses from guide.media_usage u where u.media_id = p_id;
  if v_uses > 0 then
    raise exception 'media in use' using errcode = '23503', detail = v_uses::text,
      hint = 'Call guide.media_usages(id) to list them.';
  end if;
  delete from guide.media m where m.id = p_id;
  return v_path;
end;
$$;

create or replace function guide.search_media(
  p_query text default null,
  p_filter text default 'all',
  p_limit integer default 48,
  p_offset integer default 0
)
returns table (id uuid, storage_path text, version integer, original_filename text, mime_type text,
               size_bytes integer, width integer, height integer, alt_es text, alt_en text,
               caption_es text, caption_en text, credit text, dominant_color text,
               created_at timestamptz, updated_at timestamptz, usage_count integer, total_count bigint)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_q      text;
  v_terms  text[];
  v_filter text := coalesce(p_filter, 'all');
  v_limit  integer := least(greatest(coalesce(p_limit, 48), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  if char_length(coalesce(p_query, '')) > 200 then
    raise exception 'query too long' using errcode = '22023';
  end if;
  if v_filter not in ('all', 'unused', 'in_use', 'missing_alt', 'missing_en') then
    raise exception 'invalid filter' using errcode = '22023';
  end if;

  v_q := lower(extensions.unaccent(btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'))));
  -- Cada palabra es un literal de LIKE: se escapan \ % _.
  select coalesce(array_agg('%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'), '{}')
  into v_terms
  from unnest(string_to_array(nullif(v_q, ''), ' ')) as w
  where w <> '';

  return query
  with uses as (
    select u.media_id, count(*)::integer as n from guide.media_usage u group by u.media_id
  ),
  hits as (
    select m.*, coalesce(uses.n, 0) as n, count(*) over () as t
    from guide.media m
    left join uses on uses.media_id = m.id
    where (cardinality(v_terms) = 0 or not exists (
             select 1 from unnest(v_terms) as term
             where lower(extensions.unaccent(concat_ws(' ', m.original_filename, m.alt_es, m.alt_en,
                                                       m.caption_es, m.caption_en, m.credit)))
                   not like term escape '\'))
      and case v_filter
            when 'unused' then coalesce(uses.n, 0) = 0
            when 'in_use' then coalesce(uses.n, 0) > 0
            when 'missing_alt' then m.alt_es is null or btrim(m.alt_es) = ''
            when 'missing_en' then m.alt_en is null or btrim(m.alt_en) = ''
            else true
          end
    order by m.created_at desc, m.id desc
    limit v_limit offset v_offset
  )
  select h.id, h.storage_path, h.version, h.original_filename, h.mime_type, h.size_bytes, h.width, h.height,
         h.alt_es, h.alt_en, h.caption_es, h.caption_en, h.credit, h.dominant_color, h.created_at, h.updated_at,
         h.n, h.t
  from hits h
  order by h.created_at desc, h.id desc;
end;
$$;

-- Objetos sin fila (subida a medias, versión vieja sin borrar) y filas sin objeto.
create or replace function guide.media_storage_orphans(p_min_age_minutes integer default 60)
returns table (kind text, storage_path text, media_id uuid, created_at timestamptz)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  return query
  select 'object_without_row'::text, o.name, null::uuid, o.created_at
  from storage.objects o
  where o.bucket_id = 'media'
    and o.created_at < now() - make_interval(mins => least(greatest(coalesce(p_min_age_minutes, 60), 5), 10080))
    and not exists (select 1 from guide.media m where m.storage_path = o.name)
  union all
  select 'row_without_object'::text, m.storage_path, m.id, m.created_at
  from guide.media m
  where not exists (select 1 from storage.objects o where o.bucket_id = 'media' and o.name = m.storage_path)
  order by 4;
end;
$$;

-- ───────────── Storage (solo bucket media; avatars de Chalk app no se toca) ─────────────
drop policy if exists "guide media admin update" on storage.objects;

drop policy if exists "guide media admin insert" on storage.objects;
create policy "guide media admin insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and (select guide.is_admin()) and guide.media_object_insertable(name));

drop policy if exists "guide media admin delete" on storage.objects;
create policy "guide media admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and (select guide.is_admin()) and guide.media_object_deletable(name));

-- ───────────── Grants ─────────────
revoke execute on function guide.media_path_is_wellformed(text) from public;
revoke execute on function guide.media_path_matches(text, uuid, integer, text) from public;
revoke execute on function guide.media_object_insertable(text) from public;
revoke execute on function guide.media_object_deletable(text) from public;
revoke execute on function guide.media_before_write() from public;
revoke execute on function guide.media_before_delete() from public;
revoke execute on function guide.media_is_public(uuid) from public;
revoke execute on function guide.media_clean_text(text, integer) from public;
revoke execute on function guide.create_media(uuid, text, text, integer, integer, text, text, text, text, text, text) from public;
revoke execute on function guide.replace_media(uuid, integer, text, text, integer, integer, text) from public;
revoke execute on function guide.media_usages(uuid) from public;
revoke execute on function guide.delete_media(uuid, integer) from public;
revoke execute on function guide.search_media(text, text, integer, integer) from public;
revoke execute on function guide.media_storage_orphans(integer) from public;
revoke execute on function guide.media_stats() from public;

grant execute on function guide.media_path_is_wellformed(text) to authenticated, service_role;
grant execute on function guide.media_path_matches(text, uuid, integer, text) to authenticated, service_role;
grant execute on function guide.media_object_insertable(text) to authenticated;
grant execute on function guide.media_object_deletable(text) to authenticated;
grant execute on function guide.media_is_public(uuid) to anon, authenticated;
grant execute on function guide.media_clean_text(text, integer) to authenticated;
grant execute on function guide.create_media(uuid, text, text, integer, integer, text, text, text, text, text, text) to authenticated;
grant execute on function guide.replace_media(uuid, integer, text, text, integer, integer, text) to authenticated;
grant execute on function guide.media_usages(uuid) to authenticated;
grant execute on function guide.delete_media(uuid, integer) to authenticated;
grant execute on function guide.search_media(text, text, integer, integer) to authenticated;
grant execute on function guide.media_storage_orphans(integer) to authenticated;
grant execute on function guide.media_stats() to authenticated;
