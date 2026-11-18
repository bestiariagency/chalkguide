-- F6.7 · Lo publicado no se edita en directo también en fichas (D23 en la BD, como F6.4 para artículos).
--
-- Tablas: items, detalle por categoría (gyms, resolers, shoes), author_reviews, author_review_scores, item_media.
-- Con la ficha publicada (antes y después del cambio), cualquier INSERT/UPDATE/DELETE que cambie contenido da
--   PT423 'item is live'  detail = 'changed: <columnas>' (items) | '<tabla>' / '<tabla>: <columnas>' | 'delete'
--   hint  = 'Edit a published item through save_draft/publish_draft, or unpublish it first (unpublish_item).'
-- Se permite (sin borrador):
--   · ocultar (published true → false) y publicar (false → true), con o sin más cambios en el mismo UPDATE;
--   · tocar solo items.verified_at o, en gyms, solo prices_verified_at ("marcar verificado hoy": sello editorial,
--     no contenido); cualquier otra columna en el mismo UPDATE ya da PT423;
--   · los toques de updated_at (touch_draft_parent) y las columnas generadas;
--   · cascadas al borrar una ficha no publicada (la ficha ya no existe cuando llegan a los hijos).
-- Borrar una ficha publicada: PT423 detail 'delete' (primero unpublish_item). Las fichas con opiniones siguen dando
-- antes 23503 'item has user reviews' (items_block_delete_with_reviews va primero).
-- Exenciones, atadas a la fila y al contexto (.ai/security-rls.md):
--   · guide.draft_op = 'apply:<item_id>': lo fija publish_draft para esa ficha (igual que para artículos);
--   · guide.draft_op = 'maintenance' y current_user con rolbypassrls (scripts como postgres);
--   · unpublish_item no necesita exención: oculta antes de aplicar el borrador.
-- Una categoría nueva con tabla de detalle propia necesita su trigger <tabla>_live_guard (como gyms/resolers/shoes).

create or replace function guide.item_live_exempt(p_item_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
          and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false))
      or (p_item_id is not null and coalesce(current_setting('guide.draft_op', true), '') = 'apply:' || p_item_id::text);
$$;

create or replace function guide.raise_item_live(p_detail text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'item is live'
    using errcode = 'PT423',
          detail = p_detail,
          hint = 'Edit a published item through save_draft/publish_draft, or unpublish it first (unpublish_item).';
end;
$$;

-- Columnas que cambian entre old y new, sin sellos de tiempo ni columnas generadas.
create or replace function guide.changed_columns(p_old jsonb, p_new jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_agg(n.key order by n.key)
  from jsonb_each(p_new) n
  where n.key not in ('updated_at', 'created_at', 'has_en', 'search_es', 'search_en')
    and n.value is distinct from (p_old -> n.key);
$$;

create or replace function guide.items_live_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_changed text[];
begin
  if tg_op = 'DELETE' then
    if old.published and not guide.item_live_exempt(null) then
      perform guide.raise_item_live('delete');
    end if;
    return old;
  end if;

  if not (old.published and new.published) or guide.item_live_exempt(old.id) then
    return new;
  end if;
  v_changed := guide.changed_columns(to_jsonb(old), to_jsonb(new));
  if v_changed is null or v_changed <@ array['verified_at'] then
    return new;
  end if;
  perform guide.raise_item_live('changed: ' || array_to_string(v_changed, ', '));
  return new;
end;
$$;

-- Hijos de la ficha: detalle (gyms/resolers/shoes), author_reviews, author_review_scores, item_media.
create or replace function guide.item_children_live_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_ids     uuid[];
  v_id      uuid;
  v_changed text[];
begin
  if guide.item_live_exempt(null) then
    return coalesce(new, old);
  end if;

  if tg_op = 'UPDATE' then
    v_changed := guide.changed_columns(to_jsonb(old), to_jsonb(new));
    if v_changed is null or (tg_table_name = 'gyms' and v_changed <@ array['prices_verified_at']) then
      return new;
    end if;
  end if;

  if tg_table_name = 'author_review_scores' then
    select coalesce(array_agg(distinct r.item_id), '{}') into v_ids
    from guide.author_reviews r
    where r.id = any (array[case when tg_op <> 'INSERT' then old.review_id end,
                            case when tg_op <> 'DELETE' then new.review_id end]);
  else
    v_ids := array_remove(array[case when tg_op <> 'INSERT' then old.item_id end,
                                case when tg_op <> 'DELETE' then new.item_id end], null);
  end if;

  foreach v_id in array v_ids loop
    continue when guide.item_live_exempt(v_id);
    -- Ficha inexistente (cascada de su borrado) o no publicada → libre.
    if exists (select 1 from guide.items i where i.id = v_id and i.published) then
      perform guide.raise_item_live(tg_table_name || coalesce(': ' || array_to_string(v_changed, ', '), ''));
    end if;
  end loop;
  return coalesce(new, old);
end;
$$;

drop trigger if exists items_live_guard on guide.items;
create trigger items_live_guard
  before update or delete on guide.items
  for each row execute function guide.items_live_guard();

do $$
declare
  t text;
begin
  foreach t in array array['gyms', 'resolers', 'shoes', 'author_reviews', 'author_review_scores', 'item_media'] loop
    execute format('drop trigger if exists %I on guide.%I', t || '_live_guard', t);
    execute format('create trigger %I before insert or update or delete on guide.%I
                    for each row execute function guide.item_children_live_guard()', t || '_live_guard', t);
  end loop;
end $$;

revoke execute on function guide.item_live_exempt(uuid) from public;
revoke execute on function guide.raise_item_live(text) from public;
revoke execute on function guide.changed_columns(jsonb, jsonb) from public;
revoke execute on function guide.items_live_guard() from public;
revoke execute on function guide.item_children_live_guard() from public;
grant execute on function guide.item_live_exempt(uuid) to authenticated, service_role;
grant execute on function guide.raise_item_live(text) to authenticated, service_role;
grant execute on function guide.changed_columns(jsonb, jsonb) to authenticated, service_role;

-- publish_draft: igual que 20261016085031, más 'apply:<id>' también para fichas.
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
