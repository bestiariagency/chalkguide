-- D66 · Consentimiento de comunicaciones afines (Chalk app y productos propios de escalada), parte 1: esquema.
-- Segundo consentimiento, independiente de la newsletter, en la misma fila de guide.subscribers (la fila es el contacto
-- por email; el estado de la newsletter y el de afines son independientes). Finalidad `related_products` (no «affiliates»:
-- «afiliados» son los enlaces de afiliado). Versión de texto propia en site_settings y consent_texts por finalidad.
-- Historial en subscriber_consent_events con columna `purpose`. Sin IP ni user-agent. Idempotente.

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'related_consent_status') then
    create type guide.related_consent_status as enum ('none', 'pending', 'granted', 'withdrawn');
  end if;
end $$;

-- ── subscribers: estado de afines ──
-- none: nunca dado (o pendiente descartado) · pending: marcado en el formulario, falta el doble opt-in del email ·
-- granted: vigente (email verificado) · withdrawn: retirado. related_withdrawn_at guarda la última retirada aunque
-- luego se vuelva a dar (sirve para la retención de la prueba).
alter table guide.subscribers
  add column if not exists related_status          guide.related_consent_status not null default 'none',
  add column if not exists related_consent_at      timestamptz,
  add column if not exists related_consent_source  text,
  add column if not exists related_consent_version integer,
  add column if not exists related_confirmed_at    timestamptz,
  add column if not exists related_withdrawn_at    timestamptz,
  add column if not exists related_withdraw_source text;

alter table guide.subscribers drop constraint if exists subscribers_related_source_check;
alter table guide.subscribers add constraint subscribers_related_source_check check (
  related_consent_source is null or related_consent_source in
    ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup', 'newsletter_page',
     'preferences', 'chalk_waitlist'));
alter table guide.subscribers drop constraint if exists subscribers_related_version_check;
alter table guide.subscribers add constraint subscribers_related_version_check check (
  related_consent_version is null or related_consent_version >= 1);
alter table guide.subscribers drop constraint if exists subscribers_related_withdraw_source_check;
alter table guide.subscribers add constraint subscribers_related_withdraw_source_check check (
  related_withdraw_source is null or related_withdraw_source in ('link', 'preferences', 'brevo', 'user'));
alter table guide.subscribers drop constraint if exists subscribers_related_withdraw_pair_check;
alter table guide.subscribers add constraint subscribers_related_withdraw_pair_check check (
  (related_withdrawn_at is null) = (related_withdraw_source is null));
alter table guide.subscribers drop constraint if exists subscribers_related_state_check;
alter table guide.subscribers add constraint subscribers_related_state_check check (
  case related_status
    when 'none' then related_consent_at is null and related_consent_source is null and related_consent_version is null
                     and related_confirmed_at is null
    when 'pending' then related_consent_at is not null and related_consent_source is not null
                        and related_consent_version is not null and related_confirmed_at is null
    when 'granted' then related_consent_at is not null and related_consent_source is not null
                        and related_consent_version is not null and related_confirmed_at is not null
    when 'withdrawn' then related_consent_at is not null and related_consent_source is not null
                          and related_consent_version is not null and related_withdrawn_at is not null
  end);

-- Audiencia de afines para Brevo (F4.6) y facetas del panel.
create index if not exists subscribers_related_status_idx on guide.subscribers (related_status, related_consent_at desc);

-- Lectura de admin (RLS ya filtra por is_admin): mismas reglas que el resto de columnas no secretas.
grant select (related_status, related_consent_at, related_consent_source, related_consent_version, related_confirmed_at,
              related_withdrawn_at, related_withdraw_source)
  on guide.subscribers to authenticated;

-- ── historial por finalidad ──
alter table guide.subscriber_consent_events
  add column if not exists purpose text not null default 'newsletter';
alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_purpose_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_purpose_check check (
  purpose in ('newsletter', 'related_products'));
grant select (purpose) on guide.subscriber_consent_events to authenticated;

-- ── consent_texts por finalidad ──
alter table guide.consent_texts
  add column if not exists purpose text not null default 'newsletter';
alter table guide.consent_texts drop constraint if exists consent_texts_purpose_check;
alter table guide.consent_texts add constraint consent_texts_purpose_check check (
  purpose in ('newsletter', 'related_products'));
do $$
begin
  if pg_get_constraintdef((select oid from pg_constraint where conname = 'consent_texts_pkey'
                           and conrelid = 'guide.consent_texts'::regclass)) = 'PRIMARY KEY (version)' then
    alter table guide.consent_texts drop constraint consent_texts_pkey;
    alter table guide.consent_texts add constraint consent_texts_pkey primary key (purpose, version);
  end if;
end $$;
drop index if exists guide.consent_texts_one_open_idx;
create unique index consent_texts_one_open_idx on guide.consent_texts (purpose) where valid_to is null;
grant select (purpose) on guide.consent_texts to authenticated;

-- ── site_settings: texto y versión vigentes de afines (lectura pública, como el de la newsletter) ──
-- Sin GRANT de UPDATE: cambiar el texto es una migración que sube related_consent_version (el trigger lo versiona).
alter table guide.site_settings
  add column if not exists related_consent_version integer not null default 1,
  add column if not exists related_consent_text_es text not null
    default 'Quiero que me avisen por email de novedades de Chalk app y de otros productos de ChalkGuide relacionados con la escalada. Puedo retirar mi consentimiento cuando quiera.',
  add column if not exists related_consent_text_en text not null
    default 'I''d like to be told by email about news from Chalk app and other climbing-related ChalkGuide products. I can withdraw my consent at any time.';
alter table guide.site_settings alter column related_consent_text_es drop default;
alter table guide.site_settings alter column related_consent_text_en drop default;
alter table guide.site_settings drop constraint if exists site_settings_related_consent_version_check;
alter table guide.site_settings add constraint site_settings_related_consent_version_check check (related_consent_version >= 1);
alter table guide.site_settings drop constraint if exists site_settings_related_consent_text_es_check;
alter table guide.site_settings add constraint site_settings_related_consent_text_es_check check (
  char_length(btrim(related_consent_text_es)) between 1 and 2000);
alter table guide.site_settings drop constraint if exists site_settings_related_consent_text_en_check;
alter table guide.site_settings add constraint site_settings_related_consent_text_en_check check (
  char_length(btrim(related_consent_text_en)) between 1 and 2000);
grant select (related_consent_version, related_consent_text_es, related_consent_text_en)
  on guide.site_settings to anon, authenticated;

-- Texto v1 (doc D66 §1, versión principal), idéntico al vigente de site_settings.
insert into guide.consent_texts (purpose, version, text_es, text_en, preserved, valid_from)
select 'related_products', s.related_consent_version, s.related_consent_text_es, s.related_consent_text_en, true, now()
from guide.site_settings s
where s.id = 1
  and not exists (select 1 from guide.consent_texts c where c.purpose = 'related_products')
on conflict (purpose, version) do nothing;

-- ── exportación (D36): columnas nuevas al final de la vista ──
create or replace view guide.export_subscribers with (security_invoker = true) as
select s.email, s.locale, s.status, s.consent_at, s.confirmed_at, s.id, s.consent_source, s.consent_version,
       s.consent_page, s.unsubscribed_at, s.unsubscribe_source, s.created_at,
       s.related_status, s.related_consent_at, s.related_consent_source, s.related_consent_version,
       s.related_confirmed_at, s.related_withdrawn_at, s.related_withdraw_source
from guide.subscribers s
where (select guide.is_admin()) and s.status <> 'erased';
