-- F6.10 (2) · Observaciones de buho-pixel al diseñar la pantalla de criterios.
--
--   B1. gym_indices y gym_indices_preview filtran c.is_active (y c.category = 'gym') explícitamente, como ya hacen
--       item_author_scores e item_user_ratings (F6.10 H4): el resultado no depende de la RLS de quien consulta.
--       Hoy es un no-op (beginner_friendly/family_friendly no se pueden desactivar, criteria_before_write); si
--       Xavi decide permitirlo, un criterio de fórmula desactivado cuenta como "sin nota" para todos.
--   B2. guide.criteria_usage(p_category): recuento por criterio para la lista del panel, el diálogo de desactivar y
--       saber si se puede eliminar. Solo admin (assert_admin, 42501); categoría inexistente P0002. SECURITY INVOKER:
--       la RLS de admin ve todas las notas (también de fichas ocultas y opiniones ocultas) y los borradores.
--   B4. Las notas de criterios inactivos no se tocan al guardar ni al publicar. publish_draft (sección scores) borra y
--       reinserta todas las notas de la reseña, y saveScores (fichas no publicadas) borra las que no vienen en el
--       formulario: si el editor dejara de reenviar las de inactivos (solo carga criterios activos), se perderían.
--       → author_review_scores_keep_inactive (BEFORE INSERT/UPDATE/DELETE), con criterio inactivo:
--         * DELETE: se omite (la fila se conserva) mientras exista la reseña; el borrado en cascada de la reseña o la
--           ficha sigue funcionando.
--         * UPDATE: se omite (la nota guardada no cambia).
--         * INSERT: si ya existe la nota (reinserción de publish_draft o upsert del editor) se omite y queda la
--           guardada; si no existe → 22023 'inactive criterion' (no se crean notas nuevas en inactivos).
--         Exención: mantenimiento explícito (guide.draft_op = 'maintenance' y rolbypassrls; guide_dummy_purge.sql).
--         Se ejecuta antes que author_review_scores_live_guard (orden alfabético); si omite la fila, el resto de
--         triggers de fila no corre y la fila no entra en las tablas de transición de touch_draft_parent.
--       Las notas de usuarios de criterios inactivos ya se conservan: nadie las borra salvo submit_user_review al
--       reenviar su opinión (el usuario solo puntúa activos; D17) o la cascada al borrar la opinión.
-- Idempotente.

-- ───────────── B1. Índices: solo criterios activos ─────────────
create or replace view guide.gym_indices with (security_invoker = true) as
with base as (
  select g.item_id,
         least(g.price_monthly_eur + coalesce(g.price_registration_eur, 0::numeric) / 12::numeric,
               g.price_day_eur * (104.0 / 12::numeric),
               g.price_10_pass_eur / 10::numeric * (104.0 / 12::numeric)) as monthly_cost,
         g.has_beginner_courses, g.gear_rental, g.belay_test_required, g.has_boulder,
         g.has_kids_area, g.kids_min_age, g.has_cafe,
         (select s.score from guide.author_reviews r
            join guide.author_review_scores s on s.review_id = r.id
            join guide.criteria c on c.id = s.criterion_id
          where r.item_id = g.item_id and c.category = 'gym' and c.key = 'beginner_friendly'::text and c.is_active) as beginner_score,
         (select s.score from guide.author_reviews r
            join guide.author_review_scores s on s.review_id = r.id
            join guide.criteria c on c.id = s.criterion_id
          where r.item_id = g.item_id and c.category = 'gym' and c.key = 'family_friendly'::text and c.is_active) as family_score
  from guide.gyms g
  join guide.items i on i.id = g.item_id and i.published
), weighted as (
  select b.item_id, b.monthly_cost, b.has_beginner_courses, b.gear_rental, b.belay_test_required, b.has_boulder,
         b.has_kids_area, b.kids_min_age, b.has_cafe, b.beginner_score, b.family_score,
         0.50 * coalesce((b.beginner_score - 1)::numeric / 4.0, 0::numeric)
           + 0.20 * coalesce(b.has_beginner_courses, false)::integer::numeric
           + 0.15 * coalesce(b.gear_rental, false)::integer::numeric
           + 0.15 * coalesce(not b.belay_test_required or b.has_boulder, false)::integer::numeric as beginner_w,
         (0.40 * coalesce(b.has_kids_area, false)::integer::numeric
           + 0.20 * coalesce(b.kids_min_age <= 6, false)::integer::numeric
           + 0.20 * coalesce(b.has_cafe, false)::integer::numeric
           + 0.20 * coalesce((b.family_score - 1)::numeric / 4.0, 0::numeric))
           / case when b.family_score is null then 0.8 else 1.0 end as family_w
  from base b
)
select item_id,
       round(monthly_cost, 2) as monthly_cost_2pw_eur,
       case
         when monthly_cost is null then null::smallint
         when count(monthly_cost) over () < guide.gym_price_quintile_min()
           then guide.gym_price_tier(round(monthly_cost, 2))
         else (6 - ntile(5) over (partition by (monthly_cost is null) order by monthly_cost))::smallint
       end as price_index,
       round(1::numeric + 4::numeric * beginner_w, 1) as beginner_index,
       beginner_score is not null and has_beginner_courses is not null and gear_rental is not null
         and belay_test_required is not null and has_boulder is not null as beginner_index_complete,
       round(1::numeric + 4::numeric * family_w, 1) as family_index
from weighted w;

create or replace function guide.gym_indices_preview(p_item_id uuid, p_detail jsonb default null, p_scores jsonb default null)
returns table (monthly_cost_2pw_eur numeric, price_index smallint, beginner_index numeric,
               beginner_index_complete boolean, family_index numeric)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_payload jsonb := '{}'::jsonb;
  v_g       guide.gyms;
  v_cost    numeric;
  v_beg     smallint;
  v_fam     smallint;
  v_bw      numeric;
  v_fw      numeric;
  v_rank    smallint;
begin
  perform guide.assert_admin();
  select g.* into v_g from guide.gyms g where g.item_id = p_item_id;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;

  if p_detail is not null then v_payload := v_payload || jsonb_build_object('detail', p_detail); end if;
  if p_scores is not null then v_payload := v_payload || jsonb_build_object('scores', p_scores); end if;
  if v_payload <> '{}'::jsonb then
    perform guide.draft_check_payload('item', p_item_id, v_payload);
  end if;
  if p_detail is not null then
    v_g := jsonb_populate_record(v_g, p_detail);
  end if;

  if p_scores is not null then
    select (p_scores ->> c.id::text)::smallint into v_beg from guide.criteria c
    where c.category = 'gym' and c.key = 'beginner_friendly' and c.is_active;
    select (p_scores ->> c.id::text)::smallint into v_fam from guide.criteria c
    where c.category = 'gym' and c.key = 'family_friendly' and c.is_active;
  else
    select s.score into v_beg from guide.author_reviews r
    join guide.author_review_scores s on s.review_id = r.id join guide.criteria c on c.id = s.criterion_id
    where r.item_id = p_item_id and c.category = 'gym' and c.key = 'beginner_friendly' and c.is_active;
    select s.score into v_fam from guide.author_reviews r
    join guide.author_review_scores s on s.review_id = r.id join guide.criteria c on c.id = s.criterion_id
    where r.item_id = p_item_id and c.category = 'gym' and c.key = 'family_friendly' and c.is_active;
  end if;

  v_cost := least(v_g.price_monthly_eur + coalesce(v_g.price_registration_eur, 0) / 12,
                  v_g.price_day_eur * (104.0 / 12),
                  v_g.price_10_pass_eur / 10 * (104.0 / 12));

  v_bw := 0.50 * coalesce((v_beg - 1)::numeric / 4.0, 0)
        + 0.20 * coalesce(v_g.has_beginner_courses, false)::integer
        + 0.15 * coalesce(v_g.gear_rental, false)::integer
        + 0.15 * coalesce((not v_g.belay_test_required) or v_g.has_boulder, false)::integer;
  v_fw := (0.40 * coalesce(v_g.has_kids_area, false)::integer
         + 0.20 * coalesce(v_g.kids_min_age <= 6, false)::integer
         + 0.20 * coalesce(v_g.has_cafe, false)::integer
         + 0.20 * coalesce((v_fam - 1)::numeric / 4.0, 0))
        / case when v_fam is null then 0.8 else 1.0 end;

  -- Precio: tramos fijos mientras haya pocos rocódromos con precio; quintiles desde gym_price_quintile_min().
  -- La ficha cuenta como si estuviera publicada (si ya lo está, no se cuenta dos veces).
  if v_cost is not null then
    if (select count(*) from guide.gym_indices vi
        where vi.item_id <> p_item_id and vi.monthly_cost_2pw_eur is not null) + 1 < guide.gym_price_quintile_min() then
      v_rank := guide.gym_price_tier(round(v_cost, 2));
    else
      select (6 - t.nt)::smallint into v_rank
      from (
        select x.self, ntile(5) over (order by x.cost) as nt
        from (
          select g2.cost, false as self
          from (select gp.item_id,
                       least(gp.price_monthly_eur + coalesce(gp.price_registration_eur, 0) / 12,
                             gp.price_day_eur * (104.0 / 12),
                             gp.price_10_pass_eur / 10 * (104.0 / 12)) as cost
                from guide.gyms gp join guide.items ip on ip.id = gp.item_id and ip.published) g2
          where g2.item_id <> p_item_id and g2.cost is not null
          union all
          select v_cost, true
        ) x
      ) t
      where t.self;
    end if;
  end if;

  return query select round(v_cost, 2), v_rank, round(1 + 4 * v_bw, 1),
    (v_beg is not null and v_g.has_beginner_courses is not null and v_g.gear_rental is not null
     and v_g.belay_test_required is not null and v_g.has_boulder is not null),
    round(1 + 4 * v_fw, 1);
end;
$$;


-- ───────────── B2. criteria_usage ─────────────
create or replace function guide.criteria_usage(p_category text)
returns table (criterion_id uuid, author_items integer, user_reviews integer, draft_items integer,
               used_by_index boolean, can_delete boolean)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if not exists (select 1 from guide.item_categories ic where ic.key = p_category) then
    raise exception 'category not found' using errcode = 'P0002';
  end if;
  return query
  select c.id,
         a.n, u.n, d.n,
         c.used_in_formula,
         not c.used_in_formula and a.n = 0 and u.n = 0 and d.n = 0
  from guide.criteria c
  cross join lateral (select count(distinct r.item_id)::integer as n
                      from guide.author_review_scores s join guide.author_reviews r on r.id = s.review_id
                      where s.criterion_id = c.id) a
  cross join lateral (select count(*)::integer as n from guide.user_review_scores s where s.criterion_id = c.id) u
  cross join lateral (select count(*)::integer as n from guide.content_drafts dr
                      where dr.entity = 'item' and jsonb_typeof(dr.payload -> 'scores') = 'object'
                        and (dr.payload -> 'scores') ? c.id::text) d
  where c.category = p_category
  order by c.sort_order, c.id;
end;
$$;

revoke execute on function guide.criteria_usage(text) from public, anon;
grant execute on function guide.criteria_usage(text) to authenticated, service_role;
comment on function guide.criteria_usage(text) is
  'F6.10. Por criterio de la categoría: fichas con nota del autor, opiniones de usuarios con nota (cualquier estado), '
  'borradores de fichas que lo puntúan, si lo usa una fórmula de índice y si se puede borrar. Solo admin (42501); '
  'categoría inexistente P0002.';

-- ───────────── B4. Notas del autor de criterios inactivos: no se tocan ─────────────
create or replace function guide.author_review_scores_keep_inactive()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
     and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false) then
    return coalesce(new, old);
  end if;
  if not exists (select 1 from guide.criteria c where not c.is_active
                 and c.id in ((case when tg_op = 'INSERT' then null else old.criterion_id end),
                              (case when tg_op = 'DELETE' then null else new.criterion_id end))) then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE' then
    if exists (select 1 from guide.author_reviews r where r.id = old.review_id) then
      return null;
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    return null;
  end if;
  if exists (select 1 from guide.author_review_scores s
             where s.review_id = new.review_id and s.criterion_id = new.criterion_id) then
    return null;
  end if;
  raise exception 'inactive criterion' using errcode = '22023',
    detail = new.criterion_id::text,
    hint = 'Inactive criteria keep their saved scores but take no new ones.';
end;
$$;

revoke execute on function guide.author_review_scores_keep_inactive() from public, anon, authenticated;

drop trigger if exists author_review_scores_keep_inactive on guide.author_review_scores;
create trigger author_review_scores_keep_inactive before insert or update or delete on guide.author_review_scores
  for each row execute function guide.author_review_scores_keep_inactive();
