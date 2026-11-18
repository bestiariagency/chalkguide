-- F6.10 · O1 (leona-lia, docs/security/F6.10-criteria-review.md): draft_check_payload aceptaba una nota de criterio
-- inactivo con cualquier valor si la ficha ya tenía nota, y publish_draft la descartaba en silencio
-- (author_review_scores_keep_inactive conserva la guardada: 3 → 1 quedaba 3 sin aviso).
--   → Un criterio inactivo solo admite en el borrador el mismo valor que la nota guardada de la ficha (el editor la
--     reenvía tal cual). Valor distinto o nota nueva → 22023 'invalid section: scores', detail 'inactive criterion'.
--     Lo demás de la función, sin cambios. O2 (policy SELECT de author_review_scores) queda pendiente de Xavi.
-- Idempotente.

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
      execute format('select jsonb_populate_record(null::guide.%I, $1)', v_table) using v_value;
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
      if exists (select 1 from jsonb_object_keys(v_value) k
                 where not exists (select 1 from guide.criteria c where c.id = k::uuid and c.category = v_category)) then
        raise exception 'invalid section: scores' using errcode = '22023', detail = 'criterion not in category';
      end if;
      if exists (select 1 from jsonb_object_keys(v_value) k
                 join guide.criteria c on c.id = k::uuid
                 where not c.is_active
                   and not exists (select 1 from guide.author_reviews r
                                   join guide.author_review_scores s on s.review_id = r.id
                                   where r.item_id = p_entity_id and s.criterion_id = c.id
                                     and s.score = (v_value ->> k)::smallint)) then
        raise exception 'invalid section: scores' using errcode = '22023', detail = 'inactive criterion';
      end if;

    else
      raise exception 'section not allowed: %', left(v_section, 40) using errcode = '22023';
    end if;
  end loop;
end;
$$;
