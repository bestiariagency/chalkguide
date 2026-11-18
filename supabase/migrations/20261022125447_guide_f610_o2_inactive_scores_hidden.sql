-- F6.10 · O2 (leona-lia, docs/security/F6.10-criteria-review.md; decisión de Xavi): las notas de criterios inactivos
-- tampoco se leen en las tablas base para anon y no admin. El admin las sigue viendo todas.
--   · author_review_scores_select: (ficha publicada Y criterio activo) O admin.
--   · user_review_scores_select: opinión visible para quien consulta (RLS de user_reviews) Y (criterio activo O admin).
--     El dueño deja de ver en su opinión (embed de getMyReview) las notas de criterios desactivados: coherente con el
--     formulario, que solo puntúa activos.
-- No afecta a: vistas públicas (security_invoker; ya filtran c.is_active), submit_user_review y get_my_review
-- (SECURITY DEFINER de postgres, bypassrls), editor del admin (is_admin), cascadas y FK (las acciones RI no aplican RLS),
-- triggers de F6.10 (escribe solo el admin). Coste: un EXISTS por fila sobre la PK de criteria.
-- Idempotente.

drop policy if exists author_review_scores_select on guide.author_review_scores;
create policy author_review_scores_select on guide.author_review_scores for select to anon, authenticated
  using (
    (exists (select 1 from guide.author_reviews r join guide.items i on i.id = r.item_id
             where r.id = author_review_scores.review_id and i.published)
     and exists (select 1 from guide.criteria c where c.id = author_review_scores.criterion_id and c.is_active))
    or (select guide.is_admin())
  );

drop policy if exists user_review_scores_select on guide.user_review_scores;
create policy user_review_scores_select on guide.user_review_scores for select to anon, authenticated
  using (
    exists (select 1 from guide.user_reviews r where r.id = user_review_scores.review_id)
    and (exists (select 1 from guide.criteria c where c.id = user_review_scores.criterion_id and c.is_active)
         or (select guide.is_admin()))
  );
