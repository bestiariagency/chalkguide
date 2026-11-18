-- D55 · 6.22 (corrige guide_d55_admin_search_body_min_word): el fragmento del cuerpo colapsa espacios (al quitar
-- etiquetas quedaban dobles). Palabras de 3+ letras en el cuerpo, como en la migración anterior. Resto idéntico.
-- D53/D55 · tarea 6.22: búsqueda de contenido de la paleta ⌘K del panel (docs/design/admin/README.md §15.8).
-- SECURITY INVOKER + assert_admin(): lee con los privilegios y la RLS del admin. La procedencia de los eventos
-- (columna no concedida a authenticated) sale del helper guide.admin_events_agent_info.
-- No toca user_reviews, subscribers, user_profiles, admins ni activity_log.
-- Orden en cada tipo: 1 título empieza por la búsqueda · 2 título la contiene · 3 otros campos · 4 cuerpo del
-- artículo (tsvector existente); a igualdad, updated_at más reciente. Eventos: próximos por fecha ascendente y
-- luego pasados por fecha descendente. Comparación sin tildes ni mayúsculas (extensions.unaccent).
create or replace function guide.admin_search(p_query text, p_kinds text[] default null, p_limit integer default 4)
returns table(kind text, id uuid, key text, title text, data jsonb, status text, matched_field text, snippet text,
              rank integer, total_in_kind bigint)
language plpgsql
stable
set search_path to ''
as $function$
#variable_conflict use_column
declare
  v_q          text;
  v_like       text;
  v_prefix     text;
  v_words      text;
  v_tsq_es     tsquery;
  v_tsq_en     tsquery;
  v_limit      integer := least(greatest(coalesce(p_limit, 4), 1), 20);
  v_item_kinds text[];
  v_all_kinds  text[];
  v_kinds      text[];
begin
  perform guide.assert_admin();

  -- Recorte a 100 caracteres tras normalizar espacios; el left previo acota el coste de la normalización.
  v_q := btrim(regexp_replace(left(coalesce(p_query, ''), 400), '[[:cntrl:][:space:]]+', ' ', 'g'));
  v_q := btrim(lower(extensions.unaccent(left(v_q, 100))));
  if char_length(v_q) < 2 then
    raise exception 'query too short' using errcode = '22023';
  end if;

  select coalesce(array_agg(c.key order by c.sort_order, c.key), '{}') into v_item_kinds from guide.item_categories c;
  v_all_kinds := array['article'] || v_item_kinds || array['page', 'event', 'media'];
  if p_kinds is null or cardinality(p_kinds) = 0 then
    v_kinds := v_all_kinds;
  elsif cardinality(p_kinds) > 20 or not (p_kinds <@ v_all_kinds) then
    raise exception 'invalid kind' using errcode = '22023';
  else
    v_kinds := p_kinds;
  end if;

  -- Comodines de LIKE escapados (\ primero).
  v_prefix := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_like   := '%' || v_prefix;

  -- Cuerpo: prefijos por palabra con solo letras y dígitos (sin operadores de tsquery). Palabras de 3 o más
  -- caracteres: un prefijo de 1–2 letras casaría con casi todos los artículos.
  select string_agg(w || ':*', ' & ') into v_words
  from unnest(string_to_array(btrim(regexp_replace(v_q, '[^[:alnum:]]+', ' ', 'g')), ' ')) as w
  where char_length(w) >= 3;
  if v_words is not null then
    v_tsq_es := to_tsquery('guide.spanish_unaccent'::regconfig, v_words);
    v_tsq_en := to_tsquery('guide.english_unaccent'::regconfig, v_words);
  end if;

  return query
  with cand as (
    select 'article'::text as kind, a.id, a.slug_es::text as key, a.title_es as title,
           jsonb_build_object('title_en', a.title_en, 'category_id', a.category_id, 'category_name_es', ac.name_es,
                              'published_at', a.published_at, 'updated_at', a.updated_at,
                              'has_draft', exists (select 1 from guide.content_drafts d where d.article_id = a.id)) as data,
           a.status::text as status, a.updated_at as sort_ts, null::boolean as is_past, null::timestamptz as starts_at,
           array['title_es', 'title_en'] as t_names, array[a.title_es, a.title_en] as t_vals,
           array['slug_es', 'slug_en', 'excerpt_es', 'excerpt_en'] as o_names,
           array[a.slug_es::text, a.slug_en::text, a.excerpt_es, a.excerpt_en] as o_vals,
           case when v_tsq_es is not null and a.search_es @@ v_tsq_es then 'body_es'
                when v_tsq_en is not null and a.search_en @@ v_tsq_en then 'body_en' end as body_hit
    from guide.articles a
    left join guide.article_categories ac on ac.id = a.category_id
    where 'article' = any (v_kinds)

    union all
    select i.category, i.id, i.slug::text, i.name,
           jsonb_strip_nulls(jsonb_build_object(
             'published', i.published, 'verified_at', i.verified_at, 'updated_at', i.updated_at,
             'has_draft', exists (select 1 from guide.content_drafts d where d.item_id = i.id),
             'district', coalesce(g.district, r.district), 'city', coalesce(g.city, r.city),
             'turnaround_days_min', r.turnaround_days_min, 'turnaround_days_max', r.turnaround_days_max,
             'brand', s.brand, 'model', s.model, 'price_min_eur', s.price_min_eur, 'price_max_eur', s.price_max_eur,
             'is_affiliate', s.is_affiliate)),
           case when i.published then 'published' else 'unpublished' end, i.updated_at, null, null,
           array['name'], array[i.name],
           array['slug', 'summary_es', 'summary_en', 'district', 'city', 'address', 'metro_stations', 'brand', 'model'],
           array[i.slug::text, i.summary_es, i.summary_en, coalesce(g.district, r.district), coalesce(g.city, r.city),
                 g.address, array_to_string(g.metro_stations, ', '), s.brand, s.model],
           null
    from guide.items i
    left join guide.gyms g on g.item_id = i.id
    left join guide.resolers r on r.item_id = i.id
    left join guide.shoes s on s.item_id = i.id
    where i.category = any (v_kinds)

    union all
    select 'page', p.id, p.key, p.title_es,
           jsonb_build_object('title_en', p.title_en, 'slug_es', p.slug_es::text, 'published', p.published,
                              'revised_on', p.revised_on, 'updated_at', p.updated_at,
                              'has_draft', exists (select 1 from guide.content_drafts d where d.page_id = p.id)),
           case when p.published then 'published' else 'unpublished' end, p.updated_at, null, null,
           array['title_es', 'title_en'], array[p.title_es, p.title_en],
           array['slug_es', 'slug_en', 'key'], array[p.slug_es::text, p.slug_en::text, p.key],
           null
    from guide.pages p
    where 'page' = any (v_kinds)

    union all
    select 'event', e.id, null, e.title_es,
           jsonb_build_object('title_en', e.title_en, 'starts_at', e.starts_at, 'ends_at', e.ends_at, 'all_day', e.all_day,
                              'location_text', e.location_text, 'item_id', e.item_id, 'item_name', it.name,
                              'event_type', e.event_type, 'updated_at', e.updated_at),
           e.status::text, e.updated_at, guide.event_is_past(e.starts_at, e.ends_at, e.all_day), e.starts_at,
           array['title_es', 'title_en'], array[e.title_es, e.title_en],
           array['location_text', 'item_name'], array[e.location_text, it.name],
           null
    from guide.events e
    left join guide.items it on it.id = e.item_id
    where 'event' = any (v_kinds) and e.status <> 'rejected'

    union all
    select 'media', m.id, m.storage_path, coalesce(m.original_filename, m.storage_path),
           jsonb_build_object('storage_path', m.storage_path, 'version', m.version, 'dominant_color', m.dominant_color,
                              'alt_es', m.alt_es, 'missing_alt', (m.alt_es is null or btrim(m.alt_es) = ''),
                              'width', m.width, 'height', m.height, 'updated_at', m.updated_at),
           case when m.alt_es is null or btrim(m.alt_es) = '' then 'missing_alt' end, m.updated_at, null, null,
           array['original_filename'], array[m.original_filename],
           array['alt_es', 'alt_en', 'caption_es', 'caption_en', 'credit'],
           array[m.alt_es, m.alt_en, m.caption_es, m.caption_en, m.credit],
           null
    from guide.media m
    where 'media' = any (v_kinds)
  ),
  scored as (
    select c.kind, c.id, c.key, c.title, c.data, c.status, c.sort_ts, c.is_past, c.starts_at,
           h.rnk, h.field, h.val
    from cand c
    cross join lateral (
      select x.rnk, x.field, x.val
      from (
        select case when lower(extensions.unaccent(t.v)) like v_prefix escape '\' then 1 else 2 end as rnk,
               t.n as field, t.v as val, t.o as ord
        from unnest(c.t_names, c.t_vals) with ordinality as t(n, v, o)
        where lower(extensions.unaccent(t.v)) like v_like escape '\'
        union all
        select 3, o.n, o.v, 100 + o.o
        from unnest(c.o_names, c.o_vals) with ordinality as o(n, v, o)
        where lower(extensions.unaccent(o.v)) like v_like escape '\'
        union all
        select 4, c.body_hit, null, 1000
        where c.body_hit is not null
      ) x
      order by x.rnk, x.ord
      limit 1
    ) h
  ),
  ranked as (
    select s.*,
           row_number() over (
             partition by s.kind
             order by s.rnk,
                      s.is_past nulls first,
                      case when s.is_past is false then s.starts_at end asc,
                      case when s.is_past then s.starts_at end desc,
                      s.sort_ts desc, s.id
           ) as rn,
           count(*) over (partition by s.kind) as tot
    from scored s
  ),
  top as (
    select * from ranked r where r.rn <= v_limit
  ),
  ev as (
    select ai.id, ai.source, ai.duplicate_of
    from guide.admin_events_agent_info(array(select t.id from top t where t.kind = 'event')) ai
  )
  select t.kind, t.id, t.key, t.title,
         case t.kind
           when 'event' then t.data || jsonb_build_object('source', ev.source, 'duplicate_of', ev.duplicate_of,
                                                          'is_past', t.is_past)
           when 'media' then t.data || jsonb_build_object('usage_count',
                               (select count(*) from guide.media_usage u where u.media_id = t.id))
           else t.data
         end,
         t.status, t.field,
         case
           when t.rnk = 3 and char_length(t.val) <= 120 then t.val
           when t.rnk = 3 then (
             select case when z.st > 1 then '…' else '' end || substr(t.val, z.st, 120)
                    || case when z.st + 120 <= char_length(t.val) then '…' else '' end
             from (select greatest(1, strpos(lower(extensions.unaccent(t.val)), v_q) - 40) as st) z)
           when t.rnk = 4 then (
             select btrim(ts_headline(
                      case t.field when 'body_es' then 'guide.spanish_unaccent' else 'guide.english_unaccent' end::regconfig,
                      regexp_replace(
                        replace(replace(replace(replace(replace(replace(
                          regexp_replace(case t.field when 'body_es' then a.body_html_es else a.body_html_en end,
                                         '<[^>]*>', ' ', 'g'),
                          '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''), '&amp;', '&'),
                        '[[:space:]]+', ' ', 'g'),
                      case t.field when 'body_es' then v_tsq_es else v_tsq_en end,
                      'StartSel="",StopSel="",MaxWords=18,MinWords=8,ShortWord=2,MaxFragments=1,FragmentDelimiter=" … "'))
             from guide.articles a where a.id = t.id)
         end,
         t.rnk, t.tot
  from top t
  left join ev on t.kind = 'event' and ev.id = t.id
  order by array_position(v_all_kinds, t.kind), t.rn;
end;
$function$;

revoke all on function guide.admin_search(text, text[], integer) from public, anon, service_role;
grant execute on function guide.admin_search(text, text[], integer) to authenticated;
