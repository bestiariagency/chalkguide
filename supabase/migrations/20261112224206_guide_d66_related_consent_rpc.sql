-- D66 · Consentimiento de afines, parte 3: RPC públicas (alta con casilla opcional, confirmación, dar/retirar con token,
-- preferencias) y lectura del panel (listado, ficha, series del historial solo de la newsletter). Idempotente.

-- ── Alta: parámetro opcional p_related_consent (desmarcado por defecto). Nueva firma: se borra la de 5 argumentos. ──
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
        unsubscribe_token  = gen_random_uuid(),
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
revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean) from public;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  to anon, authenticated, service_role;

-- ── Confirmación: el doble opt-in verifica el email y activa también afines pendiente ──
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
  update guide.subscribers
  set status = 'active', confirmed_at = now(),
      related_status       = case when related_status = 'pending' then 'granted' else related_status end,
      related_confirmed_at = case when related_status = 'pending' then now() else related_confirmed_at end
  where id = v_id;
  return 'ok';
end;
$$;
revoke all on function guide.confirm_newsletter(text) from public;
grant execute on function guide.confirm_newsletter(text) to anon, authenticated;

-- ── Token → fila (interno). Acepta el token de confirmación vigente de un activo (página tras el doble opt-in) o el
-- unsubscribe_token (enlace de los emails / centro de preferencias). Nunca fila suprimida. ──
create or replace function guide.subscriber_by_token(p_token text)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare v_id uuid;
begin
  if p_token is null then
    return null;
  end if;
  if p_token ~ '^[0-9a-f]{64}$' then
    select s.id into v_id from guide.subscribers s
    where s.confirm_token_hash = pg_catalog.sha256(convert_to(p_token, 'UTF8'))
      and s.status = 'active' and s.confirm_expires_at > now();
  elsif p_token ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    select s.id into v_id from guide.subscribers s
    where s.unsubscribe_token = p_token::uuid and s.status <> 'erased';
  end if;
  return v_id;
end;
$$;
revoke all on function guide.subscriber_by_token(text) from public, anon, authenticated, service_role;

-- ── Dar o retirar afines con token (tras confirmar). Sin fechas ni versión desde el cliente. ──
-- p_channel: 'preferences' (centro de preferencias) o 'link' (baja en un clic del email; solo retirar).
-- Devuelve 'ok' | 'invalid' (token) | 'unconfirmed' (dar exige un email ya verificado y no rebotado).
create or replace function guide.set_related_consent(p_token text, p_granted boolean, p_channel text default 'preferences')
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id     uuid;
  v_status guide.subscriber_status;
  v_conf   timestamptz;
  v_rel    guide.related_consent_status;
  v_ver    integer;
begin
  if p_granted is null or p_channel is null or p_channel not in ('preferences', 'link')
     or (p_channel = 'link' and p_granted) then
    raise exception 'invalid request' using errcode = '22023';
  end if;
  v_id := guide.subscriber_by_token(p_token);
  if v_id is null then
    return 'invalid';
  end if;
  select s.status, s.confirmed_at, s.related_status into v_status, v_conf, v_rel
  from guide.subscribers s where s.id = v_id for update;

  if p_granted then
    if v_rel = 'granted' then
      return 'ok';
    end if;
    if v_conf is null or v_status not in ('active', 'unsubscribed') then
      return 'unconfirmed';
    end if;
    select related_consent_version into v_ver from guide.site_settings where id = 1;
    update guide.subscribers
    set related_status = 'granted', related_consent_at = now(), related_consent_source = 'preferences',
        related_consent_version = coalesce(v_ver, 1), related_confirmed_at = now()
    where id = v_id;
  elsif v_rel in ('granted', 'pending') then
    update guide.subscribers
    set related_status = 'withdrawn', related_withdrawn_at = now(), related_withdraw_source = p_channel
    where id = v_id;
  end if;
  return 'ok';
end;
$$;
revoke all on function guide.set_related_consent(text, boolean, text) from public, anon, authenticated, service_role;
grant execute on function guide.set_related_consent(text, boolean, text) to anon, authenticated;

-- ── Estado para el centro de preferencias. Sin email ni fechas. null si el token no vale. ──
create or replace function guide.get_consent_preferences(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id uuid := guide.subscriber_by_token(p_token);
  s    guide.subscribers%rowtype;
begin
  if v_id is null then
    return null;
  end if;
  select * into s from guide.subscribers where id = v_id;
  return jsonb_build_object(
    'newsletter', case s.status when 'active' then 'active' when 'pending' then 'pending' else 'inactive' end,
    'related_products', case s.related_status when 'granted' then 'granted' when 'pending' then 'pending' else 'none' end,
    'can_grant_related', s.related_status <> 'granted' and s.confirmed_at is not null
                         and s.status in ('active', 'unsubscribed'),
    'locale', s.locale);
end;
$$;
revoke all on function guide.get_consent_preferences(text) from public, anon, authenticated, service_role;
grant execute on function guide.get_consent_preferences(text) to anon, authenticated;

-- ── Panel: listado con afines y retención unificada; motivo de baja solo de la newsletter ──
create or replace function guide.admin_list_subscribers(
  p_view text default 'active', p_query text default null, p_sources text[] default null,
  p_locale guide.locale default null, p_date_field text default 'consent', p_from timestamptz default null,
  p_to timestamptz default null, p_versions integer[] default null, p_statuses guide.subscriber_status[] default null,
  p_sort text default 'consent_at_desc', p_limit integer default 25, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q    text;
  v_like text;
  v_df   text := coalesce(p_date_field, 'consent');
  v_sort text := coalesce(p_sort, 'consent_at_desc');
  v      jsonb;
begin
  perform guide.assert_admin();

  if p_view is null or p_view not in ('active', 'pending', 'unsubscribed', 'all') then
    raise exception 'invalid view' using errcode = '22023';
  end if;
  if p_query is not null then
    if char_length(p_query) > 200 then
      raise exception 'query too long' using errcode = '22023';
    end if;
    v_q := nullif(lower(btrim(p_query)), '');
    if v_q is not null then
      v_like := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    end if;
  end if;
  if v_df not in ('consent', 'confirmed', 'unsubscribed') then
    raise exception 'invalid date field' using errcode = '22023';
  end if;
  if p_from is not null and p_to is not null and p_from > p_to then
    raise exception 'invalid range' using errcode = '22023';
  end if;
  if coalesce(cardinality(p_sources), 0) > 20 or coalesce(cardinality(p_versions), 0) > 50
     or coalesce(cardinality(p_statuses), 0) > 10 then
    raise exception 'too many filter values' using errcode = '22023';
  end if;
  if v_sort not in ('consent_at_desc', 'consent_at_asc', 'confirmed_at_desc', 'confirmed_at_asc',
                    'unsubscribed_at_desc', 'unsubscribed_at_asc', 'updated_at_desc', 'updated_at_asc',
                    'email_asc', 'email_desc') then
    raise exception 'invalid sort' using errcode = '22023';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  if p_offset is null or p_offset < 0 or p_offset > 100000 then
    raise exception 'invalid offset' using errcode = '22023';
  end if;

  with base as (
    select s.id, s.email, s.status, s.locale, s.consent_source, s.consent_version, s.consent_at, s.confirmed_at,
           s.unsubscribed_at, s.unsubscribe_source, s.updated_at, s.brevo_sync_status,
           s.related_status, s.related_consent_at, s.related_consent_source, s.related_consent_version,
           s.related_confirmed_at, s.related_withdrawn_at, s.related_withdraw_source,
           (s.user_id is not null) as has_account,
           case s.status when 'active' then 'active'
                         when 'pending' then 'pending'
                         when 'expired' then 'pending'
                         else 'unsubscribed' end as tab,
           (p_sources is null or s.consent_source = any (p_sources)) as ok_source,
           (p_versions is null or s.consent_version = any (p_versions)) as ok_version,
           (p_statuses is null or s.status = any (p_statuses)) as ok_status
    from guide.subscribers s
    where s.status <> 'erased'
      and (v_like is null or s.email like v_like escape '\')
      and (p_locale is null or s.locale = p_locale)
      and (p_from is null or (case v_df when 'consent' then s.consent_at
                                        when 'confirmed' then s.confirmed_at
                                        else s.unsubscribed_at end) >= p_from)
      and (p_to is null or (case v_df when 'consent' then s.consent_at
                                      when 'confirmed' then s.confirmed_at
                                      else s.unsubscribed_at end) < p_to)
  ),
  in_view as (
    select b.* from base b where (p_view = 'all' or b.tab = p_view) and b.ok_status
  ),
  hits as (
    select b.* from in_view b where b.ok_source and b.ok_version
  ),
  ranked as (
    select h.*, row_number() over (order by
      case when v_sort = 'consent_at_desc' then h.consent_at end desc nulls last,
      case when v_sort = 'consent_at_asc' then h.consent_at end asc nulls last,
      case when v_sort = 'confirmed_at_desc' then h.confirmed_at end desc nulls last,
      case when v_sort = 'confirmed_at_asc' then h.confirmed_at end asc nulls last,
      case when v_sort = 'unsubscribed_at_desc' then h.unsubscribed_at end desc nulls last,
      case when v_sort = 'unsubscribed_at_asc' then h.unsubscribed_at end asc nulls last,
      case when v_sort = 'updated_at_desc' then h.updated_at end desc nulls last,
      case when v_sort = 'updated_at_asc' then h.updated_at end asc nulls last,
      case when v_sort = 'email_asc' then h.email end asc nulls last,
      case when v_sort = 'email_desc' then h.email end desc nulls last,
      h.consent_at desc, h.id) as rn
    from hits h
  ),
  page as (
    select r.* from ranked r where r.rn > p_offset and r.rn <= p_offset + p_limit
  )
  select jsonb_build_object(
    'total_count', (select count(*) from hits),
    'tab_counts', (
      select jsonb_build_object(
        'active', count(*) filter (where b.tab = 'active'),
        'pending', count(*) filter (where b.tab = 'pending'),
        'unsubscribed', count(*) filter (where b.tab = 'unsubscribed'),
        'all', count(*))
      from base b where b.ok_source and b.ok_version),
    'source_counts', (
      select coalesce(jsonb_object_agg(x.consent_source, x.n), '{}'::jsonb)
      from (select v.consent_source, count(*) as n from in_view v where v.ok_version group by v.consent_source) x),
    'version_counts', (
      select coalesce(jsonb_object_agg(x.consent_version::text, x.n), '{}'::jsonb)
      from (select v.consent_version, count(*) as n from in_view v where v.ok_source group by v.consent_version) x),
    -- D66: recuento de afines dentro de los resultados (mismos filtros).
    'related_counts', (
      select jsonb_build_object(
        'granted', count(*) filter (where h.related_status = 'granted'),
        'pending', count(*) filter (where h.related_status = 'pending'),
        'withdrawn', count(*) filter (where h.related_status = 'withdrawn'),
        'none', count(*) filter (where h.related_status = 'none'))
      from hits h),
    'rows', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'id', p.id, 'email', p.email, 'status', p.status, 'locale', p.locale,
          'consent_source', p.consent_source, 'consent_version', p.consent_version,
          'consent_at', p.consent_at, 'confirmed_at', p.confirmed_at,
          'unsubscribed_at', p.unsubscribed_at, 'unsubscribe_source', p.unsubscribe_source,
          'unsubscribe_reason', case when p.status = 'unsubscribed' and p.unsubscribe_source = 'admin' then (
              select e.reason from guide.subscriber_consent_events e
              where e.subscriber_id = p.id and e.event = 'unsubscribe' and e.purpose = 'newsletter'
              order by e.occurred_at desc, e.id desc limit 1) end,
          'has_account', p.has_account, 'brevo_sync_status', p.brevo_sync_status, 'updated_at', p.updated_at,
          'expires_at', case when p.status = 'pending' then p.consent_at + interval '7 days' end,
          'anonymize_at', guide.subscriber_anonymize_at(p.status, p.consent_at, p.unsubscribed_at, p.updated_at,
                                                        p.related_status, p.related_withdrawn_at),
          'related_status', p.related_status, 'related_consent_at', p.related_consent_at,
          'related_consent_source', p.related_consent_source, 'related_consent_version', p.related_consent_version,
          'related_confirmed_at', p.related_confirmed_at, 'related_withdrawn_at', p.related_withdrawn_at,
          'related_withdraw_source', p.related_withdraw_source)
        order by p.rn), '[]'::jsonb)
      from page p)
  ) into v;
  return v;
end;
$$;
revoke all on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz,
                                                    integer[], guide.subscriber_status[], text, integer, integer)
  from public, anon, service_role;
grant execute on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz,
                                                       integer[], guide.subscriber_status[], text, integer, integer)
  to authenticated;

-- ── Panel: ficha con afines, eventos con finalidad y textos por finalidad ──
create or replace function guide.admin_get_subscriber(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s guide.subscribers%rowtype;
begin
  perform guide.assert_admin();
  select * into s from guide.subscribers where id = p_id and status <> 'erased';
  if not found then
    raise exception 'subscriber not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'subscriber', jsonb_build_object(
      'id', s.id, 'email', s.email, 'status', s.status, 'locale', s.locale,
      'consent_at', s.consent_at, 'consent_source', s.consent_source, 'consent_version', s.consent_version,
      'consent_page', s.consent_page, 'confirmed_at', s.confirmed_at, 'confirm_expires_at', s.confirm_expires_at,
      'unsubscribed_at', s.unsubscribed_at, 'unsubscribe_source', s.unsubscribe_source,
      'has_account', s.user_id is not null,
      'brevo_sync_status', s.brevo_sync_status, 'brevo_sync_error', s.brevo_sync_error, 'synced_at', s.synced_at,
      'created_at', s.created_at, 'updated_at', s.updated_at,
      'expires_at', case when s.status = 'pending' then s.consent_at + interval '7 days' end,
      'anonymize_at', guide.subscriber_anonymize_at(s.status, s.consent_at, s.unsubscribed_at, s.updated_at,
                                                    s.related_status, s.related_withdrawn_at),
      'related_status', s.related_status, 'related_consent_at', s.related_consent_at,
      'related_consent_source', s.related_consent_source, 'related_consent_version', s.related_consent_version,
      'related_confirmed_at', s.related_confirmed_at, 'related_withdrawn_at', s.related_withdrawn_at,
      'related_withdraw_source', s.related_withdraw_source),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'occurred_at', e.occurred_at, 'event', e.event, 'source', e.source, 'consent_version', e.consent_version,
          'locale', e.locale, 'page', e.page, 'actor', e.actor, 'reason', e.reason, 'purpose', e.purpose)
        order by e.occurred_at desc, e.id desc), '[]'::jsonb)
      from guide.subscriber_consent_events e where e.subscriber_id = s.id),
    'consent_texts', (
      select coalesce(jsonb_object_agg(c.version::text, jsonb_build_object(
          'text_es', c.text_es, 'text_en', c.text_en, 'preserved', c.preserved,
          'valid_from', c.valid_from, 'valid_to', c.valid_to)), '{}'::jsonb)
      from guide.consent_texts c
      where c.purpose = 'newsletter'
        and (c.version = s.consent_version
             or c.version in (select e.consent_version from guide.subscriber_consent_events e
                              where e.subscriber_id = s.id and e.purpose = 'newsletter' and e.consent_version is not null))),
    'related_consent_texts', (
      select coalesce(jsonb_object_agg(c.version::text, jsonb_build_object(
          'text_es', c.text_es, 'text_en', c.text_en, 'preserved', c.preserved,
          'valid_from', c.valid_from, 'valid_to', c.valid_to)), '{}'::jsonb)
      from guide.consent_texts c
      where c.purpose = 'related_products'
        and (c.version = s.related_consent_version
             or c.version in (select e.consent_version from guide.subscriber_consent_events e
                              where e.subscriber_id = s.id and e.purpose = 'related_products'
                                and e.consent_version is not null)))
  );
end;
$$;
revoke all on function guide.admin_get_subscriber(uuid) from public, anon, service_role;
grant execute on function guide.admin_get_subscriber(uuid) to authenticated;

-- ── Series del Inicio: solo eventos de la newsletter (los de afines no son altas ni bajas de suscriptores) ──
create or replace function guide.admin_timeseries(p_metric text, p_from date, p_to date, p_bucket text default 'day')
returns table(bucket date, value bigint)
language plpgsql
stable
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_metric is null or p_metric not in ('subscribers_new', 'subscribers_total', 'articles_published', 'user_reviews') then
    raise exception 'invalid metric' using errcode = '22023';
  end if;
  if p_bucket not in ('day', 'week', 'month') then
    raise exception 'invalid bucket' using errcode = '22023';
  end if;
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid range' using errcode = '22023';
  end if;

  return query
  with buckets as (
    select gs::date as b,
           (gs + ('1 ' || p_bucket)::interval) as b_end
    from generate_series(date_trunc(p_bucket, p_from::timestamp), p_to::timestamp, ('1 ' || p_bucket)::interval) gs
  )
  select bk.b,
    case p_metric
      when 'subscribers_new' then
        (select count(*) from guide.subscriber_consent_events e
          where e.event = 'confirm' and e.purpose = 'newsletter' and e.occurred_at >= bk.b and e.occurred_at < bk.b_end)
      when 'subscribers_total' then
        (select count(*) from (
           select distinct on (e.subscriber_id) e.event
           from guide.subscriber_consent_events e
           where e.occurred_at < bk.b_end and e.purpose = 'newsletter'
             and e.event in ('subscribe', 'confirm', 'unsubscribe', 'bounce', 'expire', 'erase')
           order by e.subscriber_id, e.occurred_at desc, e.id desc) last_ev
         where last_ev.event = 'confirm')
      when 'articles_published' then
        (select count(*) from guide.articles a
          where a.status in ('scheduled', 'published') and a.published_at >= bk.b and a.published_at < bk.b_end
            and a.published_at <= now())
      when 'user_reviews' then
        (select count(*) from guide.user_reviews r where r.created_at >= bk.b and r.created_at < bk.b_end)
      else null
    end
  from buckets bk
  order by bk.b;
end;
$$;
