-- F6.15b (D50): reglas de publicación de fichas en el servidor (antes solo en app/utils/*-checklist.ts).
-- El trigger solo actúa al pasar a publicada: las fichas que ya están vivas (12 sin portada) no se tocan.

-- Horario: { "mon": [["10:00","23:00"], ...], ... }; día cerrado = [] o sin clave. Mismas reglas que validateGym.
create or replace function guide.opening_hours_valid(p_hours jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  c_time constant text := '^([01]?[0-9]|2[0-3]):[0-5][0-9]$';
  v_day  text;
  v_val  jsonb;
  v_slot jsonb;
  v_open text;
  v_close text;
begin
  if p_hours is null or jsonb_typeof(p_hours) <> 'object' then
    return false;
  end if;
  for v_day, v_val in select e.key, e.value from jsonb_each(p_hours) e loop
    if v_day not in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun') or jsonb_typeof(v_val) <> 'array'
       or jsonb_array_length(v_val) > 6 then
      return false;
    end if;
    for v_slot in select s from jsonb_array_elements(v_val) s loop
      if jsonb_typeof(v_slot) <> 'array' or jsonb_array_length(v_slot) <> 2
         or jsonb_typeof(v_slot -> 0) <> 'string' or jsonb_typeof(v_slot -> 1) <> 'string' then
        return false;
      end if;
      v_open := v_slot ->> 0;
      v_close := v_slot ->> 1;
      if v_open !~ c_time or v_close !~ c_time then
        return false;
      end if;
      if split_part(v_close, ':', 1)::integer * 60 + split_part(v_close, ':', 2)::integer
         <= split_part(v_open, ':', 1)::integer * 60 + split_part(v_open, ':', 2)::integer then
        return false;
      end if;
    end loop;
  end loop;
  return true;
end;
$$;
revoke all on function guide.opening_hours_valid(jsonb) from public, anon;
grant execute on function guide.opening_hours_valid(jsonb) to authenticated, service_role;

do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'guide.gyms'::regclass and conname = 'gyms_opening_hours_valid') then
    alter table guide.gyms add constraint gyms_opening_hours_valid check (guide.opening_hours_valid(opening_hours)) not valid;
  end if;
end $$;
alter table guide.gyms validate constraint gyms_opening_hours_valid;

-- Bloqueos de publicación de una ficha, en el orden de la checklist del panel. Códigos estables:
-- name, slug (sin-nombre), city, brand_model, hours, disclosure, cover, alt. NULL si la ficha no existe (o no se ve).
create or replace function guide.item_publish_blockers(p_item_id uuid)
returns text[]
language plpgsql
stable
set search_path = ''
as $$
declare
  v_item   guide.items%rowtype;
  v_out    text[] := '{}';
  v_city   text;
  v_hours  jsonb;
  v_brand  text;
  v_model  text;
  v_owned  boolean;
  v_invited boolean;
  v_note   text;
begin
  select i.* into v_item from guide.items i where i.id = p_item_id;
  if not found then
    return null;
  end if;

  case v_item.category
    when 'gym' then select g.city, g.opening_hours into v_city, v_hours from guide.gyms g where g.item_id = p_item_id;
    when 'resoler' then select r.city into v_city from guide.resolers r where r.item_id = p_item_id;
    when 'shoe' then select s.brand, s.model, s.owned_by_author into v_brand, v_model, v_owned from guide.shoes s where s.item_id = p_item_id;
    else null;
  end case;
  select ar.visit_type = 'invited', ar.disclosure_note_es into v_invited, v_note
  from guide.author_reviews ar where ar.item_id = p_item_id;

  if btrim(coalesce(v_item.name, '')) = '' then
    v_out := v_out || 'name';
  end if;
  if v_item.slug::text ~ '^sin-nombre(-[0-9]+)?$' then
    v_out := v_out || 'slug';
  end if;
  if v_item.category in ('gym', 'resoler') and btrim(coalesce(v_city, '')) = '' then
    v_out := v_out || 'city';
  end if;
  if v_item.category = 'shoe' and (v_brand is null or v_model is null) then
    v_out := v_out || 'brand_model';
  end if;
  if v_item.category = 'gym' and not guide.opening_hours_valid(coalesce(v_hours, '{}'::jsonb)) then
    v_out := v_out || 'hours';
  end if;
  -- En pies de gato la reseña solo cuenta si los tiene (shoeChecklist filtra la nota de transparencia si no).
  if coalesce(v_invited, false) and guide.alt_is_missing(v_note)
     and (v_item.category <> 'shoe' or coalesce(v_owned, false)) then
    v_out := v_out || 'disclosure';
  end if;
  if v_item.cover_media_id is null then
    v_out := v_out || 'cover';
  end if;
  if cardinality(guide.entity_alt_missing('item', p_item_id)) > 0 then
    v_out := v_out || 'alt';
  end if;
  return v_out;
end;
$$;
revoke all on function guide.item_publish_blockers(uuid) from public, anon;
grant execute on function guide.item_publish_blockers(uuid) to authenticated, service_role;

-- Columna «Para publicar» del listado (README §13.7): bloqueos de todas las fichas de una categoría.
create or replace function guide.admin_item_publish_blockers(p_category text)
returns table (item_id uuid, published boolean, blockers text[])
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if not exists (select 1 from guide.item_categories c where c.key = p_category) then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  return query
    select i.id, i.published, guide.item_publish_blockers(i.id)
    from guide.items i
    where i.category = p_category
    order by i.id;
end;
$$;
revoke all on function guide.admin_item_publish_blockers(text) from public, anon;
grant execute on function guide.admin_item_publish_blockers(text) to authenticated;

-- Trigger de paso a publicada. 'alt' y 'brand_model' ya los exigen items_require_alt (PT422) y
-- items_shoe_require_brand_model (23514); aquí se suman los demás. Nombre con «z_»: se dispara después que esos dos
-- (los AFTER se ejecutan por orden alfabético), así sus errores, más concretos, salen primero.
-- Mantenimiento explícito (postgres + guide.draft_op=maintenance) queda exento, como D27.
create or replace function guide.items_publish_ready()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_blockers text[];
begin
  if not new.published or (tg_op = 'UPDATE' and old.published) or guide.alt_guard_bypassed() then
    return null;
  end if;
  -- Diferible: la ficha pudo despublicarse o borrarse después en la misma transacción.
  if not exists (select 1 from guide.items i where i.id = new.id and i.published) then
    return null;
  end if;
  v_blockers := guide.text_array_except(guide.item_publish_blockers(new.id), array['alt', 'brand_model']);
  if cardinality(v_blockers) > 0 then
    raise exception 'check violation: items_publish_ready'
      using errcode = '23514', constraint = 'items_publish_ready',
            detail = array_to_string(v_blockers, ','),
            hint = 'Codes: name, slug, city, hours, disclosure, cover (guide.item_publish_blockers).';
  end if;
  return null;
end;
$$;

drop trigger if exists items_z_publish_ready on guide.items;
create constraint trigger items_z_publish_ready
  after insert or update of published on guide.items
  deferrable initially immediate
  for each row execute function guide.items_publish_ready();

-- Publicación en lote (README §13.7): solo fichas no publicadas, nunca ocultas (published_at ya puesto) ni cambios
-- de fichas vivas (esos van por publish_draft, una a una). Cada ficha en su subtransacción; las que fallan no paran.
create or replace function guide.publish_items(p_ids uuid[])
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_id       uuid;
  v_pub      boolean;
  v_pub_at   timestamptz;
  v_blockers text[];
  v_out      jsonb := '[]'::jsonb;
  v_n        integer := 0;
  v_con      text;
  v_det      text;
begin
  perform guide.assert_admin();
  if p_ids is null or cardinality(p_ids) = 0 or cardinality(p_ids) > 100 or array_position(p_ids, null) is not null
     or (select count(distinct x) from unnest(p_ids) x) <> cardinality(p_ids) then
    raise exception 'invalid ids' using errcode = '22023', hint = '1 to 100 distinct ids';
  end if;
  perform set_config('guide.draft_op', '', true);
  perform set_config('guide.unpublish_op', '', true);

  foreach v_id in array p_ids loop
    begin
      select i.published, i.published_at into v_pub, v_pub_at from guide.items i where i.id = v_id for update;
      if not found then
        v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'not_found');
      elsif v_pub then
        v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'already_published');
      elsif v_pub_at is not null then
        v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'hidden');
      else
        v_blockers := guide.item_publish_blockers(v_id);
        if cardinality(v_blockers) > 0 then
          v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'blocked', 'blockers', to_jsonb(v_blockers));
        else
          update guide.items i set published = true where i.id = v_id returning i.published_at into v_pub_at;
          v_out := v_out || jsonb_build_object('id', v_id, 'ok', true, 'published_at', v_pub_at);
          v_n := v_n + 1;
        end if;
      end if;
    exception
      when sqlstate 'PT422' then
        v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'blocked', 'blockers', '["alt"]'::jsonb);
      when check_violation then
        get stacked diagnostics v_con = constraint_name, v_det = pg_exception_detail;
        v_out := v_out || jsonb_build_object('id', v_id, 'ok', false, 'code', 'blocked', 'blockers',
          case v_con
            when 'shoes_brand_model_required' then '["brand_model"]'::jsonb
            when 'items_publish_ready' then to_jsonb(string_to_array(v_det, ','))
            else jsonb_build_array('check:' || v_con)
          end);
    end;
  end loop;
  return jsonb_build_object('published', v_n, 'results', v_out);
end;
$$;
revoke all on function guide.publish_items(uuid[]) from public, anon;
grant execute on function guide.publish_items(uuid[]) to authenticated;
