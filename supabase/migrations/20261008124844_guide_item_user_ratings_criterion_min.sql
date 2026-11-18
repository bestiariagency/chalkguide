-- D17 · Con criterios opcionales, un criterio puede tener menos notas que opiniones el ítem.
-- avg_by_criterion solo incluye criterios con al menos min_user_reviews_for_average notas visibles
-- (mismo umbral que la media global), para no publicar una media de 1 sola persona.

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
    having count(*) >= (select s.min_n from settings s)
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
