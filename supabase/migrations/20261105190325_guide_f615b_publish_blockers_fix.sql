-- F6.15b: corrige guide.item_publish_blockers. `text[] || 'literal'` toma el literal como array y fallaba con
-- 22P02 en cuanto había un bloqueo (y con ella el trigger items_z_publish_ready al publicar). Ahora array_append.

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
    v_out := array_append(v_out, 'name');
  end if;
  if v_item.slug::text ~ '^sin-nombre(-[0-9]+)?$' then
    v_out := array_append(v_out, 'slug');
  end if;
  if v_item.category in ('gym', 'resoler') and btrim(coalesce(v_city, '')) = '' then
    v_out := array_append(v_out, 'city');
  end if;
  if v_item.category = 'shoe' and (v_brand is null or v_model is null) then
    v_out := array_append(v_out, 'brand_model');
  end if;
  if v_item.category = 'gym' and not guide.opening_hours_valid(coalesce(v_hours, '{}'::jsonb)) then
    v_out := array_append(v_out, 'hours');
  end if;
  -- En pies de gato la reseña solo cuenta si los tiene (shoeChecklist filtra la nota de transparencia si no).
  if coalesce(v_invited, false) and guide.alt_is_missing(v_note)
     and (v_item.category <> 'shoe' or coalesce(v_owned, false)) then
    v_out := array_append(v_out, 'disclosure');
  end if;
  if v_item.cover_media_id is null then
    v_out := array_append(v_out, 'cover');
  end if;
  if cardinality(guide.entity_alt_missing('item', p_item_id)) > 0 then
    v_out := array_append(v_out, 'alt');
  end if;
  return v_out;
end;
$$;
revoke all on function guide.item_publish_blockers(uuid) from public, anon;
grant execute on function guide.item_publish_blockers(uuid) to authenticated, service_role;
