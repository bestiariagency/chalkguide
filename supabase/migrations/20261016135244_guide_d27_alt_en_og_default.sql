-- D27 (2) · alt_en obligatorio en los cuerpos EN y alt de la OG por defecto (decisión de Xavi).
--
-- Requisitos por medio e idioma ('es:<uuid>' / 'en:<uuid>'):
--   artículo / página: alt_es en portada, OG, cuerpo ES y cuerpo EN (si has_en);
--                      alt_en en las imágenes del cuerpo EN (si has_en).
--   ficha:             alt_es en portada, OG, galería y cuerpo de la reseña (ES, y EN si author_reviews.has_en);
--                      alt_en en el cuerpo EN de la reseña cuando la ficha está lista en EN
--                      (author_reviews.has_en and items.has_en = guide.item_is_en_ready).
--   Portada, OG y galería: alt_en solo aviso (content_alt_check.missing_alt_en).
--   OG por defecto (site_settings.default_og_media_id): alt_es y alt_en siempre (el sitio es bilingüe: la OG por
--   defecto también sale en /en).
-- Mismas reglas que D27: al entrar en publicado/programado, todo; ya publicado, solo lo nuevo; publish_draft, el
-- resultado completo; no se vacía alt_es ni alt_en de un medio que lo exige contenido publicado o la OG por defecto.
-- Error (sin cambios en code/message): PT422 'missing alt text';
--   details = {"entity", "entity_id", "media_ids": [...],             ← se mantiene (compatibilidad)
--              "missing": [{"media_id": "<uuid>", "lang": "es"|"en"}, ...]}
--   site_settings: entity = 'site_settings', entity_id = null, "setting_id": <id>.
--   media: además "used_by": [{"entity", "entity_id"}] ('site_settings' con su id numérico).

-- ───────────── Requisitos ─────────────
create or replace function guide.alt_reqs_body(p_lang text, p_json jsonb, p_html text)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(p_lang || ':' || x::text), '{}'::text[]) from unnest(guide.body_media_ids(p_json, p_html)) x;
$$;

create or replace function guide.content_alt_reqs(
  p_cover uuid, p_og uuid, p_json_es jsonb, p_html_es text, p_json_en jsonb, p_html_en text,
  p_has_en boolean, p_en_alt boolean
)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct r), '{}'::text[])
  from (
    select 'es:' || p_cover::text where p_cover is not null
    union all select 'es:' || p_og::text where p_og is not null
    union all select unnest(guide.alt_reqs_body('es', p_json_es, p_html_es))
    union all select unnest(guide.alt_reqs_body('es', p_json_en, p_html_en)) where coalesce(p_has_en, false)
    union all select unnest(guide.alt_reqs_body('en', p_json_en, p_html_en))
              where coalesce(p_has_en, false) and coalesce(p_en_alt, false)
  ) s(r);
$$;

create or replace function guide.item_alt_reqs(p_item_id uuid, p_cover uuid, p_og uuid, p_item_has_en boolean)
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct r), '{}'::text[])
  from (
    select 'es:' || p_cover::text where p_cover is not null
    union all select 'es:' || p_og::text where p_og is not null
    union all select 'es:' || im.media_id::text from guide.item_media im where im.item_id = p_item_id
    union all
    select unnest(guide.content_alt_reqs(null, null, ar.body_json_es, ar.body_html_es, ar.body_json_en, ar.body_html_en,
                                         ar.has_en, p_item_has_en))
    from guide.author_reviews ar where ar.item_id = p_item_id
  ) s(r);
$$;

-- Requisitos cuyo alt falta (ordenados).
create or replace function guide.alt_reqs_missing(p_reqs text[])
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(r order by r), '{}'::text[])
  from unnest(coalesce(p_reqs, '{}'::text[])) r
  join guide.media m on m.id = split_part(r, ':', 2)::uuid
  where case split_part(r, ':', 1)
          when 'es' then guide.alt_is_missing(m.alt_es)
          when 'en' then guide.alt_is_missing(m.alt_en)
          else false
        end;
$$;

create or replace function guide.text_array_except(p_a text[], p_b text[])
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(x order by x), '{}'::text[])
  from (select unnest(coalesce(p_a, '{}'::text[])) except select unnest(coalesce(p_b, '{}'::text[]))) s(x);
$$;

create or replace function guide.raise_missing_alt_reqs(p_entity text, p_entity_id uuid, p_missing text[],
                                                        p_extra jsonb default '{}'::jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'missing alt text'
    using errcode = 'PT422',
          detail = (jsonb_build_object(
                      'entity', p_entity,
                      'entity_id', p_entity_id,
                      'media_ids', (select coalesce(jsonb_agg(d.x order by d.x), '[]'::jsonb)
                                    from (select distinct split_part(r, ':', 2)::uuid as x from unnest(p_missing) r) d),
                      'missing', (select coalesce(jsonb_agg(jsonb_build_object('media_id', split_part(r, ':', 2)::uuid,
                                                                               'lang', split_part(r, ':', 1)) order by r),
                                                  '[]'::jsonb)
                                  from unnest(p_missing) r))
                    || coalesce(p_extra, '{}'::jsonb))::text,
          hint = 'Fill the missing alt text of these media before publishing: alt_es always, alt_en in English bodies (D27).';
end;
$$;

-- Requisitos sin cumplir del estado GUARDADO (base de publish_draft).
create or replace function guide.entity_alt_missing(p_entity text, p_entity_id uuid)
returns text[]
language sql
stable
set search_path = ''
as $$
  select guide.alt_reqs_missing(case p_entity
    when 'article' then (select guide.content_alt_reqs(a.cover_media_id, a.og_media_id, a.body_json_es, a.body_html_es,
                                                       a.body_json_en, a.body_html_en, a.has_en, a.has_en)
                         from guide.articles a where a.id = p_entity_id)
    when 'page' then (select guide.content_alt_reqs(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                                    p.body_json_en, p.body_html_en, p.has_en, p.has_en)
                      from guide.pages p where p.id = p_entity_id)
    when 'item' then (select guide.item_alt_reqs(i.id, i.cover_media_id, i.og_media_id, i.has_en)
                      from guide.items i where i.id = p_entity_id)
  end);
$$;

-- Checklist del panel. missing_alt_es: bloquea. missing_alt_en: falta alt_en y el contenido tiene EN;
-- alt_en_required: ese alt_en bloquea (imagen de un cuerpo EN); si es false, solo aviso (portada, OG, galería).
drop function if exists guide.content_alt_check(text, uuid);
create function guide.content_alt_check(p_entity text, p_entity_id uuid)
returns table (media_id uuid, missing_alt_es boolean, missing_alt_en boolean, alt_en_required boolean)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_reqs   text[];
  v_has_en boolean;
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  case p_entity
    when 'article' then
      select guide.content_alt_reqs(a.cover_media_id, a.og_media_id, a.body_json_es, a.body_html_es,
                                    a.body_json_en, a.body_html_en, a.has_en, a.has_en), a.has_en
      into v_reqs, v_has_en from guide.articles a where a.id = p_entity_id;
    when 'page' then
      select guide.content_alt_reqs(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                    p.body_json_en, p.body_html_en, p.has_en, p.has_en), p.has_en
      into v_reqs, v_has_en from guide.pages p where p.id = p_entity_id;
    else
      select guide.item_alt_reqs(i.id, i.cover_media_id, i.og_media_id, i.has_en), i.has_en
      into v_reqs, v_has_en from guide.items i where i.id = p_entity_id;
  end case;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  return query
  select m.id,
         guide.alt_is_missing(m.alt_es),
         coalesce(v_has_en, false) and guide.alt_is_missing(m.alt_en),
         ('en:' || m.id::text) = any (v_reqs)
  from guide.media m
  where m.id in (select split_part(r, ':', 2)::uuid from unnest(v_reqs) r)
    and (guide.alt_is_missing(m.alt_es) or (coalesce(v_has_en, false) and guide.alt_is_missing(m.alt_en)))
  order by m.id;
end;
$$;

-- ───────────── Guardas por tabla ─────────────
create or replace function guide.articles_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
  v_old_committed boolean;
begin
  if new.status not in ('scheduled', 'published') or guide.alt_guard_bypassed()
     or (tg_op = 'UPDATE' and old.status in ('scheduled', 'published') and guide.alt_unpublish_bypassed(new.id)) then
    return new;
  end if;
  v_old_committed := tg_op = 'UPDATE' and old.status in ('scheduled', 'published');
  if v_old_committed
     and new.cover_media_id is not distinct from old.cover_media_id and new.og_media_id is not distinct from old.og_media_id
     and new.body_json_es is not distinct from old.body_json_es and new.body_html_es is not distinct from old.body_html_es
     and new.body_json_en is not distinct from old.body_json_en and new.body_html_en is not distinct from old.body_html_en
     and new.has_en is not distinct from old.has_en then
    return new;
  end if;

  v_missing := guide.alt_reqs_missing(guide.content_alt_reqs(
    new.cover_media_id, new.og_media_id, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en,
    new.has_en, new.has_en));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.text_array_except(v_missing, guide.alt_reqs_missing(guide.content_alt_reqs(
      old.cover_media_id, old.og_media_id, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en,
      old.has_en, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('article', new.id, v_missing);
  end if;
  return new;
end;
$$;

create or replace function guide.pages_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
  v_old_committed boolean;
begin
  if not new.published or guide.alt_guard_bypassed() then
    return new;
  end if;
  v_old_committed := tg_op = 'UPDATE' and old.published;
  if v_old_committed
     and new.og_media_id is not distinct from old.og_media_id
     and new.body_json_es is not distinct from old.body_json_es and new.body_html_es is not distinct from old.body_html_es
     and new.body_json_en is not distinct from old.body_json_en and new.body_html_en is not distinct from old.body_html_en
     and new.has_en is not distinct from old.has_en then
    return new;
  end if;

  v_missing := guide.alt_reqs_missing(guide.content_alt_reqs(
    null, new.og_media_id, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en, new.has_en, new.has_en));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.text_array_except(v_missing, guide.alt_reqs_missing(guide.content_alt_reqs(
      null, old.og_media_id, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en, old.has_en, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('page', new.id, v_missing);
  end if;
  return new;
end;
$$;

create or replace function guide.items_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
  v_old_committed boolean;
begin
  if not new.published or guide.alt_guard_bypassed() then
    return new;
  end if;
  v_old_committed := tg_op = 'UPDATE' and old.published;
  if v_old_committed and new.id = old.id
     and new.cover_media_id is not distinct from old.cover_media_id and new.og_media_id is not distinct from old.og_media_id
     and new.has_en is not distinct from old.has_en then
    return new;
  end if;

  v_missing := guide.alt_reqs_missing(guide.item_alt_reqs(new.id, new.cover_media_id, new.og_media_id, new.has_en));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.text_array_except(v_missing,
      guide.alt_reqs_missing(guide.item_alt_reqs(old.id, old.cover_media_id, old.og_media_id, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('item', new.id, v_missing);
  end if;
  return new;
end;
$$;

create or replace function guide.item_media_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
begin
  if guide.alt_guard_bypassed()
     or (tg_op = 'UPDATE' and new.media_id = old.media_id and new.item_id = old.item_id)
     or not exists (select 1 from guide.items i where i.id = new.item_id and i.published) then
    return new;
  end if;
  v_missing := guide.alt_reqs_missing(array['es:' || new.media_id::text]);
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('item', new.item_id, v_missing);
  end if;
  return new;
end;
$$;

create or replace function guide.author_reviews_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing     text[];
  v_item_has_en boolean;
begin
  select i.has_en into v_item_has_en from guide.items i where i.id = new.item_id and i.published;
  if not found or guide.alt_guard_bypassed() then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.item_id = old.item_id
     and new.body_json_es is not distinct from old.body_json_es and new.body_html_es is not distinct from old.body_html_es
     and new.body_json_en is not distinct from old.body_json_en and new.body_html_en is not distinct from old.body_html_en
     and new.has_en is not distinct from old.has_en then
    return new;
  end if;

  v_missing := guide.alt_reqs_missing(guide.content_alt_reqs(
    null, null, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en, new.has_en, v_item_has_en));
  if tg_op = 'UPDATE' and new.item_id = old.item_id and cardinality(v_missing) > 0 then
    v_missing := guide.text_array_except(v_missing, guide.alt_reqs_missing(guide.content_alt_reqs(
      null, null, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en, old.has_en, v_item_has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('item', new.item_id, v_missing);
  end if;
  return new;
end;
$$;

-- OG por defecto del sitio: alt_es y alt_en.
create or replace function guide.site_settings_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[];
begin
  if new.default_og_media_id is null or guide.alt_guard_bypassed()
     or (tg_op = 'UPDATE' and new.default_og_media_id is not distinct from old.default_og_media_id) then
    return new;
  end if;
  v_missing := guide.alt_reqs_missing(array['es:' || new.default_og_media_id::text, 'en:' || new.default_og_media_id::text]);
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('site_settings', null, v_missing, jsonb_build_object('setting_id', new.id));
  end if;
  return new;
end;
$$;

drop trigger if exists site_settings_require_alt on guide.site_settings;
create trigger site_settings_require_alt
  after insert or update of default_og_media_id on guide.site_settings
  for each row execute function guide.site_settings_require_alt();

-- Contenido publicado/programado (o la OG por defecto) que exige el alt de un medio en un idioma.
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
    where s.default_og_media_id = p_id and p_lang in ('es', 'en')
  ) o;
$$;

create or replace function guide.media_committed_owners(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select guide.media_committed_owners(p_id, 'es');
$$;

create or replace function guide.media_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing text[] := '{}';
  v_owners  jsonb := '[]'::jsonb;
  v_o       jsonb;
begin
  if guide.alt_guard_bypassed() then
    return new;
  end if;
  if not guide.alt_is_missing(old.alt_es) and guide.alt_is_missing(new.alt_es) then
    v_o := guide.media_committed_owners(new.id, 'es');
    if jsonb_array_length(v_o) > 0 then
      v_missing := v_missing || ('es:' || new.id::text);
      v_owners := v_owners || v_o;
    end if;
  end if;
  if not guide.alt_is_missing(old.alt_en) and guide.alt_is_missing(new.alt_en) then
    v_o := guide.media_committed_owners(new.id, 'en');
    if jsonb_array_length(v_o) > 0 then
      v_missing := v_missing || ('en:' || new.id::text);
      v_owners := v_owners || v_o;
    end if;
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt_reqs('media', new.id, v_missing,
      jsonb_build_object('used_by', (select jsonb_agg(distinct e) from jsonb_array_elements(v_owners) e)));
  end if;
  return new;
end;
$$;

drop trigger if exists media_require_alt on guide.media;
create trigger media_require_alt
  after update of alt_es, alt_en on guide.media
  for each row execute function guide.media_require_alt();

-- publish_draft: igual que 20261016090532, con la comprobación D27 por idioma.
create or replace function guide.publish_draft(p_entity text, p_entity_id uuid, p_force boolean default false)
returns timestamp with time zone
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
  v_missing  text[];
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

  -- F6.4 / F6.7: las guardas de lo vivo dejan escribir sobre ESTE artículo o ficha solo aquí.
  if p_entity in ('article', 'item') then
    perform set_config('guide.draft_op', 'apply:' || p_entity_id::text, true);
  end if;

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

  -- D27: el resultado publicado no puede llevar imágenes sin alt (alt_es siempre; alt_en en cuerpos EN), salvo dentro
  -- de unpublish_article / unpublish_item (V1).
  if not guide.alt_unpublish_bypassed(p_entity_id)
     and not guide.alt_guard_bypassed()
     and coalesce(guide.draft_entity_is_live(p_entity, p_entity_id)
                  or (p_entity = 'article' and exists (select 1 from guide.articles a
                                                       where a.id = p_entity_id and a.status = 'scheduled')), false) then
    v_missing := guide.entity_alt_missing(p_entity, p_entity_id);
    if cardinality(v_missing) > 0 then
      perform guide.raise_missing_alt_reqs(p_entity, p_entity_id, v_missing);
    end if;
  end if;

  perform set_config('guide.draft_op', 'publish', true);
  delete from guide.content_drafts d where d.id = v_draft.id;
  perform set_config('guide.draft_op', '', true);

  return guide.draft_entity_version(p_entity, p_entity_id);
end;
$$;

-- Funciones de la primera versión de D27 que ya no usa nada (sustituidas por las de requisitos por idioma).
drop function if exists guide.entity_missing_alt(text, uuid);
drop function if exists guide.raise_missing_alt(text, uuid, uuid[], jsonb);
drop function if exists guide.item_alt_media_ids(uuid, uuid, uuid);
drop function if exists guide.content_alt_media_ids(uuid, uuid, jsonb, text, jsonb, text, boolean);
drop function if exists guide.media_missing_alt(uuid[]);

-- ───────────── Grants ─────────────
revoke execute on function guide.alt_reqs_body(text, jsonb, text) from public;
revoke execute on function guide.content_alt_reqs(uuid, uuid, jsonb, text, jsonb, text, boolean, boolean) from public;
revoke execute on function guide.item_alt_reqs(uuid, uuid, uuid, boolean) from public;
revoke execute on function guide.alt_reqs_missing(text[]) from public;
revoke execute on function guide.text_array_except(text[], text[]) from public;
revoke execute on function guide.raise_missing_alt_reqs(text, uuid, text[], jsonb) from public;
revoke execute on function guide.entity_alt_missing(text, uuid) from public;
revoke execute on function guide.content_alt_check(text, uuid) from public;
revoke execute on function guide.site_settings_require_alt() from public;
revoke execute on function guide.media_committed_owners(uuid, text) from public;
revoke execute on function guide.media_committed_owners(uuid) from public;
grant execute on function guide.alt_reqs_body(text, jsonb, text) to authenticated, service_role;
grant execute on function guide.content_alt_reqs(uuid, uuid, jsonb, text, jsonb, text, boolean, boolean) to authenticated, service_role;
grant execute on function guide.item_alt_reqs(uuid, uuid, uuid, boolean) to authenticated, service_role;
grant execute on function guide.alt_reqs_missing(text[]) to authenticated, service_role;
grant execute on function guide.text_array_except(text[], text[]) to authenticated, service_role;
grant execute on function guide.raise_missing_alt_reqs(text, uuid, text[], jsonb) to authenticated, service_role;
grant execute on function guide.entity_alt_missing(text, uuid) to authenticated, service_role;
grant execute on function guide.content_alt_check(text, uuid) to authenticated;
grant execute on function guide.media_committed_owners(uuid, text) to authenticated, service_role;
grant execute on function guide.media_committed_owners(uuid) to authenticated, service_role;
