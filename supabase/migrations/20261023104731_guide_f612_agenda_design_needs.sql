-- F6.12 (b): necesidades del diseño de Agenda (docs/design/admin/README.md §9.8).
-- 1 reopen_event (Retirar, Recuperar, Deshacer) · 2 reject_reason de lista cerrada · 3 dedupe_key en cualquier
-- estado (ya es UNIQUE; el agente inserta con ON CONFLICT DO NOTHING) · 4 forma fija de agent_meta · 5 item_id solo
-- rocódromos · 6 contador sin caducados (también en admin_dashboard_stats) · 7 aprobar/descartar en lote.
-- El descarte automático de caducados queda pendiente de Xavi (no se implementa). Idempotente.

-- ───────────── 1. Motivo del descarte ─────────────
alter table guide.events add column if not exists reject_reason text;

do $$
begin
  alter table guide.events drop constraint if exists events_reject_reason_valid;
  alter table guide.events add constraint events_reject_reason_valid check (
    reject_reason is null
    or (status = 'rejected'
        and reject_reason in ('duplicate', 'not_climbing', 'members_only', 'outside_area', 'wrong_data')));

  -- ───────────── 4. Forma de agent_meta (pura: solo operadores jsonb) ─────────────
  -- {confidence: 0–1 (obligatoria), note ≤ 500, excerpt ≤ 2000, found_at ISO-8601, inferred: [campos],
  --  duplicate_of: uuid | null}. Sin otras claves. Solo en eventos del agente.
  alter table guide.events drop constraint if exists events_agent_meta_shape;
  alter table guide.events add constraint events_agent_meta_shape check (
    agent_meta is null
    or (jsonb_typeof(agent_meta) = 'object'
        and (agent_meta - array['confidence', 'note', 'excerpt', 'found_at', 'inferred', 'duplicate_of']) = '{}'::jsonb
        and case when jsonb_typeof(agent_meta -> 'confidence') = 'number'
                 then (agent_meta ->> 'confidence')::numeric between 0 and 1 else false end
        and (not agent_meta ? 'note' or (jsonb_typeof(agent_meta -> 'note') = 'string'
                                          and char_length(agent_meta ->> 'note') <= 500))
        and (not agent_meta ? 'excerpt' or (jsonb_typeof(agent_meta -> 'excerpt') = 'string'
                                             and char_length(agent_meta ->> 'excerpt') <= 2000))
        and (not agent_meta ? 'found_at'
             or (jsonb_typeof(agent_meta -> 'found_at') = 'string'
                 and (agent_meta ->> 'found_at') ~ '^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})?)?$'))
        and (not agent_meta ? 'inferred'
             or (jsonb_typeof(agent_meta -> 'inferred') = 'array'
                 and jsonb_array_length(agent_meta -> 'inferred') <= 10
                 and (agent_meta -> 'inferred') <@ '["type", "start", "end", "all_day", "price", "place", "title_en", "description", "url"]'::jsonb))
        and (not agent_meta ? 'duplicate_of'
             or jsonb_typeof(agent_meta -> 'duplicate_of') = 'null'
             or (jsonb_typeof(agent_meta -> 'duplicate_of') = 'string'
                 and (agent_meta ->> 'duplicate_of') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'))));

  alter table guide.events drop constraint if exists events_agent_meta_only_agent;
  alter table guide.events add constraint events_agent_meta_only_agent check (
    (source = 'agent') = (agent_meta is not null));
end $$;

-- ───────────── 3/5. Guarda: rocódromos, reabrir desde cancelado, motivo solo en descartados ─────────────
create or replace function guide.events_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_admin  boolean := guide.is_admin();
  v_maint  boolean := guide.item_live_exempt(null);
  v_from   guide.event_status;
  v_cat    text;
  v_pub    boolean;
begin
  if tg_op = 'DELETE' then
    if v_maint then
      return old;
    end if;
    if not v_admin then
      raise exception 'event_write_forbidden' using errcode = '42501';
    end if;
    if old.status in ('approved', 'cancelled') then
      raise exception 'event is live'
        using errcode = 'PT423', detail = 'delete',
              hint = 'Unpublish it first (reopen_event) or cancel it.';
    end if;
    return old;
  end if;

  new.title_es       := btrim(new.title_es);
  new.title_en       := nullif(btrim(new.title_en), '');
  new.description_es := nullif(btrim(new.description_es), '');
  new.description_en := nullif(btrim(new.description_en), '');
  new.location_text  := nullif(btrim(new.location_text), '');
  new.price_text     := nullif(btrim(new.price_text), '');
  new.url            := nullif(btrim(new.url), '');
  new.source_url     := nullif(btrim(new.source_url), '');

  if v_maint then
    return new;
  end if;

  if not v_admin then
    -- Agente (F8) o cualquier rol que salte RLS: solo INSERT de borradores propios.
    if tg_op <> 'INSERT' or new.status <> 'draft' or new.source <> 'agent' or new.approved_at is not null
       or new.reject_reason is not null then
      raise exception 'event_write_forbidden' using errcode = '42501';
    end if;
  elsif tg_op = 'INSERT' then
    new.source := 'manual';
    new.dedupe_key := null;
    new.agent_meta := null;
    if new.status not in ('draft', 'approved') then
      raise exception 'event_invalid_transition' using errcode = '55000', detail = 'insert>' || new.status::text;
    end if;
  else
    v_from := old.status;
    new.created_at := old.created_at;
    if new.source is distinct from old.source or new.dedupe_key is distinct from old.dedupe_key
       or new.agent_meta is distinct from old.agent_meta then
      raise exception 'event_provenance_immutable' using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and (old.status::text || '>' || new.status::text) <> all (array[
             'draft>approved', 'draft>rejected', 'approved>draft', 'approved>cancelled',
             'cancelled>approved', 'cancelled>draft', 'rejected>draft']) then
      raise exception 'event_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
  end if;

  if v_admin then
    if new.status in ('approved', 'cancelled') then
      new.approved_at := case when v_from in ('approved', 'cancelled') then coalesce(old.approved_at, now()) else now() end;
    else
      new.approved_at := null;
    end if;
    if new.status <> 'rejected' then
      new.reject_reason := null;
    end if;
  end if;

  -- Ficha relacionada: solo rocódromos (el sitio enlaza a la ficha de rocódromo); publicada si el evento es público.
  if new.item_id is not null and (tg_op = 'INSERT' or new.item_id is distinct from old.item_id
                                  or (new.status = 'approved' and v_from is distinct from 'approved'
                                      and v_from is distinct from 'cancelled')) then
    select i.category, i.published into v_cat, v_pub from guide.items i where i.id = new.item_id;
    if v_cat is distinct from 'gym' then
      raise exception 'event_item_category' using errcode = '23514';
    end if;
    if new.status in ('approved', 'cancelled') and not v_pub then
      raise exception 'event_item_not_published' using errcode = '23514';
    end if;
  end if;

  if new.status = 'approved' and (v_from is null or v_from = 'draft') then
    if new.item_id is null and new.location_text is null then
      raise exception 'event_place_required' using errcode = '23514';
    end if;
    if guide.event_is_past(new.starts_at, new.ends_at, new.all_day) then
      raise exception 'event_in_past' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;
revoke all on function guide.events_before_write() from public, anon, authenticated;

-- ───────────── 1/2. Cambiar estado (con motivo), reabrir, descartar ─────────────
drop function if exists guide.set_event_status(uuid, guide.event_status);
create or replace function guide.set_event_status(p_id uuid, p_status guide.event_status, p_reject_reason text default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_id  uuid;
  v_st  guide.event_status;
  v_at  timestamptz;
  v_rr  text;
  v_upd timestamptz;
begin
  perform guide.assert_admin();
  if p_id is null or p_status is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  if p_reject_reason is not null and p_status <> 'rejected' then
    raise exception 'reject reason without reject' using errcode = '22023';
  end if;
  update guide.events set status = p_status, reject_reason = p_reject_reason where id = p_id
  returning id, status, approved_at, reject_reason, updated_at into v_id, v_st, v_at, v_rr, v_upd;
  if not found then
    raise exception 'event not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('id', v_id, 'status', v_st, 'approved_at', v_at, 'reject_reason', v_rr, 'updated_at', v_upd);
end;
$$;
revoke all on function guide.set_event_status(uuid, guide.event_status, text) from public, anon;
grant execute on function guide.set_event_status(uuid, guide.event_status, text) to authenticated;

create or replace function guide.approve_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.set_event_status(p_id, 'approved');
end;
$$;

drop function if exists guide.reject_event(uuid);
create or replace function guide.reject_event(p_id uuid, p_reason text default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  return guide.set_event_status(p_id, 'rejected', p_reason);
end;
$$;

-- Vuelve a borrador (approved/cancelled → draft = Retirar; rejected → draft = Recuperar; Deshacer de aprobar/descartar).
create or replace function guide.reopen_event(p_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  return guide.set_event_status(p_id, 'draft');
end;
$$;

revoke all on function guide.approve_event(uuid) from public, anon;
revoke all on function guide.reject_event(uuid, text) from public, anon;
revoke all on function guide.reopen_event(uuid) from public, anon;
grant execute on function guide.approve_event(uuid), guide.reject_event(uuid, text), guide.reopen_event(uuid) to authenticated;

-- ───────────── 7. Lote: cada id en su subtransacción; devuelve aciertos y fallos ─────────────
create or replace function guide.set_events_status(p_ids uuid[], p_status guide.event_status, p_reject_reason text default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_id   uuid;
  v_ok   jsonb := '[]'::jsonb;
  v_bad  jsonb := '[]'::jsonb;
  v_code text;
  v_msg  text;
begin
  perform guide.assert_admin();
  if p_ids is null or cardinality(p_ids) = 0 or cardinality(p_ids) > 100 or array_position(p_ids, null) is not null
     or cardinality(p_ids) <> (select count(distinct x) from unnest(p_ids) x) then
    raise exception 'invalid ids' using errcode = '22023';
  end if;
  foreach v_id in array p_ids loop
    begin
      v_ok := v_ok || jsonb_build_array(guide.set_event_status(v_id, p_status, p_reject_reason));
    exception when others then
      get stacked diagnostics v_code = returned_sqlstate, v_msg = message_text;
      if v_code = '42501' then
        raise;
      end if;
      v_bad := v_bad || jsonb_build_array(jsonb_build_object('id', v_id, 'code', v_code, 'message', v_msg));
    end;
  end loop;
  return jsonb_build_object('ok', v_ok, 'failed', v_bad);
end;
$$;
revoke all on function guide.set_events_status(uuid[], guide.event_status, text) from public, anon;
grant execute on function guide.set_events_status(uuid[], guide.event_status, text) to authenticated;

-- ───────────── Listado: motivo, duplicado resuelto, varios tipos, orden ─────────────
drop function if exists guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
  uuid, text, text, uuid, integer, integer);
create or replace function guide.admin_list_events(
  p_status      guide.event_status default null,
  p_source      guide.event_source default null,
  p_when        text default null,
  p_from        timestamptz default null,
  p_to          timestamptz default null,
  p_item_id     uuid default null,
  p_event_types text[] default null,
  p_query       text default null,
  p_id          uuid default null,
  p_sort        text default null,
  p_limit       integer default 50,
  p_offset      integer default 0
)
returns table (
  id uuid, status guide.event_status, source guide.event_source, event_type text,
  title_es text, title_en text, description_es text, description_en text,
  starts_at timestamptz, ends_at timestamptz, all_day boolean, location_text text, url text, price_text text,
  item_id uuid, item_name text, item_slug text, item_published boolean,
  source_url text, agent_meta jsonb, duplicate_of uuid, duplicate_of_status guide.event_status,
  reject_reason text, has_en boolean, is_past boolean,
  approved_at timestamptz, created_at timestamptz, updated_at timestamptz, total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_q      text;
  v_terms  text[];
  v_desc   boolean;
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  if p_when is not null and p_when not in ('upcoming', 'past', 'all') then
    raise exception 'invalid when' using errcode = '22023';
  end if;
  if p_sort is not null and p_sort not in ('asc', 'desc') then
    raise exception 'invalid sort' using errcode = '22023';
  end if;
  if char_length(coalesce(p_query, '')) > 200 then
    raise exception 'query too long' using errcode = '22023';
  end if;
  if p_event_types is not null and (cardinality(p_event_types) > 6 or not (p_event_types <@
       array['competition', 'workshop', 'outing', 'social', 'course', 'other'])) then
    raise exception 'invalid event type' using errcode = '22023';
  end if;
  v_desc := coalesce(p_sort = 'desc', p_when = 'past', false);

  v_q := lower(extensions.unaccent(btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'))));
  select coalesce(array_agg('%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'), '{}')
  into v_terms
  from unnest(string_to_array(nullif(v_q, ''), ' ')) as w
  where w <> '';

  return query
  with base as (
    select e.id, e.status, e.source, e.event_type, e.title_es, e.title_en, e.description_es, e.description_en,
           e.starts_at, e.ends_at, e.all_day, e.location_text, e.url, e.price_text,
           e.item_id, i.name as item_name, i.slug::text as item_slug, i.published as item_published,
           e.source_url, e.agent_meta, d.id as duplicate_of, d.status as duplicate_of_status,
           e.reject_reason, e.has_en,
           guide.event_is_past(e.starts_at, e.ends_at, e.all_day) as is_past,
           e.approved_at, e.created_at, e.updated_at
    from guide.events e
    left join guide.items i on i.id = e.item_id
    left join guide.events d on d.id = (e.agent_meta ->> 'duplicate_of')::uuid and d.id <> e.id
    where (p_id is null or e.id = p_id)
      and (p_status is null or e.status = p_status)
      and (p_source is null or e.source = p_source)
      and (p_from is null or e.starts_at >= p_from)
      and (p_to is null or e.starts_at < p_to)
      and (p_item_id is null or e.item_id = p_item_id)
      and (p_event_types is null or cardinality(p_event_types) = 0 or e.event_type = any (p_event_types))
      and (cardinality(v_terms) = 0 or not exists (
             select 1 from unnest(v_terms) as term
             where lower(extensions.unaccent(concat_ws(' ', e.title_es, e.title_en, e.description_es,
                                                       e.location_text, e.price_text, i.name))) not like term escape '\'))
  ),
  filtered as (
    select b.* from base b
    where p_when is null or p_when = 'all'
       or (p_when = 'past' and b.is_past)
       or (p_when = 'upcoming' and not b.is_past)
  )
  select f.id, f.status, f.source, f.event_type, f.title_es, f.title_en, f.description_es, f.description_en,
         f.starts_at, f.ends_at, f.all_day, f.location_text, f.url, f.price_text,
         f.item_id, f.item_name, f.item_slug, f.item_published,
         f.source_url, f.agent_meta, f.duplicate_of, f.duplicate_of_status, f.reject_reason, f.has_en, f.is_past,
         f.approved_at, f.created_at, f.updated_at,
         count(*) over () as total_count
  from filtered f
  -- asc: lo próximo primero y lo ya pasado al final (bandeja); desc: lo más reciente primero (Pasados, Descartados)
  order by case when not v_desc then f.is_past end asc,
           case when v_desc then f.starts_at end desc,
           case when not v_desc then f.starts_at end asc,
           f.id
  limit v_limit offset v_offset;
end;
$$;
revoke all on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
  uuid, text[], text, uuid, text, integer, integer) from public, anon;
grant execute on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
  uuid, text[], text, uuid, text, integer, integer) to authenticated;

-- ───────────── 6. Contadores: el del menú no cuenta caducados; recuento por tipo para la barra ─────────────
create or replace function guide.admin_events_summary()
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
    'badge',              count(*) filter (where x.status = 'draft' and not x.past),
    'pending',            count(*) filter (where x.status = 'draft' and not x.past),
    'pending_agent',      count(*) filter (where x.status = 'draft' and not x.past and x.source = 'agent'),
    'pending_past',       count(*) filter (where x.status = 'draft' and x.past),
    'upcoming',           count(*) filter (where x.status = 'approved' and not x.past),
    'cancelled_upcoming', count(*) filter (where x.status = 'cancelled' and not x.past),
    'past_published',     count(*) filter (where x.status in ('approved', 'cancelled') and x.past),
    'rejected',           count(*) filter (where x.status = 'rejected'),
    'total',              count(*),
    'by_type', coalesce((select jsonb_object_agg(t.event_type, t.n)
                         from (select e.event_type, count(*) as n from guide.events e group by e.event_type) t), '{}'::jsonb))
  into v
  from (select e.status, e.source, guide.event_is_past(e.starts_at, e.ends_at, e.all_day) as past
        from guide.events e) x;
  return v;
end;
$$;
revoke all on function guide.admin_events_summary() from public, anon;
grant execute on function guide.admin_events_summary() to authenticated;

-- Inicio: misma regla que el menú (borradores no caducados) + caducados aparte. Resto sin cambios.
create or replace function guide.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform guide.assert_admin();
  select jsonb_build_object(
    'articles_by_status', (
      select coalesce(jsonb_object_agg(x.status, x.n), '{}'::jsonb)
      from (select status::text, count(*) as n from guide.articles group by status) x
    ),
    'articles_scheduled_next', (
      select coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'title_es', a.title_es, 'published_at', a.published_at)
                                order by a.published_at), '[]'::jsonb)
      from (select id, title_es, published_at from guide.articles
            where status = 'scheduled' and published_at > now() order by published_at limit 5) a
    ),
    'subscribers_active', (select count(*) from guide.subscribers where status = 'active'),
    'subscribers_pending', (select count(*) from guide.subscribers where status = 'pending'),
    'subscribers_total', (select count(*) from guide.subscribers),
    'subscribers_new_30d', (select count(*) from guide.subscribers where created_at >= now() - interval '30 days'),
    'subscribers_new_prev_30d', (select count(*) from guide.subscribers
                                 where created_at >= now() - interval '60 days' and created_at < now() - interval '30 days'),
    'unsubscribed_30d', (select count(*) from guide.subscribers where unsubscribed_at >= now() - interval '30 days'),
    'user_reviews_pending', (select count(*) from guide.user_reviews where status = 'pending'),
    'user_reviews_hidden', (select count(*) from guide.user_reviews where status = 'hidden'),
    'user_reviews_30d', (select count(*) from guide.user_reviews where created_at >= now() - interval '30 days'),
    'items_stale', (select count(*) from guide.items
                    where published and (verified_at is null or verified_at < current_date - interval '6 months')),
    'events_drafts', (select count(*) from guide.events e
                      where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    'events_drafts_expired', (select count(*) from guide.events e
                              where e.status = 'draft' and guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
    'media_without_alt', (select count(*) from guide.media where alt_es is null or btrim(alt_es) = ''),
    'recent_activity', (
      select coalesce(jsonb_agg(to_jsonb(l) - 'old_row' order by l.occurred_at desc), '[]'::jsonb)
      from (select * from guide.activity_log order by occurred_at desc limit 10) l
    )
  ) into v;
  return v;
end;
$$;
