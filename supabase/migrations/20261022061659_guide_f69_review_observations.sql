-- F6.9, observaciones de leona-lia (docs/security/F6.9-shoes-review.md).

-- O1: publicar una ficha 'shoe' sin fila en shoes también es "incompleta". Al FK items → shoes obliga a crear la ficha
-- antes que su detalle (seed, fixtures): el trigger de items pasa a constraint trigger DEFERRABLE INITIALLY IMMEDIATE.
-- Los clientes reciben el error al momento; el mantenimiento que inserta ficha publicada + detalle hace
-- `set constraints guide.items_shoe_require_brand_model deferred` en su transacción. Diferido, relee el estado actual.
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
    -- Diferido: la ficha pudo borrarse u ocultarse después en la misma transacción.
    if not exists (select 1 from guide.items i where i.id = new.id and i.published) then
      return null;
    end if;
    select (s.brand is null or s.model is null) into v_missing from guide.shoes s where s.item_id = new.id;
    v_missing := coalesce(v_missing, true); -- sin fila de detalle = incompleta
  else
    if new.brand is not null and new.model is not null then
      return null;
    end if;
    v_missing := exists (select 1 from guide.items i where i.id = new.item_id and i.published);
  end if;
  if v_missing then
    raise exception 'check violation: shoes_brand_model_required'
      using errcode = '23514', constraint = 'shoes_brand_model_required',
            detail = 'a published shoe needs brand and model';
  end if;
  return null;
end;
$$;
revoke execute on function guide.shoes_require_brand_model() from public, anon, authenticated;

drop trigger if exists items_shoe_require_brand_model on guide.items;
create constraint trigger items_shoe_require_brand_model after insert or update of published on guide.items
  deferrable initially immediate
  for each row execute function guide.shoes_require_brand_model();

-- O2: marca/modelo sin espacios ni invisibles Unicode en los extremos (NBSP, ZWSP/ZWJ/ZWNJ, marcas bidi, BOM…).
alter table guide.shoes drop constraint if exists shoes_brand_trimmed;
alter table guide.shoes add constraint shoes_brand_trimmed check (
  brand !~ '^[[:space:]\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u3000\uFEFF]|[[:space:]\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u3000\uFEFF]$'
);
alter table guide.shoes drop constraint if exists shoes_model_trimmed;
alter table guide.shoes add constraint shoes_model_trimmed check (
  model !~ '^[[:space:]\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u3000\uFEFF]|[[:space:]\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u3000\uFEFF]$'
);
