-- F6.4 · hallazgo 4, segunda parte: lo vivo tampoco se BORRA ni cambia sus relacionados en directo.
--   * BEFORE DELETE en articles: un artículo vivo (reloj del servidor) no se borra → PT423 'article is live'.
--     El admin despublica (status = 'draft') o reprograma a futuro antes de borrar.
--   * BEFORE INSERT/UPDATE/DELETE en article_items: si el artículo está vivo → PT423, salvo:
--       - guide.draft_op = 'apply:<article_id>' (publish_draft aplicando el borrador de ese artículo);
--       - DELETE en cascada al borrar una ficha (la ficha ya no existe): borrar una ficha es legítimo y
--         el artículo vivo simplemente deja de mencionarla;
--       - DELETE en cascada al borrar el artículo (ya no existe; borrarlo vivo ya está bloqueado).
--   * Mantenimiento explícito: guide.draft_op = 'maintenance' exime los tres bloqueos (también el UPDATE
--     de contenido) SOLO si el rol actual tiene rolbypassrls (postgres en el SQL editor/psql). Lo usan
--     supabase/seed/guide_dummy.sql (inserta article_items de artículos publicados) y
--     supabase/seed/guide_dummy_purge.sql (borra artículos publicados). Un cliente por PostgREST no
--     puede fijar el GUC (no hay set_config expuesto ni db_pre_request) y, aunque pudiera, anon/
--     authenticated no tienen bypassrls. Ninguna función SECURITY DEFINER fija 'maintenance' (D23 O6).
-- La comprobación de mantenimiento va en línea en cada trigger (un helper necesitaría EXECUTE para
-- authenticated y quedaría expuesto como RPC). Idempotente.

-- UPDATE: igual que en 20261009124937, con la exención de mantenimiento.
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
    if v_op is distinct from 'apply:' || old.id::text and not (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
         and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)) then
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

create or replace function guide.articles_before_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if guide.article_is_live(old.status, old.published_at) and not (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
         and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)) then
    raise exception 'article is live'
      using errcode = 'PT423',
            detail = 'delete',
            hint = 'Unpublish (status = draft) or reschedule the article before deleting it.';
  end if;
  return old;
end;
$$;
revoke execute on function guide.articles_before_delete() from public, anon, authenticated;

drop trigger if exists articles_before_delete on guide.articles;
create trigger articles_before_delete
  before delete on guide.articles
  for each row execute function guide.articles_before_delete();

create or replace function guide.article_items_live_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
         and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)) then
    return coalesce(new, old);
  end if;
  foreach v_id in array (
    case tg_op
      when 'INSERT' then array[new.article_id]
      when 'DELETE' then array[old.article_id]
      else array[old.article_id, new.article_id]
    end) loop
    continue when coalesce(current_setting('guide.draft_op', true), '') = 'apply:' || v_id::text;
    -- Cascada al borrar una ficha: la ficha ya no existe.
    continue when tg_op = 'DELETE' and not exists (select 1 from guide.items i where i.id = old.item_id);
    -- Artículo inexistente (cascada de su borrado) → no está vivo.
    if exists (select 1 from guide.articles a where a.id = v_id and guide.article_is_live(a.status, a.published_at)) then
      raise exception 'article is live'
        using errcode = 'PT423',
              detail = 'article_items',
              hint = 'Change the related items of a live article through save_draft/publish_draft (item_ids).';
    end if;
  end loop;
  return coalesce(new, old);
end;
$$;
revoke execute on function guide.article_items_live_guard() from public, anon, authenticated;

drop trigger if exists article_items_live_guard on guide.article_items;
create trigger article_items_live_guard
  before insert or update or delete on guide.article_items
  for each row execute function guide.article_items_live_guard();
