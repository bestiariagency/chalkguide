-- F6.10 · O2a (leona-lia; D29: lo inactivo no se ve): get_my_review (SECURITY DEFINER) devolvía al dueño también sus
-- notas de criterios desactivados; si el formulario las reenviaba, submit_user_review las rechazaba ('invalid scores').
--   → scores solo incluye criterios activos. Misma firma, SECURITY DEFINER, search_path '', control de dueño
--     (r.user_id = auth.uid()) y grants (authenticated, service_role) sin cambios. Las notas se conservan en BD.
-- Idempotente.

create or replace function guide.get_my_review(p_item_id uuid)
returns table (id uuid, status guide.review_status, overall_score smallint, body text, locale guide.locale,
               scores jsonb, created_at timestamp with time zone, edited_at timestamp with time zone)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.status, r.overall_score, r.body, r.locale,
    coalesce((select jsonb_object_agg(sc.criterion_id::text, sc.score)
              from guide.user_review_scores sc
              join guide.criteria c on c.id = sc.criterion_id and c.is_active
              where sc.review_id = r.id), '{}'::jsonb),
    r.created_at, r.edited_at
  from guide.user_reviews r
  where r.item_id = p_item_id and r.user_id = (select auth.uid());
$$;

revoke execute on function guide.get_my_review(uuid) from public, anon;
grant execute on function guide.get_my_review(uuid) to authenticated, service_role;
