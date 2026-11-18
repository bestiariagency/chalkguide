-- F6.11b (2/5) · Validación incondicional (sin excepción O6) y registro sin datos personales. Idempotente.
-- ───────────── 3. Validación (incondicional: también para DEFINER/bypassrls, sin excepción O6) ─────────────
create or replace function guide.user_review_photos_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_admin boolean := guide.is_admin();
  v_meta  jsonb;
  v_size  text;
  v_mime  text;
  v_slot  smallint;
  v_n     integer;
begin
  if tg_op = 'INSERT' then
    if v_uid is null or not guide.user_review_is_mine(new.review_id) then
      raise exception 'not your review' using errcode = '42501';
    end if;
    if not guide.user_review_accepts_photos(new.review_id, v_uid) then
      raise exception 'review does not accept photos' using errcode = '22023';
    end if;
    if new.status is distinct from 'pending' or new.public_path is not null or new.moderated_at is not null
       or new.reject_reason is not null then
      raise exception 'new photos start pending' using errcode = '22023';
    end if;
    if new.rights_version is distinct from guide.review_photo_rights_version() then
      raise exception 'rights_not_accepted' using errcode = 'PT412',
        detail = 'current rights version: ' || guide.review_photo_rights_version();
    end if;
    new.rights_accepted_at := now();
    if not guide.review_photo_upload_path_ok(new.storage_path)
       or split_part(new.storage_path, '/', 1) <> new.review_id::text
       or split_part(split_part(new.storage_path, '/', 2), '.', 1) <> new.id::text then
      raise exception 'invalid storage path' using errcode = '22023';
    end if;
    new.created_at := now();

    -- Cupo diario por usuario (ventana fija de 24 h); un fallo posterior deshace el incremento.
    perform pg_advisory_xact_lock(hashtextextended('guide.review_photo_quota:' || v_uid::text, 0));
    insert into guide.user_review_photo_quota as q (user_id, window_started_at, uploads)
    values (v_uid, now(), 1)
    on conflict (user_id) do update
      set window_started_at = case when q.window_started_at < now() - interval '24 hours' then now()
                                   else q.window_started_at end,
          uploads = case when q.window_started_at < now() - interval '24 hours' then 1 else q.uploads + 1 end
    returning q.uploads into v_n;
    if v_n > guide.review_photo_daily_limit() then
      raise exception 'rate_limited' using errcode = 'PT429',
        detail = format('max %s photos per 24 hours', guide.review_photo_daily_limit());
    end if;

    -- Hueco libre (1..3), serializado por opinión. El unique (review_id, sort_order) es la garantía final.
    perform pg_advisory_xact_lock(hashtextextended('guide.review_photos:' || new.review_id::text, 0));
    select s::smallint into v_slot
    from generate_series(1, 3) s
    where not exists (select 1 from guide.user_review_photos p where p.review_id = new.review_id and p.sort_order = s)
    order by s limit 1;
    if v_slot is null then
      raise exception 'photo_limit' using errcode = 'PT409', detail = 'max 3 photos per review';
    end if;
    new.sort_order := v_slot;

    -- mime y tamaño salen de los metadatos del objeto, nunca de lo que declare el cliente.
    select o.metadata into v_meta
    from storage.objects o
    where o.bucket_id = 'review-photo-uploads' and o.name = new.storage_path;
    if not found then
      raise exception 'photo object not found' using errcode = '22023';
    end if;
    v_mime := v_meta ->> 'mimetype';
    v_size := v_meta ->> 'size';
    if v_mime is null or v_size is null or v_size !~ '^[0-9]{1,12}$' then
      raise exception 'photo object metadata missing' using errcode = '22023';
    end if;
    if v_mime not in ('image/jpeg', 'image/webp')
       or substring(new.storage_path from '\.([a-z]+)$') <> (case v_mime when 'image/jpeg' then 'jpg' else 'webp' end) then
      raise exception 'invalid photo type' using errcode = '22023';
    end if;
    if v_size::bigint < 1 or v_size::bigint > 2097152 then
      raise exception 'photo too large' using errcode = '22023';
    end if;
    new.mime_type := v_mime;
    new.size_bytes := v_size::integer;
    return new;
  end if;

  -- UPDATE
  if new.id is distinct from old.id or new.review_id is distinct from old.review_id
     or new.storage_path is distinct from old.storage_path or new.mime_type is distinct from old.mime_type
     or new.size_bytes is distinct from old.size_bytes or new.created_at is distinct from old.created_at
     or new.rights_version is distinct from old.rights_version
     or new.rights_accepted_at is distinct from old.rights_accepted_at then
    raise exception 'photo is immutable' using errcode = '22023';
  end if;
  if new.sort_order is distinct from old.sort_order and not (v_admin or guide.user_review_is_mine(old.review_id)) then
    raise exception 'not your photo' using errcode = '42501';
  end if;
  if (new.status, new.public_path, new.width, new.height, new.reject_reason)
     is distinct from (old.status, old.public_path, old.width, old.height, old.reject_reason) and not v_admin then
    raise exception 'admin only' using errcode = '42501';
  end if;
  new.moderated_at := old.moderated_at;

  if new.status is distinct from old.status then
    if new.status = 'pending' then
      raise exception 'photos cannot go back to pending' using errcode = '22023';
    end if;
    new.moderated_at := now();
  elsif (new.public_path, new.width, new.height, new.reject_reason)
        is distinct from (old.public_path, old.width, old.height, old.reject_reason) then
    raise exception 'photo changes only when moderating' using errcode = '22023';
  end if;
  if new.status <> 'rejected' then
    new.reject_reason := null;
  elsif new.reject_reason is null then
    raise exception 'reject reason required' using errcode = '22023';
  end if;

  if new.status = 'approved' and new.status is distinct from old.status then
    if not guide.review_photo_public_path_ok(new.public_path) then
      raise exception 'invalid public path' using errcode = '22023';
    end if;
    select o.metadata into v_meta
    from storage.objects o
    where o.bucket_id = 'review-photos' and o.name = new.public_path;
    if not found then
      raise exception 'public photo object not found' using errcode = '22023';
    end if;
    v_mime := v_meta ->> 'mimetype';
    v_size := v_meta ->> 'size';
    if v_mime is null or v_size is null or v_size !~ '^[0-9]{1,12}$'
       or v_mime not in ('image/jpeg', 'image/webp')
       or substring(new.public_path from '\.([a-z]+)$') <> (case v_mime when 'image/jpeg' then 'jpg' else 'webp' end)
       or v_size::bigint not between 1 and 2097152 then
      raise exception 'invalid public photo object' using errcode = '22023';
    end if;
  elsif new.status <> 'approved' then
    new.public_path := null;
  end if;
  return new;
end;
$$;

drop trigger if exists user_review_photos_before_write on guide.user_review_photos;
create trigger user_review_photos_before_write
  before insert or update on guide.user_review_photos
  for each row execute function guide.user_review_photos_before_write();

-- ───────────── 4. Registro sin datos personales ─────────────
-- Solo cambios de estado (admin) y borrados sueltos. El borrado en cascada de una opinión no se registra aquí
-- (ya lo registra user_reviews_log_moderation). Nunca rutas, user_id ni nombre del autor.
create or replace function guide.user_review_photos_log_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_admin boolean := guide.is_admin();
  v_item  uuid;
  v_cat   text;
  v_owner uuid;
  v_label text;
  v_by    text;
  v_det   jsonb;
  v_row   guide.user_review_photos;
begin
  if tg_op = 'UPDATE' then
    if old.status is not distinct from new.status then
      return null;
    end if;
    v_row := new;
  else
    v_row := old;
  end if;
  select r.item_id, r.category, r.user_id into v_item, v_cat, v_owner
  from guide.user_reviews r where r.id = v_row.review_id;
  if v_item is null then
    return null;  -- cascada desde la opinión
  end if;
  v_by := case when v_admin then 'admin'
               when v_uid is not null and v_uid = v_owner then 'author'
               else 'system' end;
  if tg_op = 'UPDATE' then
    v_det := jsonb_strip_nulls(jsonb_build_object('review_id', v_row.review_id, 'item_id', v_item, 'category', v_cat,
                                'from', old.status, 'to', new.status, 'by', v_by, 'reason', new.reject_reason));
  else
    v_det := jsonb_build_object('review_id', v_row.review_id, 'item_id', v_item, 'category', v_cat,
                                'status', old.status, 'by', v_by);
  end if;
  select left(i.name, 200) into v_label from guide.items i where i.id = v_item;
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row, details)
  values (case when v_by = 'admin' then v_uid end, lower(tg_op)::guide.activity_action, 'user_review_photos',
          v_row.id::text, v_label, case when tg_op = 'UPDATE' then array['status'] end, null, v_det);
  return null;
end;
$$;

drop trigger if exists user_review_photos_log_moderation on guide.user_review_photos;
create trigger user_review_photos_log_moderation
  after update of status or delete on guide.user_review_photos
  for each row execute function guide.user_review_photos_log_moderation();

revoke all on function guide.user_review_photos_before_write() from public, anon, authenticated;
revoke all on function guide.user_review_photos_log_moderation() from public, anon, authenticated;
