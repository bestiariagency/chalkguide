-- F6.13 (D34) · Páginas, parte 2: versiones publicadas de las legales (guide.page_versions).
-- Una fila por idioma en cada publicación de una legal que fija su texto (primera publicación, o publish_draft que
-- cambia título/cuerpo o la fecha). Prueba de qué decía la política cuando alguien dio su consentimiento.
-- Solo admin lee; nadie escribe salvo el trigger (DEFINER); inmutable. Sin FK a pages: la clave es cerrada e
-- inmutable y la copia debe sobrevivir a cualquier mantenimiento de la fila. Idempotente.

create table if not exists guide.page_versions (
  id           uuid primary key default gen_random_uuid(),
  key          text not null check (key in ('legal_notice', 'privacy', 'cookies')),
  locale       guide.locale not null,
  title        text not null,
  body_html    text not null,
  revised_on   date not null,
  published_at timestamptz not null default now(),
  published_by uuid
);
comment on table guide.page_versions is
  'Copia fechada de cada publicación de una página legal (D34). Inmutable; la escribe solo guide.pages_record_version.';
comment on column guide.page_versions.published_by is 'auth.uid() del admin que publicó (null en mantenimiento). Sin FK, como activity_log.actor_id.';

create index if not exists page_versions_key_published_idx on guide.page_versions (key, published_at desc);

alter table guide.page_versions enable row level security;

drop policy if exists page_versions_select on guide.page_versions;
create policy page_versions_select on guide.page_versions
  for select to authenticated
  using ((select guide.is_admin()));

revoke all on guide.page_versions from public, anon, authenticated, service_role;
grant select on guide.page_versions to authenticated;

-- Inmutable para todos (también postgres): un cambio exige desactivar el trigger a propósito.
create or replace function guide.page_versions_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'page versions are immutable' using errcode = '42501';
end;
$$;

drop trigger if exists page_versions_immutable on guide.page_versions;
create trigger page_versions_immutable
  before update or delete on guide.page_versions
  for each row execute function guide.page_versions_immutable();

drop trigger if exists page_versions_no_truncate on guide.page_versions;
create trigger page_versions_no_truncate
  before truncate on guide.page_versions
  for each statement execute function guide.page_versions_immutable();

-- DEFINER: el admin no tiene INSERT en page_versions. Solo copia columnas de la fila ya validada (NEW, AFTER).
create or replace function guide.pages_record_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.key not in ('legal_notice', 'privacy', 'cookies') or not new.published then
    return null;
  end if;
  if tg_op = 'UPDATE' and old.published
     and (new.title_es, new.title_en, new.body_html_es, new.body_html_en, new.revised_on)
         is not distinct from (old.title_es, old.title_en, old.body_html_es, old.body_html_en, old.revised_on) then
    return null;
  end if;

  insert into guide.page_versions (key, locale, title, body_html, revised_on, published_by)
  values (new.key, 'es', new.title_es, new.body_html_es, new.revised_on, (select auth.uid()));
  if new.has_en then
    insert into guide.page_versions (key, locale, title, body_html, revised_on, published_by)
    values (new.key, 'en', new.title_en, new.body_html_en, new.revised_on, (select auth.uid()));
  end if;
  return null;
end;
$$;

revoke all on function guide.pages_record_version() from public, anon, authenticated, service_role;
revoke all on function guide.page_versions_immutable() from public, anon, authenticated, service_role;

drop trigger if exists pages_record_version on guide.pages;
create trigger pages_record_version
  after insert or update on guide.pages
  for each row execute function guide.pages_record_version();
