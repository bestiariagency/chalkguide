-- D66 / D70 · Filtro «Afines» del listado de suscriptores (admin README §18.2): p_related guide.related_consent_status[].
-- null = todos. Va al final con default, así que las llamadas actuales (posicionales o con nombre) no cambian.
-- Faceta como p_sources: related_counts se calcula sin p_related (recuento de cada casilla) y con el resto de filtros;
-- total_count, rows, tab_counts, source_counts y version_counts sí lo aplican. Idempotente.
drop function if exists guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz,
                                                    integer[], guide.subscriber_status[], text, integer, integer);

create or replace function guide.admin_list_subscribers(
  p_view text default 'active',
  p_query text default null,
  p_sources text[] default null,
  p_locale guide.locale default null,
  p_date_field text default 'consent',
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_versions integer[] default null,
  p_statuses guide.subscriber_status[] default null,
  p_sort text default 'consent_at_desc',
  p_limit integer default 25,
  p_offset integer default 0,
  p_related guide.related_consent_status[] default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
     or coalesce(cardinality(p_statuses), 0) > 10 or coalesce(cardinality(p_related), 0) > 4 then
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
           (p_statuses is null or s.status = any (p_statuses)) as ok_status,
           (p_related is null or s.related_status = any (p_related)) as ok_related
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
    select b.* from in_view b where b.ok_source and b.ok_version and b.ok_related
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
      from base b where b.ok_source and b.ok_version and b.ok_related),
    'source_counts', (
      select coalesce(jsonb_object_agg(x.consent_source, x.n), '{}'::jsonb)
      from (select v.consent_source, count(*) as n from in_view v where v.ok_version and v.ok_related
            group by v.consent_source) x),
    'version_counts', (
      select coalesce(jsonb_object_agg(x.consent_version::text, x.n), '{}'::jsonb)
      from (select v.consent_version, count(*) as n from in_view v where v.ok_source and v.ok_related
            group by v.consent_version) x),
    -- D66: recuento de afines con el resto de filtros y sin p_related (faceta del filtro «Afines»).
    'related_counts', (
      select jsonb_build_object(
        'granted', count(*) filter (where v.related_status = 'granted'),
        'pending', count(*) filter (where v.related_status = 'pending'),
        'withdrawn', count(*) filter (where v.related_status = 'withdrawn'),
        'none', count(*) filter (where v.related_status = 'none'))
      from in_view v where v.ok_source and v.ok_version),
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
$function$;

revoke all on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz,
  integer[], guide.subscriber_status[], text, integer, integer, guide.related_consent_status[])
  from public, anon, service_role;
grant execute on function guide.admin_list_subscribers(text, text, text[], guide.locale, text, timestamptz, timestamptz,
  integer[], guide.subscriber_status[], text, integer, integer, guide.related_consent_status[])
  to authenticated;
