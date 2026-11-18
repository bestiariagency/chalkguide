-- F6.12 (d): en mantenimiento (postgres + guide.draft_op = 'maintenance') la guarda también normaliza approved_at y
-- reject_reason, para que seeds y fixtures que insertan 'approved' sin fecha cumplan events_approved_at. Idempotente.
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
