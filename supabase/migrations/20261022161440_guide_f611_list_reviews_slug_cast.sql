-- F6.11: items.slug es un dominio (guide.slug) → cast a text en admin_list_user_reviews (misma firma y resultado).
create or replace function guide.admin_list_user_reviews(
  p_status       guide.review_status default null,
  p_category     text default null,
  p_item_id      uuid default null,
  p_from         timestamptz default null,
  p_to           timestamptz default null,
  p_since        timestamptz default null,
  p_max_overall  integer default null,
  p_needs_review boolean default null,
  p_query        text default null,
  p_limit        integer default 50,
  p_offset       integer default 0
)
returns table (
  id uuid, item_id uuid, item_name text, item_slug text, category text, item_published boolean,
  author_name text, overall_score smallint, body text, locale guide.locale, status guide.review_status,
  scores jsonb, created_at timestamptz, edited_at timestamptz, moderated_at timestamptz,
  last_activity_at timestamptz, needs_review boolean, author_review_count integer,
  item_visible_count integer, item_avg_overall numeric, item_avg_if_toggled numeric,
  item_count_if_toggled integer, total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_q      text;
  v_terms  text[];
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  if char_length(coalesce(p_query, '')) > 200 then
    raise exception 'query too long' using errcode = '22023';
  end if;
  if p_max_overall is not null and p_max_overall not between 1 and 5 then
    raise exception 'invalid max overall' using errcode = '22023';
  end if;
  if p_category is not null and char_length(p_category) > 40 then
    raise exception 'invalid category' using errcode = '22023';
  end if;

  v_q := lower(extensions.unaccent(btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'))));
  select coalesce(array_agg('%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'), '{}')
  into v_terms
  from unnest(string_to_array(nullif(v_q, ''), ' ')) as w
  where w <> '';

  return query
  with base as (
    select r.id, r.item_id, i.name::text as item_name, i.slug::text as item_slug, r.category::text as category, i.published as item_published,
           r.author_name, r.overall_score, r.body, r.locale, r.status, r.created_at, r.edited_at, r.moderated_at,
           r.user_id, coalesce(r.edited_at, r.created_at) as last_at,
           (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at)) as needs
    from guide.user_reviews r
    join guide.items i on i.id = r.item_id
    where (p_status is null or r.status = p_status)
      and (p_category is null or r.category = p_category)
      and (p_item_id is null or r.item_id = p_item_id)
      and (p_from is null or coalesce(r.edited_at, r.created_at) >= p_from)
      and (p_to is null or coalesce(r.edited_at, r.created_at) < p_to)
      and (p_since is null or coalesce(r.edited_at, r.created_at) > p_since)
      and (p_max_overall is null or r.overall_score <= p_max_overall)
      and (p_needs_review is null
           or (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at)) = p_needs_review)
      and (cardinality(v_terms) = 0 or not exists (
             select 1 from unnest(v_terms) as term
             where lower(extensions.unaccent(concat_ws(' ', r.body, r.author_name, i.name))) not like term escape '\'))
  ),
  page as (
    select b.*, count(*) over () as t
    from base b
    order by b.last_at desc, b.id desc
    limit v_limit offset v_offset
  )
  select p.id, p.item_id, p.item_name, p.item_slug, p.category, p.item_published,
         p.author_name, p.overall_score, p.body, p.locale, p.status,
         coalesce((
           select jsonb_agg(jsonb_build_object('criterion_id', c.id, 'key', c.key, 'name_es', c.name_es,
                                               'name_en', c.name_en, 'score', sc.score, 'is_active', c.is_active)
                            order by c.sort_order, c.name_es)
           from guide.user_review_scores sc
           join guide.criteria c on c.id = sc.criterion_id
           where sc.review_id = p.id), '[]'::jsonb),
         p.created_at, p.edited_at, p.moderated_at, p.last_at, p.needs,
         (select count(*)::integer from guide.user_reviews x where x.user_id = p.user_id),
         st.n,
         st.a,
         case when st.n2 > 0 then round(st.s2 / st.n2, 2) end,
         st.n2,
         p.t
  from page p
  cross join lateral (
    select v.n, v.a,
           case when p.status = 'visible' then v.n - 1 else v.n + 1 end as n2,
           case when p.status = 'visible' then v.s - p.overall_score else v.s + p.overall_score end::numeric as s2
    from (select count(*)::integer as n, coalesce(sum(y.overall_score), 0) as s, round(avg(y.overall_score), 2) as a
          from guide.user_reviews y where y.item_id = p.item_id and y.status = 'visible') v
  ) st
  order by p.last_at desc, p.id desc;
end;
$$;
revoke all on function guide.admin_list_user_reviews(guide.review_status, text, uuid, timestamptz, timestamptz,
  timestamptz, integer, boolean, text, integer, integer) from public, anon;
grant execute on function guide.admin_list_user_reviews(guide.review_status, text, uuid, timestamptz, timestamptz,
  timestamptz, integer, boolean, text, integer, integer) to authenticated;

