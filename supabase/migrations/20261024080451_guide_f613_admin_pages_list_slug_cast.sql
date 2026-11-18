-- F6.13: slug_es/slug_en son del dominio guide.slug; RETURN QUERY exige text. Idempotente.
create or replace function guide.admin_pages_list()
returns table (
  id               uuid,
  key              text,
  title_es         text,
  title_en         text,
  slug_es          text,
  slug_en          text,
  published        boolean,
  has_en           boolean,
  noindex          boolean,
  revised_on       date,
  updated_at       timestamptz,
  draft_changes    integer,
  draft_updated_at timestamptz,
  versions_count   integer
)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform guide.assert_admin();
  return query
  select p.id, p.key::text, p.title_es::text, p.title_en::text, p.slug_es::text, p.slug_en::text, p.published, p.has_en,
         p.noindex, p.revised_on, p.updated_at,
         -- Como en artículos: columnas del parche (mínimo 1 si hay borrador).
         case when d.id is null then 0
              else greatest(1, (select count(*)::integer from jsonb_object_keys(
                     case when jsonb_typeof(d.payload -> 'page') = 'object' then d.payload -> 'page' else '{}'::jsonb end)))
         end,
         d.updated_at,
         (select count(*)::integer from guide.page_versions v where v.key = p.key and v.locale = 'es')
  from guide.pages p
  left join guide.content_drafts d on d.entity = 'page' and d.page_id = p.id
  order by array_position(array['about', 'transparency', 'legal_notice', 'privacy', 'cookies'], p.key::text);
end;
$$;

revoke all on function guide.admin_pages_list() from public, anon;
grant execute on function guide.admin_pages_list() to authenticated;
