-- F6.14 (D35) · Suscriptores, parte 7: RPC del panel. Todas SECURITY DEFINER con assert_admin() como primera
-- sentencia, search_path = '', sin EXECUTE para public/anon y solo para authenticated.
-- · admin_list_subscribers: paginado en servidor, total, recuento por pestaña y facetas; nunca tokens ni datos de
--   auth.users (has_account es booleano); excluye suprimidos.
-- · admin_subscribers_summary: resumen de cabecera.
-- · admin_get_subscriber: ficha (fila + historial con actor y motivo + texto de cada versión aceptada).
-- · admin_unsubscribe_subscribers: baja en lote con motivo; sin operación inversa (no hay RPC de alta ni reactivar).
-- · admin_erase_subscriber: supresión RGPD de una sola fila escribiendo el email exacto.
-- · subscriber_anonymize (interna, sin EXECUTE para clientes): la comparten la supresión y la caducidad.
-- Idempotente.

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
  set status             = 'erased',
      email              = null,
      user_id            = null,
      consent_page       = null,
      brevo_contact_id   = null,
      unsubscribe_token  = gen_random_uuid(),
      confirm_token_hash = null,
      confirm_expires_at = null
  where id = p_id;
  perform set_config('guide.consent_op', '', true);
end;
$$;
revoke all on function guide.subscriber_anonymize(uuid) from public, anon, authenticated, service_role;

create or replace function guide.admin_list_subscribers(
  p_view       text default 'active',
  p_query      text default null,
  p_sources    text[] default null,
  p_locale     guide.locale default null,
  p_date_field text default 'consent',
  p_from       timestamptz default null,
  p_to         timestamptz default null,
  p_versions   integer[] default null,
  p_statuses   guide.subscriber_status[] default null,
  p_sort       text default 'consent_at_desc',
  p_limit      integer default 25,
  p_offset     integer default 0
)
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
    'rows', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'id', p.id, 'email', p.email, 'status', p.status, 'locale', p.locale,
          'consent_source', p.consent_source, 'consent_version', p.consent_version,
          'consent_at', p.consent_at, 'confirmed_at', p.confirmed_at,
          'unsubscribed_at', p.unsubscribed_at, 'unsubscribe_source', p.unsubscribe_source,
          'unsubscribe_reason', case when p.status = 'unsubscribed' and p.unsubscribe_source = 'admin' then (
              select e.reason from guide.subscriber_consent_events e
              where e.subscriber_id = p.id and e.event = 'unsubscribe'
              order by e.occurred_at desc, e.id desc limit 1) end,
          'has_account', p.has_account, 'brevo_sync_status', p.brevo_sync_status, 'updated_at', p.updated_at,
          'expires_at', case when p.status = 'pending' then p.consent_at + interval '7 days' end,
          'anonymize_at', case when p.status in ('pending', 'expired') then p.consent_at + interval '30 days'
                               when p.status in ('unsubscribed', 'bounced')
                                 then coalesce(p.unsubscribed_at, p.updated_at) + interval '3 years' end)
        order by p.rn), '[]'::jsonb)
      from page p)
  ) into v;
  return v;
end;
$$;

create or replace function guide.admin_subscribers_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform guide.assert_admin();
  select jsonb_build_object(
    'active', count(*) filter (where s.status = 'active'),
    'pending', count(*) filter (where s.status = 'pending'),
    'expired', count(*) filter (where s.status = 'expired'),
    'unsubscribed', count(*) filter (where s.status = 'unsubscribed'),
    'bounced', count(*) filter (where s.status = 'bounced'),
    'erased', count(*) filter (where s.status = 'erased'),
    'active_confirmed_30d', count(*) filter (where s.status = 'active' and s.confirmed_at >= now() - interval '30 days'),
    'unsubscribed_30d', count(*) filter (where s.status in ('unsubscribed', 'bounced')
                                           and s.unsubscribed_at >= now() - interval '30 days'),
    'signups_30d', count(*) filter (where s.consent_at >= now() - interval '30 days'),
    'signups_30d_confirmed', count(*) filter (where s.consent_at >= now() - interval '30 days'
                                                and s.confirmed_at >= s.consent_at),
    'confirm_rate_30d', case when count(*) filter (where s.consent_at >= now() - interval '30 days') = 0 then null
      else round(100.0 * count(*) filter (where s.consent_at >= now() - interval '30 days' and s.confirmed_at >= s.consent_at)
                 / count(*) filter (where s.consent_at >= now() - interval '30 days'), 1) end,
    'sync_errors', count(*) filter (where s.status <> 'erased' and s.brevo_sync_status = 'error')
  ) into v
  from guide.subscribers s;
  return v;
end;
$$;

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
      'anonymize_at', case when s.status in ('pending', 'expired') then s.consent_at + interval '30 days'
                           when s.status in ('unsubscribed', 'bounced')
                             then coalesce(s.unsubscribed_at, s.updated_at) + interval '3 years' end),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'occurred_at', e.occurred_at, 'event', e.event, 'source', e.source, 'consent_version', e.consent_version,
          'locale', e.locale, 'page', e.page, 'actor', e.actor, 'reason', e.reason)
        order by e.occurred_at desc, e.id desc), '[]'::jsonb)
      from guide.subscriber_consent_events e where e.subscriber_id = s.id),
    'consent_texts', (
      select coalesce(jsonb_object_agg(c.version::text, jsonb_build_object(
          'text_es', c.text_es, 'text_en', c.text_en, 'preserved', c.preserved,
          'valid_from', c.valid_from, 'valid_to', c.valid_to)), '{}'::jsonb)
      from guide.consent_texts c
      where c.version = s.consent_version
         or c.version in (select e.consent_version from guide.subscriber_consent_events e
                          where e.subscriber_id = s.id and e.consent_version is not null))
  );
end;
$$;

create or replace function guide.admin_unsubscribe_subscribers(p_ids uuid[], p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids   uuid[];
  v_found integer;
  v_bad   integer;
  v_n     integer;
begin
  perform guide.assert_admin();
  if p_reason is null or p_reason not in ('request', 'wrong', 'abuse', 'other') then
    raise exception 'invalid reason' using errcode = '22023';
  end if;
  if p_ids is null or cardinality(p_ids) = 0 or cardinality(p_ids) > 500 or array_position(p_ids, null) is not null then
    raise exception 'invalid ids' using errcode = '22023';
  end if;
  v_ids := array(select distinct x from unnest(p_ids) x);

  perform 1 from guide.subscribers s where s.id = any (v_ids) and s.status <> 'erased' order by s.id for update;
  select count(*), count(*) filter (where s.status not in ('pending', 'active', 'bounced'))
    into v_found, v_bad
  from guide.subscribers s where s.id = any (v_ids) and s.status <> 'erased';
  if v_found <> cardinality(v_ids) then
    raise exception 'subscriber not found' using errcode = 'P0002';
  end if;
  if v_bad > 0 then
    raise exception 'invalid subscriber state' using errcode = '22023', detail = v_bad::text,
      hint = 'Only pending, active or bounced subscribers can be unsubscribed.';
  end if;

  perform set_config('guide.consent_reason', p_reason, true);
  update guide.subscribers
  set status             = 'unsubscribed',
      unsubscribed_at    = now(),
      unsubscribe_source = 'admin',
      unsubscribe_token  = gen_random_uuid(),
      confirm_token_hash = null,
      confirm_expires_at = null
  where id = any (v_ids);
  get diagnostics v_n = row_count;
  perform set_config('guide.consent_reason', '', true);

  return jsonb_build_object('unsubscribed', v_n);
end;
$$;

create or replace function guide.admin_erase_subscriber(p_id uuid, p_email_confirm text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  perform guide.assert_admin();
  if p_reason is null or p_reason not in ('request', 'wrong', 'other') then
    raise exception 'invalid reason' using errcode = '22023';
  end if;
  select s.email into v_email from guide.subscribers s where s.id = p_id and s.status <> 'erased' for update;
  if not found then
    raise exception 'subscriber not found' using errcode = 'P0002';
  end if;
  if p_email_confirm is null or lower(btrim(p_email_confirm)) is distinct from v_email then
    raise exception 'email confirmation mismatch' using errcode = '22023';
  end if;

  perform set_config('guide.consent_reason', p_reason, true);
  perform guide.subscriber_anonymize(p_id);
  perform set_config('guide.consent_reason', '', true);
  return jsonb_build_object('id', p_id, 'erased', true);
end;
$$;

revoke all on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz, integer[], guide.subscriber_status[], text, integer, integer) from public, anon;
revoke all on function guide.admin_subscribers_summary() from public, anon;
revoke all on function guide.admin_get_subscriber(uuid) from public, anon;
revoke all on function guide.admin_unsubscribe_subscribers(uuid[], text) from public, anon;
revoke all on function guide.admin_erase_subscriber(uuid, text, text) from public, anon;
grant execute on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz, integer[], guide.subscriber_status[], text, integer, integer) to authenticated;
grant execute on function guide.admin_subscribers_summary() to authenticated;
grant execute on function guide.admin_get_subscriber(uuid) to authenticated;
grant execute on function guide.admin_unsubscribe_subscribers(uuid[], text) to authenticated;
grant execute on function guide.admin_erase_subscriber(uuid, text, text) to authenticated;
