-- F6.14 (D35) · Suscriptores, parte 2: columnas y restricciones.
-- · email admite null solo en erased (y erased exige null): la supresión anonimiza la fila y conserva fechas, origen
--   y versión para las cifras. Sin hash del email (D35).
-- · Doble opt-in: hash SHA-256 del token de confirmación (nunca el token en claro) y caducidad (48 h).
-- · Brevo (F4.6, solo preparado): brevo_sync_status + error corto.
-- · consent_source sin admin_import (D35: sin doble opt-in no hay prueba; la tabla no tiene filas con ese valor).
-- · Historial: eventos expire/erase y motivo (reason) en bajas y supresiones del panel.
-- Idempotente.

alter table guide.subscribers alter column email drop not null;

alter table guide.subscribers add column if not exists confirm_token_hash bytea;
alter table guide.subscribers add column if not exists confirm_expires_at timestamptz;
alter table guide.subscribers add column if not exists brevo_sync_status guide.brevo_sync_status not null default 'not_synced';
alter table guide.subscribers add column if not exists brevo_sync_error text;

alter table guide.subscribers drop constraint if exists subscribers_email_check;
alter table guide.subscribers add constraint subscribers_email_check check (
  email is null
  or (email = lower(btrim(email)) and char_length(email) <= 254 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'));

alter table guide.subscribers drop constraint if exists subscribers_email_null_only_erased;
alter table guide.subscribers add constraint subscribers_email_null_only_erased
  check ((email is null) = (status = 'erased'));

alter table guide.subscribers drop constraint if exists subscribers_erased_anonymized;
alter table guide.subscribers add constraint subscribers_erased_anonymized check (
  status <> 'erased'
  or (user_id is null and consent_page is null and brevo_contact_id is null
      and confirm_token_hash is null and confirm_expires_at is null));

alter table guide.subscribers drop constraint if exists subscribers_consent_source_check;
alter table guide.subscribers add constraint subscribers_consent_source_check check (
  consent_source = any (array['footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup']));

alter table guide.subscribers drop constraint if exists subscribers_confirm_token_hash_check;
alter table guide.subscribers add constraint subscribers_confirm_token_hash_check check (
  (confirm_token_hash is null or octet_length(confirm_token_hash) = 32)
  and ((confirm_token_hash is null) = (confirm_expires_at is null)));

alter table guide.subscribers drop constraint if exists subscribers_brevo_sync_error_check;
alter table guide.subscribers add constraint subscribers_brevo_sync_error_check check (
  brevo_sync_error is null or (char_length(brevo_sync_error) <= 300 and brevo_sync_status = 'error'));

create unique index if not exists subscribers_confirm_token_hash_key
  on guide.subscribers (confirm_token_hash) where confirm_token_hash is not null;
create index if not exists subscribers_status_consent_at_idx on guide.subscribers (status, consent_at desc);

-- Historial
alter table guide.subscriber_consent_events add column if not exists reason text;

alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_event_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_event_check check (
  event = any (array['subscribe', 'confirm', 'unsubscribe', 'bounce', 'expire', 'erase']));

alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_reason_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_reason_check check (
  reason is null
  or (reason = any (array['request', 'wrong', 'abuse', 'other']) and event in ('unsubscribe', 'erase')));
