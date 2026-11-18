-- F6.14 · O4 de leona-lia: subscribe_newsletter guarda consent_page sin query string ni fragmento. Misma firma y
-- mismo comportamiento en lo demás (ver guide_f614_newsletter_public). Idempotente.

create or replace function guide.subscribe_newsletter(p_email text, p_locale guide.locale, p_source text, p_consent boolean,
                                                      p_page text default null)
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

revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) from public;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) to anon, authenticated;
