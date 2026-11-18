-- F6.5 · delete_article_category: p_reassign_to con DEFAULT NULL (misma firma, mismo cuerpo que 20261015132806).
-- Así los tipos generados lo exponen como opcional (p_reassign_to?: string) y el panel puede omitirlo al borrar una
-- categoría que nada usa, en vez de enviar null contra un tipo string. Idempotente.
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
