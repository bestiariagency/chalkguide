-- F6.5 · obs. 2 de leona-lia (docs/security/F6.5-categories-review.md): la GUC de reasignación queda atada a la
-- categoría que se borra. delete_article_category fija guide.draft_op = 'reassign_category:<p_id>' y los dos triggers
-- de articles solo aplican la exención (category_id en vivo sin PT423; sin subir updated_at) si
-- old.category_id = <p_id>, igual que 'apply:<id>'. Con 'reassign_category' a secas o con otra categoría: PT423 en lo
-- vivo y updated_at sube en lo no vivo. Resto de cuerpos idéntico a 20261015133225 / 20261015181019. Idempotente.

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
  if new.status = 'published' and (new.published_at is null or new.published_at > now()) then
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
      -- Reasignación al borrar una categoría: solo los artículos de esa categoría y solo category_id.
      if v_changed is not null
         and not (v_op = 'reassign_category:' || old.category_id::text and v_changed = array['category_id']) then
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

create or replace function guide.articles_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_skip text[] := array['updated_at', 'has_en', 'search_es', 'search_en', 'sort_order'];
begin
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

-- Excepción acotada a O6 (.ai/security-rls.md): esta función DEFINER escribe en content_drafts, solo tras
-- assert_admin() y solo SET payload (nunca base_updated_at ni updated_by; updated_by lo fija el trigger).
create or replace function guide.delete_article_category(p_id uuid, p_reassign_to uuid default null)
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
    perform set_config('guide.draft_op', 'reassign_category:' || p_id::text, true);
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

-- create or replace conserva los privilegios; se reafirman por idempotencia (mismo estado que 20261015132806).
revoke execute on function guide.delete_article_category(uuid, uuid) from public, anon;
grant execute on function guide.delete_article_category(uuid, uuid) to authenticated;
revoke execute on function guide.articles_before_write() from public, anon, authenticated;
revoke execute on function guide.articles_set_updated_at() from public, anon, authenticated;
