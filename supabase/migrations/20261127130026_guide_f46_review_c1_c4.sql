-- F4.6 · Revisión de implementación de leona-lia (docs/security/F4.6-brevo-spec.md, apéndice final).
-- C1: brevo_sync de un contacto que Brevo ya tiene en lista negra o dado de baja de nuestras listas → la fila baja a
--     unsubscribed (origen brevo) sin rehabilitarlo en Brevo y el trabajo se cierra skipped/stale_state.
--     Atada al trabajo bloqueado (no depende de que brevo_contact_id ya coincida) y solo baja estados (B20).
-- C4: un confirm_email en processing con lock caducado no se reclama (pudo salir ya): se cierra failed/lock_expired.
--     Máximo un envío por trabajo; reenviar es una acción explícita (request_confirm_resend o admin_email_retry_failed).
-- Idempotente. Cero cambios en public.

alter table guide.email_outbox drop constraint if exists email_outbox_last_error_check;
alter table guide.email_outbox add constraint email_outbox_last_error_check check (last_error is null or last_error = any (array[
  'brevo_4xx', 'brevo_404', 'brevo_429', 'brevo_5xx', 'timeout', 'network', 'quota', 'email_cap',
  'global_cap', 'not_allowed_test', 'stale_state', 'config', 'max_attempts', 'lock_expired']));

create or replace function guide.svc_outbox_claim(p_limit integer, p_lock_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform guide.svc_assert();
  if p_lock_id is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  -- C4: un email de confirmación con lock caducado pudo enviarse ya; no se reintenta solo.
  update guide.email_outbox o
  set status = 'failed', last_error = 'lock_expired', lock_id = null, locked_at = null, done_at = now()
  where o.status = 'processing' and o.kind = 'confirm_email' and o.locked_at < now() - interval '10 minutes';
  -- Un trabajo colgado que ya agotó intentos no se vuelve a tomar.
  update guide.email_outbox o
  set status = 'failed', last_error = 'max_attempts', lock_id = null, locked_at = null, done_at = now()
  where o.status = 'processing' and o.locked_at < now() - interval '10 minutes' and o.attempts >= 7;

  with c as (
    select o.id from guide.email_outbox o
    where ((o.status = 'pending' and o.next_attempt_at <= now())
           or (o.status = 'processing' and o.kind <> 'confirm_email' and o.locked_at < now() - interval '10 minutes'))
      and not (o.kind = 'confirm_email' and exists (
                 select 1 from guide.email_outbox p
                 where p.kind = 'confirm_email' and p.subscriber_id = o.subscriber_id and p.id <> o.id
                   and p.status = 'processing' and p.locked_at >= now() - interval '10 minutes'))
    order by o.id
    limit least(greatest(coalesce(p_limit, 20), 1), 20)
    for update of o skip locked
  ), u as (
    update guide.email_outbox o
    set attempts = o.attempts + case when o.status = 'processing' then 1 else 0 end,
        status = 'processing', locked_at = now(), lock_id = p_lock_id
    from c where o.id = c.id
    returning o.id, o.kind, o.subscriber_id, o.brevo_contact_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'kind', u.kind, 'subscriber_id', u.subscriber_id,
                                               'brevo_contact_id', u.brevo_contact_id) order by u.id), '[]'::jsonb)
  into v from u;
  return v;
end;
$$;

-- C1: el worker ha visto en Brevo (GET /v3/contacts/{email}) que el contacto está en lista negra o dado de baja de
-- nuestras listas. No se toca Brevo (no se rehabilita ni se borra el contacto, que perdería la lista negra).
create or replace function guide.svc_outbox_sync_suppressed(p_outbox_id bigint, p_lock_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o guide.email_outbox;
  s record;
  v text := 'ignored';
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if o.kind <> 'brevo_sync' then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  select x.id, x.status into s from guide.subscribers x where x.id = o.subscriber_id for update;
  if found and s.status = 'active' then
    perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
    update guide.subscribers
    set status = 'unsubscribed', unsubscribed_at = now(), unsubscribe_source = 'brevo',
        confirm_token_hash = null, confirm_expires_at = null
    where id = s.id;
    perform set_config('guide.consent_actor', '', true);
    v := 'applied';
  end if;
  perform guide.outbox_close(o.id, 'skipped', 'stale_state');
  return v;
end;
$$;
revoke all on function guide.svc_outbox_sync_suppressed(bigint, uuid) from public, anon, authenticated, service_role;
grant execute on function guide.svc_outbox_sync_suppressed(bigint, uuid) to service_role;
