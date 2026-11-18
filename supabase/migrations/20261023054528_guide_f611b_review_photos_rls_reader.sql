-- F6.11b (3/5) · RLS, grants, vista pública y RPC del lector. Idempotente.
-- ───────────── 5. RLS y grants ─────────────
alter table guide.user_review_photos enable row level security;

drop policy if exists user_review_photos_select on guide.user_review_photos;
create policy user_review_photos_select on guide.user_review_photos
  for select to anon, authenticated
  using (
    (status = 'approved' and exists (
       select 1 from guide.user_reviews r
       join guide.items i on i.id = r.item_id
       where r.id = user_review_photos.review_id and r.status = 'visible' and i.published))
    or guide.user_review_is_mine(review_id)
    or (select guide.is_admin()));

drop policy if exists user_review_photos_insert on guide.user_review_photos;
create policy user_review_photos_insert on guide.user_review_photos
  for insert to authenticated
  with check (guide.user_review_is_mine(review_id));

drop policy if exists user_review_photos_update on guide.user_review_photos;
create policy user_review_photos_update on guide.user_review_photos
  for update to authenticated
  using (guide.user_review_is_mine(review_id) or (select guide.is_admin()))
  with check (guide.user_review_is_mine(review_id) or (select guide.is_admin()));

drop policy if exists user_review_photos_delete on guide.user_review_photos;
create policy user_review_photos_delete on guide.user_review_photos
  for delete to authenticated
  using (guide.user_review_is_mine(review_id) or (select guide.is_admin()));

revoke all on guide.user_review_photos from anon, authenticated;
grant select (id, review_id, sort_order, width, height, status, public_path, created_at)
  on guide.user_review_photos to anon;
grant select (id, review_id, sort_order, width, height, status, public_path, created_at,
              storage_path, mime_type, size_bytes, moderated_at, rights_version, rights_accepted_at, reject_reason)
  on guide.user_review_photos to authenticated;
grant insert (id, review_id, storage_path, width, height, rights_version) on guide.user_review_photos to authenticated;
grant update (sort_order, status, public_path, width, height, reject_reason) on guide.user_review_photos to authenticated;
grant delete on guide.user_review_photos to authenticated;

-- Lectura pública: solo aprobadas (RLS añade opinión visible y ficha publicada).
create or replace view guide.user_review_photos_public
with (security_invoker = true) as
select p.id, p.review_id, p.sort_order, p.width, p.height, p.public_path, p.created_at
from guide.user_review_photos p
where p.status = 'approved';
revoke all on guide.user_review_photos_public from anon, authenticated;
grant select on guide.user_review_photos_public to anon, authenticated;

-- ───────────── 6. RPC del lector ─────────────
-- p_rights_accepted: casilla de derechos de imagen (fotos propias, sin caras reconocibles), desmarcada por defecto.
-- Sin ella, o con una versión del texto que no es la vigente: PT412 'rights_not_accepted'.
create or replace function guide.register_review_photo(
  p_review_id uuid, p_photo_id uuid, p_storage_path text, p_width integer, p_height integer,
  p_rights_accepted boolean, p_rights_version text)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v guide.user_review_photos;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if p_rights_accepted is not true or p_rights_version is distinct from guide.review_photo_rights_version() then
    raise exception 'rights_not_accepted' using errcode = 'PT412',
      detail = 'current rights version: ' || guide.review_photo_rights_version();
  end if;
  if p_review_id is null or p_photo_id is null or p_storage_path is null
     or p_width is null or p_height is null then
    raise exception 'missing arguments' using errcode = '22023';
  end if;
  if p_width not between 1 and 4096 or p_height not between 1 and 4096 then
    raise exception 'invalid dimensions' using errcode = '22023';
  end if;
  insert into guide.user_review_photos (id, review_id, storage_path, width, height, rights_version)
  values (p_photo_id, p_review_id, p_storage_path, p_width, p_height, p_rights_version)
  returning * into v;
  return jsonb_build_object('id', v.id, 'review_id', v.review_id, 'sort_order', v.sort_order,
                            'status', v.status, 'storage_path', v.storage_path, 'mime_type', v.mime_type,
                            'size_bytes', v.size_bytes, 'width', v.width, 'height', v.height,
                            'rights_version', v.rights_version, 'rights_accepted_at', v.rights_accepted_at,
                            'created_at', v.created_at);
end;
$$;

-- Borra una foto (el dueño las suyas en cualquier estado; el admin cualquiera). Devuelve las rutas para que el
-- cliente borre el objeto privado (dueño o admin) y, si estaba aprobada, el panel la copia pública.
create or replace function guide.delete_review_photo(p_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_review uuid;
  v_path   text;
  v_public text;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  delete from guide.user_review_photos p where p.id = p_id
  returning p.review_id, p.storage_path, p.public_path into v_review, v_path, v_public;
  if v_review is null then
    raise exception 'photo not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('id', p_id, 'review_id', v_review, 'storage_path', v_path,
                            'public_path', v_public, 'deleted', true);
end;
$$;

-- Reordena todas las fotos de una opinión (p_ids = todas, en el orden nuevo).
create or replace function guide.reorder_review_photos(p_review_id uuid, p_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_n integer;
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;
  if not (guide.user_review_is_mine(p_review_id) or guide.is_admin()) then
    raise exception 'not your review' using errcode = '42501';
  end if;
  select count(*) into v_n from guide.user_review_photos p where p.review_id = p_review_id;
  if p_ids is null or cardinality(p_ids) <> v_n
     or (select count(distinct x) from unnest(p_ids) x) <> v_n
     or exists (select 1 from unnest(p_ids) x
                where not exists (select 1 from guide.user_review_photos p where p.id = x and p.review_id = p_review_id)) then
    raise exception 'ids must be all photos of the review' using errcode = '22023';
  end if;
  set constraints guide.user_review_photos_review_slot_key deferred;
  update guide.user_review_photos p
  set sort_order = o.ord::smallint
  from unnest(p_ids) with ordinality as o(id, ord)
  where p.id = o.id and p.review_id = p_review_id and p.sort_order is distinct from o.ord::smallint;
  set constraints guide.user_review_photos_review_slot_key immediate;
end;
$$;

revoke all on function guide.register_review_photo(uuid, uuid, text, integer, integer, boolean, text) from public, anon;
revoke all on function guide.delete_review_photo(uuid) from public, anon;
revoke all on function guide.reorder_review_photos(uuid, uuid[]) from public, anon;
grant execute on function guide.register_review_photo(uuid, uuid, text, integer, integer, boolean, text) to authenticated;
grant execute on function guide.delete_review_photo(uuid) to authenticated;
grant execute on function guide.reorder_review_photos(uuid, uuid[]) to authenticated;
