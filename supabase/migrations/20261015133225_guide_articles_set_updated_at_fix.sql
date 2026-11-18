-- F6.5 · Corrección de 20261015132806: guide.articles no tiene updated_by (retirada en guide_drop_audit_columns),
-- así que articles_set_updated_at solo gestiona updated_at. (La copia de 20261015132806 ya incluye esta versión;
-- esta migración es la que se aplicó en remoto para corregirla.) Idempotente.
create or replace function guide.articles_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_skip text[] := array['updated_at', 'has_en', 'search_es', 'search_en', 'sort_order'];
begin
  -- Ordenar (y reasignar al borrar la categoría) no es editar: no cambia la versión base de los borradores.
  if coalesce(current_setting('guide.draft_op', true), '') = 'reassign_category' then
    v_skip := v_skip || 'category_id'::text;
  end if;
  if new.updated_at is not distinct from old.updated_at
     and (new.sort_order is distinct from old.sort_order or new.category_id is distinct from old.category_id)
     and (to_jsonb(new) - v_skip) = (to_jsonb(old) - v_skip) then
    return new;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

revoke execute on function guide.articles_set_updated_at() from public, anon, authenticated;
