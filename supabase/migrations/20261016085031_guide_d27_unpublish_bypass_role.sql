-- D27 · Corrección del veto V1 de leona-lia (docs/security/D27-alt-required-review.md) y O1.
--
-- V1: la exención por guide.unpublish_op (20261016065315) no estaba atada al rol: un admin con el GUC
--     falsificado publicaba imágenes sin alt. Ahora la exención exige el GUC = id Y que current_user tenga
--     bypassrls, lo que solo ocurre dentro de guide.unpublish_article (SECURITY DEFINER de postgres; la
--     publish_draft anidada y los triggers heredan ese current_user). En articles_require_alt además solo
--     vale para un UPDATE de algo que ya estaba publicado o programado (no para publicar un borrador).
--     Sustituye a lo dicho en la cabecera de 20261016065315 ("Escapes: … unpublish_article").
-- O1: alt_is_missing trata como vacío un alt con solo espacios o invisibles (U+200B, U+200C, U+200D, U+2060,
--     U+FEFF).
-- Contrato de error sin cambios (PT422 'missing alt text', details JSON {entity, entity_id, media_ids}).

create or replace function guide.alt_is_missing(p_alt text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_alt, '') ~ ('^[[:space:]' || chr(8203) || chr(8204) || chr(8205) || chr(8288) || chr(65279) || ']*$');
$$;

-- Exención de unpublish_article: GUC del artículo y rol con bypassrls (no falsificable por un admin vía API).
create or replace function guide.alt_unpublish_bypassed(p_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_id is not null
     and coalesce(current_setting('guide.unpublish_op', true), '') = p_id::text
     and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false);
$$;

revoke execute on function guide.alt_unpublish_bypassed(uuid) from public;
grant execute on function guide.alt_unpublish_bypassed(uuid) to authenticated, service_role;

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

  -- D27: el resultado publicado no puede llevar imágenes sin alt_es (salvo dentro de unpublish_article, V1).
  if not guide.alt_unpublish_bypassed(p_entity_id)
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
