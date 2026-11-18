-- D23 · Observaciones de la revisión de leona-lia (docs/security/D23-drafts-review.md).
--
-- O1  content_drafts_before_write exige admin antes de validar nada (roles sujetos a RLS).
-- O2  En escritura directa (roles sujetos a RLS): INSERT solo sobre contenido vivo y con
--     base_updated_at forzada a draft_entity_version; en UPDATE la base es inmutable.
--     postgres/service_role (bypass RLS: mantenimiento, fixtures) quedan fuera, como con la RLS.
-- O3  Cambios en item_media, author_review_scores, article_items y el borrado de author_reviews
--     tocan el updated_at del padre (ficha, reseña o artículo) para que cuenten como versión.
--     Triggers AFTER por sentencia con tablas de transición: un solo UPDATE del padre por
--     sentencia (publish_draft reemplaza galerías/notas sin N toques). Sin recursión: los padres
--     no tienen triggers que escriban en estas tablas. Sin ruido: log_activity ya ignora los
--     UPDATE que solo cambian updated_at. Los padres no tienen updated_by.
-- Idempotente: create or replace + drop trigger if exists.

-- ───────────── Helper: ¿la entidad está viva? (compartido por save_draft y el trigger) ─────────────

create or replace function guide.draft_entity_is_live(p_entity text, p_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case p_entity
    when 'article' then (select guide.article_is_live(a.status, a.published_at) from guide.articles a where a.id = p_id)
    when 'page' then (select p.published from guide.pages p where p.id = p_id)
    when 'item' then (select i.published from guide.items i where i.id = p_id)
  end;
$$;

comment on function guide.draft_entity_is_live(text, uuid) is
  'D23. true si la entidad está publicada (artículo vivo, página o ficha published); null si no existe.';

revoke execute on function guide.draft_entity_is_live(text, uuid) from public, anon;
grant execute on function guide.draft_entity_is_live(text, uuid) to authenticated;

comment on function guide.draft_entity_version(text, uuid) is
  'D23. Versión publicada para detectar conflictos. En fichas, el mayor updated_at de ficha, detalle y reseña; galería, notas y article_items cuentan porque tocan el updated_at del padre (O3).';

-- ───────────── O1 + O2: trigger de content_drafts ─────────────

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

-- save_draft usa el helper compartido (misma lógica que antes).
create or replace function guide.save_draft(
  p_entity text,
  p_entity_id uuid,
  p_payload jsonb,
  p_base_updated_at timestamptz default null
)
returns table (id uuid, base_updated_at timestamptz, updated_at timestamptz)
language plpgsql
set search_path = ''
as $$
declare
  v_version timestamptz;
  v_draft   guide.content_drafts%rowtype;
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;

  v_version := guide.draft_entity_version(p_entity, p_entity_id);
  if v_version is null then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;

  select d.* into v_draft from guide.content_drafts d where d.entity_id = p_entity_id and d.entity = p_entity for update;

  if not found then
    -- Lo que no está publicado se edita directamente; el borrador de cambios es solo para lo vivo.
    if guide.draft_entity_is_live(p_entity, p_entity_id) is not true then
      raise exception 'entity not published' using errcode = '22023';
    end if;
    if p_base_updated_at is null or p_base_updated_at <> v_version then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    insert into guide.content_drafts (entity, article_id, page_id, item_id, payload, base_updated_at)
    values (p_entity,
            case when p_entity = 'article' then p_entity_id end,
            case when p_entity = 'page' then p_entity_id end,
            case when p_entity = 'item' then p_entity_id end,
            p_payload, v_version)
    returning * into v_draft;
  else
    if p_base_updated_at is not null and p_base_updated_at <> v_draft.base_updated_at then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    update guide.content_drafts d set payload = p_payload where d.id = v_draft.id
    returning * into v_draft;
  end if;

  return query select v_draft.id, v_draft.base_updated_at, v_draft.updated_at;
end;
$$;

revoke execute on function guide.save_draft(text, uuid, jsonb, timestamptz) from public, anon;
grant execute on function guide.save_draft(text, uuid, jsonb, timestamptz) to authenticated;

-- ───────────── O3: toque del padre ─────────────
-- tg_argv[0] = columna FK hacia el padre; tg_argv[1] = tabla padre (CASE cerrado, sin SQL dinámico).
-- SECURITY INVOKER: solo el admin escribe en estas tablas y el toque pasa por la RLS del padre.
-- En cascadas (se borra el padre) el UPDATE no encuentra la fila y no hace nada.
create or replace function guide.touch_draft_parent()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_fk  text := tg_argv[0];
  v_ids uuid[] := '{}';
begin
  -- Las tablas de transición que no define el trigger no se referencian en su rama (plpgsql planifica perezosamente).
  if tg_op in ('INSERT', 'UPDATE') then
    v_ids := v_ids || array(select (to_jsonb(n) ->> v_fk)::uuid from new_rows n);
  end if;
  if tg_op in ('UPDATE', 'DELETE') then
    v_ids := v_ids || array(select (to_jsonb(o) ->> v_fk)::uuid from old_rows o);
  end if;
  if cardinality(v_ids) = 0 then
    return null;
  end if;

  case tg_argv[1]
    when 'items' then
      update guide.items t set updated_at = now() where t.id = any (v_ids);
    when 'articles' then
      update guide.articles t set updated_at = now() where t.id = any (v_ids);
    when 'author_reviews' then
      update guide.author_reviews t set updated_at = now() where t.id = any (v_ids);
  end case;
  return null;
end;
$$;

comment on function guide.touch_draft_parent() is
  'D23 O3. Trigger AFTER por sentencia: toca updated_at del padre para que draft_entity_version detecte cambios en galería, notas y article_items.';

revoke execute on function guide.touch_draft_parent() from public, anon, authenticated;

-- item_media → items
drop trigger if exists item_media_touch_ins on guide.item_media;
create trigger item_media_touch_ins after insert on guide.item_media
  referencing new table as new_rows for each statement execute function guide.touch_draft_parent('item_id', 'items');
drop trigger if exists item_media_touch_upd on guide.item_media;
create trigger item_media_touch_upd after update on guide.item_media
  referencing old table as old_rows new table as new_rows for each statement execute function guide.touch_draft_parent('item_id', 'items');
drop trigger if exists item_media_touch_del on guide.item_media;
create trigger item_media_touch_del after delete on guide.item_media
  referencing old table as old_rows for each statement execute function guide.touch_draft_parent('item_id', 'items');

-- article_items → articles
drop trigger if exists article_items_touch_ins on guide.article_items;
create trigger article_items_touch_ins after insert on guide.article_items
  referencing new table as new_rows for each statement execute function guide.touch_draft_parent('article_id', 'articles');
drop trigger if exists article_items_touch_upd on guide.article_items;
create trigger article_items_touch_upd after update on guide.article_items
  referencing old table as old_rows new table as new_rows for each statement execute function guide.touch_draft_parent('article_id', 'articles');
drop trigger if exists article_items_touch_del on guide.article_items;
create trigger article_items_touch_del after delete on guide.article_items
  referencing old table as old_rows for each statement execute function guide.touch_draft_parent('article_id', 'articles');

-- author_review_scores → author_reviews (que ya cuenta en draft_entity_version)
drop trigger if exists author_review_scores_touch_ins on guide.author_review_scores;
create trigger author_review_scores_touch_ins after insert on guide.author_review_scores
  referencing new table as new_rows for each statement execute function guide.touch_draft_parent('review_id', 'author_reviews');
drop trigger if exists author_review_scores_touch_upd on guide.author_review_scores;
create trigger author_review_scores_touch_upd after update on guide.author_review_scores
  referencing old table as old_rows new table as new_rows for each statement execute function guide.touch_draft_parent('review_id', 'author_reviews');
drop trigger if exists author_review_scores_touch_del on guide.author_review_scores;
create trigger author_review_scores_touch_del after delete on guide.author_review_scores
  referencing old table as old_rows for each statement execute function guide.touch_draft_parent('review_id', 'author_reviews');

-- author_reviews: INSERT/UPDATE ya cuentan por su updated_at; al borrarla, su updated_at sale de
-- greatest() y el cambio podría no verse, así que se toca la ficha.
drop trigger if exists author_reviews_touch_del on guide.author_reviews;
create trigger author_reviews_touch_del after delete on guide.author_reviews
  referencing old table as old_rows for each statement execute function guide.touch_draft_parent('item_id', 'items');
