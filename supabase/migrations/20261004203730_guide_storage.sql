-- F2.8 · Storage: bucket media (lectura pública por URL, escritura solo admin). Sin SVG.
-- Las policies están acotadas a bucket_id = 'media' y no tocan las de 'avatars' (Chalk app).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 10485760,
        array['image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Sin SELECT para anon: los archivos se sirven por la URL pública y el bucket no se puede listar.
drop policy if exists "guide media admin read" on storage.objects;
create policy "guide media admin read" on storage.objects
  for select to authenticated
  using (bucket_id = 'media' and (select guide.is_admin()));

drop policy if exists "guide media admin insert" on storage.objects;
create policy "guide media admin insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'media' and (select guide.is_admin()));

drop policy if exists "guide media admin update" on storage.objects;
create policy "guide media admin update" on storage.objects
  for update to authenticated
  using (bucket_id = 'media' and (select guide.is_admin()))
  with check (bucket_id = 'media' and (select guide.is_admin()));

drop policy if exists "guide media admin delete" on storage.objects;
create policy "guide media admin delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'media' and (select guide.is_admin()));
