-- F6.12 Agenda del panel: CRUD de eventos, aprobación de borradores y base para el agente de F8 (regla 6:
-- nada se publica solo). Eventos = contenido ligero: edición directa también publicados (sin borrador de
-- cambios D23); la única guarda PT423 es el borrado de lo publicado (approved/cancelled).
-- Estados: draft (borrador por revisar) · approved (publicado) · cancelled (publicado y anulado: visible marcado)
-- · rejected (descartado; conserva dedupe_key para que el agente no lo vuelva a proponer). «Pasado» es derivado
-- (guide.event_is_past, Europe/Madrid), no un estado.
-- Idempotente. Requiere 20261023064254_guide_f612_event_status_cancelled (valor de enum ya confirmado).

-- ───────────── 1. ¿Pasado? (Europe/Madrid) ─────────────
-- Con hora de fin (y no «todo el día»): pasado cuando termina. Si no: cuando su último día en Madrid ya ha
-- terminado (un evento sin fin a las 19:00 sigue en la agenda del día).
create or replace function guide.event_is_past(p_starts timestamptz, p_ends timestamptz, p_all_day boolean)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when p_ends is not null and not coalesce(p_all_day, false) then p_ends < now()
    else (coalesce(p_ends, p_starts) at time zone 'Europe/Madrid')::date < (now() at time zone 'Europe/Madrid')::date
  end;
$$;
revoke all on function guide.event_is_past(timestamptz, timestamptz, boolean) from public, anon;
grant execute on function guide.event_is_past(timestamptz, timestamptz, boolean) to authenticated, service_role;

-- ───────────── 2. CHECK puros (sin leer datos) ─────────────
do $$
begin
  alter table guide.events drop constraint if exists events_url_check;
  alter table guide.events drop constraint if exists events_url_https;
  alter table guide.events add constraint events_url_https check (
    url is null or (char_length(url) <= 500 and url ~ '^https://[^[:space:]/?#"<>\\]+([/?#][^[:space:]"<>\\]*)?$'));

  alter table guide.events drop constraint if exists events_source_url_check;
  alter table guide.events drop constraint if exists events_source_url_valid;
  alter table guide.events add constraint events_source_url_valid check (
    source_url is null
    or (char_length(source_url) <= 1000 and source_url ~ '^https?://[^[:space:]/?#"<>\\]+([/?#][^[:space:]"<>\\]*)?$'));

  alter table guide.events drop constraint if exists events_text_no_control;
  alter table guide.events add constraint events_text_no_control check (
    title_es !~ '[[:cntrl:]]'
    and (title_en is null or title_en !~ '[[:cntrl:]]')
    and (location_text is null or location_text !~ '[[:cntrl:]]')
    and (price_text is null or price_text !~ '[[:cntrl:]]')
    and (description_es is null or description_es !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]')
    and (description_en is null or description_en !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F]'));

  -- «Todo el día»: inicio (y fin, si lo hay) a las 00:00 de Madrid; el fin es el último día, inclusive.
  alter table guide.events drop constraint if exists events_all_day_midnight;
  alter table guide.events add constraint events_all_day_midnight check (
    not all_day
    or ((starts_at at time zone 'Europe/Madrid')::time = time '00:00'
        and (ends_at is null or (ends_at at time zone 'Europe/Madrid')::time = time '00:00')));

  alter table guide.events drop constraint if exists events_duration;
  alter table guide.events add constraint events_duration check (
    ends_at is null or ends_at <= starts_at + interval '366 days');

  alter table guide.events drop constraint if exists events_starts_range;
  alter table guide.events add constraint events_starts_range check (
    starts_at >= timestamptz '2020-01-01 00:00:00+00' and starts_at < timestamptz '2100-01-01 00:00:00+00');

  alter table guide.events drop constraint if exists events_agent_dedupe;
  alter table guide.events add constraint events_agent_dedupe check (source <> 'agent' or dedupe_key is not null);

  alter table guide.events drop constraint if exists events_agent_meta_size;
  alter table guide.events add constraint events_agent_meta_size check (
    agent_meta is null or octet_length(agent_meta::text) <= 8000);

  alter table guide.events drop constraint if exists events_approved_at;
  alter table guide.events add constraint events_approved_at check (
    (status in ('approved', 'cancelled')) = (approved_at is not null));
end $$;

-- ───────────── 3. Guarda de escritura (permisos por camino, transiciones, publicación) ─────────────
-- Admin: CRUD; source/dedupe_key/agent_meta inmutables (al crear: manual y nulos); approved_at lo fija el servidor.
-- Cualquier otra sesión que llegue a escribir (solo roles que saltan RLS: service_role del agente en F8 o una
-- función DEFINER): solo INSERT de borradores source = 'agent'. Nunca aprueba, edita ni borra.
-- Mantenimiento explícito como postgres (guide.draft_op = 'maintenance', item_live_exempt): sin reglas.
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
              hint = 'Cancel it (set_event_status cancelled) or unpublish it to draft first.';
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
    if tg_op <> 'INSERT' or new.status <> 'draft' or new.source <> 'agent' or new.approved_at is not null then
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
             'cancelled>approved', 'rejected>draft']) then
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
  end if;

  -- Ficha relacionada: solo lugares (rocódromo o resolador); publicada si el evento es público.
  if new.item_id is not null and (tg_op = 'INSERT' or new.item_id is distinct from old.item_id
                                  or (new.status = 'approved' and v_from is distinct from 'approved'
                                      and v_from is distinct from 'cancelled')) then
    select i.category, i.published into v_cat, v_pub from guide.items i where i.id = new.item_id;
    if v_cat is null or v_cat not in ('gym', 'resoler') then
      raise exception 'event_item_category' using errcode = '23514';
    end if;
    if new.status in ('approved', 'cancelled') and not v_pub then
      raise exception 'event_item_not_published' using errcode = '23514';
    end if;
  end if;

  -- Publicar (entrar en approved desde borrador o al crear): lugar y no pasado.
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

drop trigger if exists events_before_write on guide.events;
create trigger events_before_write
  before insert or update or delete on guide.events
  for each row execute function guide.events_before_write();

-- ───────────── 4. Registro de actividad (sin agent_meta; quién: admin / agent / system) ─────────────
create or replace function guide.events_log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin   boolean := guide.is_admin();
  v_by      text;
  v_new     jsonb;
  v_old     jsonb;
  v_changed text[];
  v_action  guide.activity_action := lower(tg_op)::guide.activity_action;
  v_det     jsonb;
begin
  v_by := case when v_admin then 'admin'
               when coalesce((select auth.jwt()) ->> 'role', '') = 'service_role' then 'agent'
               else 'system' end;
  if tg_op = 'UPDATE' then
    v_new := to_jsonb(new) - 'updated_at';
    v_old := to_jsonb(old) - 'updated_at';
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n where n.value is distinct from (v_old -> n.key);
    if v_changed is null then
      return null;
    end if;
    v_det := jsonb_build_object('by', v_by, 'source', new.source);
    if old.status is distinct from new.status then
      v_det := v_det || jsonb_build_object('from', old.status, 'to', new.status);
      if old.status in ('approved', 'cancelled') and new.status = 'draft' then
        v_action := 'unpublish';
      end if;
    end if;
  elsif tg_op = 'INSERT' then
    v_det := jsonb_build_object('by', v_by, 'source', new.source, 'status', new.status);
  else
    v_det := jsonb_build_object('by', v_by, 'source', old.source, 'status', old.status);
  end if;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row, details)
  values (case when v_admin then (select auth.uid()) end,
          v_action,
          'events',
          (case when tg_op = 'DELETE' then old.id else new.id end)::text,
          left(case when tg_op = 'DELETE' then old.title_es else new.title_es end, 200),
          v_changed,
          case when tg_op = 'DELETE' then to_jsonb(old) - 'agent_meta' end,
          v_det);
  return null;
end;
$$;
revoke all on function guide.events_log_activity() from public, anon, authenticated;

drop trigger if exists events_log_activity on guide.events;
create trigger events_log_activity
  after insert or update or delete on guide.events
  for each row execute function guide.events_log_activity();

-- ───────────── 5. RLS y columnas legibles ─────────────
-- Público: publicados y cancelados (el sitio marca «Cancelado»). Lo pasado sigue legible (archivo /agenda/aaaa-mm).
drop policy if exists events_select on guide.events;
create policy events_select on guide.events for select to anon, authenticated
  using (status in ('approved', 'cancelled') or (select guide.is_admin()));

-- Procedencia del agente (source, source_url, dedupe_key, agent_meta) fuera del alcance de los clientes:
-- el admin la lee por admin_list_events / export_events (DEFINER con assert_admin / is_admin).
revoke select on guide.events from anon, authenticated;
grant select (id, item_id, title_es, title_en, description_es, description_en, event_type, starts_at, ends_at,
              all_day, location_text, url, price_text, status, has_en, approved_at, created_at, updated_at)
  on guide.events to anon, authenticated;

-- ───────────── 6. Exportación (misma forma de vista; lee procedencia vía DEFINER) ─────────────
create or replace function guide.export_events_rows()
returns table (id uuid, status guide.event_status, source guide.event_source, event_type text, title_es text,
               title_en text, starts_at timestamptz, ends_at timestamptz, all_day boolean, place_name text,
               location_text text, url text, price_text text, source_url text, approved_at timestamptz,
               created_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.status, e.source, e.event_type, e.title_es, e.title_en, e.starts_at, e.ends_at, e.all_day,
         i.name, e.location_text, e.url, e.price_text, e.source_url, e.approved_at, e.created_at
  from guide.events e
  left join guide.items i on i.id = e.item_id
  where (select guide.is_admin());
$$;
revoke all on function guide.export_events_rows() from public, anon;
grant execute on function guide.export_events_rows() to authenticated, service_role;

create or replace view guide.export_events with (security_invoker = true) as
select r.id, r.status, r.source, r.event_type, r.title_es, r.title_en, r.starts_at, r.ends_at, r.all_day,
       r.place_name, r.location_text, r.url, r.price_text, r.source_url, r.approved_at, r.created_at
from guide.export_events_rows() r;
revoke all on guide.export_events from anon;
grant select on guide.export_events to authenticated, service_role;

-- ───────────── 7. Cambiar estado (publicar, descartar, cancelar, despublicar, recuperar) ─────────────
create or replace function guide.set_event_status(p_id uuid, p_status guide.event_status)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_id  uuid;
  v_st  guide.event_status;
  v_at  timestamptz;
  v_upd timestamptz;
begin
  perform guide.assert_admin();
  if p_id is null or p_status is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  update guide.events set status = p_status where id = p_id
  returning id, status, approved_at, updated_at into v_id, v_st, v_at, v_upd;
  if not found then
    raise exception 'event not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('id', v_id, 'status', v_st, 'approved_at', v_at, 'updated_at', v_upd);
end;
$$;
revoke all on function guide.set_event_status(uuid, guide.event_status) from public, anon;
grant execute on function guide.set_event_status(uuid, guide.event_status) to authenticated;

create or replace function guide.approve_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.set_event_status(p_id, 'approved');
end;
$$;
create or replace function guide.reject_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.set_event_status(p_id, 'rejected');
end;
$$;
revoke all on function guide.approve_event(uuid) from public, anon;
revoke all on function guide.reject_event(uuid) from public, anon;
grant execute on function guide.approve_event(uuid), guide.reject_event(uuid) to authenticated;

-- ───────────── 8. Contadores del menú y de la pantalla ─────────────
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
    'total',              count(*))
  into v
  from (select e.status, e.source, guide.event_is_past(e.starts_at, e.ends_at, e.all_day) as past
        from guide.events e) x;
  return v;
end;
$$;
revoke all on function guide.admin_events_summary() from public, anon;
grant execute on function guide.admin_events_summary() to authenticated;

-- ───────────── 9. Listado del panel: filtros, búsqueda sin inyección, paginación ─────────────
-- DEFINER solo para leer la procedencia (columnas sin grant de cliente). Solo lectura; assert_admin lo primero.
create or replace function guide.admin_list_events(
  p_status     guide.event_status default null,
  p_source     guide.event_source default null,
  p_when       text default null,
  p_from       timestamptz default null,
  p_to         timestamptz default null,
  p_item_id    uuid default null,
  p_event_type text default null,
  p_query      text default null,
  p_id         uuid default null,
  p_limit      integer default 50,
  p_offset     integer default 0
)
returns table (
  id uuid, status guide.event_status, source guide.event_source, event_type text,
  title_es text, title_en text, description_es text, description_en text,
  starts_at timestamptz, ends_at timestamptz, all_day boolean, location_text text, url text, price_text text,
  item_id uuid, item_name text, item_slug text, item_category text, item_published boolean,
  source_url text, agent_meta jsonb, has_en boolean, is_past boolean,
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
  v_desc   boolean := coalesce(p_when = 'past', false);
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  if p_when is not null and p_when not in ('upcoming', 'past', 'all') then
    raise exception 'invalid when' using errcode = '22023';
  end if;
  if char_length(coalesce(p_query, '')) > 200 then
    raise exception 'query too long' using errcode = '22023';
  end if;
  if p_event_type is not null and p_event_type not in ('competition', 'workshop', 'outing', 'social', 'course', 'other') then
    raise exception 'invalid event type' using errcode = '22023';
  end if;

  v_q := lower(extensions.unaccent(btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'))));
  select coalesce(array_agg('%' || replace(replace(replace(w, '\', '\\'), '%', '\%'), '_', '\_') || '%'), '{}')
  into v_terms
  from unnest(string_to_array(nullif(v_q, ''), ' ')) as w
  where w <> '';

  return query
  with base as (
    select e.id, e.status, e.source, e.event_type, e.title_es, e.title_en, e.description_es, e.description_en,
           e.starts_at, e.ends_at, e.all_day, e.location_text, e.url, e.price_text,
           e.item_id, i.name as item_name, i.slug::text as item_slug, i.category::text as item_category,
           i.published as item_published, e.source_url, e.agent_meta, e.has_en,
           guide.event_is_past(e.starts_at, e.ends_at, e.all_day) as is_past,
           e.approved_at, e.created_at, e.updated_at
    from guide.events e
    left join guide.items i on i.id = e.item_id
    where (p_id is null or e.id = p_id)
      and (p_status is null or e.status = p_status)
      and (p_source is null or e.source = p_source)
      and (p_from is null or e.starts_at >= p_from)
      and (p_to is null or e.starts_at < p_to)
      and (p_item_id is null or e.item_id = p_item_id)
      and (p_event_type is null or e.event_type = p_event_type)
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
         f.item_id, f.item_name, f.item_slug, f.item_category, f.item_published,
         f.source_url, f.agent_meta, f.has_en, f.is_past, f.approved_at, f.created_at, f.updated_at,
         count(*) over () as total_count
  from filtered f
  order by case when v_desc then f.starts_at end desc,
           case when not v_desc then f.starts_at end asc,
           f.id
  limit v_limit offset v_offset;
end;
$$;
revoke all on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
  uuid, text, text, uuid, integer, integer) from public, anon;
grant execute on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
  uuid, text, text, uuid, integer, integer) to authenticated;
