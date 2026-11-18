-- F6.7 · Observaciones de leona-lia (docs/security/F6.7-items-review.md).
--
-- O1/O2: guide.changed_columns(p_rel, p_old, p_new) excluye solo updated_at y las columnas GENERADAS de la tabla
--        (pg_attribute.attgenerated, attisdropped = false), no una lista por nombre. created_at deja de estar
--        excluida: cambiarla en una ficha publicada da PT423. Sustituye a changed_columns(jsonb, jsonb).
--        articles_set_updated_at (F6.4) usaba la misma lista por nombre: ahora toma las generadas del catálogo;
--        mismo comportamiento (las generadas de articles son has_en, search_es, search_en).
-- O3:    content_drafts_log saltaba el registro con guide.unpublish_op = <id> sin mirar el rol. Era SECURITY
--        DEFINER (current_user siempre postgres), así que se divide:
--          · trigger guide.content_drafts_log() SECURITY INVOKER: solo omite la línea si
--            guide.alt_unpublish_bypassed(id) (GUC + rolbypassrls: solo dentro de unpublish_article /
--            unpublish_item, DEFINER de postgres);
--          · guide.content_drafts_log_write(...) SECURITY DEFINER: escribe la línea; solo se puede llamar desde un
--            trigger (pg_trigger_depth() > 0), no por RPC.
--        Un admin que falsifique el GUC ya no omite la línea 'draft_publish' (antes, impacto documentado F6.4 X1c).

-- ───────────── O1/O2 ─────────────
create or replace function guide.changed_columns(p_rel regclass, p_old jsonb, p_new jsonb)
returns text[]
language sql
stable
set search_path = ''
as $$
  select array_agg(n.key order by n.key)
  from jsonb_each(p_new) n
  where n.key <> 'updated_at'
    and n.value is distinct from (p_old -> n.key)
    and not exists (select 1 from pg_catalog.pg_attribute a
                    where a.attrelid = p_rel and a.attname = n.key and a.attnum > 0
                      and not a.attisdropped and a.attgenerated <> '');
$$;

revoke execute on function guide.changed_columns(regclass, jsonb, jsonb) from public;
grant execute on function guide.changed_columns(regclass, jsonb, jsonb) to authenticated, service_role;

create or replace function guide.items_live_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_changed text[];
begin
  if tg_op = 'DELETE' then
    if old.published and not guide.item_live_exempt(null) then
      perform guide.raise_item_live('delete');
    end if;
    return old;
  end if;

  if not (old.published and new.published) or guide.item_live_exempt(old.id) then
    return new;
  end if;
  v_changed := guide.changed_columns(tg_relid, to_jsonb(old), to_jsonb(new));
  if v_changed is null or v_changed <@ array['verified_at'] then
    return new;
  end if;
  perform guide.raise_item_live('changed: ' || array_to_string(v_changed, ', '));
  return new;
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
    if v_changed is null or (tg_table_name = 'gyms' and v_changed <@ array['prices_verified_at']) then
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

drop function if exists guide.changed_columns(jsonb, jsonb);

create or replace function guide.articles_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_skip text[];
begin
  -- Generadas (del catálogo) + updated_at + sort_order: ordenar no es editar.
  select array['updated_at', 'sort_order'] || coalesce(array_agg(a.attname::text), '{}')
  into v_skip
  from pg_catalog.pg_attribute a
  where a.attrelid = tg_relid and a.attnum > 0 and not a.attisdropped and a.attgenerated <> '';
  -- Ordenar (y reasignar al borrar la categoría) no es editar: no cambia la versión base de los borradores.
  -- La reasignación solo vale para artículos de la categoría que se borra.
  if coalesce(current_setting('guide.draft_op', true), '') = 'reassign_category:' || old.category_id::text then
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

-- ───────────── O3 ─────────────
create or replace function guide.content_drafts_log_write(p_entity text, p_entity_id uuid, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_label   text;
  v_table   text := case p_entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end;
  v_changed text[];
begin
  -- Solo desde el trigger de content_drafts (no por RPC: no se fabrican líneas del registro).
  if pg_catalog.pg_trigger_depth() = 0 then
    raise exception 'trigger only' using errcode = '42501';
  end if;

  select coalesce(
           (select a.title_es from guide.articles a where p_entity = 'article' and a.id = p_entity_id),
           (select p.title_es from guide.pages p where p_entity = 'page' and p.id = p_entity_id),
           (select i.name from guide.items i where p_entity = 'item' and i.id = p_entity_id))
    into v_label;
  if v_label is null then
    return;
  end if;

  select array_agg(k order by k) into v_changed
  from (
    select s.key || coalesce('.' || c.key, '') as k
    from jsonb_each(p_payload) s
    left join lateral jsonb_each(case when jsonb_typeof(s.value) = 'object' and s.key <> 'scores'
                                      then s.value else '{}'::jsonb end) c on true
  ) x;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns)
  values (
    (select auth.uid()),
    case when current_setting('guide.draft_op', true) = 'publish'
         then 'draft_publish'::guide.activity_action else 'draft_discard'::guide.activity_action end,
    v_table,
    p_entity_id::text,
    left(v_label, 200),
    v_changed);
end;
$$;

create or replace function guide.content_drafts_log()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- unpublish_article / unpublish_item aplican el borrador sin publicar y registran su propia 'unpublish'.
  -- Exención atada al GUC del id Y al rol (bypassrls: solo dentro de esas funciones DEFINER).
  if old.entity in ('article', 'item') and guide.alt_unpublish_bypassed(old.entity_id) then
    return null;
  end if;
  perform guide.content_drafts_log_write(old.entity, old.entity_id, old.payload);
  return null;
end;
$$;

revoke execute on function guide.content_drafts_log_write(text, uuid, jsonb) from public;
revoke execute on function guide.content_drafts_log() from public;
-- El trigger corre como el invocador (admin = authenticated; mantenimiento/DEFINER = postgres).
grant execute on function guide.content_drafts_log_write(text, uuid, jsonb) to authenticated, service_role;
