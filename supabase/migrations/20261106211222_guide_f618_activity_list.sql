-- 6.18 · Registro de actividad (pantalla Actividad del panel).
-- 1) Helpers puros de saneado: etiqueta y details de tablas privadas (subscribers, admins, opiniones de lectores).
--    Los usan admin_activity_list y admin_dashboard_stats.recent_activity (cumple la condición de D55/6.19:
--    subscribers y user_reviews sí se registran, así que se enmascaran en servidor).
-- 2) admin_activity_list: INVOKER, assert_admin, filtros del diseño (pestaña, entidad, acción, actor, fechas,
--    búsqueda), paginación por cursor (occurred_at, id) y recuentos por pestaña. Nunca devuelve old_row ni actor_id.

create or replace function guide.activity_safe_label(p_table text, p_label text)
returns text
language sql
immutable
set search_path to ''
as $function$
  -- admins: la etiqueta es el email. subscribers: no lleva etiqueta, pero se fuerza null por si cambia.
  select case when p_table in ('admins', 'subscribers', 'user_profiles') then null else p_label end;
$function$;

create or replace function guide.activity_safe_details(p_table text, p_details jsonb)
returns jsonb
language sql
immutable
set search_path to ''
as $function$
  -- Tablas privadas: solo claves de lista blanca (todas son ids de contenido o valores de conjuntos cerrados).
  select case
    when p_details is null then null
    when p_table in ('admins', 'subscribers', 'user_reviews', 'user_review_photos', 'user_profiles') then (
      select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb)
      from jsonb_each(p_details) e
      where e.key = any (array['from', 'to', 'by', 'status', 'reason', 'unsubscribe_source',
                               'item_id', 'category', 'review_id']))
    else p_details
  end;
$function$;

revoke all on function guide.activity_safe_label(text, text) from public, anon, service_role;
revoke all on function guide.activity_safe_details(text, jsonb) from public, anon, service_role;
grant execute on function guide.activity_safe_label(text, text) to authenticated;
grant execute on function guide.activity_safe_details(text, jsonb) to authenticated;

create or replace function guide.activity_target(
  p_table text, p_entity_id text, p_item uuid, p_item_exists boolean, p_category text)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  c_uuid  constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_id    uuid := case when p_entity_id ~* c_uuid then p_entity_id::uuid end;
  v_cat   text := case p_category when 'gym' then 'rocodromos' when 'resoler' then 'resoladores'
                                  when 'shoe' then 'pies-de-gato' end;
  v_key   text;
begin
  -- Enlace del panel a la entidad. exists = false si la entidad ya no está (borrada): la UI no enlaza.
  -- Rutas por categoría fijas: una categoría nueva necesita su ruta aquí (y su página en el panel).
  if p_table = 'articles' then
    return jsonb_build_object('route', '/administrador/articulos/' || p_entity_id, 'query', null,
      'exists', exists (select 1 from guide.articles a where a.id = v_id));
  elsif p_table in ('items', 'gyms', 'resolers', 'shoes', 'author_reviews') then
    return jsonb_build_object('route', case when v_cat is not null and p_item is not null
                                            then '/administrador/' || v_cat || '/' || p_item::text end,
      'query', null, 'exists', coalesce(p_item_exists, false) and v_cat is not null);
  elsif p_table = 'pages' then
    select p.key into v_key from guide.pages p where p.id = v_id;
    return jsonb_build_object('route', case when v_key is not null then '/administrador/paginas/' || v_key end,
      'query', null, 'exists', v_key is not null);
  elsif p_table = 'media' then
    return jsonb_build_object('route', '/administrador/medios', 'query', jsonb_build_object('medio', p_entity_id),
      'exists', exists (select 1 from guide.media m where m.id = v_id));
  elsif p_table = 'events' then
    return jsonb_build_object('route', '/administrador/agenda', 'query', jsonb_build_object('evento', p_entity_id),
      'exists', exists (select 1 from guide.events e where e.id = v_id));
  elsif p_table in ('user_reviews', 'user_review_photos') then
    return jsonb_build_object('route', '/administrador/opiniones', 'query', null, 'exists', true);
  elsif p_table = 'subscribers' then
    return jsonb_build_object('route', '/administrador/suscriptores', 'query', null, 'exists', true);
  elsif p_table = 'article_categories' then
    return jsonb_build_object('route', '/administrador/categorias', 'query', null, 'exists', true);
  elsif p_table in ('criteria', 'item_categories') then
    return jsonb_build_object('route', '/administrador/criterios', 'query', null, 'exists', true);
  elsif p_table in ('site_settings', 'authors') then
    return jsonb_build_object('route', '/administrador/ajustes', 'query', null, 'exists', true);
  elsif p_table = 'import_batches' then
    return jsonb_build_object('route', case when v_cat is not null then '/administrador/' || v_cat || '/importar' end,
      'query', null, 'exists', v_cat is not null);
  elsif p_table like 'export\_%' then
    return jsonb_build_object('route', '/administrador/exportar', 'query', null, 'exists', true);
  end if;
  return jsonb_build_object('route', null, 'query', null, 'exists', false);
end;
$function$;

revoke all on function guide.activity_target(text, text, uuid, boolean, text) from public, anon, service_role;
grant execute on function guide.activity_target(text, text, uuid, boolean, text) to authenticated;

drop function if exists guide.admin_activity_list(text, text[], text[], text, timestamptz, timestamptz, text, integer, timestamptz, bigint);

create or replace function guide.admin_activity_list(
  p_group     text          default null,  -- null = Todo · content | pub | mod | exp | sys
  p_entities  text[]        default null,  -- entity_table (articles, items, gyms, media, events, subscribers…)
  p_actions   text[]        default null,  -- valores de guide.activity_action
  p_actor     text          default null,  -- admin | agent | system | person
  p_from      timestamptz   default null,  -- incluido
  p_to        timestamptz   default null,  -- excluido
  p_search    text          default null,  -- título/archivo (ilike) o email exacto de suscriptor
  p_limit     integer       default 50,
  p_cursor_at timestamptz   default null,  -- next_cursor.occurred_at de la página anterior
  p_cursor_id bigint        default null   -- next_cursor.id de la página anterior
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  c_uuid   constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_like   text;
  v_email  text;
  v_rows   jsonb;
  v_counts jsonb;
  v_next   jsonb;
begin
  perform guide.assert_admin();

  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  if p_group is not null and p_group not in ('content', 'pub', 'mod', 'exp', 'sys') then
    raise exception 'invalid group' using errcode = '22023';
  end if;
  if p_actor is not null and p_actor not in ('admin', 'agent', 'system', 'person') then
    raise exception 'invalid actor' using errcode = '22023';
  end if;
  if p_entities is not null and (cardinality(p_entities) > 30
     or exists (select 1 from unnest(p_entities) x where x is null or x !~ '^[a-z_]{1,40}$')) then
    raise exception 'invalid entities' using errcode = '22023';
  end if;
  if p_actions is not null and (cardinality(p_actions) > 20
     or exists (select 1 from unnest(p_actions) x
                where x is null or not (x = any (enum_range(null::guide.activity_action)::text[])))) then
    raise exception 'invalid actions' using errcode = '22023';
  end if;
  if (p_cursor_at is null) <> (p_cursor_id is null) then
    raise exception 'invalid cursor' using errcode = '22023';
  end if;
  if p_from is not null and p_to is not null and p_from >= p_to then
    raise exception 'invalid range' using errcode = '22023';
  end if;
  if v_search is not null then
    if char_length(v_search) < 2 or char_length(v_search) > 100 then
      raise exception 'invalid search' using errcode = '22023';
    end if;
    if position('@' in v_search) > 0 then
      v_email := lower(v_search);
    end if;
    v_like := '%' || replace(replace(replace(v_search, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  with base as (
    select l.*,
           case when l.entity_id ~* c_uuid then l.entity_id::uuid end as eid
    from guide.activity_log l
    where (p_from is null or l.occurred_at >= p_from)
      and (p_to is null or l.occurred_at < p_to)
      and (p_entities is null or l.entity_table = any (p_entities))
      and (p_actions is null or l.action::text = any (p_actions))
  ),
  refs as (
    select b.*,
           case
             when b.entity_table in ('items', 'gyms', 'resolers', 'shoes') then b.eid
             when b.entity_table = 'author_reviews' then coalesce(
               (select ar.item_id from guide.author_reviews ar where ar.id = b.eid),
               case when b.old_row ->> 'item_id' ~* c_uuid then (b.old_row ->> 'item_id')::uuid end)
             when b.entity_table in ('user_reviews', 'user_review_photos') then
               case when b.details ->> 'item_id' ~* c_uuid then (b.details ->> 'item_id')::uuid end
           end as item_ref
    from base b
  ),
  res as (
    select r.id, r.occurred_at, r.action, r.entity_table, r.entity_id, r.changed_columns, r.details,
           r.old_row is not null as has_snapshot,
           r.item_ref,
           i.id is not null as item_exists,
           coalesce(i.category, r.old_row ->> 'category', r.details ->> 'category') as item_category,
           guide.activity_safe_label(r.entity_table, coalesce(
             r.entity_label,
             i.name,
             case when r.item_ref is not null then (
               select h.entity_label from guide.activity_log h
               where h.entity_table = 'items' and h.entity_id = r.item_ref::text and h.entity_label is not null
               order by h.id desc limit 1) end)) as label,
           case
             when r.actor_id is not null then 'admin'
             when r.details ->> 'by' = 'admin' then 'admin'
             when r.details ->> 'by' = 'agent' then 'agent'
             when r.details ->> 'by' in ('person', 'author') then 'person'
             else 'system'
           end as actor,
           case
             when r.action = 'export' then 'exp'
             when r.entity_table in ('user_reviews', 'user_review_photos') then 'mod'
             when r.action in ('import', 'import_undo')
               or r.entity_table in ('import_batches', 'site_settings', 'admins', 'subscribers', 'authors')
               or (r.entity_table = 'events' and r.details ->> 'by' in ('agent', 'system')) then 'sys'
             when r.action in ('draft_publish', 'unpublish')
               or (r.action = 'update' and r.entity_table in ('articles', 'items', 'pages', 'events')
                   and r.changed_columns && array['status', 'published']) then 'pub'
             else 'content'
           end as grp
    from refs r
    left join guide.items i on i.id = r.item_ref
  ),
  filtered as (
    select f.* from res f
    where (p_actor is null or f.actor = p_actor)
      and (v_search is null
           or f.label ilike v_like
           or (v_email is not null and f.entity_table = 'subscribers'
               and f.entity_id in (select s.id::text from guide.subscribers s where s.email = v_email)))
  ),
  page as (
    select f.* from filtered f
    where (p_group is null or f.grp = p_group)
      and (p_cursor_at is null or (f.occurred_at, f.id) < (p_cursor_at, p_cursor_id))
    order by f.occurred_at desc, f.id desc
    limit p_limit + 1
  ),
  numbered as (
    select p.*, row_number() over (order by p.occurred_at desc, p.id desc) as rn from page p
  )
  select
    (select coalesce(jsonb_agg(jsonb_build_object(
        'id', n.id,
        'occurred_at', n.occurred_at,
        'action', n.action,
        'entity_table', n.entity_table,
        'entity_id', case when n.entity_table = 'admins' then null else n.entity_id end,
        'label', n.label,
        'group', n.grp,
        'actor', n.actor,
        'item_category', n.item_category,
        'changed_columns', n.changed_columns,
        'details', guide.activity_safe_details(n.entity_table, n.details),
        'has_snapshot', n.has_snapshot,
        'target', guide.activity_target(n.entity_table, n.entity_id, n.item_ref, n.item_exists, n.item_category))
      order by n.occurred_at desc, n.id desc), '[]'::jsonb)
     from numbered n where n.rn <= p_limit),
    (select case when count(*) > p_limit then (
        select jsonb_build_object('occurred_at', n.occurred_at, 'id', n.id)
        from numbered n where n.rn = p_limit) end
     from numbered),
    (select jsonb_build_object(
        'all', count(*),
        'content', count(*) filter (where f.grp = 'content'),
        'pub', count(*) filter (where f.grp = 'pub'),
        'mod', count(*) filter (where f.grp = 'mod'),
        'exp', count(*) filter (where f.grp = 'exp'),
        'sys', count(*) filter (where f.grp = 'sys'))
     from filtered f)
  into v_rows, v_next, v_counts;

  return jsonb_build_object('entries', v_rows, 'next_cursor', v_next, 'counts', v_counts);
end;
$function$;

revoke all on function guide.admin_activity_list(text, text[], text[], text, timestamptz, timestamptz, text, integer, timestamptz, bigint) from public, anon, service_role;
grant execute on function guide.admin_activity_list(text, text[], text[], text, timestamptz, timestamptz, text, integer, timestamptz, bigint) to authenticated;
