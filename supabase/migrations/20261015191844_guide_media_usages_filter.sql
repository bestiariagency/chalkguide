-- F6.6 · media_usages filtraba sin p_id (devolvía todos los usos). Mismo contrato, con el filtro.
create or replace function guide.media_usages(p_id uuid)
returns table (owner_table text, owner_id uuid, item_category text, label text, role text)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  return query
  select distinct
         case when u.usage_table in ('item_media', 'author_reviews') then 'items' else u.usage_table end,
         case when u.usage_table = 'site_settings' then null else coalesce(ar.item_id, u.usage_id::uuid) end,
         i.category::text,
         coalesce(i.name, u.label),
         case
           when u.usage_table = 'author_reviews' then 'review_' || u.usage_field
           when u.usage_field = 'cover_media_id' then 'cover'
           when u.usage_field in ('og_media_id', 'default_og_media_id') then 'og'
           else u.usage_field
         end
  from guide.media_usage u
  left join guide.author_reviews ar on u.usage_table = 'author_reviews' and ar.id::text = u.usage_id
  left join guide.items i on i.id::text = case
                                            when u.usage_table = 'author_reviews' then ar.item_id::text
                                            when u.usage_table in ('items', 'item_media') then u.usage_id
                                          end
  where u.media_id = p_id
  order by 1, 4, 2, 5;
end;
$$;
revoke execute on function guide.media_usages(uuid) from public;
grant execute on function guide.media_usages(uuid) to authenticated;
