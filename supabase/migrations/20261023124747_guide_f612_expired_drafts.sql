-- F6.12 (g) · D33: los borradores de eventos caducados se descartan solos con motivo «Caducado» (reject_reason =
-- 'expired') en una tarea nocturna de pg_cron (SQL puro, sin pg_net). 'expired' es del sistema: el admin no lo elige
-- (set_event_status → 22023; UPDATE directo → 42501), pero lo conserva al editar y lo borra al recuperar.
-- «Caducado» = guide.event_is_past (la misma regla del contador del menú y del listado). Registro: el patrón de
-- events_log_activity (una fila por evento, by = 'system', ahora con el motivo en details). Idempotente.

-- ───────────── 1. Motivo 'expired' ─────────────
do $$
begin
  alter table guide.events drop constraint if exists events_reject_reason_valid;
  alter table guide.events add constraint events_reject_reason_valid check (
    reject_reason is null
    or (status = 'rejected'
        and reject_reason in ('duplicate', 'not_climbing', 'members_only', 'outside_area', 'wrong_data', 'expired')));
end $$;

-- ───────────── 2. Guarda: el admin no pone 'expired' ─────────────
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
    if new.status in ('approved', 'cancelled') then
      new.approved_at := coalesce(new.approved_at, now());
    else
      new.approved_at := null;
    end if;
    if new.status <> 'rejected' then
      new.reject_reason := null;
    end if;
    return new;
  end if;

  if not v_admin then
    -- Agente (F8) o cualquier rol que salte RLS: solo INSERT de borradores propios.
    if tg_op <> 'INSERT' or new.status <> 'draft' or new.source <> 'agent' or new.approved_at is not null
       or new.reject_reason is not null then
      raise exception 'event_write_forbidden' using errcode = '42501';
    end if;
    -- O1: el agente no elige id ni fechas de alta.
    new.id := gen_random_uuid();
    new.created_at := now();
    new.updated_at := now();
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
    if new.id is distinct from old.id then
      raise exception 'event_id_immutable' using errcode = '42501';
    end if;
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

  -- D33: «Caducado» lo pone solo la tarea nocturna (mantenimiento); el admin conserva el que ya hay, no lo elige.
  if v_admin and new.reject_reason = 'expired'
     and (tg_op = 'INSERT' or old.reject_reason is distinct from 'expired') then
    raise exception 'event_reason_reserved' using errcode = '42501';
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

  -- O7: lo público siempre tiene un lugar visible (también al editarlo): texto o ficha publicada.
  if new.status in ('approved', 'cancelled') and new.location_text is null
     and (new.item_id is null
          or not coalesce((select i.published from guide.items i where i.id = new.item_id), false)) then
    raise exception 'event_place_required' using errcode = '23514';
  end if;

  if new.status = 'approved' and (v_from is null or v_from = 'draft') then
    if guide.event_is_past(new.starts_at, new.ends_at, new.all_day) then
      raise exception 'event_in_past' using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;
revoke all on function guide.events_before_write() from public, anon, authenticated;

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
  if p_reject_reason = 'expired' then
    raise exception 'reserved reject reason' using errcode = '22023';
  end if;
  update guide.events set status = p_status, reject_reason = p_reject_reason where id = p_id
  returning id, status, approved_at, reject_reason, updated_at into v_id, v_st, v_at, v_rr, v_upd;
  if not found then
    raise exception 'event not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object('id', v_id, 'status', v_st, 'approved_at', v_at, 'reject_reason', v_rr, 'updated_at', v_upd);
end;
$$;
revoke all on function guide.set_event_status(uuid, guide.event_status, text) from public, anon, service_role;
grant execute on function guide.set_event_status(uuid, guide.event_status, text) to authenticated;

-- ───────────── 3. Registro: el motivo del descarte en details (lista cerrada, sin datos personales) ─────────────
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
    if new.status = 'rejected' and new.reject_reason is not null then
      v_det := v_det || jsonb_build_object('reason', new.reject_reason);
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
revoke all on function guide.events_log_activity() from public, anon, authenticated, service_role;

-- ───────────── 4. Descarte de caducados (solo mantenimiento: postgres vía pg_cron) ─────────────
-- INVOKER y sin EXECUTE para nadie salvo el dueño (postgres). Además exige rolbypassrls y que no haya JWT de
-- PostgREST, y deja guide.draft_op como estaba. Devuelve cuántos ha descartado.
create or replace function guide.discard_expired_event_drafts()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_prev text := coalesce(current_setting('guide.draft_op', true), '');
  v_n    integer;
begin
  if not coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)
     or coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ? 'role' then
    raise exception 'maintenance only' using errcode = '42501';
  end if;
  perform set_config('guide.draft_op', 'maintenance', true);
  update guide.events e
  set status = 'rejected', reject_reason = 'expired'
  where e.status = 'draft'
    and guide.event_is_past(e.starts_at, e.ends_at, e.all_day);
  get diagnostics v_n = row_count;
  perform set_config('guide.draft_op', v_prev, true);
  return v_n;
end;
$$;
revoke all on function guide.discard_expired_event_drafts() from public, anon, authenticated, service_role;

-- ───────────── 5. Tarea diaria ─────────────
-- 02:30 UTC = 03:30 en Madrid en invierno (CET) y 04:30 en verano (CEST): siempre tras la medianoche de Madrid, que es
-- cuando caducan los de todo el día. cron.schedule con el mismo nombre actualiza el job (idempotente).
select cron.schedule('guide-events-discard-expired', '30 2 * * *', $$select guide.discard_expired_event_drafts()$$);
