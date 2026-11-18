-- F6.14 (D35) · Suscriptores, parte 6: RPC públicas.
-- · subscribe_newsletter: al re-suscribir (baja, rebotado, caducado o pendiente de > 24 h) limpia confirmed_at,
--   unsubscribed_at y unsubscribe_source (la historia queda en subscriber_consent_events), rota el token de baja y
--   emite un token de confirmación nuevo del que solo se guarda el SHA-256, con caducidad de 48 h. El token en claro
--   no sale de la función: el envío del email es F4.6 y tendrá que emitirlo desde el servidor (service_role).
-- · confirm_newsletter(p_token): anon/authenticated; respuesta neutra 'ok' | 'expired' | 'invalid' (nunca el email).
-- · unsubscribe_newsletter: solo desde pending/active/bounced; borra el token de confirmación.
-- Firmas públicas sin cambios (subscribe/unsubscribe). Idempotente.

create or replace function guide.subscribe_newsletter(p_email text, p_locale guide.locale, p_source text, p_consent boolean,
                                                      p_page text default null)
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
  v_hash    bytea := pg_catalog.sha256(convert_to(encode(extensions.gen_random_bytes(32), 'hex'), 'UTF8'));
begin
  if p_consent is not true then
    raise exception 'consent required' using errcode = '22023';
  end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if p_source is null or p_source not in ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup') then
    raise exception 'invalid source' using errcode = '22023';
  end if;

  if v_uid is not null and exists (
    select 1 from auth.users u where u.id = v_uid and lower(btrim(u.email)) = v_email
  ) then
    v_link := v_uid;
  end if;

  select consent_version into v_version from guide.site_settings where id = 1;

  insert into guide.subscribers (email, status, locale, consent_at, consent_source, consent_version, consent_page, user_id,
                                 confirm_token_hash, confirm_expires_at)
  values (v_email, 'pending', coalesce(p_locale, 'es'), now(), p_source, coalesce(v_version, 1), v_page, v_link,
          v_hash, now() + interval '48 hours')
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
        unsubscribe_token  = gen_random_uuid(),
        confirm_token_hash = excluded.confirm_token_hash,
        confirm_expires_at = excluded.confirm_expires_at
    where guide.subscribers.status in ('unsubscribed', 'bounced', 'expired')
       or (guide.subscribers.status = 'pending' and guide.subscribers.consent_at < now() - interval '24 hours');
end;
$$;

create or replace function guide.confirm_newsletter(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_status  guide.subscriber_status;
  v_expires timestamptz;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return 'invalid';
  end if;
  select s.id, s.status, s.confirm_expires_at into v_id, v_status, v_expires
  from guide.subscribers s
  where s.confirm_token_hash = pg_catalog.sha256(convert_to(p_token, 'UTF8'))
  for update;
  if v_id is null then
    return 'invalid';
  end if;
  if v_status = 'active' then
    return 'ok';                       -- segundo clic en el mismo enlace
  end if;
  if v_status <> 'pending' then
    return 'invalid';
  end if;
  if v_expires < now() then
    return 'expired';
  end if;
  update guide.subscribers set status = 'active', confirmed_at = now() where id = v_id;
  return 'ok';
end;
$$;

create or replace function guide.unsubscribe_newsletter(p_token uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_token is null then
    return;
  end if;
  update guide.subscribers
  set status = 'unsubscribed', unsubscribed_at = now(), unsubscribe_source = 'link',
      confirm_token_hash = null, confirm_expires_at = null
  where unsubscribe_token = p_token and status in ('pending', 'active', 'bounced');
end;
$$;

revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) from public;
revoke all on function guide.confirm_newsletter(text) from public;
revoke all on function guide.unsubscribe_newsletter(uuid) from public;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) to anon, authenticated;
grant execute on function guide.confirm_newsletter(text) to anon, authenticated;
grant execute on function guide.unsubscribe_newsletter(uuid) to anon, authenticated;
