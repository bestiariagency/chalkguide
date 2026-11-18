-- D23 · Borradores de cambios sobre contenido publicado + registro de exportaciones.
--
-- Modelo: una tabla genérica `guide.content_drafts` (una fila por entidad publicada con cambios
-- pendientes) con `payload jsonb` por secciones y semántica de parche (solo las claves presentes
-- se aplican). Entidades: article, page, item (ficha + detalle por categoría + reseña del autor
-- + notas + galería). Las columnas editables por borrador están en una lista blanca única
-- (`guide.draft_allowed_columns`); el SQL dinámico solo usa identificadores de esa lista,
-- comprobados contra el catálogo y citados con %I.
--
-- RPC (todas SECURITY INVOKER: la RLS de admin manda y los triggers de siempre registran
-- actividad con el actor real): save_draft, publish_draft, discard_draft, draft_entity_version.
-- Única SECURITY DEFINER invocable: log_export (escribe en activity_log, que no tiene grants de
-- escritura para clientes). El trigger de log de borradores también es DEFINER por el mismo motivo.

-- ───────────── Lista blanca y helpers puros ─────────────

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
      'noindex', 'canonical_url']
    when 'pages' then array[
      'title_es', 'title_en', 'slug_es', 'slug_en', 'body_json_es', 'body_html_es', 'body_json_en',
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

comment on function guide.draft_allowed_columns(text) is
  'D23. Lista blanca de columnas editables por borrador de cambios, por tabla. Fuente única para validar y publicar.';

-- Tabla de destino de una sección de columnas del payload (null = no es sección de columnas).
create or replace function guide.draft_section_table(p_entity text, p_section text, p_category text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_entity = 'article' and p_section = 'article' then 'articles'
    when p_entity = 'page' and p_section = 'page' then 'pages'
    when p_entity = 'item' and p_section = 'item' then 'items'
    when p_entity = 'item' and p_section = 'author_review' then 'author_reviews'
    when p_entity = 'item' and p_section = 'detail' then
      case p_category when 'gym' then 'gyms' when 'resoler' then 'resolers' when 'shoe' then 'shoes' end
  end;
$$;

-- Medios referenciados por un payload: portadas/OG de cualquier sección, imágenes del editor
-- (attrs.mediaId a cualquier profundidad) y galería.
create or replace function guide.draft_media_ids(p_payload jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct m), '{}'::uuid[])
  from (
    select unnest(guide.extract_media_ids(p_payload)) as m
    union all
    select (v #>> '{}')::uuid
    from jsonb_path_query(coalesce(p_payload, '{}'::jsonb), 'strict $.*.cover_media_id', '{}'::jsonb, true) as v
    where jsonb_typeof(v) = 'string'
    union all
    select (v #>> '{}')::uuid
    from jsonb_path_query(coalesce(p_payload, '{}'::jsonb), 'strict $.*.og_media_id', '{}'::jsonb, true) as v
    where jsonb_typeof(v) = 'string'
    union all
    select (v #>> '{}')::uuid
    from jsonb_path_query(coalesce(p_payload, '{}'::jsonb), 'strict $.gallery[*]', '{}'::jsonb, true) as v
    where jsonb_typeof(v) = 'string'
  ) s;
$$;

-- Versión publicada de una entidad para detectar conflictos. En fichas incluye detalle y reseña.
-- Limitación: notas, galería y article_items no tienen updated_at y no cuentan.
create or replace function guide.draft_entity_version(p_entity text, p_id uuid)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case p_entity
    when 'article' then (select a.updated_at from guide.articles a where a.id = p_id)
    when 'page' then (select p.updated_at from guide.pages p where p.id = p_id)
    when 'item' then (
      select greatest(i.updated_at, g.updated_at, r.updated_at, s.updated_at, ar.updated_at)
      from guide.items i
      left join guide.gyms g on g.item_id = i.id
      left join guide.resolers r on r.item_id = i.id
      left join guide.shoes s on s.item_id = i.id
      left join guide.author_reviews ar on ar.item_id = i.id
      where i.id = p_id)
  end;
$$;

-- Validación completa del payload (claves, tipos, NOT NULL, relaciones). Lanza 22023 si algo
-- no está permitido. La comparten el trigger de content_drafts y publish_draft.
create or replace function guide.draft_check_payload(p_entity text, p_entity_id uuid, p_payload jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  c_uuid     constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_category text;
  v_section  text;
  v_value    jsonb;
  v_table    text;
  v_col      text;
  v_attr     record;
begin
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
    raise exception 'invalid payload' using errcode = '22023';
  end if;
  if p_entity = 'item' then
    select i.category into v_category from guide.items i where i.id = p_entity_id;
    if v_category is null then
      raise exception 'entity not found' using errcode = 'P0002';
    end if;
  end if;

  for v_section, v_value in select e.key, e.value from jsonb_each(p_payload) e loop
    v_table := guide.draft_section_table(p_entity, v_section, v_category);

    if v_table is not null then
      if jsonb_typeof(v_value) <> 'object' or v_value = '{}'::jsonb then
        raise exception 'invalid section: %', left(v_section, 40) using errcode = '22023';
      end if;
      for v_col in select jsonb_object_keys(v_value) loop
        if not (v_col = any (guide.draft_allowed_columns(v_table))) then
          raise exception 'column not allowed: %.%', left(v_section, 40), left(v_col, 64) using errcode = '22023';
        end if;
        select a.attnotnull, a.attgenerated into v_attr
        from pg_catalog.pg_attribute a
        where a.attrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(v_table))
          and a.attname = v_col and a.attnum > 0 and not a.attisdropped;
        if not found or v_attr.attgenerated <> '' then
          raise exception 'draft whitelist out of sync: %.%', v_table, v_col using errcode = 'XX000';
        end if;
        if v_attr.attnotnull and jsonb_typeof(v_value -> v_col) = 'null' then
          raise exception 'column not nullable: %.%', v_section, v_col using errcode = '23502';
        end if;
      end loop;
      -- Tipos: el cast lanza 22P02/22007/22003… si un valor no encaja. v_table viene de la lista fija.
      execute format('select jsonb_populate_record(null::guide.%I, $1)', v_table) using v_value;

    elsif (p_entity = 'article' and v_section = 'item_ids') or (p_entity = 'item' and v_section = 'gallery') then
      if jsonb_typeof(v_value) <> 'array' or jsonb_array_length(v_value) > 100
         or exists (select 1 from jsonb_array_elements(v_value) e
                    where jsonb_typeof(e) <> 'string' or (e #>> '{}') !~ c_uuid)
         or (select count(distinct e) from jsonb_array_elements(v_value) e) <> jsonb_array_length(v_value) then
        raise exception 'invalid section: %', v_section using errcode = '22023';
      end if;

    elsif p_entity = 'item' and v_section = 'scores' then
      if jsonb_typeof(v_value) <> 'object'
         or (select count(*) from jsonb_object_keys(v_value)) > 50
         or exists (select 1 from jsonb_each(v_value) e
                    where e.key !~ c_uuid or jsonb_typeof(e.value) <> 'number' or e.value::text !~ '^[1-5]$') then
        raise exception 'invalid section: scores' using errcode = '22023';
      end if;

    else
      raise exception 'section not allowed: %', left(v_section, 40) using errcode = '22023';
    end if;
  end loop;
end;
$$;

-- ───────────── Tabla ─────────────

create table if not exists guide.content_drafts (
  id              uuid primary key default gen_random_uuid(),
  entity          text not null check (entity in ('article', 'page', 'item')),
  article_id      uuid unique references guide.articles (id) on delete cascade,
  page_id         uuid unique references guide.pages (id) on delete cascade,
  item_id         uuid unique references guide.items (id) on delete cascade,
  entity_id       uuid generated always as (coalesce(article_id, page_id, item_id)) stored,
  payload         jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 2000000),
  base_updated_at timestamptz not null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  updated_by      uuid references auth.users (id) on delete set null,
  constraint content_drafts_target_check check (
    (entity = 'article' and article_id is not null and page_id is null and item_id is null) or
    (entity = 'page' and page_id is not null and article_id is null and item_id is null) or
    (entity = 'item' and item_id is not null and article_id is null and page_id is null))
);

create index if not exists content_drafts_updated_by_idx on guide.content_drafts (updated_by);

comment on table guide.content_drafts is
  'D23. Cambios pendientes sobre contenido publicado (uno por entidad). payload por secciones con semántica de parche; se aplica con guide.publish_draft.';

alter table guide.content_drafts enable row level security;

revoke all on guide.content_drafts from public, anon, authenticated;
grant select, insert, update, delete on guide.content_drafts to authenticated;

drop policy if exists content_drafts_select on guide.content_drafts;
create policy content_drafts_select on guide.content_drafts for select to authenticated
  using ((select guide.is_admin()));
drop policy if exists content_drafts_insert on guide.content_drafts;
create policy content_drafts_insert on guide.content_drafts for insert to authenticated
  with check ((select guide.is_admin()));
drop policy if exists content_drafts_update on guide.content_drafts;
create policy content_drafts_update on guide.content_drafts for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists content_drafts_delete on guide.content_drafts;
create policy content_drafts_delete on guide.content_drafts for delete to authenticated
  using ((select guide.is_admin()));

-- Validación en BD (también para escrituras directas por PostgREST): destino inmutable,
-- payload válido, medios existentes y auditoría forzada.
create or replace function guide.content_drafts_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing uuid;
begin
  if tg_op = 'UPDATE' and (new.entity, new.article_id, new.page_id, new.item_id)
                          is distinct from (old.entity, old.article_id, old.page_id, old.item_id) then
    raise exception 'draft target is immutable' using errcode = '22023';
  end if;

  perform guide.draft_check_payload(new.entity, coalesce(new.article_id, new.page_id, new.item_id), new.payload);

  select m into v_missing
  from unnest(guide.draft_media_ids(new.payload)) as m
  where not exists (select 1 from guide.media x where x.id = m)
  limit 1;
  if v_missing is not null then
    raise exception 'media not found' using errcode = '23503';
  end if;

  new.updated_by := (select auth.uid());
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists content_drafts_before_write on guide.content_drafts;
create trigger content_drafts_before_write
  before insert or update on guide.content_drafts
  for each row execute function guide.content_drafts_before_write();

-- Registro: publicar o descartar deja una entrada (sin valores, solo secciones/columnas tocadas).
-- SECURITY DEFINER porque activity_log no tiene grants de escritura (igual que guide.log_activity).
-- Si la entidad ya no existe (borrado en cascada) no se registra: el DELETE de la entidad ya queda.
create or replace function guide.content_drafts_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_label   text;
  v_table   text := case old.entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end;
  v_changed text[];
begin
  select coalesce(
           (select a.title_es from guide.articles a where old.entity = 'article' and a.id = old.entity_id),
           (select p.title_es from guide.pages p where old.entity = 'page' and p.id = old.entity_id),
           (select i.name from guide.items i where old.entity = 'item' and i.id = old.entity_id))
    into v_label;
  if v_label is null then
    return null;
  end if;

  select array_agg(k order by k) into v_changed
  from (
    select s.key || coalesce('.' || c.key, '') as k
    from jsonb_each(old.payload) s
    left join lateral jsonb_each(case when jsonb_typeof(s.value) = 'object' and s.key <> 'scores'
                                      then s.value else '{}'::jsonb end) c on true
  ) x;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns)
  values (
    (select auth.uid()),
    case when current_setting('guide.draft_op', true) = 'publish'
         then 'draft_publish'::guide.activity_action else 'draft_discard'::guide.activity_action end,
    v_table,
    old.entity_id::text,
    left(v_label, 200),
    v_changed);
  return null;
end;
$$;

revoke execute on function guide.content_drafts_log() from public, anon, authenticated;

drop trigger if exists content_drafts_log on guide.content_drafts;
create trigger content_drafts_log
  after delete on guide.content_drafts
  for each row execute function guide.content_drafts_log();

-- ───────────── "Medio en uso": un medio referenciado por un borrador no se puede borrar ─────────────

create or replace function guide.media_draft_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (select 1 from guide.content_drafts d where old.id = any (guide.draft_media_ids(d.payload))) then
    raise exception 'media in use by draft' using errcode = '23503';
  end if;
  return old;
end;
$$;

drop trigger if exists media_draft_guard on guide.media;
create trigger media_draft_guard
  before delete on guide.media
  for each row execute function guide.media_draft_guard();

create or replace view guide.media_usage with (security_invoker = true) as
select media_id, usage_table, usage_id, usage_field, label
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
  -- D23: medios usados solo en un borrador de cambios (usage_id = id de la entidad)
  select m.media_id,
         case d.entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end,
         d.entity_id::text, 'draft',
         coalesce(a.title_es, p.title_es, i.name)
  from guide.content_drafts d
  cross join lateral unnest(guide.draft_media_ids(d.payload)) as m(media_id)
  left join guide.articles a on a.id = d.article_id
  left join guide.pages p on p.id = d.page_id
  left join guide.items i on i.id = d.item_id
) u
where (select guide.is_admin());

-- ───────────── RPC del panel ─────────────

create or replace function guide.save_draft(
  p_entity text,
  p_entity_id uuid,
  p_payload jsonb,
  p_base_updated_at timestamptz default null
)
returns table (id uuid, base_updated_at timestamptz, updated_at timestamptz)
language plpgsql
set search_path = ''
as $$
declare
  v_version timestamptz;
  v_live    boolean;
  v_draft   guide.content_drafts%rowtype;
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;

  v_version := guide.draft_entity_version(p_entity, p_entity_id);
  if v_version is null then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;

  select d.* into v_draft from guide.content_drafts d where d.entity_id = p_entity_id and d.entity = p_entity for update;

  if not found then
    -- Lo que no está publicado se edita directamente; el borrador de cambios es solo para lo vivo.
    v_live := case p_entity
      when 'article' then (select guide.article_is_live(a.status, a.published_at) from guide.articles a where a.id = p_entity_id)
      when 'page' then (select p.published from guide.pages p where p.id = p_entity_id)
      when 'item' then (select i.published from guide.items i where i.id = p_entity_id)
    end;
    if v_live is not true then
      raise exception 'entity not published' using errcode = '22023';
    end if;
    if p_base_updated_at is null or p_base_updated_at <> v_version then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    insert into guide.content_drafts (entity, article_id, page_id, item_id, payload, base_updated_at)
    values (p_entity,
            case when p_entity = 'article' then p_entity_id end,
            case when p_entity = 'page' then p_entity_id end,
            case when p_entity = 'item' then p_entity_id end,
            p_payload, v_version)
    returning * into v_draft;
  else
    if p_base_updated_at is not null and p_base_updated_at <> v_draft.base_updated_at then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    update guide.content_drafts d set payload = p_payload where d.id = v_draft.id
    returning * into v_draft;
  end if;

  return query select v_draft.id, v_draft.base_updated_at, v_draft.updated_at;
end;
$$;

create or replace function guide.publish_draft(p_entity text, p_entity_id uuid, p_force boolean default false)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_draft    guide.content_drafts%rowtype;
  v_category text;
  v_section  text;
  v_patch    jsonb;
  v_table    text;
  v_key_col  text;
  v_cols     text[];
  v_review   uuid;
  v_base     jsonb;
  v_n        integer;
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;

  -- Bloquea la fila publicada para serializar con otras ediciones.
  case p_entity
    when 'article' then perform 1 from guide.articles a where a.id = p_entity_id for update;
    when 'page' then perform 1 from guide.pages p where p.id = p_entity_id for update;
    else select i.category into v_category from guide.items i where i.id = p_entity_id for update;
  end case;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;

  select d.* into v_draft from guide.content_drafts d where d.entity_id = p_entity_id and d.entity = p_entity for update;
  if not found then
    raise exception 'draft not found' using errcode = 'P0002';
  end if;

  if guide.draft_entity_version(p_entity, p_entity_id) is distinct from v_draft.base_updated_at
     and p_force is not true then
    raise exception 'draft conflict' using errcode = 'PT409';
  end if;

  -- Revalida por si la lista blanca o el esquema cambiaron desde que se guardó.
  perform guide.draft_check_payload(p_entity, p_entity_id, v_draft.payload);

  -- Secciones de columnas, en orden fijo (la ficha antes que su detalle/reseña).
  foreach v_section in array array['article', 'page', 'item', 'detail', 'author_review'] loop
    v_patch := v_draft.payload -> v_section;
    continue when v_patch is null;
    v_table := guide.draft_section_table(p_entity, v_section, v_category);
    v_key_col := case when v_table in ('gyms', 'resolers', 'shoes', 'author_reviews') then 'item_id' else 'id' end;

    select array_agg(k order by k) into v_cols
    from jsonb_object_keys(v_patch) k
    where k = any (guide.draft_allowed_columns(v_table));
    continue when v_cols is null;

    if v_table = 'author_reviews' and not exists (select 1 from guide.author_reviews r where r.item_id = p_entity_id) then
      -- Reseña nueva sobre una ficha publicada: se crea al publicar, con los defaults de la tabla.
      v_base := jsonb_build_object('body_json_es', '{"type":"doc","content":[]}'::jsonb, 'body_html_es', '',
                                   'visit_type', 'paid') || v_patch;
      select array_agg(k order by k) into v_cols
      from jsonb_object_keys(v_base) k
      where k = any (guide.draft_allowed_columns(v_table));
      execute format(
        'insert into guide.author_reviews (item_id, category, %s) select $2, $3, %s from jsonb_populate_record(null::guide.author_reviews, $1) r',
        (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
        (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
        using v_base, p_entity_id, v_category;
    else
      execute format(
        'update guide.%I t set (%s) = (select %s from jsonb_populate_record(t, $1) r) where t.%I = $2',
        v_table,
        (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
        (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c),
        v_key_col)
        using v_patch, p_entity_id;
      get diagnostics v_n = row_count;
      if v_n <> 1 then
        raise exception 'draft target row missing: %', v_table using errcode = 'P0002';
      end if;
    end if;
  end loop;

  if p_entity = 'article' and v_draft.payload ? 'item_ids' then
    delete from guide.article_items ai where ai.article_id = p_entity_id;
    insert into guide.article_items (article_id, item_id, sort_order)
    select p_entity_id, (e.v #>> '{}')::uuid, e.ord::integer
    from jsonb_array_elements(v_draft.payload -> 'item_ids') with ordinality as e(v, ord);
  end if;

  if p_entity = 'item' and v_draft.payload ? 'gallery' then
    delete from guide.item_media im where im.item_id = p_entity_id;
    insert into guide.item_media (item_id, media_id, sort_order)
    select p_entity_id, (e.v #>> '{}')::uuid, e.ord::integer
    from jsonb_array_elements(v_draft.payload -> 'gallery') with ordinality as e(v, ord);
  end if;

  if p_entity = 'item' and v_draft.payload ? 'scores' then
    select r.id into v_review from guide.author_reviews r where r.item_id = p_entity_id;
    if v_review is null then
      raise exception 'author review missing' using errcode = '22023';
    end if;
    delete from guide.author_review_scores s where s.review_id = v_review;
    insert into guide.author_review_scores (review_id, criterion_id, category, score)
    select v_review, e.key::uuid, v_category, e.value::text::smallint
    from jsonb_each(v_draft.payload -> 'scores') e;
  end if;

  perform set_config('guide.draft_op', 'publish', true);
  delete from guide.content_drafts d where d.id = v_draft.id;
  perform set_config('guide.draft_op', '', true);

  return guide.draft_entity_version(p_entity, p_entity_id);
end;
$$;

create or replace function guide.discard_draft(p_entity text, p_entity_id uuid)
returns boolean
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  perform set_config('guide.draft_op', '', true);
  delete from guide.content_drafts d where d.entity_id = p_entity_id and d.entity = p_entity;
  return found;
end;
$$;

-- ───────────── Registro de exportaciones ─────────────
-- El panel exporta leyendo las vistas export_* (RLS + is_admin) y después llama a log_export.
-- SECURITY DEFINER: activity_log no admite escrituras de clientes; aquí se valida todo y no se
-- guardan datos personales (claves de filtro en lista blanca, búsqueda libre sin su texto,
-- valores restringidos a códigos/fechas/uuid).
create or replace function guide.log_export(
  p_view text,
  p_format text,
  p_filters jsonb default '{}'::jsonb,
  p_row_count integer default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_keys    constant text[] := array['status', 'locale', 'category', 'category_id', 'item_id', 'source',
                                     'consent_source', 'visit_type', 'published', 'has_en', 'from', 'to',
                                     'sort', 'q'];
  c_value   constant text := '^[A-Za-z0-9_:.+-]{1,64}$';
  v_filters jsonb := coalesce(p_filters, '{}'::jsonb);
  v_clean   jsonb := '{}'::jsonb;
  v_key     text;
  v_val     jsonb;
begin
  if not guide.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  if p_view is null or p_view not in ('export_articles', 'export_items', 'export_user_reviews',
                                      'export_subscribers', 'export_events') then
    raise exception 'invalid view' using errcode = '22023';
  end if;
  if p_format is null or p_format not in ('csv', 'json') then
    raise exception 'invalid format' using errcode = '22023';
  end if;
  if p_row_count is null or p_row_count < 0 or p_row_count > 1000000 then
    raise exception 'invalid row count' using errcode = '22023';
  end if;
  if jsonb_typeof(v_filters) <> 'object' or (select count(*) from jsonb_object_keys(v_filters)) > 20 then
    raise exception 'invalid filters' using errcode = '22023';
  end if;

  for v_key, v_val in select e.key, e.value from jsonb_each(v_filters) e loop
    if not (v_key = any (c_keys)) then
      raise exception 'invalid filters' using errcode = '22023';
    end if;
    if v_key = 'q' then
      -- Búsqueda libre: puede contener emails o nombres; solo se registra que la hubo.
      v_clean := v_clean || jsonb_build_object('q', jsonb_typeof(v_val) = 'string' and btrim(v_val #>> '{}') <> '');
      continue;
    end if;
    if jsonb_typeof(v_val) in ('boolean', 'number', 'null')
       or (jsonb_typeof(v_val) = 'string' and (v_val #>> '{}') ~ c_value)
       or (jsonb_typeof(v_val) = 'array' and jsonb_array_length(v_val) <= 20
           and not exists (select 1 from jsonb_array_elements(v_val) x
                           where not (jsonb_typeof(x) in ('boolean', 'number')
                                      or (jsonb_typeof(x) = 'string' and (x #>> '{}') ~ c_value)))) then
      v_clean := v_clean || jsonb_build_object(v_key, v_val);
    else
      raise exception 'invalid filters' using errcode = '22023';
    end if;
  end loop;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, details)
  values ((select auth.uid()), 'export', p_view, '*', null,
          jsonb_build_object('format', p_format, 'row_count', p_row_count, 'filters', v_clean));
end;
$$;

-- ───────────── Grants ─────────────
revoke execute on function guide.draft_allowed_columns(text) from public, anon;
revoke execute on function guide.draft_section_table(text, text, text) from public, anon;
revoke execute on function guide.draft_media_ids(jsonb) from public, anon;
revoke execute on function guide.draft_entity_version(text, uuid) from public, anon;
revoke execute on function guide.draft_check_payload(text, uuid, jsonb) from public, anon;
revoke execute on function guide.content_drafts_before_write() from public, anon, authenticated;
revoke execute on function guide.media_draft_guard() from public, anon, authenticated;
revoke execute on function guide.save_draft(text, uuid, jsonb, timestamptz) from public, anon;
revoke execute on function guide.publish_draft(text, uuid, boolean) from public, anon;
revoke execute on function guide.discard_draft(text, uuid) from public, anon;
revoke execute on function guide.log_export(text, text, jsonb, integer) from public, anon;

-- Los helpers se conceden a authenticated porque las RPC (INVOKER) y la vista media_usage los
-- llaman con el rol del cliente. Son puros o leen bajo RLS; no escriben nada.
grant execute on function guide.draft_allowed_columns(text) to authenticated;
grant execute on function guide.draft_section_table(text, text, text) to authenticated;
grant execute on function guide.draft_media_ids(jsonb) to authenticated;
grant execute on function guide.draft_entity_version(text, uuid) to authenticated;
grant execute on function guide.draft_check_payload(text, uuid, jsonb) to authenticated;
grant execute on function guide.save_draft(text, uuid, jsonb, timestamptz) to authenticated;
grant execute on function guide.publish_draft(text, uuid, boolean) to authenticated;
grant execute on function guide.discard_draft(text, uuid) to authenticated;
grant execute on function guide.log_export(text, text, jsonb, integer) to authenticated;
