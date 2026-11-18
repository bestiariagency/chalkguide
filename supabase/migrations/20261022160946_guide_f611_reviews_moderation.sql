-- F6.11 Opiniones del panel: bandeja de moderación, contadores (D24), borrado excepcional con motivo.
-- Modelo sin cambios: post-moderación por defecto (site_settings.user_reviews_premoderation = false → las
-- opiniones salen 'visible' al momento y el admin oculta); con premoderación salen 'pending' y el admin aprueba.
-- Idempotente.

-- ───────────── 1. Registro de moderación sin datos personales ─────────────
-- Sustituye a user_reviews_log_activity (genérico: registraba como actor al usuario que edita su opinión y no
-- guardaba el estado anterior/nuevo). Ahora: solo cambios reales de status y borrados; nunca body, author_name,
-- user_id ni snapshot; actor_id solo si quien actúa es admin.
create or replace function guide.user_reviews_log_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_admin  boolean := guide.is_admin();
  v_mark   text := coalesce(current_setting('guide.review_delete', true), '');
  v_item   uuid;
  v_reason text;
  v_by     text;
  v_label  text;
  v_det    jsonb;
begin
  if tg_op = 'UPDATE' then
    if old.status is not distinct from new.status then
      return null;
    end if;
    v_item := new.item_id;
    v_by := case when v_admin then 'admin'
                 when v_uid is not null and v_uid = new.user_id then 'author'
                 else 'system' end;
    v_det := jsonb_build_object('item_id', new.item_id, 'category', new.category,
                                'from', old.status, 'to', new.status, 'by', v_by);
  else
    v_item := old.item_id;
    -- La marca la pone delete_user_review (atada a la fila); solo cuenta si quien borra es admin.
    if v_admin and v_mark like old.id::text || ':%' then
      v_reason := split_part(v_mark, ':', 2);
      v_by := 'admin';
    elsif v_uid is not null and v_uid = old.user_id then
      v_by := 'author';
    elsif v_admin then
      v_by := 'admin';
    else
      v_by := 'system';
    end if;
    v_det := jsonb_strip_nulls(jsonb_build_object('item_id', old.item_id, 'category', old.category,
                                                  'status', old.status, 'by', v_by, 'reason', v_reason));
  end if;

  select left(i.name, 200) into v_label from guide.items i where i.id = v_item;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row, details)
  values (case when v_by = 'admin' then v_uid end,
          lower(tg_op)::guide.activity_action,
          'user_reviews',
          coalesce(case when tg_op = 'DELETE' then old.id else new.id end::text, '?'),
          v_label,
          case when tg_op = 'UPDATE' then array['status'] end,
          null,
          v_det);
  return null;
end;
$$;
revoke all on function guide.user_reviews_log_moderation() from public, anon, authenticated;

drop trigger if exists user_reviews_log_activity on guide.user_reviews;
drop trigger if exists user_reviews_log_moderation on guide.user_reviews;
create trigger user_reviews_log_moderation
  after update of status or delete on guide.user_reviews
  for each row execute function guide.user_reviews_log_moderation();

-- ───────────── 2. Borrado: el admin solo borra por RPC con motivo; nadie borra notas sueltas ─────────────
drop policy if exists user_reviews_delete on guide.user_reviews;
create policy user_reviews_delete on guide.user_reviews
  for delete to authenticated
  using (user_id = (select auth.uid()) and status <> 'hidden');

-- Borrar notas sueltas cambiaría la opinión de otro y las medias sin rastro. Las notas caen solo en cascada
-- (borrar la opinión) o por submit_user_review.
drop policy if exists user_review_scores_delete on guide.user_review_scores;
revoke delete on guide.user_review_scores from authenticated;

-- ───────────── 3. Medias de la ficha tras moderar (helper interno de admin) ─────────────
create or replace function guide.user_review_item_stats(p_item_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_min integer := coalesce((select s.min_user_reviews_for_average from guide.site_settings s where s.id = 1)::integer, 3);
  v_n   integer;
  v_avg numeric;
begin
  perform guide.assert_admin();
  select count(*)::integer, round(avg(r.overall_score), 2) into v_n, v_avg
  from guide.user_reviews r where r.item_id = p_item_id and r.status = 'visible';
  return jsonb_build_object(
    'item_id', p_item_id,
    'item_visible_count', v_n,
    'item_avg_overall', v_avg,
    'item_public_avg_overall', case when v_n >= v_min then v_avg end,
    'min_for_average', v_min);
end;
$$;
revoke all on function guide.user_review_item_stats(uuid) from public, anon;
grant execute on function guide.user_review_item_stats(uuid) to authenticated;

-- ───────────── 4. Moderar (mostrar/ocultar/aprobar o marcar como revisada) ─────────────
drop function if exists guide.moderate_user_review(uuid, guide.review_status);
create function guide.moderate_user_review(p_id uuid, p_status guide.review_status)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_item uuid;
  v_at   timestamptz;
begin
  perform guide.assert_admin();
  if p_status is null or p_status not in ('visible', 'hidden') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update guide.user_reviews
  set status = p_status, moderated_at = now()
  where id = p_id
  returning item_id, moderated_at into v_item, v_at;
  if v_item is null then
    raise exception 'review not found' using errcode = 'P0002';
  end if;
  return guide.user_review_item_stats(v_item)
         || jsonb_build_object('id', p_id, 'status', p_status, 'moderated_at', v_at);
end;
$$;
revoke all on function guide.moderate_user_review(uuid, guide.review_status) from public, anon;
grant execute on function guide.moderate_user_review(uuid, guide.review_status) to authenticated;

-- ───────────── 5. Borrado excepcional (RGPD o contenido ilegal) ─────────────
create or replace function guide.delete_user_review(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid;
begin
  perform guide.assert_admin();
  if p_reason is null or p_reason not in ('erasure_request', 'illegal_content') then
    raise exception 'invalid reason' using errcode = '22023';
  end if;
  select r.item_id into v_item from guide.user_reviews r where r.id = p_id for update;
  if v_item is null then
    raise exception 'review not found' using errcode = 'P0002';
  end if;
  perform set_config('guide.review_delete', p_id::text || ':' || p_reason, true);
  delete from guide.user_reviews where id = p_id;
  perform set_config('guide.review_delete', '', true);
  return guide.user_review_item_stats(v_item) || jsonb_build_object('id', p_id, 'deleted', true);
end;
$$;
revoke all on function guide.delete_user_review(uuid, text) from public, anon;
grant execute on function guide.delete_user_review(uuid, text) to authenticated;

-- ───────────── 6. Bandeja: listado con filtros, búsqueda y paginación ─────────────
-- SECURITY DEFINER solo para contar las opiniones del mismo autor sin exponer user_id (el admin no tiene
-- grant de esa columna). Solo lectura; assert_admin es lo primero. Nunca devuelve user_id ni email.
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
    select r.id, r.item_id, i.name as item_name, i.slug as item_slug, r.category, i.published as item_published,
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

-- ───────────── 7. Contadores de la bandeja y del menú (D24) ─────────────
create or replace function guide.admin_reviews_summary()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_seen timestamptz;
  v jsonb;
begin
  perform guide.assert_admin();
  select a.reviews_seen_at into v_seen from guide.admins a where a.user_id = (select auth.uid());
  select jsonb_build_object(
    'seen_at', v_seen,
    'total', count(*),
    'visible', count(*) filter (where r.status = 'visible'),
    'pending', count(*) filter (where r.status = 'pending'),
    'hidden', count(*) filter (where r.status = 'hidden'),
    'recent_7d', count(*) filter (where coalesce(r.edited_at, r.created_at) >= now() - interval '7 days'),
    'low_score', count(*) filter (where r.overall_score <= 2),
    'needs_review', count(*) filter (where r.status <> 'hidden'
                                       and (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at))),
    'new_since_seen', count(*) filter (where r.status <> 'hidden'
                                         and (v_seen is null or coalesce(r.edited_at, r.created_at) > v_seen)
                                         and (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at))),
    'badge', count(*) filter (where r.status = 'pending'
                                or (r.status = 'visible'
                                    and (v_seen is null or coalesce(r.edited_at, r.created_at) > v_seen)
                                    and (r.moderated_at is null or r.moderated_at < coalesce(r.edited_at, r.created_at)))),
    'premoderation', coalesce((select s.user_reviews_premoderation from guide.site_settings s where s.id = 1), false),
    'min_for_average', coalesce((select s.min_user_reviews_for_average from guide.site_settings s where s.id = 1)::integer, 3)
  ) into v
  from guide.user_reviews r;
  return v;
end;
$$;
revoke all on function guide.admin_reviews_summary() from public, anon;
grant execute on function guide.admin_reviews_summary() to authenticated;

-- ───────────── 8. Fichas con opiniones (filtro "Ficha") ─────────────
create or replace function guide.admin_review_items()
returns table (item_id uuid, name text, category text, published boolean,
               review_count integer, visible_count integer, pending_count integer, hidden_count integer)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform guide.assert_admin();
  return query
  select i.id, i.name, i.category, i.published,
         count(*)::integer,
         (count(*) filter (where r.status = 'visible'))::integer,
         (count(*) filter (where r.status = 'pending'))::integer,
         (count(*) filter (where r.status = 'hidden'))::integer
  from guide.user_reviews r
  join guide.items i on i.id = r.item_id
  group by i.id, i.name, i.category, i.published
  order by i.name, i.id;
end;
$$;
revoke all on function guide.admin_review_items() from public, anon;
grant execute on function guide.admin_review_items() to authenticated;
