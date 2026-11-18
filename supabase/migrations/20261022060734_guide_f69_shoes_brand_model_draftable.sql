-- F6.9 (petición del panel): brand/model opcionales mientras la ficha no está publicada. Sustituye los marcadores
-- 'Sin marca'/'Sin modelo <hex>'. El unique (lower(brand), lower(model)) ya ignora nulls (NULLS DISTINCT).
-- Publicada ⇒ ambos obligatorios: lo garantizan dos triggers (cruzan tablas, así que no pueden ser CHECK puros).
alter table guide.shoes alter column brand drop not null;
alter table guide.shoes alter column model drop not null;

create or replace function guide.shoes_require_brand_model()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing boolean;
begin
  if tg_table_name = 'items' then
    if new.category <> 'shoe' or not new.published or (tg_op = 'UPDATE' and old.published) then
      return null;
    end if;
    select (s.brand is null or s.model is null) into v_missing from guide.shoes s where s.item_id = new.id;
  else
    if new.brand is not null and new.model is not null then
      return null;
    end if;
    v_missing := exists (select 1 from guide.items i where i.id = new.item_id and i.published);
  end if;
  if coalesce(v_missing, false) then
    raise exception 'check violation: shoes_brand_model_required'
      using errcode = '23514', constraint = 'shoes_brand_model_required',
            detail = 'a published shoe needs brand and model';
  end if;
  return null;
end;
$$;
revoke execute on function guide.shoes_require_brand_model() from public, anon, authenticated;

drop trigger if exists shoes_require_brand_model on guide.shoes;
create trigger shoes_require_brand_model after insert or update of brand, model on guide.shoes
  for each row execute function guide.shoes_require_brand_model();
drop trigger if exists items_shoe_require_brand_model on guide.items;
create trigger items_shoe_require_brand_model after insert or update of published on guide.items
  for each row execute function guide.shoes_require_brand_model();

-- Aviso de duplicado antes de guardar (solo admin; mismo criterio que shoes_brand_model_key).
create or replace function guide.shoe_model_taken(p_brand text, p_model text, p_except_id uuid default null)
returns boolean
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_brand is null or p_model is null or btrim(p_brand) = '' or btrim(p_model) = '' then
    return false;
  end if;
  return exists (select 1 from guide.shoes s
                 where lower(s.brand) = lower(btrim(p_brand)) and lower(s.model) = lower(btrim(p_model))
                   and (p_except_id is null or s.item_id <> p_except_id));
end;
$$;
revoke execute on function guide.shoe_model_taken(text, text, uuid) from public, anon;
grant execute on function guide.shoe_model_taken(text, text, uuid) to authenticated;
