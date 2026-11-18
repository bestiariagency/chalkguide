-- F6.11b (1/5) · Fotos en opiniones de lectores: tipos, tablas y helpers de rutas/Storage (D31). Idempotente.
-- Hasta 3 fotos por opinión. El texto de la opinión sigue con post-moderación (D30); las fotos salen 'pending'
-- y solo se ven en público tras la aprobación del admin.
--
-- Dos buckets (parte S):
--   review-photo-uploads  privado. Lo que sube el lector: '<review_id>/<photo_id>.<jpg|webp>' (sin user_id: la
--                         ruta también la ve el admin en la bandeja). Solo el dueño (y el admin) lo leen.
--   review-photos         público. Copia re-codificada por el panel del admin al aprobar (canvas → sin EXIF/GPS):
--                         '<uuid nuevo>.<jpg|webp>'. Nada identificable en la URL pública.
-- Objetos inmutables (sin UPDATE en Storage). Orden seguro: subir objeto → registrar fila; borrar fila → borrar
-- objeto. Lo que quede a medias lo lista guide.review_photos_storage_orphans().
-- Idempotente.

-- ───────────── 1. Tipos y tablas ─────────────
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'review_photo_status') then
    create type guide.review_photo_status as enum ('pending', 'approved', 'rejected');
  end if;
end $$;

create table if not exists guide.user_review_photos (
  id           uuid primary key,
  review_id    uuid not null references guide.user_reviews (id) on delete cascade,
  sort_order   smallint not null,
  storage_path text not null,
  mime_type    text not null,
  size_bytes   integer not null,
  width        integer not null,
  height       integer not null,
  status       guide.review_photo_status not null default 'pending',
  public_path  text,
  -- Consentimiento de derechos de imagen (D31): versión del texto aceptado y fecha (la pone el trigger).
  rights_version     text not null,
  rights_accepted_at timestamptz not null,
  -- Motivo del rechazo (lista cerrada): lo ve el dueño, nunca el público.
  reject_reason text,
  created_at   timestamptz not null default now(),
  moderated_at timestamptz,
  constraint user_review_photos_rights_version_check check (rights_version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  constraint user_review_photos_reject_reason_check check (
    reject_reason is null
    or reject_reason in ('not_own', 'identifiable_people', 'off_topic', 'low_quality', 'inappropriate')),
  constraint user_review_photos_rejected_reason check ((status = 'rejected') = (reject_reason is not null)),
  constraint user_review_photos_sort_order_check check (sort_order between 1 and 3),
  constraint user_review_photos_mime_check check (mime_type in ('image/jpeg', 'image/webp')),
  constraint user_review_photos_size_check check (size_bytes between 1 and 2097152),
  constraint user_review_photos_dims_check check (width between 1 and 4096 and height between 1 and 4096),
  -- Ruta privada coherente con review_id, id y mime (expresión pura, sin funciones que lean datos)
  constraint user_review_photos_path_check check (
    storage_path = review_id::text || '/' || id::text || '.'
                   || case mime_type when 'image/jpeg' then 'jpg' when 'image/webp' then 'webp' end),
  constraint user_review_photos_public_path_check check (
    public_path is null
    or public_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|webp)$'),
  constraint user_review_photos_approved_public check ((status = 'approved') = (public_path is not null)),
  constraint user_review_photos_moderated_check check ((status = 'pending') = (moderated_at is null)),
  constraint user_review_photos_storage_path_key unique (storage_path),
  constraint user_review_photos_public_path_key unique (public_path),
  -- Máximo 3 por opinión en BD: 3 huecos (1..3) únicos por opinión. Diferible para reordenar.
  constraint user_review_photos_review_slot_key unique (review_id, sort_order) deferrable initially immediate
);
create index if not exists user_review_photos_status_created_idx on guide.user_review_photos (status, created_at desc);

-- Límite de subidas por usuario (ventana fija de 24 h). Interna: sin grants ni policies para clientes.
create table if not exists guide.user_review_photo_quota (
  user_id           uuid primary key references auth.users (id) on delete cascade,
  window_started_at timestamptz not null,
  uploads           integer not null check (uploads >= 0)
);
alter table guide.user_review_photo_quota enable row level security;
revoke all on guide.user_review_photo_quota from anon, authenticated;

create or replace function guide.review_photo_daily_limit()
returns integer
language sql
immutable
set search_path = ''
as $$ select 15 $$;

-- Versión vigente del texto de derechos de imagen (D31). Cambiar el texto = migración que sube la fecha.
create or replace function guide.review_photo_rights_version()
returns text
language sql
immutable
set search_path = ''
as $$ select '2026-10-23'::text $$;

-- ───────────── 2. Rutas y helpers (usados por las policies de Storage de la parte S) ─────────────
create or replace function guide.review_photo_upload_path_ok(p_name text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    char_length(p_name) <= 100
    and p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|webp)$',
    false);
$$;

create or replace function guide.review_photo_public_path_ok(p_name text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    char_length(p_name) <= 60
    and p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|webp)$',
    false);
$$;

-- ¿La opinión es de quien llama? DEFINER: el cliente no tiene grant de user_reviews.user_id.
create or replace function guide.user_review_is_mine(p_review_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from guide.user_reviews r
                 where r.id = p_review_id and r.user_id = (select auth.uid()));
$$;

-- ¿Admite fotos nuevas? Opinión del usuario, no oculta, de una ficha publicada y de una categoría con opiniones.
create or replace function guide.user_review_accepts_photos(p_review_id uuid, p_user_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from guide.user_reviews r
    join guide.items i on i.id = r.item_id
    join guide.item_categories c on c.key = i.category
    where r.id = p_review_id and r.user_id = p_user_id and r.status <> 'hidden'
      and i.published and c.is_active and c.allows_user_reviews);
$$;

-- Storage INSERT en review-photo-uploads: ruta bien formada de una opinión propia que admite fotos, id de foto
-- nuevo, huecos libres (filas + objetos subidos sin registrar < 3) y cupo diario sin agotar.
create or replace function guide.review_photo_upload_insertable(p_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_review uuid;
  v_photo  uuid;
  v_used   integer;
begin
  if v_uid is null or not guide.review_photo_upload_path_ok(p_name) then
    return false;
  end if;
  v_review := split_part(p_name, '/', 1)::uuid;
  v_photo := split_part(split_part(p_name, '/', 2), '.', 1)::uuid;
  if not guide.user_review_accepts_photos(v_review, v_uid) then
    return false;
  end if;
  if exists (select 1 from guide.user_review_photos p where p.id = v_photo) then
    return false;
  end if;
  select (select count(*) from guide.user_review_photos p where p.review_id = v_review)
       + (select count(*) from storage.objects o
          where o.bucket_id = 'review-photo-uploads' and o.name like v_review::text || '/%'
            and not exists (select 1 from guide.user_review_photos p where p.storage_path = o.name))
    into v_used;
  if v_used >= 3 then
    return false;
  end if;
  return not exists (
    select 1 from guide.user_review_photo_quota q
    where q.user_id = v_uid and q.window_started_at >= now() - interval '24 hours'
      and q.uploads >= guide.review_photo_daily_limit());
end;
$$;

-- Storage DELETE en review-photo-uploads. Dueño del objeto: solo si no tiene fila (primero se borra la fila).
-- Admin: sin fila o con la foto ya aprobada (el original ya no hace falta: minimización).
create or replace function guide.review_photo_upload_deletable(p_name text, p_owner_id text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when guide.is_admin() then
      not exists (select 1 from guide.user_review_photos p where p.storage_path = p_name and p.status <> 'approved')
    when (select auth.uid()) is not null and p_owner_id = (select auth.uid())::text then
      not exists (select 1 from guide.user_review_photos p where p.storage_path = p_name)
    else false
  end;
$$;

-- Storage DELETE en review-photos (solo admin): la copia pública no la usa ninguna foto aprobada.
create or replace function guide.review_photo_public_deletable(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select guide.is_admin()
         and not exists (select 1 from guide.user_review_photos p where p.public_path = p_name);
$$;

alter table guide.user_review_photos enable row level security;
revoke all on guide.user_review_photos from anon, authenticated;

revoke all on function guide.review_photo_daily_limit() from public, anon, authenticated;
revoke all on function guide.review_photo_rights_version() from public;
revoke all on function guide.review_photo_upload_path_ok(text) from public, anon;
revoke all on function guide.review_photo_public_path_ok(text) from public, anon;
revoke all on function guide.user_review_is_mine(uuid) from public;
revoke all on function guide.user_review_accepts_photos(uuid, uuid) from public, anon, authenticated;
revoke all on function guide.review_photo_upload_insertable(text) from public, anon;
revoke all on function guide.review_photo_upload_deletable(text, text) from public, anon;
revoke all on function guide.review_photo_public_deletable(text) from public, anon;
grant execute on function guide.review_photo_rights_version() to anon, authenticated;
grant execute on function guide.user_review_is_mine(uuid) to anon, authenticated;
grant execute on function guide.review_photo_upload_path_ok(text) to authenticated;
grant execute on function guide.review_photo_public_path_ok(text) to authenticated;
grant execute on function guide.review_photo_upload_insertable(text) to authenticated;
grant execute on function guide.review_photo_upload_deletable(text, text) to authenticated;
grant execute on function guide.review_photo_public_deletable(text) to authenticated;
