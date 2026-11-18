-- D17 · Opiniones de usuarios: nota global obligatoria, criterios opcionales, límite antispam y pies de gato.
--   · user_reviews.overall_score smallint 1..5 not null (existentes: media redondeada de sus criterios).
--   · submit_user_review(p_item_id, p_overall, p_scores = '{}', p_body, p_locale): p_scores puede ir vacío;
--     si trae criterios, todos de la categoría del ítem, activos y enteros 1..5.
--   · Máximo 5 opiniones NUEVAS por usuario en 24 h (editar la propia no cuenta):
--     raise 'rate_limited' con SQLSTATE PT429 (PostgREST responde HTTP 429, error.code = 'PT429').
--   · item_user_ratings.avg_overall sale de overall_score; avg_by_criterion sigue saliendo de los criterios puntuados.
--   · Pies de gato admiten opiniones (item_categories.allows_user_reviews = true para 'shoe').
-- Reseñas del autor sin cambios.

-- ───────────── overall_score ─────────────
alter table guide.user_reviews add column if not exists overall_score smallint;

update guide.user_reviews r
set overall_score = coalesce(
  (select round(avg(sc.score))::smallint from guide.user_review_scores sc where sc.review_id = r.id), 3)
where r.overall_score is null;

alter table guide.user_reviews alter column overall_score set not null;
do $$ begin
  alter table guide.user_reviews
    add constraint user_reviews_overall_score_range check (overall_score between 1 and 5);
exception when duplicate_object then null; end $$;

grant select (overall_score) on guide.user_reviews to anon, authenticated;

-- ───────────── límite antispam: índice por usuario y fecha ─────────────
-- Cubre también el FK user_id (cascade de auth.users), así que el índice simple sobra.
create index if not exists user_reviews_user_created_idx on guide.user_reviews (user_id, created_at desc);
drop index if exists guide.user_reviews_user_id_idx;

-- ───────────── pies de gato ─────────────
update guide.item_categories set allows_user_reviews = true where key = 'shoe' and not allows_user_reviews;

-- ───────────── submit_user_review (firma nueva) ─────────────
drop function if exists guide.submit_user_review(uuid, jsonb, text, guide.locale);

create or replace function guide.submit_user_review(
  p_item_id uuid,
  p_overall integer,
  p_scores  jsonb default '{}'::jsonb,
  p_body    text default null,
  p_locale  guide.locale default 'es'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_new_per_day constant integer := 5;
  v_uid       uuid := (select auth.uid());
  v_category  text;
  v_body      text := nullif(btrim(p_body), '');
  v_scores    jsonb := coalesce(p_scores, '{}'::jsonb);
  v_given     integer;
  v_valid     integer;
  v_premod    boolean;
  v_review_id uuid;
  v_name      text;
  v_recent    integer;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select i.category into v_category
  from guide.items i
  join guide.item_categories c on c.key = i.category
  where i.id = p_item_id and i.published and c.is_active and c.allows_user_reviews;
  if v_category is null then
    raise exception 'item not reviewable' using errcode = '22023';
  end if;

  if p_overall is null or p_overall not between 1 and 5 then
    raise exception 'invalid overall' using errcode = '22023';
  end if;

  if v_body is not null and char_length(v_body) > 1000 then
    raise exception 'body too long' using errcode = '22023';
  end if;

  if jsonb_typeof(v_scores) <> 'object' then
    raise exception 'invalid scores' using errcode = '22023';
  end if;
  select count(*) into v_given from jsonb_object_keys(v_scores);
  select count(*) into v_valid
  from jsonb_each(v_scores) s
  join guide.criteria c on c.id::text = s.key and c.category = v_category and c.is_active
  cross join lateral (
    select case when jsonb_typeof(s.value) = 'number' then (s.value)::numeric end as n
  ) v
  where v.n between 1 and 5 and v.n = trunc(v.n);
  if v_given <> v_valid then
    raise exception 'invalid scores' using errcode = '22023';
  end if;

  select coalesce(user_reviews_premoderation, false) into v_premod from guide.site_settings where id = 1;
  v_premod := coalesce(v_premod, false);

  -- Serializa los envíos del mismo usuario para que el límite no se salte en paralelo.
  perform pg_advisory_xact_lock(hashtextextended('guide.submit_user_review:' || v_uid::text, 0));

  select r.id into v_review_id
  from guide.user_reviews r
  where r.item_id = p_item_id and r.user_id = v_uid
  for update;

  if v_review_id is null then
    select count(*) into v_recent
    from guide.user_reviews r
    where r.user_id = v_uid and r.created_at > now() - interval '24 hours';
    if v_recent >= c_max_new_per_day then
      raise exception 'rate_limited'
        using errcode = 'PT429',
              detail = format('max %s new reviews per 24 hours', c_max_new_per_day);
    end if;
  end if;

  -- Perfil: nombre de Google saneado y acortado ("Marta G."); nunca el email.
  select guide.short_display_name(
           guide.sanitize_display_name(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name')))
    into v_name
  from auth.users u where u.id = v_uid;
  insert into guide.user_profiles (user_id, display_name)
  values (v_uid, coalesce(v_name, 'Escalador/a'))
  on conflict (user_id) do nothing;
  select p.display_name into v_name from guide.user_profiles p where p.user_id = v_uid;

  if v_review_id is null then
    insert into guide.user_reviews (item_id, category, user_id, author_name, overall_score, body, locale, status)
    values (p_item_id, v_category, v_uid, v_name, p_overall::smallint, v_body, p_locale,
            case when v_premod then 'pending'::guide.review_status else 'visible'::guide.review_status end)
    returning id into v_review_id;
  else
    update guide.user_reviews
    set overall_score = p_overall::smallint,
        body = v_body,
        locale = p_locale,
        author_name = v_name,
        edited_at = now(),
        status = case
                   when status = 'hidden' then 'hidden'::guide.review_status
                   when v_premod then 'pending'::guide.review_status
                   else 'visible'::guide.review_status
                 end
    where id = v_review_id;
    delete from guide.user_review_scores where review_id = v_review_id;
  end if;

  insert into guide.user_review_scores (review_id, criterion_id, category, score)
  select v_review_id, s.key::uuid, v_category, ((s.value)::numeric)::smallint
  from jsonb_each(v_scores) s;

  return v_review_id;
end;
$$;
revoke execute on function guide.submit_user_review(uuid, integer, jsonb, text, guide.locale) from public, anon;
grant execute on function guide.submit_user_review(uuid, integer, jsonb, text, guide.locale) to authenticated, service_role;

-- ───────────── get_my_review: devuelve overall_score ─────────────
drop function if exists guide.get_my_review(uuid);
create function guide.get_my_review(p_item_id uuid)
returns table (id uuid, status guide.review_status, overall_score smallint, body text, locale guide.locale,
               scores jsonb, created_at timestamptz, edited_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.status, r.overall_score, r.body, r.locale,
    coalesce((select jsonb_object_agg(sc.criterion_id::text, sc.score)
              from guide.user_review_scores sc where sc.review_id = r.id), '{}'::jsonb),
    r.created_at, r.edited_at
  from guide.user_reviews r
  where r.item_id = p_item_id and r.user_id = (select auth.uid());
$$;
revoke execute on function guide.get_my_review(uuid) from public, anon;
grant execute on function guide.get_my_review(uuid) to authenticated, service_role;

-- ───────────── vistas ─────────────
create or replace view guide.user_reviews_public with (security_invoker = true) as
select r.id, r.item_id, r.category, r.author_name, r.body, r.locale, r.status, r.edited_at, r.created_at,
  r.overall_score
from guide.user_reviews r;
grant select on guide.user_reviews_public to anon, authenticated, service_role;

create or replace view guide.export_user_reviews with (security_invoker = true) as
select ur.id, ur.item_id, i.name as item_name, ur.category, ur.author_name as display_name, ur.status, ur.locale, ur.body,
  (select jsonb_object_agg(c.key, sc.score)
     from guide.user_review_scores sc join guide.criteria c on c.id = sc.criterion_id
    where sc.review_id = ur.id) as scores,
  ur.created_at, ur.edited_at, ur.moderated_at,
  ur.overall_score
from guide.user_reviews ur
join guide.items i on i.id = ur.item_id
where (select guide.is_admin());

-- Media pública = media de overall_score; por criterio = media de los criterios que sí se puntuaron.
create or replace view guide.item_user_ratings with (security_invoker = true) as
with settings as (
  select coalesce((select s.min_user_reviews_for_average from guide.site_settings s where s.id = 1)::integer, 3) as min_n
), visible as (
  select ur.id, ur.item_id, ur.overall_score from guide.user_reviews ur where ur.status = 'visible'
), counts as (
  select v.item_id, count(*)::integer as review_count, round(avg(v.overall_score), 2) as avg_overall
  from visible v group by v.item_id
), by_criterion as (
  select x.item_id, jsonb_object_agg(x.key, x.avg_score) as avg_by_criterion
  from (
    select v.item_id, c.key, round(avg(sc.score), 2) as avg_score
    from visible v
    join guide.user_review_scores sc on sc.review_id = v.id
    join guide.criteria c on c.id = sc.criterion_id
    group by v.item_id, c.key
  ) x
  group by x.item_id
)
select c.item_id,
  c.review_count,
  case when c.review_count >= s.min_n then c.avg_overall end as avg_overall,
  case when c.review_count >= s.min_n then b.avg_by_criterion end as avg_by_criterion
from counts c
cross join settings s
left join by_criterion b on b.item_id = c.item_id;
