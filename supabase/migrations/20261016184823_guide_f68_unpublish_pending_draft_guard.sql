-- F6.8 · Fuera de alcance de F6.7 (leona-lia, docs/security/F6.8-resolers-review.md): despublicar en directo con un
-- borrador de cambios pendiente lo dejaba huérfano (después save_draft responde 'entity not published').
--
-- Ahora, con borrador pendiente:
--   · fichas:    UPDATE items published true → false            → PT423 'pending draft', detail 'use unpublish_item'
--   · artículos: UPDATE articles status scheduled/published → draft → PT423 'pending draft', detail 'use unpublish_article'
--   hint: 'Unpublish through unpublish_item / unpublish_article (applies the pending draft), or discard the draft first.'
-- Sin borrador se sigue pudiendo despublicar en directo. Exentos: unpublish_item / unpublish_article (GUC
-- guide.unpublish_op = id + rolbypassrls, guide.alt_unpublish_bypassed) y mantenimiento como postgres.
-- unpublish_item fija ahora el GUC antes de ocultar (oculta antes de aplicar el borrador). Páginas: sin RPC de
-- despublicar; no se cambian (ver informe).

create or replace function guide.items_unpublish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.published and not new.published
     and not guide.alt_guard_bypassed() and not guide.alt_unpublish_bypassed(old.id)
     and exists (select 1 from guide.content_drafts d where d.entity = 'item' and d.entity_id = old.id) then
    raise exception 'pending draft'
      using errcode = 'PT423',
            detail = 'use unpublish_item',
            hint = 'Unpublish through unpublish_item (applies the pending draft), or discard the draft first.';
  end if;
  return new;
end;
$$;

create or replace function guide.articles_unpublish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status in ('scheduled', 'published') and new.status = 'draft'
     and not guide.alt_guard_bypassed() and not guide.alt_unpublish_bypassed(old.id)
     and exists (select 1 from guide.content_drafts d where d.entity = 'article' and d.entity_id = old.id) then
    raise exception 'pending draft'
      using errcode = 'PT423',
            detail = 'use unpublish_article',
            hint = 'Unpublish through unpublish_article (applies the pending draft), or discard the draft first.';
  end if;
  return new;
end;
$$;

drop trigger if exists items_unpublish_guard on guide.items;
create trigger items_unpublish_guard
  before update of published on guide.items
  for each row execute function guide.items_unpublish_guard();

drop trigger if exists articles_unpublish_guard on guide.articles;
create trigger articles_unpublish_guard
  before update of status on guide.articles
  for each row execute function guide.articles_unpublish_guard();

revoke execute on function guide.items_unpublish_guard() from public;
revoke execute on function guide.articles_unpublish_guard() from public;

-- unpublish_item: el GUC de la exención se fija antes de ocultar.
create or replace function guide.unpublish_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_published boolean;
  v_has_draft boolean;
  v_label     text;
begin
  perform guide.assert_admin();

  select i.published into v_published from guide.items i where i.id = p_item_id for update;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  if not v_published then
    raise exception 'item not live' using errcode = '22023',
      hint = 'Only a published item can be unpublished.';
  end if;

  v_has_draft := exists (select 1 from guide.content_drafts d where d.entity = 'item' and d.entity_id = p_item_id);

  perform set_config('guide.unpublish_op', p_item_id::text, true);
  -- Primero se oculta: el borrador se aplica ya sobre una ficha no publicada (D27 no entra; sin exenciones).
  update guide.items i set published = false where i.id = p_item_id
  returning i.name into v_label;

  if v_has_draft then
    perform guide.publish_draft('item', p_item_id, true);
  end if;
  perform set_config('guide.unpublish_op', '', true);
  perform set_config('guide.draft_op', '', true);

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'unpublish'::guide.activity_action, 'items', p_item_id::text, left(v_label, 200),
          array['published'], jsonb_build_object('draft_applied', v_has_draft));
end;
$$;
