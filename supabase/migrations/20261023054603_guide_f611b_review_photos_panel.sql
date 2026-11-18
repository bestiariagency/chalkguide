-- F6.11b (4/5) · RPC del panel: moderar con motivo, listar, huérfanos de Storage, limpieza diaria. Idempotente.
-- ───────────── 7. RPC del panel ─────────────
-- Aprobar exige la copia pública ya subida por el panel (re-codificada en canvas) en review-photos.
create or replace function guide.moderate_review_photo(
  p_id uuid, p_status guide.review_photo_status, p_public_path text default null,
  p_width integer default null, p_height integer default null, p_reject_reason text default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_old_status guide.review_photo_status;
  v_old_public text;
  v guide.user_review_photos;
begin
  perform guide.assert_admin();
  if p_status is null or p_status not in ('approved', 'rejected') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  select p.status, p.public_path into v_old_status, v_old_public
  from guide.user_review_photos p where p.id = p_id for update;
  if v_old_status is null then
    raise exception 'photo not found' using errcode = 'P0002';
  end if;
  if v_old_status = p_status then
    raise exception 'status unchanged' using errcode = '22023';
  end if;
  if p_status = 'rejected' and (p_reject_reason is null or p_reject_reason not in
       ('not_own', 'identifiable_people', 'off_topic', 'low_quality', 'inappropriate')) then
    raise exception 'invalid reject reason' using errcode = '22023';
  end if;
  if p_status = 'approved' and p_reject_reason is not null then
    raise exception 'reject reason only when rejecting' using errcode = '22023';
  end if;
  if p_status = 'approved' then
    if p_public_path is null or p_width is null or p_height is null
       or p_width not between 1 and 4096 or p_height not between 1 and 4096 then
      raise exception 'approval needs the public copy and its size' using errcode = '22023';
    end if;
    update guide.user_review_photos p
    set status = 'approved', public_path = p_public_path, width = p_width, height = p_height
    where p.id = p_id
    returning * into v;
  else
    update guide.user_review_photos p
    set status = 'rejected', public_path = null, reject_reason = p_reject_reason
    where p.id = p_id
    returning * into v;
  end if;
  return jsonb_build_object('id', v.id, 'review_id', v.review_id, 'status', v.status,
                            'public_path', v.public_path, 'previous_public_path', v_old_public,
                            'reject_reason', v.reject_reason,
                            'storage_path', v.storage_path, 'width', v.width, 'height', v.height,
                            'moderated_at', v.moderated_at);
end;
$$;

create or replace function guide.admin_list_review_photos(
  p_status    guide.review_photo_status default 'pending',
  p_review_id uuid default null,
  p_limit     integer default 50,
  p_offset    integer default 0)
returns table (
  id uuid, review_id uuid, item_id uuid, item_name text, item_slug text, category text, item_published boolean,
  review_status guide.review_status, author_name text, sort_order smallint, status guide.review_photo_status,
  storage_path text, public_path text, mime_type text, size_bytes integer, width integer, height integer,
  reject_reason text, rights_version text, rights_accepted_at timestamptz,
  created_at timestamptz, moderated_at timestamptz, total_count bigint)
language plpgsql
stable
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  return query
  select p.id, p.review_id, r.item_id, i.name, i.slug::text, r.category, i.published, r.status, r.author_name,
         p.sort_order, p.status, p.storage_path, p.public_path, p.mime_type, p.size_bytes, p.width, p.height,
         p.reject_reason, p.rights_version, p.rights_accepted_at, p.created_at, p.moderated_at, count(*) over ()
  from guide.user_review_photos p
  join guide.user_reviews r on r.id = p.review_id
  join guide.items i on i.id = r.item_id
  where (p_status is null or p.status = p_status)
    and (p_review_id is null or p.review_id = p_review_id)
  order by p.created_at asc, p.id
  limit v_limit offset v_offset;
end;
$$;

-- Limpieza (patrón media_storage_orphans). kind:
--   upload_without_row    objeto privado sin fila (subida a medias, foto o opinión borradas, cuenta borrada)
--   approved_original     original privado de una foto ya aprobada (minimización: borrar tras aprobar)
--   public_without_row    copia pública sin foto aprobada (rechazada después, borrada, opinión o cuenta borradas)
--   row_without_object    fila sin su objeto (pendiente/rechazada sin original, aprobada sin copia pública)
--   rejected_expired      rechazada hace más de 30 días: borrar fila (delete_review_photo) y objeto
create or replace function guide.review_photos_storage_orphans(p_min_age_minutes integer default 60)
returns table (kind text, bucket_id text, storage_path text, photo_id uuid, created_at timestamptz)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_min interval := make_interval(mins => least(greatest(coalesce(p_min_age_minutes, 60), 5), 10080));
begin
  perform guide.assert_admin();
  return query
  select 'upload_without_row'::text, o.bucket_id, o.name, null::uuid, o.created_at
  from storage.objects o
  where o.bucket_id = 'review-photo-uploads' and o.created_at < now() - v_min
    and not exists (select 1 from guide.user_review_photos p where p.storage_path = o.name)
  union all
  select 'approved_original', o.bucket_id, o.name, p.id, o.created_at
  from storage.objects o
  join guide.user_review_photos p on p.storage_path = o.name and p.status = 'approved'
  where o.bucket_id = 'review-photo-uploads'
  union all
  select 'public_without_row', o.bucket_id, o.name, null::uuid, o.created_at
  from storage.objects o
  where o.bucket_id = 'review-photos' and o.created_at < now() - v_min
    and not exists (select 1 from guide.user_review_photos p where p.public_path = o.name)
  union all
  select 'row_without_object', case when p.status = 'approved' then 'review-photos' else 'review-photo-uploads' end,
         case when p.status = 'approved' then p.public_path else p.storage_path end, p.id, p.created_at
  from guide.user_review_photos p
  where (p.status <> 'approved' and not exists (select 1 from storage.objects o
           where o.bucket_id = 'review-photo-uploads' and o.name = p.storage_path))
     or (p.status = 'approved' and not exists (select 1 from storage.objects o
           where o.bucket_id = 'review-photos' and o.name = p.public_path))
  union all
  select 'rejected_expired', 'review-photo-uploads', p.storage_path, p.id, p.created_at
  from guide.user_review_photos p
  where p.status = 'rejected' and p.moderated_at < now() - interval '30 days'
  order by 5;
end;
$$;

-- ───────────── 8b. Limpieza diaria (Edge Function review-photos-cleanup, solo service_role) ─────────────
-- Borra las filas rechazadas hace más de 30 días y devuelve los objetos que la función debe borrar por la API de
-- Storage: subidas sin fila (> 60 min), originales de fotos aprobadas, copias públicas sin fila (> 60 min) y los
-- originales de las rechazadas purgadas. Nunca devuelve user_id. Idempotente: lo que falle sale al día siguiente.
create or replace function guide.review_photos_cleanup_collect(p_limit integer default 500)
returns table (bucket_id text, storage_path text, kind text)
language plpgsql
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_limit integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
begin
  return query
  with purged as (
    delete from guide.user_review_photos p
    where p.id in (select x.id from guide.user_review_photos x
                   where x.status = 'rejected' and x.moderated_at < now() - interval '30 days'
                   order by x.moderated_at limit v_limit)
    returning p.storage_path
  ),
  cand as (
    select 'review-photo-uploads'::text as b, pu.storage_path as n, 'rejected_expired'::text as k from purged pu
    union all
    select o.bucket_id, o.name, 'upload_without_row'
    from storage.objects o
    where o.bucket_id = 'review-photo-uploads' and o.created_at < now() - interval '60 minutes'
      and not exists (select 1 from guide.user_review_photos p where p.storage_path = o.name)
    union all
    select o.bucket_id, o.name, 'approved_original'
    from storage.objects o
    join guide.user_review_photos p on p.storage_path = o.name and p.status = 'approved'
    where o.bucket_id = 'review-photo-uploads'
    union all
    select o.bucket_id, o.name, 'public_without_row'
    from storage.objects o
    where o.bucket_id = 'review-photos' and o.created_at < now() - interval '60 minutes'
      and not exists (select 1 from guide.user_review_photos p where p.public_path = o.name)
  )
  select distinct on (c.b, c.n) c.b, c.n, c.k from cand c
  order by c.b, c.n
  limit v_limit;
end;
$$;

revoke all on function guide.moderate_review_photo(uuid, guide.review_photo_status, text, integer, integer, text) from public, anon;
revoke all on function guide.admin_list_review_photos(guide.review_photo_status, uuid, integer, integer) from public, anon;
revoke all on function guide.review_photos_storage_orphans(integer) from public, anon;
revoke all on function guide.review_photos_cleanup_collect(integer) from public, anon, authenticated;
grant execute on function guide.moderate_review_photo(uuid, guide.review_photo_status, text, integer, integer, text) to authenticated;
grant execute on function guide.admin_list_review_photos(guide.review_photo_status, uuid, integer, integer) to authenticated;
grant execute on function guide.review_photos_storage_orphans(integer) to authenticated;
grant execute on function guide.review_photos_cleanup_collect(integer) to service_role;
