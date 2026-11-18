-- D66 · Consentimiento de afines, parte 2: guardas, historial, versionado del texto y retención. Idempotente.

-- ── Guarda de afines (BEFORE INSERT OR UPDATE; corre tras subscribers_guard, que congela los erased) ──
-- Transiciones: none → pending|granted · pending → granted|none|withdrawn · granted → withdrawn ·
-- withdrawn → pending|granted. Un consentimiento vigente no se re-sella. Cualquier cambio que entre o salga de
-- granted marca la fila para sincronizar con Brevo (F4.6).
create or replace function guide.subscribers_related_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.related_status not in ('none', 'pending') or new.related_withdrawn_at is not null then
      raise exception 'invalid related consent state' using errcode = '22023';
    end if;
    return new;
  end if;

  if new.related_status is distinct from old.related_status and not (
       (old.related_status = 'none'      and new.related_status in ('pending', 'granted'))
    or (old.related_status = 'pending'   and new.related_status in ('granted', 'none', 'withdrawn'))
    or (old.related_status = 'granted'   and new.related_status = 'withdrawn')
    or (old.related_status = 'withdrawn' and new.related_status in ('pending', 'granted'))
  ) then
    raise exception 'invalid related consent transition' using errcode = '22023',
      detail = old.related_status::text || ' -> ' || new.related_status::text;
  end if;
  if old.related_status = 'granted' and new.related_status = 'granted'
     and (new.related_consent_at, new.related_consent_source, new.related_consent_version, new.related_confirmed_at)
         is distinct from
         (old.related_consent_at, old.related_consent_source, old.related_consent_version, old.related_confirmed_at) then
    raise exception 'granted related consent is immutable' using errcode = '22023';
  end if;
  if (new.related_withdrawn_at, new.related_withdraw_source) is distinct from (old.related_withdrawn_at, old.related_withdraw_source)
     and not (new.related_status = 'withdrawn' and old.related_status <> 'withdrawn') then
    raise exception 'related withdrawal only on withdraw' using errcode = '22023';
  end if;

  if new.related_status is distinct from old.related_status
     and (old.related_status = 'granted' or new.related_status = 'granted') then
    new.brevo_sync_status := 'pending';
    new.brevo_sync_error := null;
  end if;
  return new;
end;
$$;
revoke all on function guide.subscribers_related_guard() from public, anon, authenticated, service_role;
drop trigger if exists subscribers_related_guard on guide.subscribers;
create trigger subscribers_related_guard before insert or update on guide.subscribers
  for each row execute function guide.subscribers_related_guard();

-- ── Historial: el mismo trigger registra ahora también la finalidad related_products ──
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
  if new.status <> 'erased' and new.related_consent_at is not null
     and (tg_op = 'INSERT' or new.related_consent_at is distinct from old.related_consent_at) then
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

-- ── Versionado del texto por finalidad (site_settings → consent_texts) ──
create or replace function guide.site_settings_consent_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Newsletter
  if new.consent_version < old.consent_version then
    raise exception 'consent_version_cannot_decrease' using errcode = '22023';
  end if;
  if new.consent_version = old.consent_version then
    if new.newsletter_consent_text_es is distinct from old.newsletter_consent_text_es
       or new.newsletter_consent_text_en is distinct from old.newsletter_consent_text_en then
      raise exception 'consent_text_requires_version_bump' using errcode = '22023',
        hint = 'Changing the newsletter consent text requires increasing consent_version.';
    end if;
  else
    if exists (select 1 from guide.consent_texts c where c.purpose = 'newsletter' and c.version >= new.consent_version) then
      raise exception 'consent_version_already_used' using errcode = '22023';
    end if;
    update guide.consent_texts set valid_to = now() where purpose = 'newsletter' and valid_to is null;
    insert into guide.consent_texts (purpose, version, text_es, text_en, preserved, valid_from, created_by)
    values ('newsletter', new.consent_version, new.newsletter_consent_text_es,
            case when btrim(new.newsletter_consent_text_en) <> '' then new.newsletter_consent_text_en end, true,
            now(), (select auth.uid()));
  end if;

  -- D66: afines
  if new.related_consent_version < old.related_consent_version then
    raise exception 'consent_version_cannot_decrease' using errcode = '22023';
  end if;
  if new.related_consent_version = old.related_consent_version then
    if new.related_consent_text_es is distinct from old.related_consent_text_es
       or new.related_consent_text_en is distinct from old.related_consent_text_en then
      raise exception 'consent_text_requires_version_bump' using errcode = '22023',
        hint = 'Changing the related products consent text requires increasing related_consent_version.';
    end if;
  else
    if exists (select 1 from guide.consent_texts c where c.purpose = 'related_products'
               and c.version >= new.related_consent_version) then
      raise exception 'consent_version_already_used' using errcode = '22023';
    end if;
    update guide.consent_texts set valid_to = now() where purpose = 'related_products' and valid_to is null;
    insert into guide.consent_texts (purpose, version, text_es, text_en, preserved, valid_from, created_by)
    values ('related_products', new.related_consent_version, new.related_consent_text_es, new.related_consent_text_en, true,
            now(), (select auth.uid()));
  end if;
  return new;
end;
$$;
revoke all on function guide.site_settings_consent_version() from public, anon, authenticated, service_role;

-- ── Retención (una sola fuente para el panel y la tarea) ──
-- Newsletter como D35 (pendientes 30 días, bajas 3 años). D66: con afines vigentes la fila no se anonimiza; tras retirar
-- afines, la prueba se conserva 3 años desde la retirada. Gana el plazo más largo (greatest ignora los null).
create or replace function guide.subscriber_anonymize_at(
  p_status guide.subscriber_status, p_consent_at timestamptz, p_unsubscribed_at timestamptz, p_updated_at timestamptz,
  p_related_status guide.related_consent_status, p_related_withdrawn_at timestamptz)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case
    when p_related_status = 'granted' then null
    when p_status in ('pending', 'expired')
      then greatest(p_consent_at + interval '30 days', p_related_withdrawn_at + interval '3 years')
    when p_status in ('unsubscribed', 'bounced')
      then greatest(coalesce(p_unsubscribed_at, p_updated_at) + interval '3 years', p_related_withdrawn_at + interval '3 years')
  end;
$$;
revoke all on function guide.subscriber_anonymize_at(guide.subscriber_status, timestamptz, timestamptz, timestamptz,
                                                     guide.related_consent_status, timestamptz)
  from public, anon, authenticated, service_role;

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

  -- D66: un afines pendiente de la misma alta se descarta con ella (nunca se verificó el email).
  update guide.subscribers
  set status = 'expired', confirm_token_hash = null, confirm_expires_at = null,
      related_status          = case when related_status = 'pending' then 'none' else related_status end,
      related_consent_at      = case when related_status = 'pending' then null else related_consent_at end,
      related_consent_source  = case when related_status = 'pending' then null else related_consent_source end,
      related_consent_version = case when related_status = 'pending' then null else related_consent_version end
  where status = 'pending' and consent_at < now() - interval '7 days';
  get diagnostics v_expired = row_count;

  for v_id in
    select s.id from guide.subscribers s
    where s.status in ('pending', 'expired')
      and guide.subscriber_anonymize_at(s.status, s.consent_at, s.unsubscribed_at, s.updated_at,
                                        s.related_status, s.related_withdrawn_at) < now()
    order by s.id for update
  loop
    perform guide.subscriber_anonymize(v_id);
    v_anon_pend := v_anon_pend + 1;
  end loop;

  for v_id in
    select s.id from guide.subscribers s
    where s.status in ('unsubscribed', 'bounced')
      and guide.subscriber_anonymize_at(s.status, s.consent_at, s.unsubscribed_at, s.updated_at,
                                        s.related_status, s.related_withdrawn_at) < now()
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
