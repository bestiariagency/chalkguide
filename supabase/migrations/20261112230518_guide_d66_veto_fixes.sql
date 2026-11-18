-- D66 · Correcciones del veto de leona-lia (docs/security/D66-related-consent-review.md). Idempotente.
-- V1: la re-suscripción no rota el unsubscribe_token de una fila con afines vigente (el enlace de retirada de los emails
--     ya enviados sigue sirviendo; art. 7.3 RGPD y art. 22 LSSI).
-- O6: subscribe_newsletter sin EXECUTE de service_role (solo anon y authenticated, como F6.14 O4).
-- O5: admin_withdraw_related(p_id, p_reason): el admin retira afines sin suprimir la fila ni tocar la newsletter.
-- O3: la supresión normaliza afines (granted|pending → withdrawn, origen 'erase'): una fila suprimida nunca queda granted.

-- ── Orígenes de retirada: + admin (panel) y erase (supresión) ──
alter table guide.subscribers drop constraint if exists subscribers_related_withdraw_source_check;
alter table guide.subscribers add constraint subscribers_related_withdraw_source_check check (
  related_withdraw_source is null or related_withdraw_source in ('link', 'preferences', 'brevo', 'user', 'admin', 'erase'));

-- ── V1 + O6: alta ──
drop function if exists guide.subscribe_newsletter(text, guide.locale, text, boolean, text);
create or replace function guide.subscribe_newsletter(
  p_email text, p_locale guide.locale, p_source text, p_consent boolean, p_page text default null,
  p_related_consent boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email   text := lower(btrim(p_email));
  -- O4 (leona-lia): sin query string ni fragmento (utm_*, emails o tokens no llegan a la prueba de consentimiento).
  v_page    text := case when p_page ~ '^/' then left(split_part(split_part(p_page, '?', 1), '#', 1), 300) end;
  v_uid     uuid := (select auth.uid());
  v_link    uuid;
  v_version integer;
  v_rel_ver integer;
  v_rel     boolean := coalesce(p_related_consent, false);
  v_hash    bytea := pg_catalog.sha256(convert_to(encode(extensions.gen_random_bytes(32), 'hex'), 'UTF8'));
begin
  if p_consent is not true then
    raise exception 'consent required' using errcode = '22023';
  end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if p_source is null or p_source not in ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup', 'newsletter_page') then
    raise exception 'invalid source' using errcode = '22023';
  end if;

  if v_uid is not null and exists (
    select 1 from auth.users u where u.id = v_uid and lower(btrim(u.email)) = v_email
  ) then
    v_link := v_uid;
  end if;

  select consent_version, related_consent_version into v_version, v_rel_ver from guide.site_settings where id = 1;

  -- D66: afines queda `pending` hasta el doble opt-in (confirm_newsletter). Si la fila ya existe y no se re-suscribe
  -- (activa o pendiente reciente) no cambia nada: a un suscriptor activo se le ofrece desde preferencias.
  -- Re-suscripción: con la casilla, pending salvo que ya esté vigente (no se re-sella); sin ella, un pending sin
  -- verificar de un alta anterior se descarta y lo demás se conserva.
  -- V1: con afines vigente el token no rota (cualquiera puede re-suscribir un email ajeno; rotarlo rompería la retirada
  -- en un clic de los emails de afines ya enviados).
  insert into guide.subscribers (email, status, locale, consent_at, consent_source, consent_version, consent_page, user_id,
                                 confirm_token_hash, confirm_expires_at,
                                 related_status, related_consent_at, related_consent_source, related_consent_version)
  values (v_email, 'pending', coalesce(p_locale, 'es'), now(), p_source, coalesce(v_version, 1), v_page, v_link,
          v_hash, now() + interval '48 hours',
          case when v_rel then 'pending'::guide.related_consent_status else 'none'::guide.related_consent_status end,
          case when v_rel then now() end, case when v_rel then p_source end,
          case when v_rel then coalesce(v_rel_ver, 1) end)
  on conflict (email) do update
    set status             = 'pending',
        locale             = excluded.locale,
        consent_at         = excluded.consent_at,
        consent_source     = excluded.consent_source,
        consent_version    = excluded.consent_version,
        consent_page       = excluded.consent_page,
        user_id            = coalesce(guide.subscribers.user_id, excluded.user_id),
        confirmed_at       = null,
        unsubscribed_at    = null,
        unsubscribe_source = null,
        unsubscribe_token  = case when guide.subscribers.related_status = 'granted' then guide.subscribers.unsubscribe_token
                                  else gen_random_uuid() end,
        confirm_token_hash = excluded.confirm_token_hash,
        confirm_expires_at = excluded.confirm_expires_at,
        related_status = case
          when guide.subscribers.related_status = 'granted' then guide.subscribers.related_status
          when v_rel then 'pending'::guide.related_consent_status
          when guide.subscribers.related_status = 'pending' then 'none'::guide.related_consent_status
          else guide.subscribers.related_status end,
        related_consent_at = case
          when guide.subscribers.related_status = 'granted' then guide.subscribers.related_consent_at
          when v_rel then excluded.related_consent_at
          when guide.subscribers.related_status = 'pending' then null
          else guide.subscribers.related_consent_at end,
        related_consent_source = case
          when guide.subscribers.related_status = 'granted' then guide.subscribers.related_consent_source
          when v_rel then excluded.related_consent_source
          when guide.subscribers.related_status = 'pending' then null
          else guide.subscribers.related_consent_source end,
        related_consent_version = case
          when guide.subscribers.related_status = 'granted' then guide.subscribers.related_consent_version
          when v_rel then excluded.related_consent_version
          when guide.subscribers.related_status = 'pending' then null
          else guide.subscribers.related_consent_version end,
        related_confirmed_at = case
          when guide.subscribers.related_status = 'granted' then guide.subscribers.related_confirmed_at
          when v_rel then null
          else guide.subscribers.related_confirmed_at end
    where guide.subscribers.status in ('unsubscribed', 'bounced', 'expired')
       or (guide.subscribers.status = 'pending' and guide.subscribers.consent_at < now() - interval '24 hours');
end;
$$;
revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  from public, anon, authenticated, service_role;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  to anon, authenticated;

-- ── O3: supresión con afines normalizado ──
-- granted|pending → withdrawn (origen 'erase', ahora): transición permitida por subscribers_related_guard y coherente
-- con subscribers_related_state_check. El historial no registra un evento de afines (la fila ya es erased): basta el
-- `erase`, que afecta a toda la fila.
create or replace function guide.subscriber_anonymize(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  -- Exención atada a la fila: el guard de subscribers solo deja pasar a erased y el de eventos solo deja vaciar
  -- `page` cuando la marca es exactamente erase:<id>.
  perform set_config('guide.consent_op', 'erase:' || p_id::text, true);
  update guide.subscriber_consent_events set page = null where subscriber_id = p_id and page is not null;
  update guide.subscribers
  set status                  = 'erased',
      email                   = null,
      user_id                 = null,
      consent_page            = null,
      brevo_contact_id        = null,
      unsubscribe_token       = gen_random_uuid(),
      confirm_token_hash      = null,
      confirm_expires_at      = null,
      related_status          = case when related_status in ('granted', 'pending')
                                     then 'withdrawn'::guide.related_consent_status else related_status end,
      related_withdrawn_at    = case when related_status in ('granted', 'pending') then now() else related_withdrawn_at end,
      related_withdraw_source = case when related_status in ('granted', 'pending') then 'erase' else related_withdraw_source end
  where id = p_id;
  perform set_config('guide.consent_op', '', true);
end;
$$;
revoke all on function guide.subscriber_anonymize(uuid) from public, anon, authenticated, service_role;

-- ── Historial: la retirada de afines desde el panel guarda el motivo (como la baja de admin de la newsletter) ──
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
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor, purpose, reason)
      values (new.id, new.related_withdrawn_at, 'unsubscribe', new.related_withdraw_source, new.locale, v_actor,
              'related_products', case when new.related_withdraw_source = 'admin' then v_reason end);
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

-- ── O5: retirada de afines desde el panel (petición por email del titular) ──
-- Solo afines: la newsletter no cambia. granted|pending → withdrawn; otro estado → 22023 (no hay nada que retirar).
create or replace function guide.admin_withdraw_related(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rel guide.related_consent_status;
begin
  perform guide.assert_admin();
  if p_reason is null or p_reason not in ('request', 'wrong', 'abuse', 'other') then
    raise exception 'invalid reason' using errcode = '22023';
  end if;
  select s.related_status into v_rel from guide.subscribers s where s.id = p_id and s.status <> 'erased' for update;
  if not found then
    raise exception 'subscriber not found' using errcode = 'P0002';
  end if;
  if v_rel not in ('granted', 'pending') then
    raise exception 'invalid related consent state' using errcode = '22023', detail = v_rel::text;
  end if;

  perform set_config('guide.consent_reason', p_reason, true);
  update guide.subscribers
  set related_status = 'withdrawn', related_withdrawn_at = now(), related_withdraw_source = 'admin'
  where id = p_id;
  perform set_config('guide.consent_reason', '', true);
  return jsonb_build_object('id', p_id, 'related_status', 'withdrawn');
end;
$$;
revoke all on function guide.admin_withdraw_related(uuid, text) from public, anon, authenticated, service_role;
grant execute on function guide.admin_withdraw_related(uuid, text) to authenticated;
