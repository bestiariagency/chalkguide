-- D66 · Consentimiento de afines, parte 4 (ajuste): el historial registra el alta de afines también cuando se vuelve a
-- dar en la misma transacción que la retirada (now() no cambia y related_consent_at no se distinguía). Idempotente.

create or replace function guide.subscribers_log_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_reason text := nullif(current_setting('guide.consent_reason', true), '');
  v_actor  text;
begin
  v_actor := case
    when (select guide.is_admin()) then 'admin'
    when coalesce(current_setting('guide.consent_actor', true), '') = 'service' then 'service'
    when (select auth.uid()) is not null then 'user'
    when v_claims ->> 'role' = 'service_role' then 'service'
    else 'anon'
  end;
  if v_actor <> 'admin' then
    v_reason := null;
  end if;

  -- Newsletter (sin cambios)
  if new.status <> 'erased' and (tg_op = 'INSERT' or new.consent_at is distinct from old.consent_at) then
    insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, consent_version, locale, page, actor)
    values (new.id, new.consent_at, 'subscribe', new.consent_source, new.consent_version, new.locale, new.consent_page, v_actor);
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'active' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor)
      values (new.id, coalesce(new.confirmed_at, now()), 'confirm', 'double_opt_in', new.locale, v_actor);
    elsif new.status = 'unsubscribed' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor, reason)
      values (new.id, coalesce(new.unsubscribed_at, now()), 'unsubscribe', new.unsubscribe_source, new.locale, v_actor,
              case when new.unsubscribe_source = 'admin' then v_reason end);
    elsif new.status = 'bounced' then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (new.id, 'bounce', 'brevo', new.locale, v_actor);
    elsif new.status = 'expired' then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (new.id, 'expire', 'timeout', new.locale, v_actor);
    elsif new.status = 'erased' then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor, reason)
      values (new.id, 'erase', case when v_actor = 'admin' then 'admin' else 'retention' end, new.locale, v_actor, v_reason);
    end if;
  end if;

  -- D66: afines. Página solo si se dio en un formulario del sitio (la misma ruta que la newsletter).
  -- También al entrar en pending/granted desde none/withdrawn: en la misma transacción now() no cambia.
  if new.status <> 'erased' and new.related_consent_at is not null
     and (tg_op = 'INSERT' or new.related_consent_at is distinct from old.related_consent_at
          or (new.related_status in ('pending', 'granted') and old.related_status in ('none', 'withdrawn'))) then
    insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, consent_version, locale, page,
                                                 actor, purpose)
    values (new.id, new.related_consent_at, 'subscribe', new.related_consent_source, new.related_consent_version, new.locale,
            case when new.related_consent_source not in ('preferences', 'chalk_waitlist') then new.consent_page end,
            v_actor, 'related_products');
  end if;
  if tg_op = 'UPDATE' and new.status <> 'erased' and new.related_status is distinct from old.related_status then
    if new.related_status = 'granted' and old.related_status = 'pending' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor, purpose)
      values (new.id, new.related_confirmed_at, 'confirm', 'double_opt_in', new.locale, v_actor, 'related_products');
    elsif new.related_status = 'withdrawn' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor, purpose)
      values (new.id, new.related_withdrawn_at, 'unsubscribe', new.related_withdraw_source, new.locale, v_actor,
              'related_products');
    elsif new.related_status = 'none' then
      -- Pendiente sin verificar descartado: por caducidad del alta o por un alta nueva sin la casilla.
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor, purpose)
      values (new.id, 'expire', case when new.status = 'expired' then 'timeout' else 'resubscribe' end, new.locale, v_actor,
              'related_products');
    end if;
  end if;
  return null;
end;
$$;
revoke all on function guide.subscribers_log_consent() from public, anon, authenticated, service_role;
