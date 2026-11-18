-- F6.19 punto 6 (docs/security/F6.19-panel-review.md). Idempotente.
-- Desempate determinista de quintiles de precio: con costes iguales, ntile(5) ordena también por item_id, en la
-- vista (order by monthly_cost, item_id) y en la preview (order by x.cost, x.item_id, con p_item_id para la ficha
-- previsualizada). Los dos ordenan por el coste sin redondear (mismo valor en ambos). No se adopta rank() (que costes
-- iguales caigan en el mismo quintil): decisión de producto pendiente de Xavi. Resto sin cambios (20261022105954).
-- create or replace view conserva grants; security_invoker explícito.

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
         else (6 - ntile(5) over (partition by (monthly_cost is null) order by monthly_cost, item_id))::smallint
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
        select x.self, ntile(5) over (order by x.cost, x.item_id) as nt
        from (
          select g2.cost, g2.item_id, false as self
          from (select gp.item_id,
                       least(gp.price_monthly_eur + coalesce(gp.price_registration_eur, 0) / 12,
                             gp.price_day_eur * (104.0 / 12),
                             gp.price_10_pass_eur / 10 * (104.0 / 12)) as cost
                from guide.gyms gp join guide.items ip on ip.id = gp.item_id and ip.published) g2
          where g2.item_id <> p_item_id and g2.cost is not null
          union all
          select v_cost, p_item_id, true
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
