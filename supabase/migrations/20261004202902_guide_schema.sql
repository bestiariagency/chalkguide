-- F2.2 · Schema guide: schema, grants base, enums, dominio slug y trigger updated_at.
-- Idempotente. No toca el schema public.

create schema if not exists guide;

revoke all on schema guide from public;
grant usage on schema guide to anon, authenticated, service_role;

-- Enums (máquinas de estado cerradas)
do $$ begin create type guide.locale as enum ('es', 'en'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.article_status as enum ('draft', 'scheduled', 'published'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.review_status as enum ('pending', 'visible', 'hidden'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.visit_type as enum ('paid', 'invited'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.event_status as enum ('draft', 'approved', 'rejected'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.event_source as enum ('manual', 'agent'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.subscriber_status as enum ('pending', 'active', 'unsubscribed', 'bounced'); exception when duplicate_object then null; end $$;
do $$ begin create type guide.activity_action as enum ('insert', 'update', 'delete'); exception when duplicate_object then null; end $$;

-- Slug de URL: minúsculas, números y guiones simples; máx. 120.
do $$ begin
  create domain guide.slug as text
    check (char_length(value) between 1 and 120 and value ~ '^[a-z0-9]+(-[a-z0-9]+)*$');
exception when duplicate_object then null; end $$;

-- updated_at (y updated_by si la tabla lo tiene) en cada UPDATE.
-- jsonb_populate_record ignora claves que la tabla no tenga: un único trigger para todas.
create or replace function guide.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new := jsonb_populate_record(
    new,
    jsonb_build_object('updated_at', now(), 'updated_by', (select auth.uid()))
  );
  return new;
end;
$$;

revoke execute on function guide.set_updated_at() from public;
