-- F8 (8.5) · Modelo de noticias, ingesta y newsletter semanal (D70–D81; docs/security/F8.1-ingest-spec.md).
-- Tablas: news_categories (seed 8, docs/copy/f8/categorias-noticias.md), news_sources (vacía, D81), news,
-- news_links (≤ 3 relaciones), ingest_tokens, ingest_runs, ingest_config (ventana R1), newsletter_issues,
-- newsletter_issue_items. RLS en todas; grants por columna (J27, J28). CHECK puros (J37). Idempotente.
-- Las guardas, el registro y las RPC van en las migraciones siguientes de F8.

create extension if not exists pg_trgm with schema extensions;

-- ───────────── 1. Enums ─────────────
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'news_status') then
    create type guide.news_status as enum ('draft', 'published', 'rejected');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'news_scope') then
    create type guide.news_scope as enum ('cat', 'es', 'intl');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'ingest_kind') then
    create type guide.ingest_kind as enum ('events', 'news', 'both');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'ingest_run_status') then
    create type guide.ingest_run_status as enum ('open', 'ok', 'error', 'abandoned', 'revoked');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'newsletter_status') then
    create type guide.newsletter_status as enum ('draft', 'scheduled', 'sending', 'sent', 'cancelled', 'failed');
  end if;
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'newsletter_item_kind') then
    create type guide.newsletter_item_kind as enum ('article', 'news', 'event');
  end if;
end $$;

-- ───────────── 2. Categorías de noticias ─────────────
create table if not exists guide.news_categories (
  id             uuid primary key default gen_random_uuid(),
  key            text not null unique check (key ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(key) <= 40),
  label_es       text not null check (char_length(label_es) between 1 and 40 and label_es !~ '[[:cntrl:]]'),
  label_en       text not null check (char_length(label_en) between 1 and 40 and label_en !~ '[[:cntrl:]]'),
  description_es text check (char_length(description_es) <= 160 and description_es !~ '[[:cntrl:]]'),
  description_en text check (char_length(description_en) <= 160 and description_en !~ '[[:cntrl:]]'),
  sort_order     integer not null default 0,
  active         boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
alter table guide.news_categories enable row level security;
revoke all on guide.news_categories from public, anon, authenticated, service_role;
grant select (id, key, label_es, label_en, description_es, description_en, sort_order, active, updated_at)
  on guide.news_categories to anon, authenticated;
grant insert (key, label_es, label_en, description_es, description_en, sort_order, active),
      update (key, label_es, label_en, description_es, description_en, sort_order, active),
      delete on guide.news_categories to authenticated;
drop policy if exists news_categories_select on guide.news_categories;
create policy news_categories_select on guide.news_categories for select to anon, authenticated
  using (active or (select guide.is_admin()));
drop policy if exists news_categories_insert on guide.news_categories;
create policy news_categories_insert on guide.news_categories for insert to authenticated
  with check ((select guide.is_admin()));
drop policy if exists news_categories_update on guide.news_categories;
create policy news_categories_update on guide.news_categories for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists news_categories_delete on guide.news_categories;
create policy news_categories_delete on guide.news_categories for delete to authenticated
  using ((select guide.is_admin()));

insert into guide.news_categories (key, label_es, label_en, description_es, description_en, sort_order) values
  ('competicion', 'Competición', 'Competition',
   'Copas, campeonatos y resultados de escalada deportiva.', 'Cups, championships and results from competition climbing.', 1),
  ('roca-vias', 'Roca y vías', 'Rock and routes',
   'Aperturas, ascensiones destacadas y nuevas zonas de escalada.', 'New routes, notable ascents and newly developed crags.', 2),
  ('material', 'Material', 'Gear',
   'Novedades, retiradas y avisos sobre equipo de escalada.', 'Releases, recalls and notices about climbing gear.', 3),
  ('rocodromos', 'Rocódromos', 'Climbing gyms',
   'Aperturas, cierres, cambios de tarifas y novedades en salas.', 'Openings, closures, price changes and news from gyms.', 4),
  ('seguridad', 'Seguridad', 'Safety',
   'Accidentes explicados con rigor, avisos y buenas prácticas.', 'Carefully reported incidents, warnings and good practice.', 5),
  ('acceso-entorno', 'Accesos y entorno', 'Access and environment',
   'Restricciones, nidificación, cierres temporales y cuidado de la roca.', 'Restrictions, nesting closures, temporary bans and crag care.', 6),
  ('federaciones', 'Federaciones y clubes', 'Federations and clubs',
   'Noticias de la FEEC, la FEDME, clubes y normativa deportiva.', 'News from the FEEC, FEDME, clubs and sport regulations.', 7),
  ('comunidad', 'Comunidad', 'Community',
   'Festivales, cine de montaña, iniciativas y gente de la escalada.', 'Festivals, mountain film, initiatives and people in climbing.', 8)
on conflict (key) do nothing;

-- ───────────── 3. Fuentes (allowlist J24; vacía hasta verificar URLs, D81) ─────────────
create table if not exists guide.news_sources (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 1 and 120 and name !~ '[[:cntrl:]]'),
  -- Dominio registrable en minúsculas, sin esquema, puerto ni ruta (subdominios aceptados en J24).
  domain       text not null unique check (
                 char_length(domain) <= 253
                 and domain ~ '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$'
                 and domain !~ '(^|\.)(local|internal|localhost)$'),
  url          text not null check (
                 char_length(url) <= 1000 and url ~ '^https://[^[:space:]/?#"<>\\@:]+([/?#][^[:space:]"<>\\]*)?$'),
  kind         guide.ingest_kind not null default 'news',
  scope        guide.news_scope not null default 'es',
  lang         text check (lang in ('es', 'ca', 'en', 'fr', 'it', 'de', 'other')),
  instructions text check (char_length(instructions) <= 280
                           and instructions !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  -- SEO (D79): enlace editorial sin nofollow solo si la fuente es de confianza.
  trusted      boolean not null default false,
  active       boolean not null default true,
  last_seen_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table guide.news_sources enable row level security;
revoke all on guide.news_sources from public, anon, authenticated, service_role;
-- Público: solo lo que el sitio necesita para citar (nombre, dominio, rel según trusted) de fuentes con noticias
-- publicadas. El admin lee el resto (instrucciones, tasa de aprobación) con admin_list_news_sources.
grant select (id, name, domain, trusted) on guide.news_sources to anon, authenticated;
grant insert (name, domain, url, kind, scope, lang, instructions, trusted, active),
      update (name, domain, url, kind, scope, lang, instructions, trusted, active),
      delete on guide.news_sources to authenticated;

-- ───────────── 4. Tokens y runs de la ingesta (J1–J7, J28) ─────────────
create table if not exists guide.ingest_tokens (
  id           uuid primary key default gen_random_uuid(),
  token_hash   bytea not null unique check (octet_length(token_hash) = 32),
  hint         text not null check (hint ~ '^[0-9a-f]{4}$'),
  label        text not null check (char_length(label) between 1 and 60 and label !~ '[[:cntrl:]]'),
  created_at   timestamptz not null default now(),
  created_by   uuid references auth.users(id) on delete set null,
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  revoked_by   uuid references auth.users(id) on delete set null,
  last_used_at timestamptz,
  constraint ingest_tokens_expiry check (expires_at > created_at and expires_at <= created_at + interval '30 days'),
  constraint ingest_tokens_revoked check ((revoked_by is null) or (revoked_at is not null))
);
alter table guide.ingest_tokens enable row level security;
-- J28: sin grants para la API; el admin lo ve por admin_list_ingest_tokens (sin token_hash).
revoke all on guide.ingest_tokens from public, anon, authenticated, service_role;

create table if not exists guide.ingest_runs (
  id                 uuid primary key default gen_random_uuid(),
  token_id           uuid not null references guide.ingest_tokens(id) on delete restrict,
  kind               guide.ingest_kind not null,
  dry_run            boolean not null,
  status             guide.ingest_run_status not null default 'open',
  outside_window     boolean not null default false,
  started_at         timestamptz not null default now(),
  finished_at        timestamptz,
  calls              integer not null default 0 check (calls between 0 and 80),
  inserted           integer not null default 0 check (inserted between 0 and 40),
  inserted_events    integer not null default 0 check (inserted_events >= 0),
  inserted_news      integer not null default 0 check (inserted_news >= 0),
  would_insert       integer not null default 0 check (would_insert >= 0),
  duplicates         integer not null default 0 check (duplicates >= 0),
  duplicate_rejected integer not null default 0 check (duplicate_rejected >= 0),
  invalid            jsonb not null default '{}'::jsonb check (jsonb_typeof(invalid) = 'object' and octet_length(invalid::text) <= 1000),
  newsletter_intro   boolean not null default false,
  stats              jsonb check (stats is null or (jsonb_typeof(stats) = 'object' and octet_length(stats::text) <= 4096)),
  errors             text check (errors is null or (octet_length(errors) <= 4096
                                 and errors !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]')),
  constraint ingest_runs_finished check ((status = 'open') = (finished_at is null)),
  constraint ingest_runs_inserted_split check (inserted = inserted_events + inserted_news),
  constraint ingest_runs_dry_no_insert check (not dry_run or inserted = 0)
);
-- J30: un único run abierto en total (no por token).
create unique index if not exists ingest_runs_one_open on guide.ingest_runs ((true)) where status = 'open';
create index if not exists ingest_runs_started_idx on guide.ingest_runs (started_at desc);
create index if not exists ingest_runs_token_idx on guide.ingest_runs (token_id);
alter table guide.ingest_runs enable row level security;
revoke all on guide.ingest_runs from public, anon, authenticated, service_role;
grant select on guide.ingest_runs to authenticated;
drop policy if exists ingest_runs_select on guide.ingest_runs;
create policy ingest_runs_select on guide.ingest_runs for select to authenticated using ((select guide.is_admin()));

-- R1: ventana «abrir 2 h» para pruebas fuera de lun/jue 03:00–12:00 (Madrid). Fila única.
create table if not exists guide.ingest_config (
  id                boolean primary key default true check (id),
  window_open_until timestamptz,
  updated_at        timestamptz not null default now(),
  updated_by        uuid references auth.users(id) on delete set null
);
insert into guide.ingest_config (id) values (true) on conflict (id) do nothing;
alter table guide.ingest_config enable row level security;
revoke all on guide.ingest_config from public, anon, authenticated, service_role;
grant select on guide.ingest_config to authenticated;
drop policy if exists ingest_config_select on guide.ingest_config;
create policy ingest_config_select on guide.ingest_config for select to authenticated using ((select guide.is_admin()));

-- ───────────── 5. Noticias ─────────────
create table if not exists guide.news (
  id                  uuid primary key default gen_random_uuid(),
  slug                text not null unique check (char_length(slug) between 3 and 120 and slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  status              guide.news_status not null default 'draft',
  source              guide.event_source not null default 'manual',
  title_es            text not null check (char_length(title_es) between 1 and 200 and title_es !~ '[[:cntrl:]]'),
  title_en            text check (char_length(title_en) between 1 and 200 and title_en !~ '[[:cntrl:]]'),
  summary_es          text not null check (char_length(summary_es) between 1 and 1200
                                           and summary_es !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  summary_en          text check (char_length(summary_en) between 1 and 1200
                                  and summary_en !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  -- «Nota de Xavi» (D73/D79): solo el admin la escribe (J21).
  author_note_es      text check (char_length(author_note_es) between 1 and 1200
                                  and author_note_es !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  author_note_en      text check (char_length(author_note_en) between 1 and 1200
                                  and author_note_en !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  category_id         uuid not null references guide.news_categories(id) on delete restrict,
  scope               guide.news_scope not null default 'es',
  tags                text[] not null default '{}' check (cardinality(tags) <= 10
                                                          and octet_length(array_to_string(tags, ',')) <= 400
                                                          and array_to_string(tags, ',') !~ '[[:cntrl:]]'),
  source_name         text not null check (char_length(source_name) between 1 and 120 and source_name !~ '[[:cntrl:]]'),
  source_url          text not null check (char_length(source_url) <= 1000
                                           and source_url ~ '^https://[^[:space:]/?#"<>\\@:]+([/?#][^[:space:]"<>\\]*)?$'),
  source_title        text check (char_length(source_title) between 1 and 300 and source_title !~ '[[:cntrl:]]'),
  source_published_on date,
  source_lang         text check (source_lang in ('es', 'ca', 'en', 'fr', 'it', 'de', 'other')),
  source_id           uuid references guide.news_sources(id) on delete restrict,
  media_id            uuid references guide.media(id) on delete restrict,
  image_license       text check (image_license in ('own', 'permission', 'cc-by-4.0', 'cc-by-sa-4.0', 'cc0')),
  image_credit        text check (char_length(image_credit) between 1 and 200 and image_credit !~ '[[:cntrl:]]'),
  run_id              uuid references guide.ingest_runs(id) on delete set null,
  dedupe_key          text unique check (char_length(dedupe_key) <= 200),
  url_key             text check (char_length(url_key) <= 200),
  agent_meta          jsonb,
  similarity          real check (similarity between 0 and 1),
  reject_reason       text,
  approved_by         uuid references auth.users(id) on delete set null,
  published_at        timestamptz,
  first_published_at  timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  has_en              boolean generated always as (title_en is not null and summary_en is not null) stored,
  -- D79: la ficha es indexable solo con «Nota de Xavi» de ≥ 60 palabras (sitemap, robots y UI leen lo mismo).
  indexable           boolean generated always as (
                        author_note_es is not null
                        and coalesce(array_length(regexp_split_to_array(btrim(author_note_es), '\s+'), 1), 0) >= 60) stored,
  indexable_en        boolean generated always as (
                        title_en is not null and summary_en is not null and author_note_en is not null
                        and coalesce(array_length(regexp_split_to_array(btrim(author_note_en), '\s+'), 1), 0) >= 60) stored,
  search_es           tsvector generated always as (
                        setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(title_es, '')), 'A')
                        || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(summary_es, '')), 'B')
                        || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(author_note_es, '')), 'C')
                        || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(source_name, '')), 'D')) stored,
  search_en           tsvector generated always as (
                        setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(title_en, '')), 'A')
                        || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(summary_en, '')), 'B')
                        || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(author_note_en, '')), 'C')
                        || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(source_name, '')), 'D')) stored,
  constraint news_published_at check ((status = 'published') = (published_at is not null)),
  constraint news_first_published check (published_at is null or first_published_at is not null),
  constraint news_agent_dedupe check (source <> 'agent' or (dedupe_key is not null and url_key is not null)),
  constraint news_agent_meta_only_agent check ((source = 'agent') = (agent_meta is not null)),
  constraint news_agent_meta_shape check (
    agent_meta is null or (
      jsonb_typeof(agent_meta) = 'object'
      and octet_length(agent_meta::text) <= 4000
      and (agent_meta - array['confidence', 'note', 'excerpt', 'found_at', 'inferred', 'duplicate_of']) = '{}'::jsonb
      and case when jsonb_typeof(agent_meta -> 'confidence') = 'number'
               then (agent_meta ->> 'confidence')::numeric between 0 and 1 else false end
      and (not agent_meta ? 'note' or (jsonb_typeof(agent_meta -> 'note') = 'string' and char_length(agent_meta ->> 'note') <= 500))
      and (not agent_meta ? 'excerpt' or (jsonb_typeof(agent_meta -> 'excerpt') = 'string' and char_length(agent_meta ->> 'excerpt') <= 1000))
      and (not agent_meta ? 'found_at' or (jsonb_typeof(agent_meta -> 'found_at') = 'string'
                                           and (agent_meta ->> 'found_at') ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}'))
      and (not agent_meta ? 'inferred' or (jsonb_typeof(agent_meta -> 'inferred') = 'array'
                                           and jsonb_array_length(agent_meta -> 'inferred') <= 10
                                           and (agent_meta -> 'inferred') <@ '["title_en","summary_en","category","published_on","source_name"]'::jsonb))
      and (not agent_meta ? 'duplicate_of' or jsonb_typeof(agent_meta -> 'duplicate_of') = 'null'
           or (jsonb_typeof(agent_meta -> 'duplicate_of') = 'string'
               and (agent_meta ->> 'duplicate_of') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')))),
  constraint news_reject_reason_valid check (
    reject_reason is null
    or (status = 'rejected' and reject_reason in ('duplicate', 'not_climbing', 'outside_area', 'not_relevant',
                                                   'wrong_data', 'unreliable_source'))),
  constraint news_image_rights check (media_id is null or (image_license is not null and image_credit is not null))
);
create index if not exists news_status_published_idx on guide.news (status, published_at desc);
create index if not exists news_category_idx on guide.news (category_id);
create index if not exists news_source_id_idx on guide.news (source_id);
create index if not exists news_run_id_idx on guide.news (run_id);
create index if not exists news_media_id_idx on guide.news (media_id);
create index if not exists news_url_key_idx on guide.news (url_key);
create index if not exists news_search_es_idx on guide.news using gin (search_es);
create index if not exists news_search_en_idx on guide.news using gin (search_en);

alter table guide.news enable row level security;
revoke all on guide.news from public, anon, authenticated, service_role;
-- J27: columnas públicas; fuera dedupe_key, url_key, agent_meta, run_id, source, reject_reason, approved_by,
-- similarity, tags (internas en v1) y created_at. El admin lee todo por admin_list_news (DEFINER).
grant select (id, slug, status, title_es, title_en, summary_es, summary_en, author_note_es, author_note_en,
              category_id, scope, source_name, source_url, source_title, source_published_on, source_lang, source_id,
              media_id, image_license, image_credit, published_at, first_published_at, updated_at,
              has_en, indexable, indexable_en, search_es, search_en)
  on guide.news to anon, authenticated;
grant insert (slug, status, title_es, title_en, summary_es, summary_en, author_note_es, author_note_en, category_id,
              scope, tags, source_name, source_url, source_title, source_published_on, source_lang, source_id,
              media_id, image_license, image_credit, reject_reason),
      update (slug, status, title_es, title_en, summary_es, summary_en, author_note_es, author_note_en, category_id,
              scope, tags, source_name, source_url, source_title, source_published_on, source_lang, source_id,
              media_id, image_license, image_credit, reject_reason),
      delete on guide.news to authenticated;
drop policy if exists news_select on guide.news;
create policy news_select on guide.news for select to anon, authenticated
  using (status = 'published' or (select guide.is_admin()));
drop policy if exists news_insert on guide.news;
create policy news_insert on guide.news for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists news_update on guide.news;
create policy news_update on guide.news for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists news_delete on guide.news;
create policy news_delete on guide.news for delete to authenticated using ((select guide.is_admin()));

-- Política de news_sources (necesita guide.news).
drop policy if exists news_sources_select on guide.news_sources;
create policy news_sources_select on guide.news_sources for select to anon, authenticated
  using ((select guide.is_admin())
         or exists (select 1 from guide.news n where n.source_id = news_sources.id and n.status = 'published'));
drop policy if exists news_sources_insert on guide.news_sources;
create policy news_sources_insert on guide.news_sources for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists news_sources_update on guide.news_sources;
create policy news_sources_update on guide.news_sources for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists news_sources_delete on guide.news_sources;
create policy news_sources_delete on guide.news_sources for delete to authenticated using ((select guide.is_admin()));

-- ───────────── 6. Relaciones noticia ↔ rocódromo / artículo / evento (máx. 3; spec SEO §13) ─────────────
create table if not exists guide.news_links (
  news_id    uuid not null references guide.news(id) on delete cascade,
  position   smallint not null check (position between 1 and 3),
  item_id    uuid references guide.items(id) on delete cascade,
  article_id uuid references guide.articles(id) on delete cascade,
  event_id   uuid references guide.events(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (news_id, position),
  constraint news_links_one_target check (num_nonnulls(item_id, article_id, event_id) = 1)
);
create unique index if not exists news_links_item_uq on guide.news_links (news_id, item_id) where item_id is not null;
create unique index if not exists news_links_article_uq on guide.news_links (news_id, article_id) where article_id is not null;
create unique index if not exists news_links_event_uq on guide.news_links (news_id, event_id) where event_id is not null;
create index if not exists news_links_item_idx on guide.news_links (item_id);
create index if not exists news_links_article_idx on guide.news_links (article_id);
create index if not exists news_links_event_idx on guide.news_links (event_id);
alter table guide.news_links enable row level security;
revoke all on guide.news_links from public, anon, authenticated, service_role;
grant select on guide.news_links to anon, authenticated;
grant insert, update, delete on guide.news_links to authenticated;
drop policy if exists news_links_select on guide.news_links;
create policy news_links_select on guide.news_links for select to anon, authenticated
  using ((select guide.is_admin())
         or exists (select 1 from guide.news n where n.id = news_links.news_id and n.status = 'published'));
drop policy if exists news_links_insert on guide.news_links;
create policy news_links_insert on guide.news_links for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists news_links_update on guide.news_links;
create policy news_links_update on guide.news_links for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists news_links_delete on guide.news_links;
create policy news_links_delete on guide.news_links for delete to authenticated using ((select guide.is_admin()));

-- ───────────── 7. Newsletter semanal (D75, D77, D78) ─────────────
create table if not exists guide.newsletter_issues (
  id                 uuid primary key default gen_random_uuid(),
  week_start         date not null unique check (extract(isodow from week_start) = 1),
  status             guide.newsletter_status not null default 'draft',
  subject_es         text check (char_length(subject_es) between 1 and 80 and subject_es !~ '[[:cntrl:]]'),
  subject_en         text check (char_length(subject_en) between 1 and 80 and subject_en !~ '[[:cntrl:]]'),
  preheader_es       text check (char_length(preheader_es) between 1 and 110 and preheader_es !~ '[[:cntrl:]]'),
  preheader_en       text check (char_length(preheader_en) between 1 and 110 and preheader_en !~ '[[:cntrl:]]'),
  intro_es           text check (char_length(intro_es) between 1 and 600
                                 and intro_es !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  intro_en           text check (char_length(intro_en) between 1 and 600
                                 and intro_en !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'),
  intro_by_agent     boolean not null default false,
  composed_by        text not null default 'admin' check (composed_by in ('admin', 'agent')),
  composed_at        timestamptz not null default now(),
  approved_at        timestamptz,
  approved_by        uuid references auth.users(id) on delete set null,
  scheduled_for      timestamptz,
  sent_at            timestamptz,
  sent_counts        jsonb check (sent_counts is null or (jsonb_typeof(sent_counts) = 'object' and octet_length(sent_counts::text) <= 1000)),
  error_code         text check (char_length(error_code) <= 80 and error_code !~ '[[:cntrl:]]'),
  brevo_campaign_ids jsonb check (brevo_campaign_ids is null or (jsonb_typeof(brevo_campaign_ids) = 'object'
                                                                 and octet_length(brevo_campaign_ids::text) <= 1000)),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- D78: sin versión EN completa, los suscriptores en inglés reciben la española con aviso.
  has_en             boolean generated always as (subject_en is not null and intro_en is not null) stored,
  constraint newsletter_scheduled check (
    (status in ('scheduled', 'sending', 'sent', 'failed')) = (approved_at is not null and scheduled_for is not null)),
  constraint newsletter_schedule_gap check (scheduled_for is null or scheduled_for >= approved_at + interval '1 hour'),
  constraint newsletter_sent check ((status = 'sent') = (sent_at is not null))
);
alter table guide.newsletter_issues enable row level security;
revoke all on guide.newsletter_issues from public, anon, authenticated, service_role;
grant select on guide.newsletter_issues to authenticated;
grant insert (week_start, subject_es, subject_en, preheader_es, preheader_en, intro_es, intro_en),
      update (status, subject_es, subject_en, preheader_es, preheader_en, intro_es, intro_en),
      delete on guide.newsletter_issues to authenticated;
drop policy if exists newsletter_issues_select on guide.newsletter_issues;
create policy newsletter_issues_select on guide.newsletter_issues for select to authenticated using ((select guide.is_admin()));
drop policy if exists newsletter_issues_insert on guide.newsletter_issues;
create policy newsletter_issues_insert on guide.newsletter_issues for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists newsletter_issues_update on guide.newsletter_issues;
create policy newsletter_issues_update on guide.newsletter_issues for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists newsletter_issues_delete on guide.newsletter_issues;
create policy newsletter_issues_delete on guide.newsletter_issues for delete to authenticated using ((select guide.is_admin()));

create table if not exists guide.newsletter_issue_items (
  id         uuid primary key default gen_random_uuid(),
  issue_id   uuid not null references guide.newsletter_issues(id) on delete cascade,
  kind       guide.newsletter_item_kind not null,
  ref_id     uuid not null,
  position   smallint not null check (position between 1 and 50),
  blurb_es   text check (char_length(blurb_es) between 1 and 200 and blurb_es !~ '[[:cntrl:]]'),
  blurb_en   text check (char_length(blurb_en) between 1 and 200 and blurb_en !~ '[[:cntrl:]]'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint newsletter_items_ref_uq unique (issue_id, kind, ref_id),
  constraint newsletter_items_pos_uq unique (issue_id, kind, position) deferrable initially deferred
);
alter table guide.newsletter_issue_items enable row level security;
revoke all on guide.newsletter_issue_items from public, anon, authenticated, service_role;
grant select on guide.newsletter_issue_items to authenticated;
grant insert (issue_id, kind, ref_id, position, blurb_es, blurb_en),
      update (position, blurb_es, blurb_en),
      delete on guide.newsletter_issue_items to authenticated;
drop policy if exists newsletter_items_select on guide.newsletter_issue_items;
create policy newsletter_items_select on guide.newsletter_issue_items for select to authenticated using ((select guide.is_admin()));
drop policy if exists newsletter_items_insert on guide.newsletter_issue_items;
create policy newsletter_items_insert on guide.newsletter_issue_items for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists newsletter_items_update on guide.newsletter_issue_items;
create policy newsletter_items_update on guide.newsletter_issue_items for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists newsletter_items_delete on guide.newsletter_issue_items;
create policy newsletter_items_delete on guide.newsletter_issue_items for delete to authenticated using ((select guide.is_admin()));

-- ───────────── 8. Salud de la ingesta (J35): detalle en job_health ─────────────
alter table guide.job_health add column if not exists details jsonb
  check (details is null or (jsonb_typeof(details) = 'object' and octet_length(details::text) <= 2000));
