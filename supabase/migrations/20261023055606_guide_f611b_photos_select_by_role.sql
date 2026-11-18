-- F6.11b · SELECT por rol: anon solo aprobadas (sin llamar a user_review_is_mine, que deja de ser ejecutable por anon);
-- authenticated: aprobadas + las suyas + admin. Idempotente.
drop policy if exists user_review_photos_select on guide.user_review_photos;
drop policy if exists user_review_photos_select_anon on guide.user_review_photos;
drop policy if exists user_review_photos_select_auth on guide.user_review_photos;
create policy user_review_photos_select_anon on guide.user_review_photos
  for select to anon
  using (status = 'approved' and exists (
           select 1 from guide.user_reviews r
           join guide.items i on i.id = r.item_id
           where r.id = user_review_photos.review_id and r.status = 'visible' and i.published));
create policy user_review_photos_select_auth on guide.user_review_photos
  for select to authenticated
  using (
    (status = 'approved' and exists (
       select 1 from guide.user_reviews r
       join guide.items i on i.id = r.item_id
       where r.id = user_review_photos.review_id and r.status = 'visible' and i.published))
    or guide.user_review_is_mine(review_id)
    or (select guide.is_admin()));
revoke all on function guide.user_review_is_mine(uuid) from public, anon;
grant execute on function guide.user_review_is_mine(uuid) to authenticated;
