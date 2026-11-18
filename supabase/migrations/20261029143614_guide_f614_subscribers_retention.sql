-- F6.14 (D35) · Suscriptores, parte 8: caducidad y retención.
-- expire_pending_subscribers(): Sin confirmar → Caducado a los 7 días del alta (evento expire, actor service);
-- Sin confirmar/Caducado → anonimizado a los 30 días del alta; bajas y rebotados → anonimizados a los 3 años
-- (prueba de la baja conservada ese plazo, D35; a reflejar en privacidad, F7.4). También retira el hash de
-- confirmación de los ya confirmados cuyo token caducó.
-- ⚠ NO se programa todavía: hasta F4.6 no se envían emails de confirmación y caducaría todo. En F4.6, osset-op/jabali-javi
-- añaden el job de pg_cron (p. ej. diario: select guide.expire_pending_subscribers();).
-- Sin EXECUTE para clientes: solo postgres (pg_cron). Idempotente.

create or replace function guide.expire_pending_subscribers()
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_expired    integer;
  v_anon_pend  integer := 0;
  v_anon_unsub integer := 0;
  v_id         uuid;
begin
  perform set_config('guide.consent_actor', 'service', true);
  perform set_config('guide.consent_reason', '', true);

  update guide.subscribers
  set status = 'expired', confirm_token_hash = null, confirm_expires_at = null
  where status = 'pending' and consent_at < now() - interval '7 days';
  get diagnostics v_expired = row_count;

  for v_id in
    select s.id from guide.subscribers s
    where s.status in ('pending', 'expired') and s.consent_at < now() - interval '30 days'
    order by s.id for update
  loop
    perform guide.subscriber_anonymize(v_id);
    v_anon_pend := v_anon_pend + 1;
  end loop;

  for v_id in
    select s.id from guide.subscribers s
    where s.status in ('unsubscribed', 'bounced') and coalesce(s.unsubscribed_at, s.updated_at) < now() - interval '3 years'
    order by s.id for update
  loop
    perform guide.subscriber_anonymize(v_id);
    v_anon_unsub := v_anon_unsub + 1;
  end loop;

  update guide.subscribers
  set confirm_token_hash = null, confirm_expires_at = null
  where status = 'active' and confirm_expires_at < now();

  perform set_config('guide.consent_actor', '', true);
  return jsonb_build_object('expired', v_expired, 'anonymized_unconfirmed', v_anon_pend,
                            'anonymized_unsubscribed', v_anon_unsub);
end;
$$;
revoke all on function guide.expire_pending_subscribers() from public, anon, authenticated, service_role;
