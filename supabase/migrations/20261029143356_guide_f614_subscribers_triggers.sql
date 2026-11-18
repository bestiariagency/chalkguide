-- F6.14 (D35) · Suscriptores, parte 4: triggers.
-- · subscribers_guard (BEFORE UPDATE): transiciones de estado cerradas, email inmutable salvo al suprimir, la fila
--   suprimida queda congelada y la supresión solo pasa con la exención atada a la fila (guide.consent_op =
--   'erase:<id>', la fijan admin_erase_subscriber y expire_pending_subscribers). Además marca Brevo como pendiente
--   cuando cambia el estado de una fila confirmada o de baja (F4.6 propagará el cambio).
-- · subscribers_log_consent: eventos expire/erase, motivo (guide.consent_reason) solo si actúa el admin y actor
--   'service' para la tarea de caducidad (guide.consent_actor).
-- · subscriber_consent_events_guard: sigue siendo append-only; única excepción, quitar `page` de los eventos de la
--   fila que se está suprimiendo (misma exención erase:<id>) sin tocar nada más.
-- · subscribers_log_status sustituye al log_activity genérico: una línea por cambio de estado, sin email ni etiqueta,
--   y actor_id solo si actúa el admin (así no queda un user_id que re-identifique una fila suprimida).
-- Idempotente.

create or replace function guide.subscribers_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_op text := coalesce(current_setting('guide.consent_op', true), '');
begin
  if old.status = 'erased' then
    raise exception 'erased subscriber is frozen' using errcode = '42501';
  end if;
  if new.status = 'erased' and v_op is distinct from 'erase:' || old.id::text then
    raise exception 'erase only through admin_erase_subscriber' using errcode = '42501';
  end if;
  if new.email is distinct from old.email and new.status <> 'erased' then
    raise exception 'subscriber email is immutable' using errcode = '42501';
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'pending'      and new.status in ('active', 'unsubscribed', 'expired', 'erased'))
    or (old.status = 'active'       and new.status in ('unsubscribed', 'bounced', 'erased'))
    or (old.status = 'unsubscribed' and new.status in ('pending', 'erased'))
    or (old.status = 'bounced'      and new.status in ('pending', 'unsubscribed', 'erased'))
    or (old.status = 'expired'      and new.status in ('pending', 'erased'))
  ) then
    raise exception 'invalid subscriber status transition' using errcode = '22023',
      detail = old.status::text || ' -> ' || new.status::text;
  end if;

  if new.status is distinct from old.status
     and (old.confirmed_at is not null or old.status in ('active', 'unsubscribed', 'bounced') or new.status = 'active') then
    new.brevo_sync_status := 'pending';
    new.brevo_sync_error := null;
  end if;
  return new;
end;
$$;

drop trigger if exists subscribers_guard on guide.subscribers;
create trigger subscribers_guard before update on guide.subscribers
  for each row execute function guide.subscribers_guard();

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
  return null;
end;
$$;

create or replace function guide.subscriber_consent_events_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if coalesce(current_setting('guide.consent_op', true), '') = 'erase:' || old.subscriber_id::text
       and new.page is null
       and (to_jsonb(new) - 'page') = (to_jsonb(old) - 'page') then
      return new;
    end if;
    raise exception 'subscriber_consent_events is append-only' using errcode = '42501';
  end if;
  if exists (select 1 from guide.subscribers s where s.id = old.subscriber_id) then
    raise exception 'subscriber_consent_events is append-only' using errcode = '42501';
  end if;
  return old;
end;
$$;

create or replace function guide.subscribers_log_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin  boolean := (select guide.is_admin());
  v_by     text;
  v_reason text := nullif(current_setting('guide.consent_reason', true), '');
begin
  if old.status is not distinct from new.status then
    return null;
  end if;
  v_by := case
    when v_admin then 'admin'
    when coalesce(current_setting('guide.consent_actor', true), '') = 'service' then 'system'
    else 'person'
  end;
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values (case when v_admin then (select auth.uid()) end,
          'update', 'subscribers', new.id::text, null, array['status'],
          jsonb_strip_nulls(jsonb_build_object(
            'from', old.status, 'to', new.status, 'by', v_by,
            'reason', case when v_admin then v_reason end,
            'unsubscribe_source', case when new.status = 'unsubscribed' then new.unsubscribe_source end)));
  return null;
end;
$$;

drop trigger if exists subscribers_log_activity on guide.subscribers;
drop trigger if exists subscribers_log_status on guide.subscribers;
create trigger subscribers_log_status after update of status on guide.subscribers
  for each row execute function guide.subscribers_log_status();

revoke all on function guide.subscribers_guard() from public, anon, authenticated;
revoke all on function guide.subscribers_log_consent() from public, anon, authenticated;
revoke all on function guide.subscriber_consent_events_guard() from public, anon, authenticated;
revoke all on function guide.subscribers_log_status() from public, anon, authenticated;
