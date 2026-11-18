-- F6.5 · Categorías del panel: auditoría de reorder_articles, reorder_article_categories y delete_article_category.
--
-- Hallazgos que corrige esta migración:
--   H1. Reordenar un artículo vivo con borrador de cambios rompía el borrador: sort_order no está en la lista blanca
--       (articles_before_write lo deja pasar, bien), pero set_updated_at subía updated_at, que es la versión base de
--       los borradores (draft_entity_version) → publish_draft daba PT409. Además reordenaba el listado del panel
--       "por última edición". Igual al reasignar artículos al borrar su categoría.
--       → articles_set_updated_at(): un UPDATE que solo cambia sort_order (o category_id + sort_order dentro de la
--         reasignación de delete_article_category, guide.draft_op = 'reassign_category') conserva updated_at
--         (guide.articles no tiene updated_by). Cualquier otro cambio, o fijar updated_at a mano (toque O3 de touch_draft_parent), sigue
--         subiendo la versión como siempre.
--   H2. reorder_* no validaban la lista: con ids de menos dejaban sort_order duplicados; con duplicados o nulos,
--       un orden indefinido. reorder_article_categories aceptaba ids desconocidos en silencio.
--       → Lista completa (todas las categorías / todos los artículos de la categoría, borradores incluidos), sin
--         nulos ni duplicados: si no, 22023. Categoría de reorder_articles inexistente: P0002. Solo se escriben las
--         filas cuyo sort_order cambia (sin actividad ni toques de más). Siguen siendo SECURITY INVOKER (RLS de
--         admin + assert_admin, 42501), search_path '' y EXECUTE solo authenticated/service_role.
--   H3. delete_article_category:
--       * exigía destino aunque la categoría estuviera vacía (el panel borraba por DELETE directo, saltándose todo);
--       * una categoría inexistente era un no-op silencioso;
--       * dejaba borradores de cambios apuntando (payload article.category_id) a la categoría borrada → publish_draft
--         fallaba después con 23503;
--       * borraba en cascada sus redirecciones 301 (D24) y su URL actual quedaba en 404;
--       * permitía borrar la última categoría (P1: las categorías son los pilares del blog; sin ninguna no se puede
--         crear un artículo).
--       → p_reassign_to puede ser NULL si nada la usa (ni artículos ni borradores); si la usan, 22023 'target
--         required'. Inexistente: P0002 'category not found'. Última categoría: 22023 'cannot delete the last
--         category'. Con destino: reasigna artículos (al final del destino, conservando su orden relativo y su
--         updated_at), reescribe los borradores que la elegían, mueve sus redirecciones al destino y añade las de sus
--         slugs actuales (es; en si tenía versión en) → destino. Sin destino: sus redirecciones caen con ella.
--       → Pasa a SECURITY DEFINER (assert_admin dentro, como unpublish_article) porque escribe slug_redirects, que
--         no tiene grants de escritura para clientes. Firma sin cambios.
--       → Se retira el DELETE directo de clientes sobre article_categories (grant + policy): borrar es solo vía RPC.
--         postgres/service_role (mantenimiento, guide_dummy_purge.sql) siguen pudiendo.
--
-- Sin cambios (verificado en la suite): INSERT/UPDATE por PostgREST solo admin; slug_es y slug_en únicos (23505);
-- color '^#[0-9a-fA-F]{6}$' (23514); cambiar un slug de categoría crea la 301 (track_slug_redirects; categorías
-- siempre públicas). Actividad: crear/editar/borrar/reordenar quedan en activity_log por articles_log_activity y
-- article_categories_log_activity (insert/update/delete por fila, como reorder_criteria y reorder_item_media).
-- Idempotente.

-- ───────────── H1. updated_at de artículos ─────────────
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

drop trigger if exists articles_set_updated_at on guide.articles;
create trigger articles_set_updated_at before update on guide.articles
  for each row execute function guide.articles_set_updated_at();

-- ───────────── H2. reorder_* ─────────────
create or replace function guide.reorder_article_categories(p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_ids is null or array_position(p_ids, null) is not null then
    raise exception 'ids required' using errcode = '22023';
  end if;
  if (select count(distinct u) from unnest(p_ids) u) <> cardinality(p_ids) then
    raise exception 'duplicate ids' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_ids) u(id) where not exists (select 1 from guide.article_categories c where c.id = u.id)) then
    raise exception 'unknown category' using errcode = '22023';
  end if;
  if (select count(*) from guide.article_categories) <> cardinality(p_ids) then
    raise exception 'list must include every category' using errcode = '22023';
  end if;

  update guide.article_categories c
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where c.id = x.id and c.sort_order is distinct from x.ord::integer;
end;
$$;

create or replace function guide.reorder_articles(p_category_id uuid, p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if not exists (select 1 from guide.article_categories c where c.id = p_category_id) then
    raise exception 'category not found' using errcode = 'P0002';
  end if;
  if p_ids is null or array_position(p_ids, null) is not null then
    raise exception 'ids required' using errcode = '22023';
  end if;
  if (select count(distinct u) from unnest(p_ids) u) <> cardinality(p_ids) then
    raise exception 'duplicate ids' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_ids) as u(id)
    left join guide.articles a on a.id = u.id and a.category_id = p_category_id
    where a.id is null
  ) then
    raise exception 'articles must belong to the category' using errcode = '22023';
  end if;
  if (select count(*) from guide.articles a where a.category_id = p_category_id) <> cardinality(p_ids) then
    raise exception 'list must include every article of the category' using errcode = '22023';
  end if;

  -- sort_order no está en la lista blanca de lo vivo y no sube updated_at (articles_set_updated_at).
  update guide.articles a
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where a.id = x.id and a.sort_order is distinct from x.ord::integer;
end;
$$;

revoke execute on function guide.reorder_article_categories(uuid[]) from public, anon;
revoke execute on function guide.reorder_articles(uuid, uuid[]) from public, anon;
grant execute on function guide.reorder_article_categories(uuid[]) to authenticated, service_role;
grant execute on function guide.reorder_articles(uuid, uuid[]) to authenticated, service_role;

comment on function guide.reorder_article_categories(uuid[]) is
  'F6.5. Orden de las categorías (1..n). Lista completa sin nulos ni duplicados (22023: ids required, duplicate ids, '
  'unknown category, list must include every category). Solo admin (42501).';
comment on function guide.reorder_articles(uuid, uuid[]) is
  'F6.5. Orden de los artículos de una categoría (1..n), borradores incluidos. No crea borradores ni cambia updated_at. '
  'Categoría inexistente P0002; lista incompleta, ajena, con nulos o duplicados 22023. Solo admin (42501).';

-- ───────────── H3. delete_article_category ─────────────
create or replace function guide.delete_article_category(p_id uuid, p_reassign_to uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cat  guide.article_categories%rowtype;
  v_used boolean;
  v_max  integer;
  v_loc  text;
  v_slug text;
begin
  perform guide.assert_admin();
  if p_id = p_reassign_to then
    raise exception 'target must differ' using errcode = '22023';
  end if;

  select c.* into v_cat from guide.article_categories c where c.id = p_id for update;
  if not found then
    raise exception 'category not found' using errcode = 'P0002';
  end if;
  if (select count(*) from guide.article_categories) <= 1 then
    raise exception 'cannot delete the last category' using errcode = '22023';
  end if;

  v_used := exists (select 1 from guide.articles a where a.category_id = p_id)
         or exists (select 1 from guide.content_drafts d
                    where d.entity = 'article' and d.payload -> 'article' ->> 'category_id' = p_id::text);

  if p_reassign_to is null then
    if v_used then
      raise exception 'target required' using errcode = '22023',
        hint = 'The category has articles or pending drafts: pass p_reassign_to.';
    end if;
  else
    perform 1 from guide.article_categories c where c.id = p_reassign_to for update;
    if not found then
      raise exception 'target category not found' using errcode = '22023';
    end if;

    select coalesce(max(a.sort_order), 0) into v_max from guide.articles a where a.category_id = p_reassign_to;
    perform set_config('guide.draft_op', 'reassign_category', true);
    update guide.articles a
    set category_id = p_reassign_to, sort_order = v_max + x.rn::integer
    from (select a2.id, row_number() over (order by a2.sort_order, a2.created_at, a2.id) as rn
          from guide.articles a2 where a2.category_id = p_id) x
    where a.id = x.id;
    perform set_config('guide.draft_op', '', true);

    update guide.content_drafts d
    set payload = jsonb_set(d.payload, '{article,category_id}', to_jsonb(p_reassign_to))
    where d.entity = 'article' and d.payload -> 'article' ->> 'category_id' = p_id::text;

    update guide.slug_redirects r
    set article_category_id = p_reassign_to, created_at = now()
    where r.kind = 'article_category' and r.article_category_id = p_id;
    foreach v_loc in array array['es', 'en'] loop
      v_slug := case v_loc when 'es' then v_cat.slug_es else v_cat.slug_en end;
      continue when v_slug is null or (v_loc = 'en' and not v_cat.has_en);
      insert into guide.slug_redirects (kind, locale, old_slug, article_category_id)
      values ('article_category', v_loc::guide.locale, v_slug, p_reassign_to)
      on conflict on constraint slug_redirects_key
      do update set article_id = null, page_id = null, article_category_id = excluded.article_category_id, created_at = now();
    end loop;
  end if;

  delete from guide.article_categories c where c.id = p_id;
end;
$$;

revoke execute on function guide.delete_article_category(uuid, uuid) from public, anon, service_role;
grant execute on function guide.delete_article_category(uuid, uuid) to authenticated;

comment on function guide.delete_article_category(uuid, uuid) is
  'F6.5. Borra una categoría. p_reassign_to NULL solo si nada la usa (si no, 22023 target required). Con destino: '
  'reasigna artículos (al final, sin tocar updated_at), reescribe borradores y mueve sus 301 al destino. '
  'Errores 22023: target must differ, target category not found, cannot delete the last category; P0002 category '
  'not found. Solo admin (42501). Único camino de borrado para clientes.';

-- Borrar solo vía RPC (DEFINER): sin DELETE directo para clientes.
drop policy if exists article_categories_delete on guide.article_categories;
revoke delete on guide.article_categories from anon, authenticated;
