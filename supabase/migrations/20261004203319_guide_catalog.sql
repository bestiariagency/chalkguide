-- F2.5 · Fichas (modelo genérico): categorías de ítem, items, detalle por categoría, galerías,
-- criterios, reseñas del autor y relación artículos↔fichas.
-- Integridad categoría↔detalle y criterio↔ítem con FK compuestas (id, category).

-- ───────────── item_categories (configuración) ─────────────
create table if not exists guide.item_categories (
  key                 text primary key check (key ~ '^[a-z][a-z_]*$' and char_length(key) <= 40),
  name_es             text not null check (char_length(name_es) between 1 and 80),
  name_en             text check (char_length(name_en) between 1 and 80),
  plural_es           text not null check (char_length(plural_es) between 1 and 80),
  plural_en           text check (char_length(plural_en) between 1 and 80),
  route_es            guide.slug not null unique,
  route_en            guide.slug unique,
  detail_table        text check (detail_table ~ '^[a-z][a-z_]*$'),
  allows_user_reviews boolean not null default true,
  sort_order          integer not null default 0,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
alter table guide.item_categories enable row level security;

insert into guide.item_categories (key, name_es, name_en, plural_es, plural_en, route_es, route_en, detail_table, allows_user_reviews, sort_order)
values
  ('gym',     'Rocódromo',   'Climbing gym',   'Rocódromos',   'Climbing gyms',   'rocodromos',   'climbing-gyms',  'gyms',     true,  1),
  ('resoler', 'Resolador',   'Resoler',        'Resoladores',  'Resolers',        'resoladores',  'resolers',       'resolers', true,  2),
  ('shoe',    'Pie de gato', 'Climbing shoe',  'Pies de gato', 'Climbing shoes',  'pies-de-gato', 'climbing-shoes', 'shoes',    false, 3)
on conflict (key) do nothing;

drop trigger if exists item_categories_set_updated_at on guide.item_categories;
create trigger item_categories_set_updated_at before update on guide.item_categories
  for each row execute function guide.set_updated_at();
drop trigger if exists item_categories_log_activity on guide.item_categories;
create trigger item_categories_log_activity after insert or update or delete on guide.item_categories
  for each row execute function guide.log_activity('key', 'name_es', 'true');

-- ───────────── items ─────────────
create table if not exists guide.items (
  id                 uuid primary key default gen_random_uuid(),
  category           text not null references guide.item_categories (key) on update cascade on delete restrict,
  name               text not null check (char_length(name) between 1 and 120),
  slug               guide.slug not null,
  summary_es         text check (char_length(summary_es) <= 400),
  summary_en         text check (char_length(summary_en) <= 400),
  cover_media_id     uuid references guide.media (id) on delete restrict,
  attributes         jsonb not null default '{}'::jsonb check (jsonb_typeof(attributes) = 'object'),
  published          boolean not null default false,
  published_at       timestamptz,
  is_featured        boolean not null default false,
  verified_at        date,
  source             text check (char_length(source) <= 200),
  source_url         text check (source_url ~ '^https?://'),
  seo_title_es       text check (char_length(seo_title_es) <= 70),
  seo_title_en       text check (char_length(seo_title_en) <= 70),
  seo_description_es text check (char_length(seo_description_es) <= 160),
  seo_description_en text check (char_length(seo_description_en) <= 160),
  og_media_id        uuid references guide.media (id) on delete restrict,
  noindex            boolean not null default false,
  has_en             boolean generated always as (summary_en is not null) stored,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by         uuid references auth.users (id) on delete set null,
  constraint items_category_slug_key unique (category, slug),
  constraint items_id_category_key unique (id, category)
);
alter table guide.items enable row level security;
create index if not exists items_category_published_idx on guide.items (category, published);
create index if not exists items_verified_at_idx on guide.items (verified_at);
create index if not exists items_featured_idx on guide.items (category) where is_featured;
create index if not exists items_cover_media_id_idx on guide.items (cover_media_id);
create index if not exists items_og_media_id_idx on guide.items (og_media_id);

create or replace function guide.items_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.published and new.published_at is null then
    new.published_at := now();
  end if;
  return new;
end;
$$;
revoke execute on function guide.items_before_write() from public;

drop trigger if exists items_before_write on guide.items;
create trigger items_before_write before insert or update on guide.items
  for each row execute function guide.items_before_write();
drop trigger if exists items_set_updated_at on guide.items;
create trigger items_set_updated_at before update on guide.items
  for each row execute function guide.set_updated_at();
drop trigger if exists items_log_activity on guide.items;
create trigger items_log_activity after insert or update or delete on guide.items
  for each row execute function guide.log_activity('id', 'name', 'true');

-- ───────────── item_media (galerías) ─────────────
create table if not exists guide.item_media (
  item_id    uuid not null references guide.items (id) on delete cascade,
  media_id   uuid not null references guide.media (id) on delete restrict,
  sort_order integer not null default 0,
  primary key (item_id, media_id)
);
alter table guide.item_media enable row level security;
create index if not exists item_media_media_id_idx on guide.item_media (media_id);

-- ───────────── gyms ─────────────
create table if not exists guide.gyms (
  item_id                uuid primary key,
  category               text not null default 'gym' check (category = 'gym'),
  address                text,
  city                   text not null default 'Barcelona',
  district               text,
  postal_code            text check (postal_code ~ '^[0-9]{5}$'),
  lat                    numeric(9, 6) check (lat between -90 and 90),
  lng                    numeric(9, 6) check (lng between -180 and 180),
  metro_stations         text[] not null default '{}',
  opening_hours          jsonb not null default '{}'::jsonb check (jsonb_typeof(opening_hours) = 'object'),
  opening_hours_note_es  text,
  opening_hours_note_en  text,
  website_url            text check (website_url ~ '^https?://'),
  instagram_url          text check (instagram_url ~ '^https?://'),
  phone                  text check (char_length(phone) <= 30),
  price_registration_eur numeric(6, 2) check (price_registration_eur >= 0),
  price_day_eur          numeric(6, 2) check (price_day_eur >= 0),
  price_10_pass_eur      numeric(6, 2) check (price_10_pass_eur >= 0),
  price_monthly_eur      numeric(6, 2) check (price_monthly_eur >= 0),
  discounts_es           text,
  discounts_en           text,
  prices_verified_at     date,
  surface_m2             integer check (surface_m2 > 0),
  max_height_m           numeric(4, 1) check (max_height_m > 0),
  has_lead               boolean,
  has_boulder            boolean,
  routes_count           integer check (routes_count >= 0),
  autobelays_count       integer check (autobelays_count >= 0),
  has_training_area      boolean,
  belay_test_required    boolean,
  gear_rental            boolean,
  has_beginner_courses   boolean,
  has_cafe               boolean,
  serves_beer            boolean,
  has_kids_area          boolean,
  has_showers            boolean,
  has_wifi               boolean,
  kids_min_age           smallint check (kids_min_age between 0 and 18),
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint gyms_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.gyms enable row level security;
create index if not exists gyms_city_district_idx on guide.gyms (city, district);

-- ───────────── resolers ─────────────
create table if not exists guide.resolers (
  item_id             uuid primary key,
  category            text not null default 'resoler' check (category = 'resoler'),
  address             text,
  city                text not null default 'Barcelona',
  district            text,
  postal_code         text check (postal_code ~ '^[0-9]{5}$'),
  lat                 numeric(9, 6) check (lat between -90 and 90),
  lng                 numeric(9, 6) check (lng between -180 and 180),
  website_url         text check (website_url ~ '^https?://'),
  instagram_url       text check (instagram_url ~ '^https?://'),
  phone               text check (char_length(phone) <= 30),
  price_per_pair_eur  numeric(6, 2) check (price_per_pair_eur >= 0),
  price_rand_eur      numeric(6, 2) check (price_rand_eur >= 0),
  turnaround_days_min smallint check (turnaround_days_min >= 0),
  turnaround_days_max smallint check (turnaround_days_max >= 0),
  accepts_mail        boolean,
  mail_notes_es       text,
  mail_notes_en       text,
  rubber_brands       text[] not null default '{}',
  prices_verified_at  date,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint resolers_turnaround_range check (turnaround_days_min is null or turnaround_days_max is null or turnaround_days_min <= turnaround_days_max),
  constraint resolers_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.resolers enable row level security;

-- ───────────── shoes ─────────────
create table if not exists guide.shoes (
  item_id             uuid primary key,
  category            text not null default 'shoe' check (category = 'shoe'),
  brand               text not null check (char_length(brand) between 1 and 60),
  model               text not null check (char_length(model) between 1 and 80),
  fit                 text not null default 'unisex' check (fit in ('unisex', 'women', 'men', 'kids')),
  profile             text check (profile in ('flat', 'moderate', 'aggressive')),
  asymmetry           text check (asymmetry in ('none', 'slight', 'moderate', 'strong')),
  closure             text check (closure in ('lace', 'velcro', 'slipper')),
  rubber              text check (char_length(rubber) <= 80),
  rubber_thickness_mm numeric(3, 1) check (rubber_thickness_mm > 0),
  stiffness           smallint check (stiffness between 1 and 5),
  recommended_use     text[] not null default '{}'
                      check (recommended_use <@ array['gym', 'boulder', 'sport', 'trad', 'multipitch', 'training']::text[]),
  levels              text[] not null default '{}'
                      check (levels <@ array['beginner', 'intermediate', 'advanced']::text[]),
  price_min_eur       numeric(6, 2) check (price_min_eur >= 0),
  price_max_eur       numeric(6, 2) check (price_max_eur >= 0),
  price_checked_at    date,
  affiliate_url       text check (affiliate_url ~ '^https://'),
  affiliate_program   text check (char_length(affiliate_program) <= 80),
  is_affiliate        boolean generated always as (affiliate_url is not null) stored,
  owned_by_author     boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint shoes_price_range check (price_min_eur is null or price_max_eur is null or price_min_eur <= price_max_eur),
  constraint shoes_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.shoes enable row level security;
create unique index if not exists shoes_brand_model_key on guide.shoes (lower(brand), lower(model));
create index if not exists shoes_profile_idx on guide.shoes (profile);
create index if not exists shoes_price_min_idx on guide.shoes (price_min_eur);

do $$
declare t text;
begin
  foreach t in array array['gyms', 'resolers', 'shoes'] loop
    execute format('drop trigger if exists %I on guide.%I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on guide.%I for each row execute function guide.set_updated_at()', t || '_set_updated_at', t);
    execute format('drop trigger if exists %I on guide.%I', t || '_log_activity', t);
    execute format('create trigger %I after insert or update or delete on guide.%I for each row execute function guide.log_activity(%L, %L, %L)', t || '_log_activity', t, 'item_id', '', 'true');
  end loop;
end $$;

-- ───────────── criteria ─────────────
create table if not exists guide.criteria (
  id             uuid primary key default gen_random_uuid(),
  category       text not null references guide.item_categories (key) on update cascade on delete restrict,
  key            text not null check (key ~ '^[a-z][a-z_]*$' and char_length(key) <= 40),
  name_es        text not null check (char_length(name_es) between 1 and 80),
  name_en        text check (char_length(name_en) between 1 and 80),
  description_es text check (char_length(description_es) <= 300),
  description_en text check (char_length(description_en) <= 300),
  sort_order     integer not null default 0,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint criteria_category_key_key unique (category, key),
  constraint criteria_id_category_key unique (id, category)
);
alter table guide.criteria enable row level security;

drop trigger if exists criteria_set_updated_at on guide.criteria;
create trigger criteria_set_updated_at before update on guide.criteria
  for each row execute function guide.set_updated_at();
drop trigger if exists criteria_log_activity on guide.criteria;
create trigger criteria_log_activity after insert or update or delete on guide.criteria
  for each row execute function guide.log_activity('id', 'name_es', 'true');

-- ───────────── author_reviews ─────────────
create table if not exists guide.author_reviews (
  id                 uuid primary key default gen_random_uuid(),
  item_id            uuid not null unique,
  category           text not null,
  headline_es        text check (char_length(headline_es) <= 200),
  headline_en        text check (char_length(headline_en) <= 200),
  body_json_es       jsonb not null default '{"type":"doc","content":[]}'::jsonb,
  body_html_es       text not null default '',
  body_json_en       jsonb,
  body_html_en       text,
  visit_date         date,
  visit_type         guide.visit_type not null default 'paid',
  disclosure_note_es text check (char_length(disclosure_note_es) <= 500),
  disclosure_note_en text check (char_length(disclosure_note_en) <= 500),
  has_en             boolean generated always as (body_html_en is not null and body_html_en <> '') stored,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by         uuid references auth.users (id) on delete set null,
  constraint author_reviews_id_category_key unique (id, category),
  constraint author_reviews_body_en_coherent check ((body_json_en is null) = (body_html_en is null)),
  constraint author_reviews_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.author_reviews enable row level security;
create index if not exists author_reviews_item_category_idx on guide.author_reviews (item_id, category);

drop trigger if exists author_reviews_set_updated_at on guide.author_reviews;
create trigger author_reviews_set_updated_at before update on guide.author_reviews
  for each row execute function guide.set_updated_at();
drop trigger if exists author_reviews_sync_media_refs on guide.author_reviews;
create trigger author_reviews_sync_media_refs
  after insert or delete or update of body_json_es, body_json_en on guide.author_reviews
  for each row execute function guide.sync_content_media_refs();
drop trigger if exists author_reviews_log_activity on guide.author_reviews;
create trigger author_reviews_log_activity after insert or update or delete on guide.author_reviews
  for each row execute function guide.log_activity('id', 'headline_es', 'true');

create table if not exists guide.author_review_scores (
  review_id    uuid not null,
  criterion_id uuid not null,
  category     text not null,
  score        smallint not null check (score between 1 and 5),
  primary key (review_id, criterion_id),
  constraint author_review_scores_review_fk foreign key (review_id, category)
    references guide.author_reviews (id, category) on delete cascade,
  constraint author_review_scores_criterion_fk foreign key (criterion_id, category)
    references guide.criteria (id, category) on delete restrict
);
alter table guide.author_review_scores enable row level security;
create index if not exists author_review_scores_review_category_idx on guide.author_review_scores (review_id, category);
create index if not exists author_review_scores_criterion_category_idx on guide.author_review_scores (criterion_id, category);

-- ───────────── article_items ─────────────
create table if not exists guide.article_items (
  article_id uuid not null references guide.articles (id) on delete cascade,
  item_id    uuid not null references guide.items (id) on delete cascade,
  sort_order integer not null default 0,
  primary key (article_id, item_id)
);
alter table guide.article_items enable row level security;
create index if not exists article_items_item_id_idx on guide.article_items (item_id);

-- ───────────── Grants ─────────────
grant select on guide.item_categories, guide.items, guide.item_media, guide.gyms, guide.resolers, guide.shoes,
  guide.criteria, guide.author_reviews, guide.author_review_scores, guide.article_items to anon, authenticated;
grant insert, update, delete on guide.item_categories, guide.items, guide.item_media, guide.gyms, guide.resolers, guide.shoes,
  guide.criteria, guide.author_reviews, guide.author_review_scores, guide.article_items to authenticated;
grant all on guide.item_categories, guide.items, guide.item_media, guide.gyms, guide.resolers, guide.shoes,
  guide.criteria, guide.author_reviews, guide.author_review_scores, guide.article_items to service_role;

-- ───────────── Policies: lectura ─────────────
drop policy if exists item_categories_select on guide.item_categories;
create policy item_categories_select on guide.item_categories for select to anon, authenticated
  using (is_active or (select guide.is_admin()));

drop policy if exists items_select on guide.items;
create policy items_select on guide.items for select to anon, authenticated
  using (published or (select guide.is_admin()));

drop policy if exists criteria_select on guide.criteria;
create policy criteria_select on guide.criteria for select to anon, authenticated
  using (is_active or (select guide.is_admin()));

-- Detalle, galería y reseña del autor: visibles si el ítem padre está publicado.
do $$
declare t text;
begin
  foreach t in array array['item_media', 'gyms', 'resolers', 'shoes', 'author_reviews'] loop
    execute format('drop policy if exists %I on guide.%I', t || '_select', t);
    execute format(
      'create policy %I on guide.%I for select to anon, authenticated using (
         exists (select 1 from guide.items i where i.id = %I.item_id and i.published)
         or (select guide.is_admin()))', t || '_select', t, t);
  end loop;
end $$;

drop policy if exists author_review_scores_select on guide.author_review_scores;
create policy author_review_scores_select on guide.author_review_scores for select to anon, authenticated
  using (
    exists (
      select 1 from guide.author_reviews r join guide.items i on i.id = r.item_id
      where r.id = author_review_scores.review_id and i.published
    )
    or (select guide.is_admin())
  );

drop policy if exists article_items_select on guide.article_items;
create policy article_items_select on guide.article_items for select to anon, authenticated
  using (
    (
      exists (select 1 from guide.articles a where a.id = article_items.article_id
              and guide.article_is_live(a.status, a.published_at))
      and exists (select 1 from guide.items i where i.id = article_items.item_id and i.published)
    )
    or (select guide.is_admin())
  );

-- ───────────── Policies: escritura solo admin ─────────────
do $$
declare t text;
begin
  foreach t in array array['item_categories', 'items', 'item_media', 'gyms', 'resolers', 'shoes',
                           'criteria', 'author_reviews', 'author_review_scores', 'article_items'] loop
    execute format('drop policy if exists %I on guide.%I', t || '_insert', t);
    execute format('create policy %I on guide.%I for insert to authenticated with check ((select guide.is_admin()))', t || '_insert', t);
    execute format('drop policy if exists %I on guide.%I', t || '_update', t);
    execute format('create policy %I on guide.%I for update to authenticated using ((select guide.is_admin())) with check ((select guide.is_admin()))', t || '_update', t);
    execute format('drop policy if exists %I on guide.%I', t || '_delete', t);
    execute format('create policy %I on guide.%I for delete to authenticated using ((select guide.is_admin()))', t || '_delete', t);
  end loop;
end $$;
