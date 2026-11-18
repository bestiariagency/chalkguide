-- D22 · Newsletter en artículo: dos orígenes de consentimiento nuevos.
--   article_mid  tarjeta clara a mitad de artículo (artículos ≥ 7 min, README §9.9.5)
--   article_end  bloque al final del artículo
-- 'article' se mantiene por compatibilidad (altas anteriores y clientes viejos).
-- subscribe_newsletter: misma función, solo cambia la lista blanca de p_source (admin_import sigue fuera:
-- es solo del panel). CREATE OR REPLACE conserva propietario, SECURITY DEFINER y GRANTs.

alter table guide.subscribers drop constraint if exists subscribers_consent_source_check;
alter table guide.subscribers add constraint subscribers_consent_source_check check (
  consent_source = any (array['footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup', 'admin_import'])
);

create or replace function guide.subscribe_newsletter(p_email text, p_locale guide.locale, p_source text, p_consent boolean, p_page text default null)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
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
  if p_source is null or p_source not in ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup') then
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
$function$;
