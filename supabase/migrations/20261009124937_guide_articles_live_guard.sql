-- F6.4 · hallazgo 4 (leona-lia): "no se edita en directo un artículo vivo" deja de depender del reloj
-- del navegador. En UPDATE, si la fila está viva según el reloj del servidor (article_is_live(old.*))
-- y sigue viva tras el UPDATE, no se puede cambiar ninguna columna que gestiona el borrador de cambios
-- (draft_allowed_columns('articles')): 'article is live', SQLSTATE PT423 (HTTP 423 por PostgREST).
--
-- Sigue permitido sobre un vivo: despublicar (status → draft), reprogramar a futuro u ocultar
-- (cualquier cambio que deje la fila no viva, con o sin contenido), cambiar solo status/published_at
-- dejándola viva, sort_order (reorder_articles), el cambio a published de publish_due_articles y el
-- toque de updated_at de O3 (touch_draft_parent): no tocan columnas de contenido.
--
-- Excepciones, marcadas en el GUC local de la transacción guide.draft_op (el mismo de publish_draft):
--   'apply:<article id>'  publish_draft mientras aplica el borrador de ESE artículo (todo permitido).
--   'reassign_category'   delete_article_category al reasignar (solo puede cambiar category_id).
-- El GUC no es manipulable por clientes: PostgREST no expone pg_catalog.set_config, no hay
-- db_pre_request y solo fija role/search_path/request.*; las únicas funciones expuestas que llaman a
-- set_config (publish_draft, discard_draft, delete_article_category) usan valores fijos y exigen admin.
-- Aun falsificado solo afectaría a quien ya puede escribir en articles (admin por RLS): es una red de
-- seguridad de integridad, no de autorización. El bloqueo vale para todos los roles (también
-- postgres/service_role), así que ninguna función SECURITY DEFINER lo salta en silencio (D23 O6).
-- Idempotente (create or replace).

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
  if new.status = 'published' and new.published_at is null then
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
    if v_op is distinct from 'apply:' || old.id::text then
      select array_agg(k order by k) into v_changed
      from unnest(guide.draft_allowed_columns('articles')) k
      where (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k);
      if v_changed is not null
         and not (v_op = 'reassign_category' and v_changed = array['category_id']) then
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

-- publish_draft: marca 'apply:<id>' solo mientras aplica un borrador de artículo; luego 'publish'
-- (registro en activity_log, igual que antes) y por último ''.
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

  perform set_config('guide.draft_op', 'publish', true);
  delete from guide.content_drafts d where d.id = v_draft.id;
  perform set_config('guide.draft_op', '', true);

  return guide.draft_entity_version(p_entity, p_entity_id);
end;
$$;

-- delete_article_category: reasignar también mueve artículos vivos (la categoría desaparece);
-- marca 'reassign_category' solo durante ese UPDATE (el trigger solo admite category_id).
create or replace function guide.delete_article_category(p_id uuid, p_reassign_to uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_offset integer;
begin
  perform guide.assert_admin();
  if p_id = p_reassign_to then
    raise exception 'target must differ' using errcode = '22023';
  end if;
  if not exists (select 1 from guide.article_categories where id = p_reassign_to) then
    raise exception 'target category not found' using errcode = '22023';
  end if;
  select coalesce(max(sort_order), 0) + 1 into v_offset from guide.articles where category_id = p_reassign_to;
  perform set_config('guide.draft_op', 'reassign_category', true);
  update guide.articles
  set category_id = p_reassign_to, sort_order = sort_order + v_offset
  where category_id = p_id;
  perform set_config('guide.draft_op', '', true);
  delete from guide.article_categories where id = p_id;
end;
$$;
