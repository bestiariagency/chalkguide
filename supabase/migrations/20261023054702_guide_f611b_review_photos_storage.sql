-- F6.11b (S) · Buckets y policies de Storage de las fotos de opiniones (D31). No toca avatars ni media.
-- Sin policies UPDATE (objetos inmutables; x-upsert falla). Idempotente.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('review-photo-uploads', 'review-photo-uploads', false, 2097152, array['image/jpeg', 'image/webp']),
  ('review-photos', 'review-photos', true, 2097152, array['image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Privado: el lector sube a su opinión; lee sus objetos; borra los suyos sin fila. El admin lee todo y borra
-- los que no tienen fila o cuya foto ya está aprobada.
drop policy if exists "guide review uploads owner insert" on storage.objects;
create policy "guide review uploads owner insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'review-photo-uploads'
              and owner_id = (select auth.uid())::text
              and guide.review_photo_upload_insertable(name));

drop policy if exists "guide review uploads read" on storage.objects;
create policy "guide review uploads read" on storage.objects
  for select to authenticated
  using (bucket_id = 'review-photo-uploads'
         and (owner_id = (select auth.uid())::text or (select guide.is_admin())));

drop policy if exists "guide review uploads delete" on storage.objects;
create policy "guide review uploads delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'review-photo-uploads' and guide.review_photo_upload_deletable(name, owner_id));

-- Público: solo el admin sube la copia re-codificada y la borra cuando ninguna foto aprobada la usa.
-- Sin SELECT para anon (no se lista); la lectura va por /object/public/review-photos/<uuid>.<ext>.
drop policy if exists "guide review photos admin read" on storage.objects;
create policy "guide review photos admin read" on storage.objects
  for select to authenticated
  using (bucket_id = 'review-photos' and (select guide.is_admin()));

drop policy if exists "guide review photos admin insert" on storage.objects;
create policy "guide review photos admin insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'review-photos' and (select guide.is_admin())
              and guide.review_photo_public_path_ok(name));

drop policy if exists "guide review photos admin delete" on storage.objects;
create policy "guide review photos admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'review-photos' and guide.review_photo_public_deletable(name));
