-- F2.4 · Contenido editorial: ajustes del sitio, categorías del blog (= 6 pilares), artículos y páginas.

-- ───────────── site_settings (singleton) ─────────────
create table if not exists guide.site_settings (
  id                            smallint primary key default 1 check (id = 1),
  site_name                     text not null default 'Chalk Guide' check (char_length(site_name) between 1 and 80),
  tagline_es                    text check (char_length(tagline_es) <= 200),
  tagline_en                    text check (char_length(tagline_en) <= 200),
  default_seo_title_es          text check (char_length(default_seo_title_es) <= 70),
  default_seo_title_en          text check (char_length(default_seo_title_en) <= 70),
  default_seo_description_es    text check (char_length(default_seo_description_es) <= 160),
  default_seo_description_en    text check (char_length(default_seo_description_en) <= 160),
  default_og_media_id           uuid references guide.media (id) on delete restrict,
  social_links                  jsonb not null default '{}'::jsonb check (jsonb_typeof(social_links) = 'object'),
  contact_email                 text check (contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  footer_text_es                text,
  footer_text_en                text,
  newsletter_title_es           text,
  newsletter_title_en           text,
  newsletter_body_es            text,
  newsletter_body_en            text,
  -- Texto provisional: lo redacta loro-lola y lo valida Xavi antes de lanzar.
  newsletter_consent_text_es    text not null default 'Quiero recibir novedades de Chalk Guide por email. Puedo darme de baja cuando quiera.',
  newsletter_consent_text_en    text,
  consent_version               integer not null default 1 check (consent_version >= 1),
  user_reviews_premoderation    boolean not null default false,
  min_user_reviews_for_average  smallint not null default 3 check (min_user_reviews_for_average between 1 and 50),
  updated_at                    timestamptz not null default now(),
  updated_by                    uuid references auth.users (id) on delete set null
);
alter table guide.site_settings enable row level security;
create index if not exists site_settings_default_og_media_id_idx on guide.site_settings (default_og_media_id);
insert into guide.site_settings (id) values (1) on conflict (id) do nothing;

drop trigger if exists site_settings_set_updated_at on guide.site_settings;
create trigger site_settings_set_updated_at before update on guide.site_settings
  for each row execute function guide.set_updated_at();
drop trigger if exists site_settings_log_activity on guide.site_settings;
create trigger site_settings_log_activity after update on guide.site_settings
  for each row execute function guide.log_activity('id', 'site_name', 'false');

-- ───────────── article_categories ─────────────
create table if not exists guide.article_categories (
  id             uuid primary key default gen_random_uuid(),
  name_es        text not null check (char_length(name_es) between 1 and 80),
  name_en        text check (char_length(name_en) between 1 and 80),
  slug_es        guide.slug not null unique,
  slug_en        guide.slug unique,
  description_es text check (char_length(description_es) <= 300),
  description_en text check (char_length(description_en) <= 300),
  color          text check (color ~ '^#[0-9a-fA-F]{6}$'),
  icon           text check (char_length(icon) <= 60),
  sort_order     integer not null default 0,
  has_en         boolean generated always as (name_en is not null and slug_en is not null) stored,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by     uuid references auth.users (id) on delete set null,
  constraint article_categories_en_coherent check ((name_en is null) = (slug_en is null))
);
alter table guide.article_categories enable row level security;
create index if not exists article_categories_sort_order_idx on guide.article_categories (sort_order);

drop trigger if exists article_categories_set_updated_at on guide.article_categories;
create trigger article_categories_set_updated_at before update on guide.article_categories
  for each row execute function guide.set_updated_at();
drop trigger if exists article_categories_log_activity on guide.article_categories;
create trigger article_categories_log_activity after insert or update or delete on guide.article_categories
  for each row execute function guide.log_activity('id', 'name_es', 'true');

-- ───────────── articles ─────────────
create table if not exists guide.articles (
  id                 uuid primary key default gen_random_uuid(),
  category_id        uuid not null references guide.article_categories (id) on delete restrict,
  status             guide.article_status not null default 'draft',
  published_at       timestamptz,
  title_es           text not null check (char_length(title_es) between 1 and 200),
  title_en           text check (char_length(title_en) between 1 and 200),
  slug_es            guide.slug not null unique,
  slug_en            guide.slug unique,
  excerpt_es         text check (char_length(excerpt_es) <= 300),
  excerpt_en         text check (char_length(excerpt_en) <= 300),
  body_json_es       jsonb not null default '{"type":"doc","content":[]}'::jsonb,
  body_html_es       text not null default '',
  body_json_en       jsonb,
  body_html_en       text,
  cover_media_id     uuid references guide.media (id) on delete restrict,
  is_featured        boolean not null default false,
  sort_order         integer not null default 0,
  reading_minutes_es smallint,
  reading_minutes_en smallint,
  author_id          uuid default auth.uid() references auth.users (id) on delete set null,
  seo_title_es       text check (char_length(seo_title_es) <= 70),
  seo_title_en       text check (char_length(seo_title_en) <= 70),
  seo_description_es text check (char_length(seo_description_es) <= 160),
  seo_description_en text check (char_length(seo_description_en) <= 160),
  og_media_id        uuid references guide.media (id) on delete restrict,
  noindex            boolean not null default false,
  canonical_url      text check (canonical_url ~ '^https?://'),
  has_en             boolean generated always as (
                       title_en is not null and slug_en is not null
                       and body_html_en is not null and body_html_en <> ''
                     ) stored,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by         uuid references auth.users (id) on delete set null,
  constraint articles_published_at_required check (status = 'draft' or published_at is not null),
  constraint articles_en_coherent check ((title_en is null) = (slug_en is null)),
  constraint articles_body_en_coherent check ((body_json_en is null) = (body_html_en is null))
);
alter table guide.articles enable row level security;
create index if not exists articles_category_sort_idx on guide.articles (category_id, sort_order);
create index if not exists articles_status_published_at_idx on guide.articles (status, published_at desc);
create index if not exists articles_featured_idx on guide.articles (published_at desc) where is_featured;
create index if not exists articles_cover_media_id_idx on guide.articles (cover_media_id);
create index if not exists articles_og_media_id_idx on guide.articles (og_media_id);

-- Visibilidad pública por tiempo: un programado es público en cuanto llega su hora, sin cron.
create or replace function guide.article_is_live(p_status guide.article_status, p_published_at timestamptz)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_status in ('scheduled', 'published') and p_published_at is not null and p_published_at <= now();
$$;
revoke execute on function guide.article_is_live(guide.article_status, timestamptz) from public;
grant execute on function guide.article_is_live(guide.article_status, timestamptz) to anon, authenticated, service_role;

create or replace function guide.articles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_words integer;
begin
  -- Publicación
  if new.status = 'published' and new.published_at is null then
    new.published_at := now();
  elsif new.status = 'scheduled' then
    if new.published_at is null then
      raise exception 'scheduled articles need published_at' using errcode = '23514';
    end if;
    if new.published_at <= now() then
      if tg_op = 'INSERT' or old.status is distinct from 'scheduled'
         or old.published_at is distinct from new.published_at then
        raise exception 'scheduled date must be in the future' using errcode = '23514';
      end if;
      -- Programado ya vencido que se edita: se normaliza a publicado.
      new.status := 'published';
    end if;
  end if;

  -- Tiempo de lectura (200 palabras/min)
  if tg_op = 'INSERT' or new.body_html_es is distinct from old.body_html_es then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_es := case when btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  if tg_op = 'INSERT' or new.body_html_en is distinct from old.body_html_en then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_en := case when btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  return new;
end;
$$;
revoke execute on function guide.articles_before_write() from public;

drop trigger if exists articles_before_write on guide.articles;
create trigger articles_before_write before insert or update on guide.articles
  for each row execute function guide.articles_before_write();
drop trigger if exists articles_set_updated_at on guide.articles;
create trigger articles_set_updated_at before update on guide.articles
  for each row execute function guide.set_updated_at();
drop trigger if exists articles_sync_media_refs on guide.articles;
create trigger articles_sync_media_refs
  after insert or delete or update of body_json_es, body_json_en on guide.articles
  for each row execute function guide.sync_content_media_refs();
drop trigger if exists articles_log_activity on guide.articles;
create trigger articles_log_activity after insert or update or delete on guide.articles
  for each row execute function guide.log_activity('id', 'title_es', 'true');

-- ───────────── pages ─────────────
create table if not exists guide.pages (
  id                 uuid primary key default gen_random_uuid(),
  key                text not null unique check (key ~ '^[a-z][a-z_]*$' and char_length(key) <= 40),
  title_es           text not null check (char_length(title_es) between 1 and 200),
  title_en           text check (char_length(title_en) between 1 and 200),
  slug_es            guide.slug not null unique,
  slug_en            guide.slug unique,
  body_json_es       jsonb not null default '{"type":"doc","content":[]}'::jsonb,
  body_html_es       text not null default '',
  body_json_en       jsonb,
  body_html_en       text,
  published          boolean not null default false,
  seo_title_es       text check (char_length(seo_title_es) <= 70),
  seo_title_en       text check (char_length(seo_title_en) <= 70),
  seo_description_es text check (char_length(seo_description_es) <= 160),
  seo_description_en text check (char_length(seo_description_en) <= 160),
  og_media_id        uuid references guide.media (id) on delete restrict,
  noindex            boolean not null default false,
  has_en             boolean generated always as (
                       title_en is not null and slug_en is not null
                       and body_html_en is not null and body_html_en <> ''
                     ) stored,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by         uuid references auth.users (id) on delete set null,
  constraint pages_en_coherent check ((title_en is null) = (slug_en is null)),
  constraint pages_body_en_coherent check ((body_json_en is null) = (body_html_en is null))
);
alter table guide.pages enable row level security;
create index if not exists pages_og_media_id_idx on guide.pages (og_media_id);

drop trigger if exists pages_set_updated_at on guide.pages;
create trigger pages_set_updated_at before update on guide.pages
  for each row execute function guide.set_updated_at();
drop trigger if exists pages_sync_media_refs on guide.pages;
create trigger pages_sync_media_refs
  after insert or delete or update of body_json_es, body_json_en on guide.pages
  for each row execute function guide.sync_content_media_refs();
drop trigger if exists pages_log_activity on guide.pages;
create trigger pages_log_activity after insert or update or delete on guide.pages
  for each row execute function guide.log_activity('id', 'title_es', 'true');

-- ───────────── Grants ─────────────
grant select on guide.site_settings, guide.article_categories, guide.articles, guide.pages to anon, authenticated;
grant update on guide.site_settings to authenticated;
grant insert, update, delete on guide.article_categories, guide.articles, guide.pages to authenticated;
grant all on guide.site_settings, guide.article_categories, guide.articles, guide.pages to service_role;

-- ───────────── Policies ─────────────
drop policy if exists site_settings_select on guide.site_settings;
create policy site_settings_select on guide.site_settings for select to anon, authenticated using (true);
drop policy if exists site_settings_update on guide.site_settings;
create policy site_settings_update on guide.site_settings for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));

drop policy if exists article_categories_select on guide.article_categories;
create policy article_categories_select on guide.article_categories for select to anon, authenticated using (true);

drop policy if exists articles_select on guide.articles;
create policy articles_select on guide.articles for select to anon, authenticated
  using (guide.article_is_live(status, published_at) or (select guide.is_admin()));

drop policy if exists pages_select on guide.pages;
create policy pages_select on guide.pages for select to anon, authenticated
  using (published or (select guide.is_admin()));

-- Escritura solo admin (insert/update/delete) en tablas editoriales.
do $$
declare t text;
begin
  foreach t in array array['article_categories', 'articles', 'pages'] loop
    execute format('drop policy if exists %I on guide.%I', t || '_insert', t);
    execute format('create policy %I on guide.%I for insert to authenticated with check ((select guide.is_admin()))', t || '_insert', t);
    execute format('drop policy if exists %I on guide.%I', t || '_update', t);
    execute format('create policy %I on guide.%I for update to authenticated using ((select guide.is_admin())) with check ((select guide.is_admin()))', t || '_update', t);
    execute format('drop policy if exists %I on guide.%I', t || '_delete', t);
    execute format('create policy %I on guide.%I for delete to authenticated using ((select guide.is_admin()))', t || '_delete', t);
  end loop;
end $$;
