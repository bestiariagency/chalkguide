-- F2.10 · Correcciones de leona-lia: H2 (prueba RGPD append-only) y H3 (user_id solo si el email coincide).
-- Sin IP ni user-agent (minimización). Rate limit y captcha: Edge Function de F4.6 (H6).

create table if not exists guide.subscriber_consent_events (
  id              bigint generated always as identity primary key,
  subscriber_id   uuid not null references guide.subscribers (id) on delete cascade,
  occurred_at     timestamptz not null default now(),
  event           text not null check (event in ('subscribe', 'confirm', 'unsubscribe', 'bounce')),
  source          text check (char_length(source) <= 40),
  consent_version integer,
  locale          guide.locale,
  page            text check (char_length(page) <= 300),
  actor           text not null check (actor in ('anon', 'user', 'admin', 'service'))
);
alter table guide.subscriber_consent_events enable row level security;
create index if not exists subscriber_consent_events_subscriber_idx
  on guide.subscriber_consent_events (subscriber_id, occurred_at);

grant select on guide.subscriber_consent_events to authenticated;
grant select, insert on guide.subscriber_consent_events to service_role;

drop policy if exists subscriber_consent_events_select on guide.subscriber_consent_events;
create policy subscriber_consent_events_select on guide.subscriber_consent_events
  for select to authenticated using ((select guide.is_admin()));

-- Append-only: nunca UPDATE; DELETE solo en cascada al suprimir al suscriptor (derecho de supresión).
create or replace function guide.subscriber_consent_events_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'subscriber_consent_events is append-only' using errcode = '42501';
  end if;
  if exists (select 1 from guide.subscribers s where s.id = old.subscriber_id) then
    raise exception 'subscriber_consent_events is append-only' using errcode = '42501';
  end if;
  return old;
end;
$$;
revoke execute on function guide.subscriber_consent_events_guard() from public;

drop trigger if exists subscriber_consent_events_guard on guide.subscriber_consent_events;
create trigger subscriber_consent_events_guard before update or delete on guide.subscriber_consent_events
  for each row execute function guide.subscriber_consent_events_guard();

-- Registra cada consentimiento, confirmación, baja y rebote, venga de la RPC, del panel o de la Edge Function.
create or replace function guide.subscribers_log_consent()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claims jsonb := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  v_actor  text;
begin
  v_actor := case
    when (select guide.is_admin()) then 'admin'
    when (select auth.uid()) is not null then 'user'
    when v_claims ->> 'role' = 'service_role' then 'service'
    else 'anon'
  end;

  if tg_op = 'INSERT' or new.consent_at is distinct from old.consent_at then
    insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, consent_version, locale, page, actor)
    values (new.id, new.consent_at, 'subscribe', new.consent_source, new.consent_version, new.locale, new.consent_page, v_actor);
  end if;

  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'active' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor)
      values (new.id, coalesce(new.confirmed_at, now()), 'confirm', 'double_opt_in', new.locale, v_actor);
    elsif new.status = 'unsubscribed' then
      insert into guide.subscriber_consent_events (subscriber_id, occurred_at, event, source, locale, actor)
      values (new.id, coalesce(new.unsubscribed_at, now()), 'unsubscribe', new.unsubscribe_source, new.locale, v_actor);
    elsif new.status = 'bounced' then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (new.id, 'bounce', 'brevo', new.locale, v_actor);
    end if;
  end if;
  return null;
end;
$$;
revoke execute on function guide.subscribers_log_consent() from public;

drop trigger if exists subscribers_log_consent on guide.subscribers;
create trigger subscribers_log_consent after insert or update on guide.subscribers
  for each row execute function guide.subscribers_log_consent();

-- subscribe_newsletter:
-- H2: re-suscribir no borra unsubscribed_at/unsubscribe_source/confirmed_at (la historia completa está en
--     subscriber_consent_events). Una fila 'pending' de < 24 h no se toca (no reenvía confirmaciones en bucle).
-- H3: user_id solo si el email de auth.users del llamante coincide con p_email.
create or replace function guide.subscribe_newsletter(
  p_email   text,
  p_locale  guide.locale,
  p_source  text,
  p_consent boolean,
  p_page    text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email   text := lower(btrim(p_email));
  v_page    text := case when p_page ~ '^/' then left(p_page, 300) end;
  v_uid     uuid := (select auth.uid());
  v_link    uuid;
  v_version integer;
begin
  if p_consent is not true then
    raise exception 'consent required' using errcode = '22023';
  end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if p_source is null or p_source not in ('footer', 'article', 'item_page', 'home', 'popup') then
    raise exception 'invalid source' using errcode = '22023';
  end if;

  if v_uid is not null and exists (
    select 1 from auth.users u where u.id = v_uid and lower(btrim(u.email)) = v_email
  ) then
    v_link := v_uid;
  end if;

  select consent_version into v_version from guide.site_settings where id = 1;

  insert into guide.subscribers (email, status, locale, consent_at, consent_source, consent_version, consent_page, user_id)
  values (v_email, 'pending', coalesce(p_locale, 'es'), now(), p_source, coalesce(v_version, 1), v_page, v_link)
  on conflict (email) do update
    set status          = 'pending',
        locale          = excluded.locale,
        consent_at      = excluded.consent_at,
        consent_source  = excluded.consent_source,
        consent_version = excluded.consent_version,
        consent_page    = excluded.consent_page,
        user_id         = coalesce(guide.subscribers.user_id, excluded.user_id)
    where guide.subscribers.status in ('unsubscribed', 'bounced')
       or (guide.subscribers.status = 'pending' and guide.subscribers.consent_at < now() - interval '24 hours');
end;
$$;
revoke execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) from public;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) to anon, authenticated, service_role;
