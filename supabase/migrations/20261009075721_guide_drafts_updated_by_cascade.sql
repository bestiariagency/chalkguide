-- D23 O5 (re-revisión leona-lia) · content_drafts_before_write: el ON DELETE SET NULL de updated_by
-- (borrar un usuario de auth) no revalida el payload ni toca updated_at. Así un borrador antiguo que
-- ya no valide tras un cambio de esquema nunca bloquea el borrado de un usuario.
-- El atajo solo vale sin RLS (la acción referencial corre como propietario de la tabla) y solo si lo único
-- que cambia es updated_by → null: un admin por PostgREST no puede usarlo para falsear la auditoría.
create or replace function guide.content_drafts_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_missing uuid;
  v_rls     boolean;
  v_id      uuid;
  v_live    boolean;
begin
  -- O1: anon/authenticated (sujetos a RLS) → admin antes de gastar nada en validar.
  select not r.rolbypassrls into v_rls from pg_catalog.pg_roles r where r.rolname = current_user;
  v_rls := coalesce(v_rls, true);

  -- O5: cascada ON DELETE SET NULL de updated_by. entity_id (generada) aún no está calculada en BEFORE.
  if tg_op = 'UPDATE' and not v_rls and new.updated_by is null and old.updated_by is not null
     and (to_jsonb(new) - 'updated_by' - 'entity_id') = (to_jsonb(old) - 'updated_by' - 'entity_id') then
    return new;
  end if;

  if v_rls then
    perform guide.assert_admin();
  end if;

  if tg_op = 'UPDATE' and (new.entity, new.article_id, new.page_id, new.item_id)
                          is distinct from (old.entity, old.article_id, old.page_id, old.item_id) then
    raise exception 'draft target is immutable' using errcode = '22023';
  end if;

  v_id := coalesce(new.article_id, new.page_id, new.item_id);

  -- O2: misma regla que save_draft también por escritura directa.
  if v_rls then
    if tg_op = 'INSERT' then
      v_live := guide.draft_entity_is_live(new.entity, v_id);
      if v_live is null then
        raise exception 'entity not found' using errcode = 'P0002';
      elsif not v_live then
        raise exception 'entity not published' using errcode = '22023';
      end if;
      new.base_updated_at := guide.draft_entity_version(new.entity, v_id);
    else
      new.base_updated_at := old.base_updated_at;
    end if;
  end if;

  perform guide.draft_check_payload(new.entity, v_id, new.payload);

  select m into v_missing
  from unnest(guide.draft_media_ids(new.payload)) as m
  where not exists (select 1 from guide.media x where x.id = m)
  limit 1;
  if v_missing is not null then
    raise exception 'media not found' using errcode = '23503';
  end if;

  new.updated_by := (select auth.uid());
  new.updated_at := now();
  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function guide.content_drafts_before_write() from public, anon, authenticated;
