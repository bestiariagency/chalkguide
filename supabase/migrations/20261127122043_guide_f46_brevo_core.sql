-- F4.6 · Brevo doble opt-in (docs/security/F4.6-brevo-spec.md §3–§4, decisiones de Xavi y condiciones L1–L11).
-- Cola transaccional sin datos personales (guide.email_outbox), topes de alta (newsletter_rate, captcha_spent),
-- RPC svc_* solo para service_role, guardas con actor brevo:<id> atado a la fila y jobs de cron (inertes hasta que
-- exista el secreto de Vault `newsletter_worker_secret`).
-- L9: en ESTA migración van también B10 (subscribe_newsletter sin EXECUTE de anon/authenticated) y O3 (service_role
-- sin grants de tabla en subscribers, subscriber_consent_events, consent_texts, newsletter_* ni tablas nuevas, y sin
-- EXECUTE en unsubscribe_newsletter).
-- Idempotente. Cero cambios en public.

-- ───────────── 1. Tipos ─────────────
do $$
begin
  if not exists (select 1 from pg_type where typname = 'outbox_kind' and typnamespace = 'guide'::regnamespace) then
    create type guide.outbox_kind as enum ('confirm_email', 'brevo_sync', 'brevo_delete');
  end if;
  if not exists (select 1 from pg_type where typname = 'outbox_status' and typnamespace = 'guide'::regnamespace) then
    create type guide.outbox_status as enum ('pending', 'processing', 'done', 'failed', 'skipped');
  end if;
end $$;

-- ───────────── 2. subscribers y su historial ─────────────
do $$
begin
  if (select format_type(a.atttypid, a.atttypmod) from pg_attribute a
      where a.attrelid = 'guide.subscribers'::regclass and a.attname = 'brevo_contact_id') = 'text' then
    alter table guide.subscribers alter column brevo_contact_id type bigint using nullif(btrim(brevo_contact_id), '')::bigint;
  end if;
end $$;

alter table guide.subscribers
  add column if not exists confirm_sent_at timestamptz,
  add column if not exists confirm_sends smallint not null default 0,
  add column if not exists confirm_resend_used boolean not null default false;

alter table guide.subscribers drop constraint if exists subscribers_confirm_sends_check;
alter table guide.subscribers add constraint subscribers_confirm_sends_check check (confirm_sends between 0 and 2);
alter table guide.subscribers drop constraint if exists subscribers_brevo_contact_id_check;
alter table guide.subscribers add constraint subscribers_brevo_contact_id_check check (brevo_contact_id is null or brevo_contact_id > 0);
-- Queja de spam (Brevo) = baja con origen propio.
alter table guide.subscribers drop constraint if exists subscribers_unsubscribe_source_check;
alter table guide.subscribers add constraint subscribers_unsubscribe_source_check
  check (unsubscribe_source = any (array['link', 'brevo', 'complaint', 'admin', 'user']));
create index if not exists subscribers_brevo_contact_id_idx on guide.subscribers (brevo_contact_id) where brevo_contact_id is not null;

alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_event_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_event_check
  check (event = any (array['subscribe', 'confirm', 'unsubscribe', 'bounce', 'expire', 'erase', 'confirm_sent']));
alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_actor_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_actor_check
  check (actor = any (array['anon', 'user', 'admin', 'service', 'brevo']));
create index if not exists subscriber_consent_events_confirm_sent_idx
  on guide.subscriber_consent_events (occurred_at, subscriber_id) where event = 'confirm_sent';

-- ───────────── 3. Tablas nuevas (RLS sin policies: solo por svc_* / admin_*) ─────────────
create table if not exists guide.email_outbox (
  id               bigint generated always as identity primary key,
  kind             guide.outbox_kind not null,
  subscriber_id    uuid references guide.subscribers (id) on delete set null,
  brevo_contact_id bigint check (brevo_contact_id is null or brevo_contact_id > 0),
  status           guide.outbox_status not null default 'pending',
  attempts         smallint not null default 0 check (attempts between 0 and 8),
  next_attempt_at  timestamptz not null default now(),
  locked_at        timestamptz,
  lock_id          uuid,
  -- L4: id opaco del email transaccional (sin PII), para casar bounces/quejas del email de confirmación.
  brevo_message_id text check (brevo_message_id is null
                               or (char_length(brevo_message_id) between 3 and 200 and brevo_message_id ~ '^<?[A-Za-z0-9._%+=@-]+>?$')),
  -- B15: solo códigos de lista blanca; nunca texto de Brevo ni emails.
  last_error       text check (last_error is null or last_error = any (array[
                     'brevo_4xx', 'brevo_404', 'brevo_429', 'brevo_5xx', 'timeout', 'network', 'quota', 'email_cap',
                     'global_cap', 'not_allowed_test', 'stale_state', 'config', 'max_attempts'])),
  created_at       timestamptz not null default now(),
  done_at          timestamptz,
  constraint email_outbox_target check (case when kind = 'brevo_delete' then brevo_contact_id is not null and subscriber_id is null
                                             else brevo_contact_id is null end),
  constraint email_outbox_lock check ((status = 'processing') = (lock_id is not null and locked_at is not null)),
  constraint email_outbox_closed check ((status in ('done', 'failed', 'skipped')) = (done_at is not null)),
  constraint email_outbox_message_kind check (brevo_message_id is null or kind = 'confirm_email')
);
create unique index if not exists email_outbox_pending_uq on guide.email_outbox (kind, subscriber_id)
  where status = 'pending' and kind in ('confirm_email', 'brevo_sync');
-- L10: el brevo_delete de la supresión y el del trigger de salida de active se deduplican aquí.
create unique index if not exists email_outbox_delete_uq on guide.email_outbox (brevo_contact_id)
  where status = 'pending' and kind = 'brevo_delete';
create index if not exists email_outbox_due_idx on guide.email_outbox (next_attempt_at) where status = 'pending';
create index if not exists email_outbox_subscriber_idx on guide.email_outbox (subscriber_id) where subscriber_id is not null;
create index if not exists email_outbox_message_idx on guide.email_outbox (brevo_message_id) where brevo_message_id is not null;

create table if not exists guide.newsletter_rate (
  bucket       text not null check (bucket ~ '^(ip|ipnojs):[0-9a-f]{64}$'),
  span         text not null check (span in ('hour', 'day')),
  window_start timestamptz not null,
  hits         integer not null default 0 check (hits >= 0),
  primary key (bucket, span, window_start)
);

create table if not exists guide.captcha_spent (
  challenge_hash bytea primary key check (octet_length(challenge_hash) = 32),
  expires_at     timestamptz not null
);

alter table guide.email_outbox enable row level security;
alter table guide.newsletter_rate enable row level security;
alter table guide.captcha_spent enable row level security;
revoke all on guide.email_outbox, guide.newsletter_rate, guide.captcha_spent from public, anon, authenticated, service_role;

-- ───────────── 4. L9 · B10 + O3 ─────────────
revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  from public, anon, authenticated, service_role;
revoke all on guide.subscribers, guide.subscriber_consent_events, guide.consent_texts,
              guide.newsletter_issues, guide.newsletter_issue_items
  from service_role;
revoke execute on function guide.unsubscribe_newsletter(uuid) from service_role;

-- ───────────── 5. Guardas y registro ─────────────
create or replace function guide.subscribers_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_op    text := coalesce(current_setting('guide.consent_op', true), '');
  v_actor text := coalesce(current_setting('guide.consent_actor', true), '');
  v_brevo boolean := v_actor like 'brevo:%';
  c_brevo_cols constant text[] := array['status', 'unsubscribed_at', 'unsubscribe_source', 'brevo_contact_id', 'brevo_sync_status',
                                        'brevo_sync_error', 'synced_at', 'confirm_token_hash', 'confirm_expires_at',
                                        'confirm_sent_at', 'confirm_sends', 'confirm_resend_used', 'updated_at'];
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

  -- F4.6 (B14): actor brevo:<id> de las svc_*, atado a la fila. Solo columnas de sincronización y confirmación, y
  -- solo bajadas de estado (nunca activa, reactiva ni cambia idioma).
  if v_brevo then
    if v_actor <> 'brevo:' || old.id::text then
      raise exception 'brevo actor bound to another row' using errcode = '42501';
    end if;
    if (to_jsonb(new) - c_brevo_cols) is distinct from (to_jsonb(old) - c_brevo_cols) then
      raise exception 'brevo actor column not allowed' using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and (old.status::text || '>' || new.status::text)
           <> all (array['active>unsubscribed', 'active>bounced', 'pending>bounced', 'pending>unsubscribed']) then
      raise exception 'brevo actor status not allowed' using errcode = '42501';
    end if;
    if new.status is not distinct from old.status
       and (new.unsubscribed_at, new.unsubscribe_source) is distinct from (old.unsubscribed_at, old.unsubscribe_source) then
      raise exception 'brevo actor column not allowed' using errcode = '42501';
    end if;
  end if;

  if new.status is distinct from old.status and not (
       (old.status = 'pending'      and new.status in ('active', 'unsubscribed', 'expired', 'erased'))
    or (old.status = 'pending'      and new.status = 'bounced' and v_brevo)   -- L4: solo con actor brevo
    or (old.status = 'active'       and new.status in ('unsubscribed', 'bounced', 'erased'))
    or (old.status = 'unsubscribed' and new.status in ('pending', 'erased'))
    or (old.status = 'bounced'      and new.status in ('pending', 'unsubscribed', 'erased'))
    or (old.status = 'expired'      and new.status in ('pending', 'erased'))
  ) then
    raise exception 'invalid subscriber status transition' using errcode = '22023',
      detail = old.status::text || ' -> ' || new.status::text;
  end if;

  -- Re-alta (nuevo pending): contadores de confirmación de esta alta a cero. El tope por email de 30 días (B9) se
  -- cuenta en subscriber_consent_events y no se reinicia.
  if new.status = 'pending' and (new.status is distinct from old.status or new.consent_at is distinct from old.consent_at) then
    new.confirm_sends := 0;
    new.confirm_resend_used := false;
    new.confirm_sent_at := null;
  end if;

  -- Espejo N3: entrar en active o salir con contacto en Brevo deja la sincronización pendiente (la hace el outbox).
  if new.status = 'erased' then
    new.brevo_sync_status := 'not_synced';
    new.brevo_sync_error := null;
  elsif new.status is distinct from old.status and (new.status = 'active' or old.brevo_contact_id is not null) then
    new.brevo_sync_status := 'pending';
    new.brevo_sync_error := null;
  end if;
  return new;
end;
$$;

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

  -- F4.6 §3.6: la fila suprimida queda not_synced (no se re-marca por la retirada de afines de la supresión).
  if new.related_status is distinct from old.related_status and new.status <> 'erased'
     and (old.related_status = 'granted' or new.related_status = 'granted') then
    new.brevo_sync_status := 'pending';
    new.brevo_sync_error := null;
  end if;
  return new;
end;
$$;

create or replace function guide.subscribers_log_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_reason text := nullif(current_setting('guide.consent_reason', true), '');
  v_ca     text := coalesce(current_setting('guide.consent_actor', true), '');
  v_actor  text;
begin
  -- F4.6: svc_subscribe fija 'anon' o 'user' (la persona que rellenó el formulario, no la EF); brevo:<id> = Brevo.
  v_actor := case
    when (select guide.is_admin()) then 'admin'
    when v_ca = 'service' then 'service'
    when v_ca like 'brevo:%' then 'brevo'
    when v_ca in ('anon', 'user') then v_ca
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

create or replace function guide.subscribers_log_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin  boolean := (select guide.is_admin());
  v_ca     text := coalesce(current_setting('guide.consent_actor', true), '');
  v_by     text;
  v_reason text := nullif(current_setting('guide.consent_reason', true), '');
begin
  if old.status is not distinct from new.status then
    return null;
  end if;
  v_by := case
    when v_admin then 'admin'
    when v_ca = 'service' or v_ca like 'brevo:%' then 'system'
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

-- §3.6 / O2b / L10: la supresión encola el borrado en Brevo con el id numérico antes de vaciar la fila (sin email).
create or replace function guide.subscriber_anonymize(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_contact bigint;
begin
  select s.brevo_contact_id into v_contact from guide.subscribers s where s.id = p_id;
  if v_contact is not null then
    insert into guide.email_outbox (kind, brevo_contact_id) values ('brevo_delete', v_contact)
    on conflict (brevo_contact_id) where status = 'pending' and kind = 'brevo_delete' do nothing;
  end if;
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

-- ───────────── 6. Encolado y aviso al worker ─────────────
create or replace function guide.subscribers_brevo_enqueue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- B15: el outbox nunca guarda email ni token; el worker relee el estado vigente al procesar (B17).
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from new.status or new.consent_at is distinct from old.consent_at) then
    insert into guide.email_outbox (kind, subscriber_id) values ('confirm_email', new.id)
    on conflict (kind, subscriber_id) where status = 'pending' and kind in ('confirm_email', 'brevo_sync') do nothing;
  end if;
  if tg_op = 'UPDATE' then
    if new.status = 'active' and (old.status is distinct from 'active' or new.locale is distinct from old.locale) then
      insert into guide.email_outbox (kind, subscriber_id) values ('brevo_sync', new.id)
      on conflict (kind, subscriber_id) where status = 'pending' and kind in ('confirm_email', 'brevo_sync') do nothing;
    end if;
    -- N3: cualquier salida de active (o supresión de una fila con contacto) borra el contacto por id.
    if new.status is distinct from old.status and new.status <> 'active' and old.brevo_contact_id is not null then
      insert into guide.email_outbox (kind, brevo_contact_id) values ('brevo_delete', old.brevo_contact_id)
      on conflict (brevo_contact_id) where status = 'pending' and kind = 'brevo_delete' do nothing;
    end if;
  end if;
  return null;
end;
$$;
revoke all on function guide.subscribers_brevo_enqueue() from public, anon, authenticated, service_role;

drop trigger if exists subscribers_brevo_enqueue on guide.subscribers;
create trigger subscribers_brevo_enqueue
after insert or update of status, locale, consent_at on guide.subscribers
for each row execute function guide.subscribers_brevo_enqueue();

-- Una petición pg_net por sentencia (no por fila) y solo si se insertó algo. Sin secreto en Vault no hace nada.
-- Un fallo de pg_net nunca bloquea un alta o una baja: el barrido de 5 min recoge el trabajo.
create or replace function guide.outbox_kick()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
begin
  if not exists (select 1 from new_rows) then
    return null;
  end if;
  begin
    select ds.decrypted_secret into v_secret from vault.decrypted_secrets ds where ds.name = 'newsletter_worker_secret' limit 1;
    if v_secret is not null and char_length(v_secret) >= 32 then
      perform net.http_post(
        url := 'https://eqtjlafxtrzbjazhhyin.supabase.co/functions/v1/newsletter-worker',
        body := '{}'::jsonb,
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-worker-secret', v_secret),
        timeout_milliseconds := 30000);
    end if;
  exception when others then
    null;
  end;
  return null;
end;
$$;
revoke all on function guide.outbox_kick() from public, anon, authenticated, service_role;

drop trigger if exists email_outbox_kick on guide.email_outbox;
create trigger email_outbox_kick
after insert on guide.email_outbox
referencing new table as new_rows
for each statement execute function guide.outbox_kick();

-- ───────────── 7. RPC svc_* (solo service_role) ─────────────
create or replace function guide.svc_assert()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if (select auth.role()) is distinct from 'service_role' then
    raise exception 'service only' using errcode = '42501';
  end if;
end;
$$;
revoke all on function guide.svc_assert() from public, anon, authenticated, service_role;

-- Alta desde la EF newsletter-subscribe. Devuelve 'ok' | 'invalid' | 'limit' | 'captcha'; nunca si el email existía (B8).
create or replace function guide.svc_subscribe(
  p_email text, p_locale guide.locale, p_source text, p_consent boolean, p_page text, p_related_consent boolean,
  p_user_id uuid, p_ip_hash text, p_mode text, p_captcha_hash text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(btrim(p_email));
  v_hour  timestamptz := date_trunc('hour', now());
  v_day   timestamptz := date_trunc('day', now(), 'UTC');
  v_n     integer;
  v_h     integer;
  v_d     integer;
  v_id    uuid;
  v_user  boolean := false;
begin
  perform guide.svc_assert();
  if p_mode is null or p_mode not in ('js', 'nojs') or p_ip_hash is null or p_ip_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid argument' using errcode = '22023';
  end if;

  -- B7: una solución ALTCHA, un solo uso (la firma ya la verificó la EF).
  if p_mode = 'js' then
    if p_captcha_hash is null or p_captcha_hash !~ '^[0-9a-f]{64}$' then
      return 'captcha';
    end if;
    insert into guide.captcha_spent (challenge_hash, expires_at)
    values (decode(p_captcha_hash, 'hex'), now() + interval '15 minutes')
    on conflict do nothing;
    get diagnostics v_n = row_count;
    if v_n = 0 then
      return 'captcha';
    end if;
  end if;

  -- B6: cuentan todos los intentos (también los inválidos). Con JS 5/h y 20/día por IP; sin JS 2/día por IP.
  if p_mode = 'js' then
    insert into guide.newsletter_rate as r (bucket, span, window_start, hits) values ('ip:' || p_ip_hash, 'hour', v_hour, 1)
    on conflict (bucket, span, window_start) do update set hits = r.hits + 1 returning r.hits into v_h;
    insert into guide.newsletter_rate as r (bucket, span, window_start, hits) values ('ip:' || p_ip_hash, 'day', v_day, 1)
    on conflict (bucket, span, window_start) do update set hits = r.hits + 1 returning r.hits into v_d;
    if v_h > 5 or v_d > 20 then
      return 'limit';
    end if;
  else
    insert into guide.newsletter_rate as r (bucket, span, window_start, hits) values ('ipnojs:' || p_ip_hash, 'day', v_day, 1)
    on conflict (bucket, span, window_start) do update set hits = r.hits + 1 returning r.hits into v_d;
    if v_d > 2 then
      return 'limit';
    end if;
  end if;

  if p_consent is not true or p_locale is null
     or v_email is null or char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
     or p_source is null or p_source not in ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup',
                                             'newsletter_page', 'noticias') then
    return 'invalid';
  end if;

  -- B9: máximo 3 emails de confirmación en 30 días por dirección, aunque haya re-altas. Respuesta neutra.
  select s.id into v_id from guide.subscribers s where s.email = v_email;
  if v_id is not null and (select count(*) from guide.subscriber_consent_events e
                           where e.subscriber_id = v_id and e.event = 'confirm_sent'
                             and e.occurred_at > now() - interval '30 days') >= 3 then
    return 'ok';
  end if;

  -- H3 / B12: la cuenta solo se vincula si su email coincide (la EF ya validó el JWT con auth.getUser).
  if p_user_id is not null then
    v_user := exists (select 1 from auth.users u where u.id = p_user_id and lower(btrim(u.email)) = v_email);
  end if;

  perform set_config('guide.consent_actor', case when v_user then 'user' else 'anon' end, true);
  perform guide.subscribe_newsletter(v_email, p_locale, p_source, true, p_page, coalesce(p_related_consent, false));
  if v_user then
    update guide.subscribers s set user_id = p_user_id
    where s.email = v_email and s.user_id is null and s.status <> 'erased';
  end if;
  perform set_config('guide.consent_actor', '', true);
  return 'ok';
end;
$$;

-- Cola: toma hasta 20 trabajos vencidos (o colgados > 10 min) con skip locked.
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
  -- Un trabajo colgado que ya agotó intentos no se vuelve a tomar.
  update guide.email_outbox o
  set status = 'failed', last_error = 'max_attempts', lock_id = null, locked_at = null, done_at = now()
  where o.status = 'processing' and o.locked_at < now() - interval '10 minutes' and o.attempts >= 7;

  with c as (
    select o.id from guide.email_outbox o
    where ((o.status = 'pending' and o.next_attempt_at <= now())
           or (o.status = 'processing' and o.locked_at < now() - interval '10 minutes'))
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

-- Bloquea el trabajo de este lock o lanza 55000. Interno.
create or replace function guide.outbox_locked(p_outbox_id bigint, p_lock_id uuid)
returns guide.email_outbox
language plpgsql
set search_path = ''
as $$
declare
  r guide.email_outbox;
begin
  select * into r from guide.email_outbox o
  where o.id = p_outbox_id and o.status = 'processing' and o.lock_id = p_lock_id and p_lock_id is not null
  for update;
  if not found then
    raise exception 'outbox lock lost' using errcode = '55000';
  end if;
  return r;
end;
$$;
revoke all on function guide.outbox_locked(bigint, uuid) from public, anon, authenticated, service_role;

-- Cierra un trabajo sin llamar a Brevo (skipped) o lo reprograma (aplazado por el tope global). Interno.
create or replace function guide.outbox_close(p_outbox_id bigint, p_status guide.outbox_status, p_code text)
returns void
language sql
set search_path = ''
as $$
  update guide.email_outbox
  set status = p_status, last_error = p_code, lock_id = null, locked_at = null, done_at = now()
  where id = p_outbox_id;
$$;
revoke all on function guide.outbox_close(bigint, guide.outbox_status, text) from public, anon, authenticated, service_role;

-- B1/B2/B5/B6/B9/B27: única función que devuelve el token en claro, y solo a service_role, justo antes del envío.
-- 'ok' {email, locale, token} | 'skip' (cerrado aquí con su código) | 'defer' (tope global: mañana).
create or replace function guide.svc_issue_confirm_token(p_outbox_id bigint, p_lock_id uuid, p_allowlist text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o       guide.email_outbox;
  s       record;
  v_today timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v_token text;
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if o.kind <> 'confirm_email' then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  select x.id, x.status, x.email, x.locale, x.confirm_sends into s
  from guide.subscribers x where x.id = o.subscriber_id for update;
  if not found or s.status <> 'pending' then
    perform guide.outbox_close(o.id, 'skipped', 'stale_state');
    return jsonb_build_object('result', 'skip');
  end if;
  if s.confirm_sends >= 2 or (select count(*) from guide.subscriber_consent_events e
                              where e.subscriber_id = s.id and e.event = 'confirm_sent'
                                and e.occurred_at > now() - interval '30 days') >= 3 then
    perform guide.outbox_close(o.id, 'skipped', 'email_cap');
    return jsonb_build_object('result', 'skip');
  end if;
  if coalesce(cardinality(p_allowlist), 0) > 0
     and not (s.email = any (array(select lower(btrim(a)) from unnest(p_allowlist) a))) then
    perform guide.outbox_close(o.id, 'skipped', 'not_allowed_test');
    return jsonb_build_object('result', 'skip');
  end if;
  -- B6: tope global de 100 emails de confirmación al día (Europe/Madrid). El alta sigue pending; se envía mañana.
  if (select count(*) from guide.subscriber_consent_events e
      where e.event = 'confirm_sent' and e.occurred_at >= v_today) >= 100 then
    update guide.email_outbox
    set status = 'pending', lock_id = null, locked_at = null, last_error = 'global_cap',
        next_attempt_at = v_today + interval '1 day' + interval '5 minutes'
    where id = o.id;
    return jsonb_build_object('result', 'defer');
  end if;

  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
  update guide.subscribers
  set confirm_token_hash = pg_catalog.sha256(convert_to(v_token, 'UTF8')), confirm_expires_at = now() + interval '48 hours'
  where id = s.id;
  perform set_config('guide.consent_actor', '', true);
  return jsonb_build_object('result', 'ok', 'email', s.email, 'locale', s.locale, 'token', v_token);
end;
$$;

-- Estado vigente para brevo_sync (email solo si active) o comprobación L2 para brevo_delete.
create or replace function guide.svc_outbox_target(p_outbox_id bigint, p_lock_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o guide.email_outbox;
  s record;
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if o.kind = 'brevo_sync' then
    select x.status, x.email, x.locale, x.brevo_contact_id into s from guide.subscribers x where x.id = o.subscriber_id;
    if not found then
      return jsonb_build_object('status', null);
    end if;
    return jsonb_build_object('status', s.status, 'email', case when s.status = 'active' then s.email end,
                              'locale', s.locale, 'brevo_contact_id', s.brevo_contact_id);
  elsif o.kind = 'brevo_delete' then
    -- L2: si una fila active tiene ese contacto (re-alta ya sincronizada), no se borra.
    return jsonb_build_object('contact_id', o.brevo_contact_id,
      'stale', exists (select 1 from guide.subscribers x where x.brevo_contact_id = o.brevo_contact_id and x.status = 'active'));
  end if;
  raise exception 'invalid argument' using errcode = '22023';
end;
$$;

-- Cierra un trabajo ('done' | 'skipped'). L1: brevo_sync relee la fila con for update y, si ya no está active, encola
-- el borrado del contacto que acaba de crear. L2: brevo_delete solo limpia el id en filas que no estén active.
create or replace function guide.svc_outbox_done(p_outbox_id bigint, p_lock_id uuid, p_result text, p_code text,
                                                 p_brevo_contact_id bigint, p_message_id text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o     guide.email_outbox;
  s       record;
  v_out   text := 'done';
  v_found boolean;
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if p_result is null or p_result not in ('done', 'skipped') or (p_result = 'skipped' and p_code is null)
     or (p_code is not null and p_code not in ('brevo_404', 'not_allowed_test', 'stale_state', 'email_cap', 'config')) then
    raise exception 'invalid argument' using errcode = '22023';
  end if;

  if p_result = 'skipped' then
    perform guide.outbox_close(o.id, 'skipped', p_code);
    return 'skipped';
  end if;

  if o.kind = 'confirm_email' then
    if p_message_id is null or char_length(p_message_id) > 200 or p_message_id !~ '^<?[A-Za-z0-9._%+=@-]+>?$' then
      raise exception 'invalid argument' using errcode = '22023';
    end if;
    update guide.email_outbox set brevo_message_id = p_message_id where id = o.id;
    select x.id, x.status, x.locale, x.confirm_sends into s from guide.subscribers x where x.id = o.subscriber_id for update;
    v_found := found;
    if v_found and s.status = 'pending' then
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers set confirm_sends = least(s.confirm_sends + 1, 2), confirm_sent_at = now() where id = s.id;
      perform set_config('guide.consent_actor', '', true);
    end if;
    if v_found then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (s.id, 'confirm_sent', 'brevo', s.locale, 'service');
    end if;

  elsif o.kind = 'brevo_sync' then
    if p_brevo_contact_id is null or p_brevo_contact_id <= 0 then
      raise exception 'invalid argument' using errcode = '22023';
    end if;
    select x.id, x.status into s from guide.subscribers x where x.id = o.subscriber_id for update;
    if found and s.status = 'active' then
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers
      set brevo_contact_id = p_brevo_contact_id, brevo_sync_status = 'synced', brevo_sync_error = null, synced_at = now()
      where id = s.id;
      perform set_config('guide.consent_actor', '', true);
    else
      insert into guide.email_outbox (kind, brevo_contact_id) values ('brevo_delete', p_brevo_contact_id)
      on conflict (brevo_contact_id) where status = 'pending' and kind = 'brevo_delete' do nothing;
      v_out := 'deleted_stale';
    end if;

  else
    for s in select x.id from guide.subscribers x
             where x.brevo_contact_id = o.brevo_contact_id and x.status not in ('active', 'erased')
             for update
    loop
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers set brevo_contact_id = null, brevo_sync_status = 'not_synced', brevo_sync_error = null,
                                   synced_at = now()
      where id = s.id;
    end loop;
    perform set_config('guide.consent_actor', '', true);
  end if;

  update guide.email_outbox
  set status = 'done', last_error = p_code, lock_id = null, locked_at = null, done_at = now()
  where id = o.id;
  return v_out;
end;
$$;

-- Reintento con backoff (1, 5, 15, 60, 180, 360, 720 min); al 8.º intento, failed (L10: un brevo_delete failed
-- bloquea el envío y avisa en «Sistema»).
create or replace function guide.svc_outbox_fail(p_outbox_id bigint, p_lock_id uuid, p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o       guide.email_outbox;
  c_delay constant integer[] := array[1, 5, 15, 60, 180, 360, 720];
  v_att   integer;
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if p_code is null or p_code not in ('brevo_4xx', 'brevo_429', 'brevo_5xx', 'timeout', 'network', 'quota', 'config') then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  v_att := least(o.attempts + 1, 8);
  if v_att >= 8 then
    update guide.email_outbox
    set status = 'failed', attempts = v_att, last_error = p_code, lock_id = null, locked_at = null, done_at = now()
    where id = o.id;
    return 'failed';
  end if;
  update guide.email_outbox
  set status = 'pending', attempts = v_att, last_error = p_code, lock_id = null, locked_at = null,
      next_attempt_at = now() + make_interval(mins => c_delay[v_att])
  where id = o.id;
  return 'retry';
end;
$$;

-- Webhook de marketing y reconciliación L3: solo baja estados y exige id de contacto y email coincidentes (B20).
create or replace function guide.svc_apply_brevo_event(p_event text, p_contact_id bigint, p_email text, p_event_at timestamptz)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  s        record;
  v_to     guide.subscriber_status;
  v_source text;
begin
  perform guide.svc_assert();
  if p_event is null or p_event not in ('unsubscribed', 'hardBounce', 'spam', 'blocked')
     or p_contact_id is null or p_email is null then
    return 'ignored';
  end if;
  select x.id, x.status into s from guide.subscribers x
  where x.brevo_contact_id = p_contact_id and x.email = lower(btrim(p_email)) and x.status = 'active'
  for update;
  if not found then
    return 'ignored';
  end if;
  v_to := case when p_event in ('unsubscribed', 'spam') then 'unsubscribed' else 'bounced' end;
  v_source := case p_event when 'unsubscribed' then 'brevo' when 'spam' then 'complaint' end;
  perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
  update guide.subscribers
  set status = v_to,
      unsubscribed_at = case when v_to = 'unsubscribed' then least(coalesce(p_event_at, now()), now()) end,
      unsubscribe_source = v_source,
      confirm_token_hash = null, confirm_expires_at = null
  where id = s.id;
  perform set_config('guide.consent_actor', '', true);
  return 'applied';
end;
$$;

-- L4: webhook transaccional (email de confirmación). Exige messageId del outbox y email coincidentes.
create or replace function guide.svc_apply_brevo_tx_event(p_event text, p_message_id text, p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  s        record;
  v_to     guide.subscriber_status;
begin
  perform guide.svc_assert();
  if p_event is null or p_event not in ('hardBounce', 'spam', 'blocked') or p_message_id is null or p_email is null
     or char_length(p_message_id) > 200 then
    return 'ignored';
  end if;
  select x.id, x.status into s
  from guide.email_outbox o join guide.subscribers x on x.id = o.subscriber_id
  where o.kind = 'confirm_email' and o.brevo_message_id = p_message_id and x.email = lower(btrim(p_email))
    and x.status in ('pending', 'active')
  limit 1
  for update of x;
  if not found then
    return 'ignored';
  end if;
  v_to := case when p_event = 'spam' then 'unsubscribed' else 'bounced' end;
  perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
  update guide.subscribers
  set status = v_to,
      unsubscribed_at = case when v_to = 'unsubscribed' then now() end,
      unsubscribe_source = case when v_to = 'unsubscribed' then 'complaint' end,
      confirm_token_hash = null, confirm_expires_at = null
  where id = s.id;
  perform set_config('guide.consent_actor', '', true);
  return 'applied';
end;
$$;

-- L3: tras el preflight, reencola la sincronización de activos que faltan en la lista de Brevo y el borrado de
-- contactos que sobran y pertenecen a una fila que no está active. Devuelve cuántos encoló.
create or replace function guide.svc_outbox_resync(p_subscriber_ids uuid[], p_contact_ids bigint[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sync integer;
  v_del  integer;
begin
  perform guide.svc_assert();
  if coalesce(cardinality(p_subscriber_ids), 0) > 5000 or coalesce(cardinality(p_contact_ids), 0) > 5000 then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  insert into guide.email_outbox (kind, subscriber_id)
  select 'brevo_sync', s.id from guide.subscribers s
  where s.id = any (coalesce(p_subscriber_ids, '{}')) and s.status = 'active'
  on conflict (kind, subscriber_id) where status = 'pending' and kind in ('confirm_email', 'brevo_sync') do nothing;
  get diagnostics v_sync = row_count;
  insert into guide.email_outbox (kind, brevo_contact_id)
  select distinct c from unnest(coalesce(p_contact_ids, '{}')) c
  where c > 0 and not exists (select 1 from guide.subscribers s where s.brevo_contact_id = c and s.status = 'active')
  on conflict (brevo_contact_id) where status = 'pending' and kind = 'brevo_delete' do nothing;
  get diagnostics v_del = row_count;
  return jsonb_build_object('sync', v_sync, 'delete', v_del);
end;
$$;

-- ───────────── 8. Reenviar confirmación (público, neutro) ─────────────
create or replace function guide.request_confirm_resend(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return 'invalid';
  end if;
  -- B5: una vez por alta y como mucho 2 emails de confirmación por alta. El enlace nuevo invalida el anterior.
  update guide.subscribers s set confirm_resend_used = true
  where s.confirm_token_hash = pg_catalog.sha256(convert_to(p_token, 'UTF8'))
    and s.status = 'pending' and not s.confirm_resend_used and s.confirm_sends < 2
  returning s.id into v_id;
  if v_id is not null then
    insert into guide.email_outbox (kind, subscriber_id) values ('confirm_email', v_id)
    on conflict (kind, subscriber_id) where status = 'pending' and kind in ('confirm_email', 'brevo_sync') do nothing;
  end if;
  return 'ok';
end;
$$;

-- ───────────── 9. Cron: barrido, caducidad, purga y salud ─────────────
create or replace function guide.run_outbox_sweep()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_id     bigint;
begin
  if not exists (select 1 from guide.email_outbox o
                 where (o.status = 'pending' and o.next_attempt_at <= now())
                    or (o.status = 'processing' and o.locked_at < now() - interval '10 minutes')) then
    return null;
  end if;
  select ds.decrypted_secret into v_secret from vault.decrypted_secrets ds where ds.name = 'newsletter_worker_secret' limit 1;
  if v_secret is not null and char_length(v_secret) >= 32 then
    select net.http_post(
             url := 'https://eqtjlafxtrzbjazhhyin.supabase.co/functions/v1/newsletter-worker',
             body := '{}'::jsonb,
             headers := jsonb_build_object('Content-Type', 'application/json', 'x-worker-secret', v_secret),
             timeout_milliseconds := 60000)
      into v_id;
  end if;
  insert into guide.job_health (job, request_id) values ('newsletter-worker', v_id)
  on conflict (job) do update set request_id = excluded.request_id;
  return v_id;
end;
$$;

create or replace function guide.run_subscribers_expire()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  begin
    v := guide.expire_pending_subscribers();
    insert into guide.job_health (job, checked_at, status_code, details) values ('subscribers-expire', now(), 200, v)
    on conflict (job) do update set checked_at = excluded.checked_at, status_code = 200, details = excluded.details;
  exception when others then
    insert into guide.job_health (job, checked_at, status_code, details)
    values ('subscribers-expire', now(), 500, jsonb_build_object('alerts', jsonb_build_array('expire_failed')))
    on conflict (job) do update set checked_at = excluded.checked_at, status_code = 500, details = excluded.details;
  end;
  return v;
end;
$$;

-- Purga (outbox done/skipped 7 días, failed 30; contadores 48 h; retos gastados caducados) y señal 'newsletter_email'
-- en job_health (solo recuentos y códigos).
create or replace function guide.purge_newsletter_queue()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today   timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v_n       bigint := 0;
  v_k       bigint;
  v_failed  integer;
  v_fdel    integer;
  v_stuck   integer;
  v_sent    integer;
  v_alerts  jsonb := '[]'::jsonb;
begin
  delete from guide.email_outbox where status in ('done', 'skipped') and done_at < now() - interval '7 days';
  get diagnostics v_k = row_count; v_n := v_n + v_k;
  delete from guide.email_outbox where status = 'failed' and done_at < now() - interval '30 days';
  get diagnostics v_k = row_count; v_n := v_n + v_k;
  delete from guide.newsletter_rate where window_start < now() - interval '48 hours';
  delete from guide.captcha_spent where expires_at < now();

  select count(*) filter (where status = 'failed'),
         count(*) filter (where status = 'failed' and kind = 'brevo_delete'),
         count(*) filter (where status in ('pending', 'processing') and created_at < now() - interval '1 hour'
                          and coalesce(last_error, '') <> 'global_cap')
  into v_failed, v_fdel, v_stuck
  from guide.email_outbox;
  select count(*) into v_sent from guide.subscriber_consent_events e where e.event = 'confirm_sent' and e.occurred_at >= v_today;

  if v_fdel > 0 then v_alerts := v_alerts || '"gdpr_delete_failed"'::jsonb; end if;
  if v_failed > v_fdel then v_alerts := v_alerts || '"outbox_failed"'::jsonb; end if;
  if v_stuck > 0 then v_alerts := v_alerts || '"outbox_stuck"'::jsonb; end if;
  if v_sent >= 100 then v_alerts := v_alerts || '"confirm_global_cap"'::jsonb; end if;

  insert into guide.job_health (job, checked_at, status_code, details)
  values ('newsletter_email', now(), case when jsonb_array_length(v_alerts) > 0 then 500 else 200 end,
          jsonb_build_object('alerts', v_alerts, 'failed', v_failed, 'failed_deletes', v_fdel, 'stuck', v_stuck,
                             'confirm_sent_today', v_sent, 'confirm_cap_per_day', 100, 'purged_rows', v_n))
  on conflict (job) do update set checked_at = excluded.checked_at, status_code = excluded.status_code,
                                  details = excluded.details;
  return v_n;
end;
$$;

-- ───────────── 10. Panel (solo admin) ─────────────
create or replace function guide.admin_email_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v       jsonb;
begin
  perform guide.assert_admin();
  select jsonb_build_object(
    'outbox', coalesce((select jsonb_agg(jsonb_build_object('kind', t.kind, 'status', t.status, 'code', t.last_error, 'n', t.n)
                                         order by t.kind, t.status, t.last_error)
                        from (select o.kind, o.status, o.last_error, count(*) n from guide.email_outbox o
                              group by o.kind, o.status, o.last_error) t), '[]'::jsonb),
    'oldest_pending_at', (select min(o.created_at) from guide.email_outbox o where o.status in ('pending', 'processing')),
    'failed_deletes', (select count(*) from guide.email_outbox o where o.kind = 'brevo_delete' and o.status = 'failed'),
    'confirm_sent_today', (select count(*) from guide.subscriber_consent_events e
                           where e.event = 'confirm_sent' and e.occurred_at >= v_today),
    'confirm_cap_per_day', 100,
    'last_confirm_sent_at', (select max(e.occurred_at) from guide.subscriber_consent_events e where e.event = 'confirm_sent'),
    'active_es', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'es'),
    'active_en', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'en'),
    'active_unsynced', (select count(*) from guide.subscribers s where s.status = 'active' and s.brevo_sync_status <> 'synced'))
  into v;
  return v;
end;
$$;

-- Reintentar los trabajos en failed (p. ej. tras arreglar la clave de Brevo). Solo admin.
create or replace function guide.admin_email_retry_failed()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v integer;
begin
  perform guide.assert_admin();
  update guide.email_outbox
  set status = 'pending', attempts = 0, last_error = null, done_at = null, next_attempt_at = now()
  where status = 'failed'
    and not (kind in ('confirm_email', 'brevo_sync')
             and exists (select 1 from guide.email_outbox p where p.kind = email_outbox.kind
                         and p.subscriber_id = email_outbox.subscriber_id and p.status = 'pending'))
    and not (kind = 'brevo_delete'
             and exists (select 1 from guide.email_outbox p where p.kind = 'brevo_delete'
                         and p.brevo_contact_id = email_outbox.brevo_contact_id and p.status = 'pending'));
  get diagnostics v = row_count;
  return v;
end;
$$;

-- ───────────── 11. EXECUTE ─────────────
do $$
declare
  f text;
begin
  foreach f in array array[
    'guide.svc_subscribe(text, guide.locale, text, boolean, text, boolean, uuid, text, text, text)',
    'guide.svc_outbox_claim(integer, uuid)',
    'guide.svc_issue_confirm_token(bigint, uuid, text[])',
    'guide.svc_outbox_target(bigint, uuid)',
    'guide.svc_outbox_done(bigint, uuid, text, text, bigint, text)',
    'guide.svc_outbox_fail(bigint, uuid, text)',
    'guide.svc_apply_brevo_event(text, bigint, text, timestamptz)',
    'guide.svc_apply_brevo_tx_event(text, text, text)',
    'guide.svc_outbox_resync(uuid[], bigint[])'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  foreach f in array array['guide.admin_email_health()', 'guide.admin_email_retry_failed()'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  execute 'revoke all on function guide.request_confirm_resend(text) from public, anon, authenticated, service_role';
  execute 'grant execute on function guide.request_confirm_resend(text) to anon, authenticated';
  foreach f in array array['guide.run_outbox_sweep()', 'guide.run_subscribers_expire()', 'guide.purge_newsletter_queue()',
                           'guide.subscribers_guard()', 'guide.subscribers_related_guard()', 'guide.subscribers_log_consent()',
                           'guide.subscribers_log_status()', 'guide.expire_pending_subscribers()'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
  end loop;
end $$;

-- ───────────── 12. Jobs (cron.schedule con el mismo nombre actualiza el job: idempotente) ─────────────
select cron.schedule('guide-outbox-sweep', '*/5 * * * *', $$select guide.run_outbox_sweep()$$);
select cron.schedule('guide-subscribers-expire', '20 2 * * *', $$select guide.run_subscribers_expire()$$);
select cron.schedule('guide-newsletter-queue-purge', '45 * * * *', $$select guide.purge_newsletter_queue()$$);
