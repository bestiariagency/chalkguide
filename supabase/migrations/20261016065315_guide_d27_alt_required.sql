-- D27 · Texto alternativo obligatorio: no se publica contenido con imágenes sin alt_es.
--
-- "Comprometido" = lo que está o va a estar a la vista sin otra acción del autor:
--   artículos status in ('scheduled','published') (programado incluido: publish_due_articles lo publica solo),
--   fichas items.published, páginas pages.published.
-- Imágenes que exigen alt_es (media.alt_es no vacío tras quitar espacios):
--   artículo: cover_media_id, og_media_id, cuerpo ES, cuerpo EN si has_en;
--   página:   og_media_id, cuerpo ES, cuerpo EN si has_en;
--   ficha:    cover_media_id, og_media_id, galería (item_media), cuerpo ES de la reseña del autor y EN si
--             author_reviews.has_en.
--   Cuerpo = attrs.mediaId del JSON (lo que indexa content_media_refs) ∪ data-media-id del HTML ∪ medios cuya
--   ruta vigente aparece en el HTML (imagen pegada por URL, mismo criterio que media_usage).
--
-- Mecanismo (triggers AFTER ROW: ven la fila final, con la normalización de articles_before_write y las
-- columnas generadas has_en, que no existen aún en BEFORE; un error aborta la sentencia igual):
--   · Entrar en comprometido (insert o transición) → todas las imágenes deben tener alt_es.
--   · Seguir comprometido → solo se rechazan imágenes sin alt NUEVAS (delta frente a OLD): lo existente
--     no se rompe y publish_due_articles (scheduled → published, sin cambio de contenido) nunca falla por D27.
--   · item_media / author_reviews sobre una ficha publicada → delta.
--   · publish_draft ("Publicar cambios") → comprobación completa del resultado (es publicar).
--   · media: no se puede vaciar alt_es de un medio usado por contenido comprometido.
--   Escapes: mantenimiento explícito como rol con bypassrls (guide.draft_op = 'maintenance', igual que F6.4) y
--   unpublish_article (aplica el borrador pendiente justo antes de pasar a borrador). OJO: la exención por
--   guide.unpublish_op de esta versión no exigía rol (veto V1); la corrige 20261016085031 (GUC + bypassrls).
--
-- Contrato de error (PostgREST lo devuelve como HTTP 422):
--   code    'PT422'
--   message 'missing alt text'
--   details JSON: {"entity":"article|page|item|media","entity_id":"<uuid>","media_ids":["<uuid>",…]}
--           (media: además "used_by":[{"entity":…,"entity_id":…}])
--   hint    'Fill alt_es of these media before publishing (D27).'

-- ───────────── Helpers ─────────────
create or replace function guide.alt_is_missing(p_alt text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_alt, '') ~ '^[[:space:]]*$';
$$;

create or replace function guide.html_media_ids(p_html text)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct lower(m[1])::uuid), '{}'::uuid[])
  from regexp_matches(coalesce(p_html, ''),
    'data-media-id\s*=\s*["'']([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})["'']', 'gi') as m;
$$;

create or replace function guide.body_media_ids(p_json jsonb, p_html text)
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct x), '{}'::uuid[])
  from (
    select unnest(guide.extract_media_ids(p_json))
    union all
    select unnest(guide.html_media_ids(p_html))
    union all
    select m.id from guide.media m where p_html is not null and strpos(p_html, m.storage_path) > 0
  ) s(x)
  where x is not null;
$$;

-- Medios de un contenido que exigen alt_es (artículos, páginas y cuerpos de reseña; p_cover/p_og null si no aplica).
create or replace function guide.content_alt_media_ids(
  p_cover uuid, p_og uuid, p_json_es jsonb, p_html_es text, p_json_en jsonb, p_html_en text, p_has_en boolean
)
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct x), '{}'::uuid[])
  from (
    select p_cover union all select p_og
    union all select unnest(guide.body_media_ids(p_json_es, p_html_es))
    union all select unnest(guide.body_media_ids(p_json_en, p_html_en)) where coalesce(p_has_en, false)
  ) s(x)
  where x is not null;
$$;

-- Ficha: portada/OG (valores de la fila que se escribe) + galería y reseña del autor guardadas.
create or replace function guide.item_alt_media_ids(p_item_id uuid, p_cover uuid, p_og uuid)
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(distinct x), '{}'::uuid[])
  from (
    select p_cover union all select p_og
    union all select im.media_id from guide.item_media im where im.item_id = p_item_id
    union all
    select unnest(guide.content_alt_media_ids(null, null, ar.body_json_es, ar.body_html_es,
                                              ar.body_json_en, ar.body_html_en, ar.has_en))
    from guide.author_reviews ar where ar.item_id = p_item_id
  ) s(x)
  where x is not null;
$$;

create or replace function guide.media_missing_alt(p_ids uuid[])
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array_agg(m.id order by m.id), '{}'::uuid[])
  from guide.media m
  where m.id = any (coalesce(p_ids, '{}'::uuid[])) and guide.alt_is_missing(m.alt_es);
$$;

-- a \ b, ordenado (para el delta "solo lo nuevo").
create or replace function guide.uuid_array_except(p_a uuid[], p_b uuid[])
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(x order by x), '{}'::uuid[])
  from (select unnest(coalesce(p_a, '{}'::uuid[])) except select unnest(coalesce(p_b, '{}'::uuid[]))) s(x);
$$;

create or replace function guide.alt_guard_bypassed()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
     and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false);
$$;

create or replace function guide.raise_missing_alt(p_entity text, p_entity_id uuid, p_media_ids uuid[], p_extra jsonb default '{}'::jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'missing alt text'
    using errcode = 'PT422',
          detail = (jsonb_build_object('entity', p_entity, 'entity_id', p_entity_id, 'media_ids', to_jsonb(p_media_ids))
                    || coalesce(p_extra, '{}'::jsonb))::text,
          hint = 'Fill alt_es of these media before publishing (D27).';
end;
$$;

-- Medios sin alt_es del estado GUARDADO de un contenido (comprometido o no). Base de publish_draft.
create or replace function guide.entity_missing_alt(p_entity text, p_entity_id uuid)
returns uuid[]
language sql
stable
set search_path = ''
as $$
  select guide.media_missing_alt(case p_entity
    when 'article' then (select guide.content_alt_media_ids(a.cover_media_id, a.og_media_id, a.body_json_es, a.body_html_es,
                                                            a.body_json_en, a.body_html_en, a.has_en)
                         from guide.articles a where a.id = p_entity_id)
    when 'page' then (select guide.content_alt_media_ids(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                                         p.body_json_en, p.body_html_en, p.has_en)
                      from guide.pages p where p.id = p_entity_id)
    when 'item' then (select guide.item_alt_media_ids(i.id, i.cover_media_id, i.og_media_id)
                      from guide.items i where i.id = p_entity_id)
  end);
$$;

-- RPC del panel (checklist de publicar): imágenes del estado guardado con alt pendiente.
-- missing_alt_es bloquea publicar (D27); missing_alt_en es solo aviso y solo si el contenido tiene versión EN.
create or replace function guide.content_alt_check(p_entity text, p_entity_id uuid)
returns table (media_id uuid, missing_alt_es boolean, missing_alt_en boolean)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_ids    uuid[];
  v_has_en boolean;
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  case p_entity
    when 'article' then
      select guide.content_alt_media_ids(a.cover_media_id, a.og_media_id, a.body_json_es, a.body_html_es,
                                         a.body_json_en, a.body_html_en, a.has_en), a.has_en
      into v_ids, v_has_en from guide.articles a where a.id = p_entity_id;
    when 'page' then
      select guide.content_alt_media_ids(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                         p.body_json_en, p.body_html_en, p.has_en), p.has_en
      into v_ids, v_has_en from guide.pages p where p.id = p_entity_id;
    else
      select guide.item_alt_media_ids(i.id, i.cover_media_id, i.og_media_id), i.has_en
      into v_ids, v_has_en from guide.items i where i.id = p_entity_id;
  end case;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  return query
  select m.id, guide.alt_is_missing(m.alt_es), coalesce(v_has_en, false) and guide.alt_is_missing(m.alt_en)
  from guide.media m
  where m.id = any (v_ids)
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
  v_missing uuid[];
  v_old_committed boolean;
begin
  if new.status not in ('scheduled', 'published') or guide.alt_guard_bypassed()
     or coalesce(current_setting('guide.unpublish_op', true), '') = new.id::text then
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

  v_missing := guide.media_missing_alt(guide.content_alt_media_ids(
    new.cover_media_id, new.og_media_id, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en, new.has_en));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.uuid_array_except(v_missing, guide.media_missing_alt(guide.content_alt_media_ids(
      old.cover_media_id, old.og_media_id, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt('article', new.id, v_missing);
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
  v_missing uuid[];
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

  v_missing := guide.media_missing_alt(guide.content_alt_media_ids(
    null, new.og_media_id, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en, new.has_en));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.uuid_array_except(v_missing, guide.media_missing_alt(guide.content_alt_media_ids(
      null, old.og_media_id, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt('page', new.id, v_missing);
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
  v_missing uuid[];
  v_old_committed boolean;
begin
  if not new.published or guide.alt_guard_bypassed() then
    return new;
  end if;
  v_old_committed := tg_op = 'UPDATE' and old.published;
  if v_old_committed and new.id = old.id
     and new.cover_media_id is not distinct from old.cover_media_id and new.og_media_id is not distinct from old.og_media_id then
    return new;
  end if;

  v_missing := guide.media_missing_alt(guide.item_alt_media_ids(new.id, new.cover_media_id, new.og_media_id));
  if v_old_committed and cardinality(v_missing) > 0 then
    v_missing := guide.uuid_array_except(v_missing,
      guide.media_missing_alt(guide.item_alt_media_ids(old.id, old.cover_media_id, old.og_media_id)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt('item', new.id, v_missing);
  end if;
  return new;
end;
$$;

create or replace function guide.item_media_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if guide.alt_guard_bypassed()
     or (tg_op = 'UPDATE' and new.media_id = old.media_id and new.item_id = old.item_id)
     or not exists (select 1 from guide.items i where i.id = new.item_id and i.published)
     or cardinality(guide.media_missing_alt(array[new.media_id])) = 0 then
    return new;
  end if;
  perform guide.raise_missing_alt('item', new.item_id, array[new.media_id]);
  return new;
end;
$$;

create or replace function guide.author_reviews_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing uuid[];
begin
  if guide.alt_guard_bypassed()
     or not exists (select 1 from guide.items i where i.id = new.item_id and i.published) then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.item_id = old.item_id
     and new.body_json_es is not distinct from old.body_json_es and new.body_html_es is not distinct from old.body_html_es
     and new.body_json_en is not distinct from old.body_json_en and new.body_html_en is not distinct from old.body_html_en
     and new.has_en is not distinct from old.has_en then
    return new;
  end if;

  v_missing := guide.media_missing_alt(guide.content_alt_media_ids(
    null, null, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en, new.has_en));
  if tg_op = 'UPDATE' and new.item_id = old.item_id and cardinality(v_missing) > 0 then
    v_missing := guide.uuid_array_except(v_missing, guide.media_missing_alt(guide.content_alt_media_ids(
      null, null, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en, old.has_en)));
  end if;
  if cardinality(v_missing) > 0 then
    perform guide.raise_missing_alt('item', new.item_id, v_missing);
  end if;
  return new;
end;
$$;

-- Contenido comprometido que exige el alt de un medio (para no dejar vaciarlo).
create or replace function guide.media_committed_owners(p_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object('entity', o.entity, 'entity_id', o.id) order by o.entity, o.id), '[]'::jsonb)
  from (
    select 'article'::text as entity, a.id
    from guide.articles a
    where a.status in ('scheduled', 'published')
      and p_id = any (guide.content_alt_media_ids(a.cover_media_id, a.og_media_id, a.body_json_es, a.body_html_es,
                                                  a.body_json_en, a.body_html_en, a.has_en))
    union
    select 'page', p.id
    from guide.pages p
    where p.published
      and p_id = any (guide.content_alt_media_ids(null, p.og_media_id, p.body_json_es, p.body_html_es,
                                                  p.body_json_en, p.body_html_en, p.has_en))
    union
    select 'item', i.id
    from guide.items i
    where i.published and p_id = any (guide.item_alt_media_ids(i.id, i.cover_media_id, i.og_media_id))
  ) o;
$$;

create or replace function guide.media_require_alt()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_owners jsonb;
begin
  if guide.alt_guard_bypassed() or guide.alt_is_missing(old.alt_es) or not guide.alt_is_missing(new.alt_es) then
    return new;
  end if;
  v_owners := guide.media_committed_owners(new.id);
  if jsonb_array_length(v_owners) > 0 then
    perform guide.raise_missing_alt('media', new.id, array[new.id], jsonb_build_object('used_by', v_owners));
  end if;
  return new;
end;
$$;

drop trigger if exists articles_require_alt on guide.articles;
create trigger articles_require_alt
  after insert or update on guide.articles
  for each row execute function guide.articles_require_alt();

drop trigger if exists pages_require_alt on guide.pages;
create trigger pages_require_alt
  after insert or update on guide.pages
  for each row execute function guide.pages_require_alt();

drop trigger if exists items_require_alt on guide.items;
create trigger items_require_alt
  after insert or update on guide.items
  for each row execute function guide.items_require_alt();

drop trigger if exists item_media_require_alt on guide.item_media;
create trigger item_media_require_alt
  after insert or update on guide.item_media
  for each row execute function guide.item_media_require_alt();

drop trigger if exists author_reviews_require_alt on guide.author_reviews;
create trigger author_reviews_require_alt
  after insert or update on guide.author_reviews
  for each row execute function guide.author_reviews_require_alt();

drop trigger if exists media_require_alt on guide.media;
create trigger media_require_alt
  after update of alt_es on guide.media
  for each row execute function guide.media_require_alt();

-- ───────────── publish_draft: "Publicar cambios" exige el resultado completo (D27) ─────────────
-- Igual que antes + comprobación completa tras aplicar, salvo dentro de unpublish_article (pasa a borrador).
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
  v_missing  uuid[];
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

  -- F6.4: articles_before_write deja escribir contenido sobre ESTE artículo vivo solo aquí.
  if p_entity = 'article' then
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

  -- D27: el resultado publicado no puede llevar imágenes sin alt_es (salvo al despublicar).
  if coalesce(current_setting('guide.unpublish_op', true), '') is distinct from p_entity_id::text
     and not guide.alt_guard_bypassed()
     and coalesce(guide.draft_entity_is_live(p_entity, p_entity_id)
                  or (p_entity = 'article' and exists (select 1 from guide.articles a
                                                       where a.id = p_entity_id and a.status = 'scheduled')), false) then
    v_missing := guide.entity_missing_alt(p_entity, p_entity_id);
    if cardinality(v_missing) > 0 then
      perform guide.raise_missing_alt(p_entity, p_entity_id, v_missing);
    end if;
  end if;

  perform set_config('guide.draft_op', 'publish', true);
  delete from guide.content_drafts d where d.id = v_draft.id;
  perform set_config('guide.draft_op', '', true);

  return guide.draft_entity_version(p_entity, p_entity_id);
end;
$$;

-- ───────────── Grants ─────────────
revoke execute on function guide.alt_is_missing(text) from public;
revoke execute on function guide.html_media_ids(text) from public;
revoke execute on function guide.body_media_ids(jsonb, text) from public;
revoke execute on function guide.content_alt_media_ids(uuid, uuid, jsonb, text, jsonb, text, boolean) from public;
revoke execute on function guide.item_alt_media_ids(uuid, uuid, uuid) from public;
revoke execute on function guide.media_missing_alt(uuid[]) from public;
revoke execute on function guide.uuid_array_except(uuid[], uuid[]) from public;
revoke execute on function guide.alt_guard_bypassed() from public;
revoke execute on function guide.raise_missing_alt(text, uuid, uuid[], jsonb) from public;
revoke execute on function guide.entity_missing_alt(text, uuid) from public;
revoke execute on function guide.content_alt_check(text, uuid) from public;
revoke execute on function guide.media_committed_owners(uuid) from public;
revoke execute on function guide.articles_require_alt() from public;
revoke execute on function guide.pages_require_alt() from public;
revoke execute on function guide.items_require_alt() from public;
revoke execute on function guide.item_media_require_alt() from public;
revoke execute on function guide.author_reviews_require_alt() from public;
revoke execute on function guide.media_require_alt() from public;

-- Los triggers corren como el invocador (admin = authenticated; mantenimiento = postgres).
grant execute on function guide.alt_is_missing(text) to authenticated, service_role;
grant execute on function guide.html_media_ids(text) to authenticated, service_role;
grant execute on function guide.body_media_ids(jsonb, text) to authenticated, service_role;
grant execute on function guide.content_alt_media_ids(uuid, uuid, jsonb, text, jsonb, text, boolean) to authenticated, service_role;
grant execute on function guide.item_alt_media_ids(uuid, uuid, uuid) to authenticated, service_role;
grant execute on function guide.media_missing_alt(uuid[]) to authenticated, service_role;
grant execute on function guide.uuid_array_except(uuid[], uuid[]) to authenticated, service_role;
grant execute on function guide.alt_guard_bypassed() to authenticated, service_role;
grant execute on function guide.raise_missing_alt(text, uuid, uuid[], jsonb) to authenticated, service_role;
grant execute on function guide.entity_missing_alt(text, uuid) to authenticated, service_role;
grant execute on function guide.content_alt_check(text, uuid) to authenticated;
grant execute on function guide.media_committed_owners(uuid) to authenticated, service_role;
