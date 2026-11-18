-- F2.4 · Biblioteca de medios y referencias desde cuerpos rich text.

create table if not exists guide.media (
  id                uuid primary key default gen_random_uuid(),
  storage_path      text not null unique
                    check (char_length(storage_path) between 3 and 512 and storage_path !~ '^/'),
  version           integer not null default 1 check (version >= 1),
  original_filename text not null check (char_length(original_filename) between 1 and 255),
  mime_type         text not null
                    check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif')),
  size_bytes        integer not null check (size_bytes > 0 and size_bytes <= 10485760),
  width             integer check (width > 0),
  height            integer check (height > 0),
  alt_es            text check (char_length(alt_es) <= 300),
  alt_en            text check (char_length(alt_en) <= 300),
  caption_es        text check (char_length(caption_es) <= 500),
  caption_en        text check (char_length(caption_en) <= 500),
  credit            text check (char_length(credit) <= 200),
  has_en            boolean generated always as (alt_en is not null) stored,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by        uuid references auth.users (id) on delete set null
);
alter table guide.media enable row level security;
create index if not exists media_created_at_idx on guide.media (created_at desc);

drop trigger if exists media_set_updated_at on guide.media;
create trigger media_set_updated_at before update on guide.media
  for each row execute function guide.set_updated_at();
drop trigger if exists media_log_activity on guide.media;
create trigger media_log_activity after insert or update or delete on guide.media
  for each row execute function guide.log_activity('id', 'original_filename', 'true');

-- Medios incrustados en cuerpos Tiptap (nodos con attrs.mediaId). La mantiene un trigger.
create table if not exists guide.content_media_refs (
  media_id    uuid not null references guide.media (id) on delete restrict,
  owner_table text not null check (owner_table in ('articles', 'pages', 'author_reviews')),
  owner_id    uuid not null,
  locale      guide.locale not null,
  primary key (media_id, owner_table, owner_id, locale)
);
alter table guide.content_media_refs enable row level security;
create index if not exists content_media_refs_owner_idx on guide.content_media_refs (owner_table, owner_id);

create or replace function guide.extract_media_ids(p_doc jsonb)
returns uuid[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(distinct (v #>> '{}')::uuid), '{}'::uuid[])
  from jsonb_path_query(coalesce(p_doc, '{}'::jsonb), 'strict $.**.attrs.mediaId', '{}'::jsonb, true) as v
  where jsonb_typeof(v) = 'string';
$$;
revoke execute on function guide.extract_media_ids(jsonb) from public;
grant execute on function guide.extract_media_ids(jsonb) to authenticated, service_role;

-- Requiere columnas id, body_json_es, body_json_en en la tabla dueña.
create or replace function guide.sync_content_media_refs()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    delete from guide.content_media_refs
    where owner_table = tg_table_name and owner_id = old.id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    insert into guide.content_media_refs (media_id, owner_table, owner_id, locale)
    select m, tg_table_name, new.id, 'es'::guide.locale
    from unnest(guide.extract_media_ids(new.body_json_es)) as m
    union
    select m, tg_table_name, new.id, 'en'::guide.locale
    from unnest(guide.extract_media_ids(new.body_json_en)) as m;
  end if;
  return null;
end;
$$;
revoke execute on function guide.sync_content_media_refs() from public;

-- Grants
grant select on guide.media to anon, authenticated;
grant insert, update, delete on guide.media to authenticated;
grant select on guide.content_media_refs to authenticated;
grant all on guide.media, guide.content_media_refs to service_role;

-- Policies
drop policy if exists media_select on guide.media;
create policy media_select on guide.media for select to anon, authenticated using (true);
drop policy if exists media_insert on guide.media;
create policy media_insert on guide.media for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists media_update on guide.media;
create policy media_update on guide.media for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists media_delete on guide.media;
create policy media_delete on guide.media for delete to authenticated using ((select guide.is_admin()));

drop policy if exists content_media_refs_select on guide.content_media_refs;
create policy content_media_refs_select on guide.content_media_refs
  for select to authenticated using ((select guide.is_admin()));
