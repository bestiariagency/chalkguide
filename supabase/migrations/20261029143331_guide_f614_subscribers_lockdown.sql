-- F6.14 (D35) · Suscriptores, parte 3: sin escritura directa. Toda escritura va por RPC SECURITY DEFINER
-- (subscribe_newsletter, confirm_newsletter, unsubscribe_newsletter, admin_unsubscribe_subscribers,
-- admin_erase_subscriber, expire_pending_subscribers). El admin conserva SELECT (lo usa la vista security_invoker
-- export_subscribers) pero solo de columnas no secretas: ni tokens, ni user_id, ni datos de Brevo.
-- Idempotente.

drop policy if exists subscribers_insert on guide.subscribers;
drop policy if exists subscribers_update on guide.subscribers;
drop policy if exists subscribers_delete on guide.subscribers;

revoke all on guide.subscribers from public, anon, authenticated;
grant select (id, email, status, locale, consent_at, consent_source, consent_version, consent_page,
              confirmed_at, unsubscribed_at, unsubscribe_source, created_at, updated_at)
  on guide.subscribers to authenticated;

-- La policy de lectura (solo admin) se mantiene; se recrea por si faltara.
drop policy if exists subscribers_select on guide.subscribers;
create policy subscribers_select on guide.subscribers for select to authenticated
  using ((select guide.is_admin()));

-- Historial: solo lectura de admin (sin cambios de grants); se reafirma.
revoke all on guide.subscriber_consent_events from public, anon, authenticated;
grant select on guide.subscriber_consent_events to authenticated;
