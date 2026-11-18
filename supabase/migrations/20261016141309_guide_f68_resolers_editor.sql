-- F6.8 · Resoladores (backend del editor; mismo modelo genérico que rocódromos).
--
-- Auditoría: los servicios (D18) son la columna resolers.services text[] con CHECK resolers_services_allowed; ya están
-- en la lista blanca del detalle ('detail.services'), en draft_entity_version, en la guarda PT423 (resolers_live_guard)
-- y en create_item/unpublish_item/publish_draft. Criterios 'resoler' (quality, turnaround, service, value) y reseña
-- del autor: genéricos. Sin índices propios. Lo que se añade:
--   1. draft_check_payload valida también los CHECK de la tabla sobre la fila resultante (fila guardada + parche):
--      save_draft / INSERT directo en content_drafts / publish_draft responden 23514 'check violation: <constraint>'
--      (p. ej. resolers_services_allowed, resolers_turnaround_range, gyms_grading_difficulty_check) al guardar.
--   2. Sello de verificación de precios sin borrador también en resolers.prices_verified_at y shoes.price_checked_at
--      (antes solo gyms.prices_verified_at). Solo si es la única columna que cambia.

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
  v_con      record;
  v_key      text;
  v_ok       boolean;
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
      -- F6.8: los CHECK de la tabla sobre la fila resultante (guardada + parche): save_draft avisa ya con 23514
      -- 'check violation: <constraint>' en vez de fallar al publicar. Sin fila (reseña nueva) se valida al publicar.
      v_key := case when v_table in ('articles', 'pages', 'items') then 'id' else 'item_id' end;
      for v_con in select c.conname, pg_catalog.pg_get_constraintdef(c.oid) as def
                   from pg_catalog.pg_constraint c
                   where c.conrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(v_table))
                     and c.contype = 'c' and c.convalidated
                   order by c.conname loop
        execute format(
          'select coalesce(bool_and(coalesce((%s), true)), true) from (select (jsonb_populate_record(t, $1)).* from guide.%I t where t.%I = $2) s',
          regexp_replace(v_con.def, '^CHECK \((.*)\)$', '\1'), v_table, v_key)
          into v_ok using v_value, p_entity_id;
        if not v_ok then
          raise exception 'check violation: %', v_con.conname using errcode = '23514', constraint = v_con.conname;
        end if;
      end loop;

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
      -- F6.7: solo criterios de la categoría de la ficha.
      if exists (select 1 from jsonb_object_keys(v_value) k
                 where not exists (select 1 from guide.criteria c where c.id = k::uuid and c.category = v_category)) then
        raise exception 'invalid section: scores' using errcode = '22023';
      end if;

    else
      raise exception 'section not allowed: %', left(v_section, 40) using errcode = '22023';
    end if;
  end loop;
end;
$$;

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
    v_changed := guide.changed_columns(tg_relid, to_jsonb(old), to_jsonb(new));
    -- Sellos de verificación de precios del detalle (gyms/resolers: prices_verified_at; shoes: price_checked_at):
    -- solos, sin borrador. Con cualquier otra columna en el mismo UPDATE ya es PT423.
    if v_changed is null
       or (tg_table_name in ('gyms', 'resolers', 'shoes') and v_changed <@ array['prices_verified_at', 'price_checked_at']) then
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
