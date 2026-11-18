-- F2.6 · Comunidad: perfiles públicos de la guía, opiniones, newsletter, agenda y lista de espera.
-- page_views (D5) NO se crea aquí: se decide en F4 (tabla propia vs. Cloudflare Web Analytics).

-- ───────────── user_profiles ─────────────
create table if not exists guide.user_profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 40),
  avatar_url   text check (avatar_url ~ '^https://'),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table guide.user_profiles enable row level security;

drop trigger if exists user_profiles_set_updated_at on guide.user_profiles;
create trigger user_profiles_set_updated_at before update on guide.user_profiles
  for each row execute function guide.set_updated_at();

-- ───────────── user_reviews ─────────────
create table if not exists guide.user_reviews (
  id           uuid primary key default gen_random_uuid(),
  item_id      uuid not null,
  category     text not null,
  user_id      uuid not null references auth.users (id) on delete cascade,
  body         text check (char_length(body) <= 1000),
  locale       guide.locale not null default 'es',
  status       guide.review_status not null default 'visible',
  edited_at    timestamptz,
  moderated_at timestamptz,
  moderated_by uuid references auth.users (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint user_reviews_item_user_key unique (item_id, user_id),
  constraint user_reviews_id_category_key unique (id, category),
  constraint user_reviews_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.user_reviews enable row level security;
create index if not exists user_reviews_item_status_idx on guide.user_reviews (item_id, status);
create index if not exists user_reviews_status_created_idx on guide.user_reviews (status, created_at desc);
create index if not exists user_reviews_user_id_idx on guide.user_reviews (user_id);
create index if not exists user_reviews_item_category_idx on guide.user_reviews (item_id, category);

drop trigger if exists user_reviews_set_updated_at on guide.user_reviews;
create trigger user_reviews_set_updated_at before update on guide.user_reviews
  for each row execute function guide.set_updated_at();
-- Solo se registra la moderación (cambios de estado), sin instantánea de contenido de usuarios.
drop trigger if exists user_reviews_log_activity on guide.user_reviews;
create trigger user_reviews_log_activity after update of status on guide.user_reviews
  for each row execute function guide.log_activity('id', '', 'false');

create table if not exists guide.user_review_scores (
  review_id    uuid not null,
  criterion_id uuid not null,
  category     text not null,
  score        smallint not null check (score between 1 and 5),
  primary key (review_id, criterion_id),
  constraint user_review_scores_review_fk foreign key (review_id, category)
    references guide.user_reviews (id, category) on delete cascade,
  constraint user_review_scores_criterion_fk foreign key (criterion_id, category)
    references guide.criteria (id, category) on delete restrict
);
alter table guide.user_review_scores enable row level security;
create index if not exists user_review_scores_review_category_idx on guide.user_review_scores (review_id, category);
create index if not exists user_review_scores_criterion_category_idx on guide.user_review_scores (criterion_id, category);

-- ───────────── subscribers ─────────────
create table if not exists guide.subscribers (
  id                 uuid primary key default gen_random_uuid(),
  email              text not null unique
                     check (email = lower(btrim(email)) and char_length(email) <= 254
                            and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  status             guide.subscriber_status not null default 'pending',
  locale             guide.locale not null default 'es',
  consent_at         timestamptz not null default now(),
  consent_source     text not null
                     check (consent_source in ('footer', 'article', 'item_page', 'home', 'popup', 'admin_import')),
  consent_version    integer not null check (consent_version >= 1),
  consent_page       text check (char_length(consent_page) <= 300 and consent_page ~ '^/'),
  confirmed_at       timestamptz,
  unsubscribed_at    timestamptz,
  unsubscribe_source text check (unsubscribe_source in ('link', 'brevo', 'admin', 'user')),
  unsubscribe_token  uuid not null unique default gen_random_uuid(),
  user_id            uuid references auth.users (id) on delete set null,
  brevo_contact_id   text,
  synced_at          timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
alter table guide.subscribers enable row level security;
create index if not exists subscribers_status_created_idx on guide.subscribers (status, created_at);
create index if not exists subscribers_user_id_idx on guide.subscribers (user_id);

drop trigger if exists subscribers_set_updated_at on guide.subscribers;
create trigger subscribers_set_updated_at before update on guide.subscribers
  for each row execute function guide.set_updated_at();
-- Sin etiqueta ni instantánea: el log no debe conservar emails tras un borrado RGPD.
drop trigger if exists subscribers_log_activity on guide.subscribers;
create trigger subscribers_log_activity after update of status on guide.subscribers
  for each row execute function guide.log_activity('id', '', 'false');

-- ───────────── events ─────────────
create table if not exists guide.events (
  id             uuid primary key default gen_random_uuid(),
  item_id        uuid references guide.items (id) on delete set null,
  title_es       text not null check (char_length(title_es) between 1 and 200),
  title_en       text check (char_length(title_en) between 1 and 200),
  description_es text check (char_length(description_es) <= 2000),
  description_en text check (char_length(description_en) <= 2000),
  event_type     text not null default 'other'
                 check (event_type in ('competition', 'workshop', 'outing', 'social', 'course', 'other')),
  starts_at      timestamptz not null,
  ends_at        timestamptz,
  all_day        boolean not null default false,
  location_text  text check (char_length(location_text) <= 200),
  url            text check (url ~ '^https?://'),
  price_text     text check (char_length(price_text) <= 120),
  status         guide.event_status not null default 'draft',
  source         guide.event_source not null default 'manual',
  source_url     text check (source_url ~ '^https?://'),
  dedupe_key     text unique check (char_length(dedupe_key) <= 200),
  agent_meta     jsonb check (agent_meta is null or jsonb_typeof(agent_meta) = 'object'),
  approved_at    timestamptz,
  approved_by    uuid references auth.users (id) on delete set null,
  has_en         boolean generated always as (title_en is not null) stored,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid default auth.uid() references auth.users (id) on delete set null,
  updated_by     uuid references auth.users (id) on delete set null,
  constraint events_dates check (ends_at is null or ends_at >= starts_at)
);
alter table guide.events enable row level security;
create index if not exists events_status_starts_idx on guide.events (status, starts_at);
create index if not exists events_item_id_idx on guide.events (item_id);

drop trigger if exists events_set_updated_at on guide.events;
create trigger events_set_updated_at before update on guide.events
  for each row execute function guide.set_updated_at();
drop trigger if exists events_log_activity on guide.events;
create trigger events_log_activity after insert or update or delete on guide.events
  for each row execute function guide.log_activity('id', 'title_es', 'true');

-- ───────────── gym_waitlist (F9) ─────────────
create table if not exists guide.gym_waitlist (
  item_id    uuid not null,
  category   text not null default 'gym' check (category = 'gym'),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (item_id, user_id),
  constraint gym_waitlist_item_fk foreign key (item_id, category)
    references guide.items (id, category) on delete cascade
);
alter table guide.gym_waitlist enable row level security;
create index if not exists gym_waitlist_user_id_idx on guide.gym_waitlist (user_id);
create index if not exists gym_waitlist_item_category_idx on guide.gym_waitlist (item_id, category);

-- ───────────── Grants ─────────────
grant select on guide.user_profiles, guide.user_reviews, guide.user_review_scores, guide.events to anon, authenticated;
-- Perfil propio: solo columnas editables (user_id lo fija la policy y no puede cambiarse).
grant insert (user_id, display_name, avatar_url) on guide.user_profiles to authenticated;
grant update (display_name, avatar_url) on guide.user_profiles to authenticated;
grant delete on guide.user_profiles to authenticated;
-- Opiniones: alta/edición solo vía guide.submit_user_review. update = moderación admin; delete = propia o admin.
grant update, delete on guide.user_reviews to authenticated;
grant delete on guide.user_review_scores to authenticated;
grant select, insert, update, delete on guide.subscribers to authenticated;
grant insert, update, delete on guide.events to authenticated;
grant select, delete on guide.gym_waitlist to authenticated;
grant insert (item_id) on guide.gym_waitlist to authenticated;
grant all on guide.user_profiles, guide.user_reviews, guide.user_review_scores, guide.subscribers,
  guide.events, guide.gym_waitlist to service_role;

-- ───────────── Policies ─────────────
-- user_profiles
drop policy if exists user_profiles_select on guide.user_profiles;
create policy user_profiles_select on guide.user_profiles for select to anon, authenticated
  using (
    user_id = (select auth.uid())
    or exists (select 1 from guide.user_reviews r where r.user_id = user_profiles.user_id and r.status = 'visible')
    or (select guide.is_admin())
  );
drop policy if exists user_profiles_insert on guide.user_profiles;
create policy user_profiles_insert on guide.user_profiles for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists user_profiles_update on guide.user_profiles;
create policy user_profiles_update on guide.user_profiles for update to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()))
  with check (user_id = (select auth.uid()) or (select guide.is_admin()));
drop policy if exists user_profiles_delete on guide.user_profiles;
create policy user_profiles_delete on guide.user_profiles for delete to authenticated
  using ((select guide.is_admin()));

-- user_reviews
drop policy if exists user_reviews_select on guide.user_reviews;
create policy user_reviews_select on guide.user_reviews for select to anon, authenticated
  using (
    (status = 'visible' and exists (select 1 from guide.items i where i.id = user_reviews.item_id and i.published))
    or user_id = (select auth.uid())
    or (select guide.is_admin())
  );
drop policy if exists user_reviews_update on guide.user_reviews;
create policy user_reviews_update on guide.user_reviews for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists user_reviews_delete on guide.user_reviews;
create policy user_reviews_delete on guide.user_reviews for delete to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()));

-- user_review_scores: visibles si la opinión padre es visible para quien consulta (RLS encadenada).
drop policy if exists user_review_scores_select on guide.user_review_scores;
create policy user_review_scores_select on guide.user_review_scores for select to anon, authenticated
  using (exists (select 1 from guide.user_reviews r where r.id = user_review_scores.review_id));
drop policy if exists user_review_scores_delete on guide.user_review_scores;
create policy user_review_scores_delete on guide.user_review_scores for delete to authenticated
  using ((select guide.is_admin()));

-- subscribers: solo admin (alta y baja públicas por RPC SECURITY DEFINER).
drop policy if exists subscribers_select on guide.subscribers;
create policy subscribers_select on guide.subscribers for select to authenticated using ((select guide.is_admin()));
drop policy if exists subscribers_insert on guide.subscribers;
create policy subscribers_insert on guide.subscribers for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists subscribers_update on guide.subscribers;
create policy subscribers_update on guide.subscribers for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists subscribers_delete on guide.subscribers;
create policy subscribers_delete on guide.subscribers for delete to authenticated using ((select guide.is_admin()));

-- events
drop policy if exists events_select on guide.events;
create policy events_select on guide.events for select to anon, authenticated
  using (status = 'approved' or (select guide.is_admin()));
drop policy if exists events_insert on guide.events;
create policy events_insert on guide.events for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists events_update on guide.events;
create policy events_update on guide.events for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists events_delete on guide.events;
create policy events_delete on guide.events for delete to authenticated using ((select guide.is_admin()));

-- gym_waitlist
drop policy if exists gym_waitlist_select on guide.gym_waitlist;
create policy gym_waitlist_select on guide.gym_waitlist for select to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()));
drop policy if exists gym_waitlist_insert on guide.gym_waitlist;
create policy gym_waitlist_insert on guide.gym_waitlist for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from guide.items i where i.id = gym_waitlist.item_id and i.category = 'gym' and i.published)
  );
drop policy if exists gym_waitlist_delete on guide.gym_waitlist;
create policy gym_waitlist_delete on guide.gym_waitlist for delete to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()));
