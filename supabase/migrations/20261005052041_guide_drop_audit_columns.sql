-- F2.10 · Corrección H5 de leona-lia: anon/authenticated no deben leer auth.uid del admin.
-- Se eliminan las columnas de auditoría por fila (created_by, updated_by, author_id, moderated_by, approved_by).
-- El "quién" queda en guide.activity_log (solo admin). Tablas vacías: sin pérdida de datos.
-- Re-ejecutable: drop column if exists, create or replace.

drop view if exists guide.media_library;

alter table guide.media              drop column if exists created_by, drop column if exists updated_by;
alter table guide.site_settings      drop column if exists updated_by;
alter table guide.article_categories drop column if exists created_by, drop column if exists updated_by;
alter table guide.articles           drop column if exists author_id, drop column if exists created_by, drop column if exists updated_by;
alter table guide.pages              drop column if exists created_by, drop column if exists updated_by;
alter table guide.items              drop column if exists created_by, drop column if exists updated_by;
alter table guide.author_reviews     drop column if exists created_by, drop column if exists updated_by;
alter table guide.events             drop column if exists created_by, drop column if exists updated_by, drop column if exists approved_by;
alter table guide.user_reviews       drop column if exists moderated_by;

create view guide.media_library with (security_invoker = true) as
select m.id, m.storage_path, m.version, m.original_filename, m.mime_type, m.size_bytes, m.width, m.height,
  m.alt_es, m.alt_en, m.caption_es, m.caption_en, m.credit, m.has_en, m.created_at, m.updated_at,
  (select count(*) from guide.media_usage u where u.media_id = m.id)::integer as usage_count
from guide.media m
where (select guide.is_admin());
grant select on guide.media_library to authenticated, service_role;

create or replace function guide.moderate_user_review(p_id uuid, p_status guide.review_status)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.user_reviews
  set status = p_status, moderated_at = now()
  where id = p_id;
end;
$$;

create or replace function guide.approve_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.events
  set status = 'approved', approved_at = now()
  where id = p_id;
end;
$$;

create or replace function guide.reject_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.events
  set status = 'rejected', approved_at = null
  where id = p_id;
end;
$$;

-- Verificación: ninguna función ejecutable por PUBLIC; reglas de §F2.9 + H5.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as fn from pg_proc p where p.pronamespace = 'guide'::regnamespace loop
    execute format('revoke execute on function %s from public', r.fn);
  end loop;
end $$;

do $$
declare
  v_bad text;
begin
  select string_agg(c.relname, ', ') into v_bad
  from pg_class c
  where c.relnamespace = 'guide'::regnamespace and c.relkind = 'r'
    and (not c.relrowsecurity or not exists (select 1 from pg_policy p where p.polrelid = c.oid));
  if v_bad is not null then raise exception 'Tablas sin RLS o sin policies: %', v_bad; end if;

  select string_agg(table_name || '.' || column_name, ', ') into v_bad
  from information_schema.columns
  where table_schema = 'guide'
    and column_name in ('created_by', 'updated_by', 'author_id', 'moderated_by', 'approved_by');
  if v_bad is not null then raise exception 'Quedan columnas de auditoría: %', v_bad; end if;

  -- user_id solo legible por anon/authenticated donde la RLS lo limita a la propia fila
  select string_agg(distinct table_name, ', ') into v_bad
  from information_schema.column_privileges
  where table_schema = 'guide' and grantee in ('anon', 'authenticated') and privilege_type = 'SELECT'
    and column_name = 'user_id' and table_name in ('user_reviews');
  if v_bad is not null then raise exception 'user_id legible en: %', v_bad; end if;

  select string_agg(distinct table_name, ', ') into v_bad
  from information_schema.role_table_grants
  where table_schema = 'guide' and grantee = 'anon'
    and (privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
         or table_name in ('admins', 'activity_log', 'content_media_refs', 'subscribers', 'subscriber_consent_events',
                           'gym_waitlist', 'user_profiles', 'media_usage', 'media_library', 'export_articles',
                           'export_items', 'export_user_reviews', 'export_subscribers', 'export_events'));
  if v_bad is not null then raise exception 'anon con privilegios indebidos en: %', v_bad; end if;

  select string_agg(c.relname, ', ') into v_bad
  from pg_class c
  where c.relnamespace = 'guide'::regnamespace and c.relkind = 'v'
    and not coalesce(c.reloptions @> array['security_invoker=true'], false);
  if v_bad is not null then raise exception 'Vistas sin security_invoker: %', v_bad; end if;

  select string_agg(p.proname, ', ') into v_bad
  from pg_proc p
  where p.pronamespace = 'guide'::regnamespace
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%');
  if v_bad is not null then raise exception 'Funciones sin search_path: %', v_bad; end if;
end $$;
