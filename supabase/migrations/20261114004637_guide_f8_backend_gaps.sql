-- F8 · huecos de backend que dejaron 8.9 (noticias públicas) y 8.10 (panel de noticias). Idempotente.
-- 1. subscribe_newsletter: nuevo origen 'noticias' (formulario de /noticias) en la lista cerrada de p_source y en los
--    CHECK de consent_source y related_consent_source. Mismo cuerpo que guide_d66_veto_fixes.
-- 2. events.run_id (FK a ingest_runs, como news.run_id): la ingesta lo rellena solo en el INSERT (J20); la guarda lo
--    anula en las altas del admin y lo hace inmutable (event_provenance_immutable). No se concede a anon ni se lee por
--    columna desde authenticated: sale por admin_list_events (DEFINER) junto con la fecha de la recogida.
-- 3. search_news: filtro opcional p_scope y columna has_note (hay nota de Xavi en el idioma pedido) para la insignia
--    «Con nota de Xavi». Cambia el tipo de retorno: drop y create.
-- 4. admin_search (⌘K): tipo 'news' (sin descartadas, como los eventos), entre 'event' y 'media'.
-- 5. Exportar (D36): módulo 'news' en export_build (y por tanto en admin_export y admin_export_count) sobre la vista
--    export_news, sin datos personales (approved_by fuera) y sin agent_meta, dedupe_key, url_key, run_id ni similarity.
-- No toca public.

-- ───────────── 1. Origen 'noticias' ─────────────
alter table guide.subscribers drop constraint if exists subscribers_consent_source_check;
alter table guide.subscribers add constraint subscribers_consent_source_check check (
  consent_source = any (array['footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup',
                              'newsletter_page', 'noticias']));
alter table guide.subscribers drop constraint if exists subscribers_related_source_check;
alter table guide.subscribers add constraint subscribers_related_source_check check (
  related_consent_source is null or related_consent_source in
    ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup', 'newsletter_page', 'noticias',
     'preferences', 'chalk_waitlist'));

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
  if p_source is null or p_source not in ('footer', 'article', 'article_mid', 'article_end', 'item_page', 'home', 'popup', 'newsletter_page', 'noticias') then
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
  -- V1: con afines vigente el token no rota (cualquiera puede re-suscribir un email ajeno; rotarlo rompería la retirada
  -- en un clic de los emails de afines ya enviados).
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
        unsubscribe_token  = case when guide.subscribers.related_status = 'granted' then guide.subscribers.unsubscribe_token
                                  else gen_random_uuid() end,
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

revoke all on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  from public, anon, authenticated, service_role;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)
  to anon, authenticated;

-- ───────────── 2. events.run_id ─────────────
alter table guide.events add column if not exists run_id uuid references guide.ingest_runs(id) on delete set null;
create index if not exists events_run_id_idx on guide.events (run_id) where run_id is not null;

create or replace function guide.events_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_admin   boolean := guide.is_admin();
  v_maint   boolean := guide.item_live_exempt(null);
  v_from    guide.event_status;
  v_cat     text;
  v_pub     boolean;
  v_release boolean := false;
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
    -- J27b (D33-3): al caducar, la evidencia del agente se reduce a la confianza.
    if tg_op = 'UPDATE' and old.source = 'agent' and old.status = 'draft' and new.status <> 'draft' then
      new.agent_meta := jsonb_build_object('confidence', old.agent_meta -> 'confidence');
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
    new.run_id := null;
    if new.status not in ('draft', 'approved') then
      raise exception 'event_invalid_transition' using errcode = '55000', detail = 'insert>' || new.status::text;
    end if;
  else
    v_from := old.status;
    new.created_at := old.created_at;
    if new.id is distinct from old.id then
      raise exception 'event_id_immutable' using errcode = '42501';
    end if;
    -- J18b: única excepción a event_provenance_immutable, atada a la fila (GUC release_dedupe:<id>).
    v_release := coalesce(current_setting('guide.draft_op', true), '') = 'release_dedupe:' || old.id::text
                 and old.status = 'rejected' and old.reject_reason = 'wrong_data' and new.status = 'rejected'
                 and new.dedupe_key = 'released:' || old.id::text;
    if new.source is distinct from old.source or new.run_id is distinct from old.run_id
       or (not v_release and new.dedupe_key is distinct from old.dedupe_key)
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
    -- J27b (O5): al aprobar o descartar un borrador del agente, la evidencia se reduce a la confianza.
    if old.source = 'agent' and old.status = 'draft' and new.status <> 'draft' then
      new.agent_meta := jsonb_build_object('confidence', old.agent_meta -> 'confidence');
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

revoke all on function guide.events_before_write() from public, anon, authenticated, service_role;

create or replace function guide.ingest_submit_event(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_keys    constant text[] := array['title_es', 'title_en', 'description_es', 'description_en', 'event_type',
                                     'starts_at', 'ends_at', 'all_day', 'location_text', 'item_id', 'url', 'price_text',
                                     'source_url', 'confidence', 'note', 'excerpt', 'inferred'];
  c_reasons constant text[] := array['not_object', 'too_large', 'unknown_key', 'secret', 'missing_field', 'invalid_type',
                                     'bad_chars', 'too_long', 'bad_url', 'shortener', 'pii', 'invalid_date', 'dates',
                                     'past', 'too_far', 'event_type', 'item', 'confidence', 'inferred', 'constraint'];
  c_iso     constant text := '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:?\d{2})$';
  v_token    uuid;
  v_run      guide.ingest_runs;
  v_reason   text;
  v_field    text;
  v_title_es text;
  v_title_en text;
  v_desc_es  text;
  v_desc_en  text;
  v_type     text;
  v_loc      text;
  v_price    text;
  v_note     text;
  v_excerpt  text;
  v_tmp      text;
  v_starts   timestamptz;
  v_ends     timestamptz;
  v_all_day  boolean := false;
  v_item     uuid;
  v_url      jsonb;
  v_src      jsonb;
  v_conf     numeric;
  v_inferred jsonb;
  v_key      text;
  v_dup      guide.event_status;
  v_flags    text[] := '{}';
begin
  v_token := guide.ingest_auth(p_token);
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  v_run := guide.ingest_run_for(v_token, p_run_id, 'events');

  -- J32: 80 llamadas por run (las inválidas también cuentan).
  update guide.ingest_runs r set calls = r.calls + 1 where r.id = v_run.id and r.calls < 80;
  if not found then
    return jsonb_build_object('result', 'rejected', 'reason', 'call_limit');
  end if;

  begin
    if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
      raise exception 'not_object';
    end if;
    if octet_length(p_payload::text) > 16384 then
      raise exception 'too_large';
    end if;
    if exists (select 1 from jsonb_object_keys(p_payload) k where k <> all (c_keys)) then
      raise exception 'unknown_key';
    end if;
    if guide.ingest_has_secret(p_payload::text, p_token) then
      raise exception 'secret';
    end if;

    v_title_es := guide.ingest_field_text(p_payload, 'title_es', 200, false, true);
    v_title_en := guide.ingest_field_text(p_payload, 'title_en', 200, false, false);
    v_desc_es  := guide.ingest_field_text(p_payload, 'description_es', 2000, true, false);
    v_desc_en  := guide.ingest_field_text(p_payload, 'description_en', 2000, true, false);
    v_loc      := guide.ingest_field_text(p_payload, 'location_text', 200, false, false);
    v_price    := guide.ingest_field_text(p_payload, 'price_text', 120, false, false);
    v_note     := guide.ingest_field_text(p_payload, 'note', 500, true, false);
    v_excerpt  := guide.ingest_field_text(p_payload, 'excerpt', 1000, true, false);

    v_type := coalesce(guide.ingest_field_text(p_payload, 'event_type', 20, false, false), 'other');
    if v_type <> all (array['competition', 'workshop', 'outing', 'social', 'course', 'other']) then
      raise exception 'event_type' using detail = 'event_type';
    end if;

    if jsonb_typeof(p_payload -> 'starts_at') is distinct from 'string' or (p_payload ->> 'starts_at') !~ c_iso then
      raise exception 'invalid_date' using detail = 'starts_at';
    end if;
    begin
      v_starts := (p_payload ->> 'starts_at')::timestamptz;
    exception when others then
      raise exception 'invalid_date' using detail = 'starts_at';
    end;
    if coalesce(jsonb_typeof(p_payload -> 'ends_at'), 'null') <> 'null' then
      if jsonb_typeof(p_payload -> 'ends_at') <> 'string' or (p_payload ->> 'ends_at') !~ c_iso then
        raise exception 'invalid_date' using detail = 'ends_at';
      end if;
      begin
        v_ends := (p_payload ->> 'ends_at')::timestamptz;
      exception when others then
        raise exception 'invalid_date' using detail = 'ends_at';
      end;
      if v_ends < v_starts then
        raise exception 'dates' using detail = 'ends_at';
      end if;
    end if;
    if coalesce(jsonb_typeof(p_payload -> 'all_day'), 'null') <> 'null' then
      if jsonb_typeof(p_payload -> 'all_day') <> 'boolean' then
        raise exception 'invalid_type' using detail = 'all_day';
      end if;
      v_all_day := (p_payload ->> 'all_day')::boolean;
    end if;
    -- J15 / D71: confirmados y futuros, como mucho a 18 meses.
    if guide.event_is_past(v_starts, v_ends, v_all_day) then
      raise exception 'past' using detail = 'starts_at';
    end if;
    if v_starts > now() + interval '18 months' then
      raise exception 'too_far' using detail = 'starts_at';
    end if;

    if coalesce(jsonb_typeof(p_payload -> 'item_id'), 'null') <> 'null' then
      if jsonb_typeof(p_payload -> 'item_id') <> 'string'
         or (p_payload ->> 'item_id') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        raise exception 'item' using detail = 'item_id';
      end if;
      v_item := (p_payload ->> 'item_id')::uuid;
      if not exists (select 1 from guide.items i where i.id = v_item and i.category = 'gym' and i.published) then
        raise exception 'item' using detail = 'item_id';
      end if;
    end if;

    v_tmp := guide.ingest_field_text(p_payload, 'url', 1000, false, false);
    if v_tmp is not null then
      begin
        v_url := guide.ingest_url(v_tmp);
      exception when raise_exception then
        get stacked diagnostics v_reason = message_text;
        raise exception '%', v_reason using detail = 'url';
      end;
      if char_length(v_url ->> 'url') > 500 then
        raise exception 'too_long' using detail = 'url';
      end if;
    end if;
    v_tmp := guide.ingest_field_text(p_payload, 'source_url', 1000, false, true);
    begin
      v_src := guide.ingest_url(v_tmp);
    exception when raise_exception then
      get stacked diagnostics v_reason = message_text;
      raise exception '%', v_reason using detail = 'source_url';
    end;

    if (case when jsonb_typeof(p_payload -> 'confidence') is distinct from 'number' then true
             else (p_payload ->> 'confidence')::numeric not between 0 and 1 end) then
      raise exception 'confidence' using detail = 'confidence';
    end if;
    v_conf := (p_payload ->> 'confidence')::numeric;

    if coalesce(jsonb_typeof(p_payload -> 'inferred'), 'null') <> 'null' then
      v_inferred := p_payload -> 'inferred';
      if jsonb_typeof(v_inferred) <> 'array' or jsonb_array_length(v_inferred) > 10
         or not (v_inferred <@ '["type","start","end","all_day","price","place","title_en","description","url"]'::jsonb) then
        raise exception 'inferred' using detail = 'inferred';
      end if;
    end if;

    if guide.ingest_has_pii(concat_ws(E'\n|\n', v_title_es, v_title_en, v_desc_es, v_desc_en, v_loc, v_price,
                                      v_note, v_excerpt)) then
      raise exception 'pii';
    end if;
  exception when others then
    get stacked diagnostics v_reason = message_text, v_field = pg_exception_detail;
    if v_reason is null or v_reason <> all (c_reasons) then
      v_reason := 'invalid';
    end if;
    if v_field is null or v_field <> all (c_keys) then
      v_field := null;
    end if;
    perform guide.ingest_count_invalid(v_run.id, v_reason);
    return jsonb_strip_nulls(jsonb_build_object('result', 'invalid', 'reason', v_reason, 'field', v_field));
  end;

  -- J32: 40 filas por run (en dry_run, las que se habrían insertado).
  if (case when v_run.dry_run then v_run.would_insert else v_run.inserted end) >= 40 then
    return jsonb_build_object('result', 'rejected', 'reason', 'row_limit');
  end if;

  -- J18 / J19: clave del servidor; respuesta de duplicado sin más información.
  v_key := guide.ingest_dedupe_key(v_src ->> 'host', (v_starts at time zone 'Europe/Madrid')::date, v_title_es);
  select e.status into v_dup from guide.events e where e.dedupe_key = v_key;
  if found then
    update guide.ingest_runs r
    set duplicates = r.duplicates + case when v_dup = 'rejected' then 0 else 1 end,
        duplicate_rejected = r.duplicate_rejected + case when v_dup = 'rejected' then 1 else 0 end
    where r.id = v_run.id;
    return jsonb_build_object('result', 'duplicate');
  end if;

  if v_run.dry_run then
    update guide.ingest_runs r set would_insert = r.would_insert + 1 where r.id = v_run.id;
    return jsonb_build_object('result', 'would_insert');
  end if;

  -- J24 (eventos): sin allowlist, pero se marca la fuente no listada; J23: se marca el punycode.
  if not exists (select 1 from guide.news_sources s
                 where s.active and ((v_src ->> 'host') = s.domain or (v_src ->> 'host') like '%.' || s.domain)) then
    v_flags := v_flags || 'fuente no listada'::text;
  end if;
  if (v_src ->> 'punycode')::boolean or coalesce((v_url ->> 'punycode')::boolean, false) then
    v_flags := v_flags || 'dominio punycode'::text;
  end if;
  if cardinality(v_flags) > 0 then
    v_note := left(concat_ws(' · ', array_to_string(v_flags, ' · '), v_note), 500);
  end if;

  begin
    insert into guide.events (title_es, title_en, description_es, description_en, event_type, starts_at, ends_at,
                              all_day, location_text, item_id, url, price_text, status, source, source_url,
                              dedupe_key, run_id, agent_meta)
    values (v_title_es, v_title_en, v_desc_es, v_desc_en, v_type, v_starts, v_ends, v_all_day, v_loc, v_item,
            v_url ->> 'url', v_price, 'draft', 'agent', v_src ->> 'url', v_key, v_run.id,
            jsonb_strip_nulls(jsonb_build_object(
              'confidence', v_conf, 'note', v_note, 'excerpt', v_excerpt, 'inferred', v_inferred,
              'found_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))));
  exception
    when unique_violation then
      update guide.ingest_runs r set duplicates = r.duplicates + 1 where r.id = v_run.id;
      return jsonb_build_object('result', 'duplicate');
    when check_violation or not_null_violation or foreign_key_violation or string_data_right_truncation then
      perform guide.ingest_count_invalid(v_run.id, 'constraint');
      return jsonb_build_object('result', 'invalid', 'reason', 'constraint');
  end;

  update guide.ingest_runs r
  set inserted = r.inserted + 1, inserted_events = r.inserted_events + 1
  where r.id = v_run.id;
  update guide.news_sources s set last_seen_at = now()
  where s.active and ((v_src ->> 'host') = s.domain or (v_src ->> 'host') like '%.' || s.domain);
  return jsonb_build_object('result', 'inserted');
end;
$$;

revoke all on function guide.ingest_submit_event(text, uuid, jsonb) from public, anon, authenticated, service_role;
grant execute on function guide.ingest_submit_event(text, uuid, jsonb) to anon;

drop function if exists guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
                                                uuid, text[], text, uuid, text, integer, integer);
create function guide.admin_list_events(p_status guide.event_status default null, p_source guide.event_source default null,
                                        p_when text default null, p_from timestamptz default null,
                                        p_to timestamptz default null, p_item_id uuid default null,
                                        p_event_types text[] default null, p_query text default null,
                                        p_id uuid default null, p_sort text default null, p_limit integer default 50,
                                        p_offset integer default 0)
returns table(id uuid, status guide.event_status, source guide.event_source, event_type text, title_es text,
              title_en text, description_es text, description_en text, starts_at timestamptz, ends_at timestamptz,
              all_day boolean, location_text text, url text, price_text text, item_id uuid, item_name text,
              item_slug text, item_published boolean, source_url text, agent_meta jsonb, run_id uuid,
              run_started_at timestamptz, duplicate_of uuid, duplicate_of_status guide.event_status,
              reject_reason text, has_en boolean, is_past boolean, approved_at timestamptz, created_at timestamptz,
              updated_at timestamptz, total_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
           e.source_url, e.agent_meta, e.run_id, r.started_at as run_started_at,
           d.id as duplicate_of, d.status as duplicate_of_status,
           e.reject_reason, e.has_en,
           guide.event_is_past(e.starts_at, e.ends_at, e.all_day) as is_past,
           e.approved_at, e.created_at, e.updated_at
    from guide.events e
    left join guide.items i on i.id = e.item_id
    left join guide.ingest_runs r on r.id = e.run_id
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
         f.source_url, f.agent_meta, f.run_id, f.run_started_at, f.duplicate_of, f.duplicate_of_status,
         f.reject_reason, f.has_en, f.is_past, f.approved_at, f.created_at, f.updated_at,
         count(*) over () as total_count
  from filtered f
  order by case when not v_desc then f.is_past end asc,
           case when v_desc then f.starts_at end desc,
           case when not v_desc then f.starts_at end asc,
           f.id
  limit v_limit offset v_offset;
end;
$function$;

revoke all on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
                                               uuid, text[], text, uuid, text, integer, integer)
  from public, anon, service_role;
grant execute on function guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz,
                                                  uuid, text[], text, uuid, text, integer, integer)
  to authenticated;

-- ───────────── 3. search_news: p_scope y has_note ─────────────
drop function if exists guide.search_news(text, guide.locale, uuid, integer, integer);
drop function if exists guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope);
create function guide.search_news(p_query text, p_locale guide.locale, p_category_id uuid default null,
                                  p_limit integer default 20, p_offset integer default 0,
                                  p_scope guide.news_scope default null)
returns table(id uuid, slug text, title text, summary text, category_id uuid, category_key text, category_label text,
              scope guide.news_scope, source_name text, source_url text, published_at timestamptz, has_note boolean,
              indexable boolean, rank real, headline text, total_count bigint)
language plpgsql
stable
set search_path = ''
as $function$
#variable_conflict use_column
declare
  c_max_len constant integer := 200;
  c_opts constant text :=
    E'StartSel=\u0002, StopSel=\u0003, MaxWords=30, MinWords=12, ShortWord=3, MaxFragments=2, FragmentDelimiter=" … "';
  v_q text;
  v_rest text;
  v_last text;
  v_cfg regconfig;
  v_tsq tsquery;
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 1000);
begin
  if p_locale is null then
    raise exception 'invalid locale' using errcode = '22023';
  end if;
  if char_length(coalesce(p_query, '')) > c_max_len then
    raise exception 'query too long' using errcode = '22023';
  end if;
  v_q := btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:][:space:]]+', ' ', 'g'));
  if char_length(v_q) < 2 then
    return;
  end if;
  v_cfg := case p_locale when 'en' then 'guide.english_unaccent'::regconfig else 'guide.spanish_unaccent'::regconfig end;
  v_last := substring(v_q from '(?:^|\s)([[:alnum:]]{3,})$');
  v_rest := left(v_q, char_length(v_q) - coalesce(char_length(v_last), 0));
  if v_last is not null
     and (char_length(v_q) - char_length(replace(v_q, '"', ''))) % 2 = 0
     and v_rest !~* '(^|\s)or\s*$' then
    v_tsq := websearch_to_tsquery(v_cfg, v_rest) && to_tsquery(v_cfg, lower(v_last) || ':*');
  else
    v_tsq := websearch_to_tsquery(v_cfg, v_q);
  end if;
  if v_tsq is null or numnode(v_tsq) = 0 or querytree(v_tsq) = 'T' then
    return;
  end if;

  if p_locale = 'es' then
    return query
      with m as (
        select n.id as nid, ts_rank(n.search_es, v_tsq, 1) as r, count(*) over () as t
        from guide.news n
        where n.search_es @@ v_tsq and n.status = 'published'
          and (p_category_id is null or n.category_id = p_category_id)
          and (p_scope is null or n.scope = p_scope)
        order by r desc, n.published_at desc, n.id
        limit v_limit offset v_offset
      )
      select n.id, n.slug, n.title_es, n.summary_es, c.id, c.key, c.label_es, n.scope, n.source_name, n.source_url,
             n.published_at, n.author_note_es is not null, n.indexable, m.r,
             ts_headline(v_cfg, concat_ws(' ', n.summary_es, n.author_note_es), v_tsq, c_opts), m.t
      from m
      join guide.news n on n.id = m.nid
      left join guide.news_categories c on c.id = n.category_id
      order by m.r desc, n.published_at desc, n.id;
  else
    return query
      with m as (
        select n.id as nid, ts_rank(n.search_en, v_tsq, 1) as r, count(*) over () as t
        from guide.news n
        where n.search_en @@ v_tsq and n.status = 'published' and n.has_en
          and (p_category_id is null or n.category_id = p_category_id)
          and (p_scope is null or n.scope = p_scope)
        order by r desc, n.published_at desc, n.id
        limit v_limit offset v_offset
      )
      select n.id, n.slug, n.title_en, n.summary_en, c.id, c.key, c.label_en, n.scope, n.source_name, n.source_url,
             n.published_at, n.author_note_en is not null, n.indexable_en, m.r,
             ts_headline(v_cfg, concat_ws(' ', n.summary_en, n.author_note_en), v_tsq, c_opts), m.t
      from m
      join guide.news n on n.id = m.nid
      left join guide.news_categories c on c.id = n.category_id
      order by m.r desc, n.published_at desc, n.id;
  end if;
end;
$function$;

revoke all on function guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope)
  from public, anon, authenticated, service_role;
grant execute on function guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope)
  to anon, authenticated;

-- ───────────── 4. ⌘K: tipo 'news' ─────────────
create or replace function guide.admin_search(p_query text, p_kinds text[] default null, p_limit integer default 4)
returns table(kind text, id uuid, key text, title text, data jsonb, status text, matched_field text, snippet text,
              rank integer, total_in_kind bigint)
language plpgsql
stable
set search_path to ''
as $function$
#variable_conflict use_column
declare
  v_q          text;
  v_like       text;
  v_prefix     text;
  v_words      text;
  v_tsq_es     tsquery;
  v_tsq_en     tsquery;
  v_limit      integer := least(greatest(coalesce(p_limit, 4), 1), 20);
  v_item_kinds text[];
  v_all_kinds  text[];
  v_kinds      text[];
begin
  perform guide.assert_admin();

  -- Recorte a 100 caracteres tras normalizar espacios; el left previo acota el coste de la normalización.
  v_q := btrim(regexp_replace(left(coalesce(p_query, ''), 400), '[[:cntrl:][:space:]]+', ' ', 'g'));
  v_q := btrim(lower(extensions.unaccent(left(v_q, 100))));
  if char_length(v_q) < 2 then
    raise exception 'query too short' using errcode = '22023';
  end if;

  select coalesce(array_agg(c.key order by c.sort_order, c.key), '{}') into v_item_kinds from guide.item_categories c;
  v_all_kinds := array['article'] || v_item_kinds || array['page', 'event', 'news', 'media'];
  if p_kinds is null or cardinality(p_kinds) = 0 then
    v_kinds := v_all_kinds;
  elsif cardinality(p_kinds) > 20 or not (p_kinds <@ v_all_kinds) then
    raise exception 'invalid kind' using errcode = '22023';
  else
    v_kinds := p_kinds;
  end if;

  -- Comodines de LIKE escapados (\ primero).
  v_prefix := replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_like   := '%' || v_prefix;

  -- Cuerpo: prefijos por palabra con solo letras y dígitos (sin operadores de tsquery). Palabras de 3 o más
  -- caracteres: un prefijo de 1–2 letras casaría con casi todos los artículos.
  select string_agg(w || ':*', ' & ') into v_words
  from unnest(string_to_array(btrim(regexp_replace(v_q, '[^[:alnum:]]+', ' ', 'g')), ' ')) as w
  where char_length(w) >= 3;
  if v_words is not null then
    v_tsq_es := to_tsquery('guide.spanish_unaccent'::regconfig, v_words);
    v_tsq_en := to_tsquery('guide.english_unaccent'::regconfig, v_words);
  end if;

  return query
  with cand as (
    select 'article'::text as kind, a.id, a.slug_es::text as key, a.title_es as title,
           jsonb_build_object('title_en', a.title_en, 'category_id', a.category_id, 'category_name_es', ac.name_es,
                              'published_at', a.published_at, 'updated_at', a.updated_at,
                              'has_draft', exists (select 1 from guide.content_drafts d where d.article_id = a.id)) as data,
           a.status::text as status, a.updated_at as sort_ts, null::boolean as is_past, null::timestamptz as starts_at,
           array['title_es', 'title_en'] as t_names, array[a.title_es, a.title_en] as t_vals,
           array['slug_es', 'slug_en', 'excerpt_es', 'excerpt_en'] as o_names,
           array[a.slug_es::text, a.slug_en::text, a.excerpt_es, a.excerpt_en] as o_vals,
           case when v_tsq_es is not null and a.search_es @@ v_tsq_es then 'body_es'
                when v_tsq_en is not null and a.search_en @@ v_tsq_en then 'body_en' end as body_hit
    from guide.articles a
    left join guide.article_categories ac on ac.id = a.category_id
    where 'article' = any (v_kinds)

    union all
    select i.category, i.id, i.slug::text, i.name,
           jsonb_strip_nulls(jsonb_build_object(
             'published', i.published, 'verified_at', i.verified_at, 'updated_at', i.updated_at,
             'has_draft', exists (select 1 from guide.content_drafts d where d.item_id = i.id),
             'district', coalesce(g.district, r.district), 'city', coalesce(g.city, r.city),
             'turnaround_days_min', r.turnaround_days_min, 'turnaround_days_max', r.turnaround_days_max,
             'brand', s.brand, 'model', s.model, 'price_min_eur', s.price_min_eur, 'price_max_eur', s.price_max_eur,
             'is_affiliate', s.is_affiliate)),
           case when i.published then 'published' else 'unpublished' end, i.updated_at, null, null,
           array['name'], array[i.name],
           array['slug', 'summary_es', 'summary_en', 'district', 'city', 'address', 'metro_stations', 'brand', 'model'],
           array[i.slug::text, i.summary_es, i.summary_en, coalesce(g.district, r.district), coalesce(g.city, r.city),
                 g.address, array_to_string(g.metro_stations, ', '), s.brand, s.model],
           null
    from guide.items i
    left join guide.gyms g on g.item_id = i.id
    left join guide.resolers r on r.item_id = i.id
    left join guide.shoes s on s.item_id = i.id
    where i.category = any (v_kinds)

    union all
    select 'page', p.id, p.key, p.title_es,
           jsonb_build_object('title_en', p.title_en, 'slug_es', p.slug_es::text, 'published', p.published,
                              'revised_on', p.revised_on, 'updated_at', p.updated_at,
                              'has_draft', exists (select 1 from guide.content_drafts d where d.page_id = p.id)),
           case when p.published then 'published' else 'unpublished' end, p.updated_at, null, null,
           array['title_es', 'title_en'], array[p.title_es, p.title_en],
           array['slug_es', 'slug_en', 'key'], array[p.slug_es::text, p.slug_en::text, p.key],
           null
    from guide.pages p
    where 'page' = any (v_kinds)

    union all
    select 'event', e.id, null, e.title_es,
           jsonb_build_object('title_en', e.title_en, 'starts_at', e.starts_at, 'ends_at', e.ends_at, 'all_day', e.all_day,
                              'location_text', e.location_text, 'item_id', e.item_id, 'item_name', it.name,
                              'event_type', e.event_type, 'updated_at', e.updated_at),
           e.status::text, e.updated_at, guide.event_is_past(e.starts_at, e.ends_at, e.all_day), e.starts_at,
           array['title_es', 'title_en'], array[e.title_es, e.title_en],
           array['location_text', 'item_name'], array[e.location_text, it.name],
           null
    from guide.events e
    left join guide.items it on it.id = e.item_id
    where 'event' = any (v_kinds) and e.status <> 'rejected'

    union all
    select 'news', n.id, n.slug, n.title_es,
           jsonb_build_object('title_en', n.title_en, 'category_id', n.category_id, 'category_label_es', nc.label_es,
                              'scope', n.scope, 'source_name', n.source_name, 'published_at', n.published_at,
                              'has_note', n.author_note_es is not null, 'updated_at', n.updated_at),
           n.status::text, n.updated_at, null, null,
           array['title_es', 'title_en'], array[n.title_es, n.title_en],
           array['slug', 'summary_es', 'summary_en', 'author_note_es', 'source_name'],
           array[n.slug, n.summary_es, n.summary_en, n.author_note_es, n.source_name],
           null
    from guide.news n
    left join guide.news_categories nc on nc.id = n.category_id
    where 'news' = any (v_kinds) and n.status <> 'rejected'

    union all
    select 'media', m.id, m.storage_path, coalesce(m.original_filename, m.storage_path),
           jsonb_build_object('storage_path', m.storage_path, 'version', m.version, 'dominant_color', m.dominant_color,
                              'alt_es', m.alt_es, 'missing_alt', (m.alt_es is null or btrim(m.alt_es) = ''),
                              'width', m.width, 'height', m.height, 'updated_at', m.updated_at),
           case when m.alt_es is null or btrim(m.alt_es) = '' then 'missing_alt' end, m.updated_at, null, null,
           array['original_filename'], array[m.original_filename],
           array['alt_es', 'alt_en', 'caption_es', 'caption_en', 'credit'],
           array[m.alt_es, m.alt_en, m.caption_es, m.caption_en, m.credit],
           null
    from guide.media m
    where 'media' = any (v_kinds)
  ),
  scored as (
    select c.kind, c.id, c.key, c.title, c.data, c.status, c.sort_ts, c.is_past, c.starts_at,
           h.rnk, h.field, h.val
    from cand c
    cross join lateral (
      select x.rnk, x.field, x.val
      from (
        select case when lower(extensions.unaccent(t.v)) like v_prefix escape '\' then 1 else 2 end as rnk,
               t.n as field, t.v as val, t.o as ord
        from unnest(c.t_names, c.t_vals) with ordinality as t(n, v, o)
        where lower(extensions.unaccent(t.v)) like v_like escape '\'
        union all
        select 3, o.n, o.v, 100 + o.o
        from unnest(c.o_names, c.o_vals) with ordinality as o(n, v, o)
        where lower(extensions.unaccent(o.v)) like v_like escape '\'
        union all
        select 4, c.body_hit, null, 1000
        where c.body_hit is not null
      ) x
      order by x.rnk, x.ord
      limit 1
    ) h
  ),
  ranked as (
    select s.*,
           row_number() over (
             partition by s.kind
             order by s.rnk,
                      s.is_past nulls first,
                      case when s.is_past is false then s.starts_at end asc,
                      case when s.is_past then s.starts_at end desc,
                      s.sort_ts desc, s.id
           ) as rn,
           count(*) over (partition by s.kind) as tot
    from scored s
  ),
  top as (
    select * from ranked r where r.rn <= v_limit
  ),
  ev as (
    select ai.id, ai.source, ai.duplicate_of
    from guide.admin_events_agent_info(array(select t.id from top t where t.kind = 'event')) ai
  )
  select t.kind, t.id, t.key, t.title,
         case t.kind
           when 'event' then t.data || jsonb_build_object('source', ev.source, 'duplicate_of', ev.duplicate_of,
                                                          'is_past', t.is_past)
           when 'media' then t.data || jsonb_build_object('usage_count',
                               (select count(*) from guide.media_usage u where u.media_id = t.id))
           else t.data
         end,
         t.status, t.field,
         case
           when t.rnk = 3 and char_length(t.val) <= 120 then t.val
           when t.rnk = 3 then (
             select case when z.st > 1 then '…' else '' end || substr(t.val, z.st, 120)
                    || case when z.st + 120 <= char_length(t.val) then '…' else '' end
             from (select greatest(1, strpos(lower(extensions.unaccent(t.val)), v_q) - 40) as st) z)
           when t.rnk = 4 then (
             select btrim(ts_headline(
                      case t.field when 'body_es' then 'guide.spanish_unaccent' else 'guide.english_unaccent' end::regconfig,
                      regexp_replace(
                        replace(replace(replace(replace(replace(replace(
                          regexp_replace(case t.field when 'body_es' then a.body_html_es else a.body_html_en end,
                                         '<[^>]*>', ' ', 'g'),
                          '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''), '&amp;', '&'),
                        '[[:space:]]+', ' ', 'g'),
                      case t.field when 'body_es' then v_tsq_es else v_tsq_en end,
                      'StartSel="",StopSel="",MaxWords=18,MinWords=8,ShortWord=2,MaxFragments=1,FragmentDelimiter=" … "'))
             from guide.articles a where a.id = t.id)
         end,
         t.rnk, t.tot
  from top t
  left join ev on t.kind = 'event' and ev.id = t.id
  order by array_position(v_all_kinds, t.kind), t.rn;
end;
$function$;

revoke all on function guide.admin_search(text, text[], integer) from public, anon, service_role;
grant execute on function guide.admin_search(text, text[], integer) to authenticated;

-- ───────────── 5. Exportar noticias (D36) ─────────────
-- Solo la lee export_build (corre como owner desde admin_export/admin_export_count). Ningún rol de la API.
drop view if exists guide.export_news;
create view guide.export_news with (security_invoker = true) as
select n.id, n.status, n.source, n.scope, n.category_id, c.key as category_key, c.label_es as category_es,
       n.slug, n.title_es, n.title_en, n.summary_es, n.summary_en, n.author_note_es, n.author_note_en,
       n.has_en, n.indexable, n.indexable_en, array_to_string(n.tags, ', ') as tags,
       n.source_id, n.source_name, n.source_title, n.source_url, n.source_published_on, n.source_lang,
       n.media_id, n.image_license, n.image_credit, n.reject_reason,
       n.published_at, n.first_published_at, n.created_at, n.updated_at
from guide.news n
left join guide.news_categories c on c.id = n.category_id
where (select guide.is_admin());
revoke all on guide.export_news from public, anon, authenticated, service_role;

create or replace function guide.export_build(p_module text, p_format text, p_filters jsonb, p_count_only boolean)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  c_cap_max   constant integer := 50000;
  c_uuid      constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  c_purposes  constant text[] := array['backup', 'send_tool', 'data_request', 'audit', 'other'];
  c_sub_min   constant text[] := array['email', 'locale', 'status', 'consent_at', 'confirmed_at'];
  v_cap_set   text := current_setting('guide.export_cap', true);
  v_cap       integer := c_cap_max;
  v_take      integer;
  v_f         jsonb := coalesce(p_filters, '{}'::jsonb);
  v_view      text;
  v_allowed   text[];
  v_key       text;
  v_all_cols  text[];
  v_permitted text[];
  v_default   text[];
  v_cols      text[];
  v_drop      text[];
  v_clean     jsonb := '{}'::jsonb;
  -- filtros ya validados
  v_statuses  text[];
  v_df        text;
  v_from      timestamptz;
  v_to        timestamptz;
  v_ids       uuid[];
  v_category  text;
  v_cat_id    uuid;
  v_item_id   uuid;
  v_has_en    boolean;
  v_published boolean;
  v_with_body boolean;
  v_locale    text;
  v_source    text;
  v_sources   text[];
  v_types     text[];
  v_scopes    text[];
  v_news_cat  uuid;
  v_versions  integer[];
  v_purpose   text;
  v_n         bigint;
  v_rows      jsonb;
begin
  if v_cap_set ~ '^\d{1,6}$' then
    v_cap := least(c_cap_max, greatest(1, v_cap_set::integer));
  end if;

  if p_module is null or p_module not in ('articles', 'items', 'user_reviews', 'subscribers', 'events', 'news') then
    raise exception 'invalid module' using errcode = '22023';
  end if;
  if not p_count_only and (p_format is null or p_format not in ('csv', 'json')) then
    raise exception 'invalid format' using errcode = '22023';
  end if;
  if jsonb_typeof(v_f) <> 'object' then
    raise exception 'invalid filters' using errcode = '22023';
  end if;
  v_view := 'export_' || p_module;

  v_allowed := array['statuses', 'date_field', 'from', 'to', 'ids', 'columns'] ||
    case p_module
      when 'articles'     then array['category_id', 'has_en', 'with_body']
      when 'items'        then array['category', 'published', 'has_en', 'with_body']
      when 'user_reviews' then array['category', 'locale', 'item_id']
      when 'subscribers'  then array['sources', 'locale', 'consent_version', 'purpose']
      when 'events'       then array['source', 'event_types', 'item_id']
      when 'news'         then array['source', 'category_id', 'scopes', 'has_en']
    end;
  for v_key in select jsonb_object_keys(v_f) loop
    if not (v_key = any (v_allowed)) then
      raise exception 'invalid filter: %', left(v_key, 40) using errcode = '22023';
    end if;
  end loop;

  -- Comunes
  v_statuses := guide.export_f_text_array('statuses', v_f -> 'statuses', 10, '^[a-z_]{1,20}$');
  if v_statuses is not null and exists (
       select 1 from unnest(v_statuses) x
       where x not in (select unnest(case p_module
                                       when 'articles'     then array['draft', 'scheduled', 'published']
                                       when 'items'        then array[]::text[]
                                       when 'user_reviews' then array['pending', 'visible', 'hidden']
                                       when 'subscribers'  then array['pending', 'active', 'unsubscribed', 'bounced', 'expired']
                                       when 'events'       then array['draft', 'approved', 'cancelled', 'rejected']
                                       when 'news'         then array['draft', 'published', 'rejected']
                                     end))) then
    raise exception 'invalid filter: statuses' using errcode = '22023';
  end if;
  -- D-C: suscriptores, por defecto solo activos. Opiniones: por defecto visibles (§12.2). Los suprimidos nunca.
  if v_statuses is null and p_module = 'subscribers' then v_statuses := array['active']; end if;
  if v_statuses is null and p_module = 'user_reviews' then v_statuses := array['visible']; end if;

  v_df := guide.export_f_text('date_field', v_f -> 'date_field', '^[a-z_]{1,20}$');
  v_df := coalesce(v_df, case p_module when 'articles' then 'published_at' when 'items' then 'created_at'
                                      when 'user_reviews' then 'created_at' when 'subscribers' then 'consent'
                                      when 'events' then 'starts_at' when 'news' then 'published_at' end);
  if not (v_df = any (case p_module
                        when 'articles'     then array['published_at', 'created_at', 'updated_at']
                        when 'items'        then array['created_at', 'updated_at', 'published_at', 'verified_at']
                        when 'user_reviews' then array['created_at', 'moderated_at', 'edited_at']
                        when 'subscribers'  then array['consent', 'confirmed', 'unsubscribed']
                        when 'events'       then array['starts_at', 'created_at', 'approved_at']
                        when 'news'         then array['published_at', 'created_at', 'updated_at']
                      end)) then
    raise exception 'invalid filter: date_field' using errcode = '22023';
  end if;
  v_from := guide.export_f_ts('from', v_f -> 'from', false);
  v_to   := guide.export_f_ts('to', v_f -> 'to', true);
  if v_from is not null and v_to is not null and v_from >= v_to then
    raise exception 'invalid filter: range' using errcode = '22023';
  end if;
  v_ids := guide.export_f_text_array('ids', v_f -> 'ids', 5000, c_uuid)::uuid[];

  -- Por módulo
  if p_module in ('items', 'user_reviews') then
    v_category := guide.export_f_text('category', v_f -> 'category', '^[a-z_]{1,40}$');
    if v_category is not null and not exists (select 1 from guide.item_categories c where c.key = v_category) then
      raise exception 'invalid filter: category' using errcode = '22023';
    end if;
  end if;
  if p_module = 'articles' then
    v_cat_id := guide.export_f_text('category_id', v_f -> 'category_id', c_uuid)::uuid;
  end if;
  if p_module in ('user_reviews', 'events') then
    v_item_id := guide.export_f_text('item_id', v_f -> 'item_id', c_uuid)::uuid;
  end if;
  if p_module = 'news' then
    v_source   := guide.export_f_text('source', v_f -> 'source', '^(manual|agent)$');
    v_news_cat := guide.export_f_text('category_id', v_f -> 'category_id', c_uuid)::uuid;
    v_scopes   := guide.export_f_text_array('scopes', v_f -> 'scopes', 3, '^(cat|es|intl)$');
    v_has_en   := guide.export_f_bool('has_en', v_f -> 'has_en');
  end if;
  if p_module in ('articles', 'items') then
    v_has_en := guide.export_f_bool('has_en', v_f -> 'has_en');
    v_with_body := coalesce(guide.export_f_bool('with_body', v_f -> 'with_body'), false);
  end if;
  if p_module = 'items' then
    v_published := guide.export_f_bool('published', v_f -> 'published');
  end if;
  if p_module in ('user_reviews', 'subscribers') then
    v_locale := guide.export_f_text('locale', v_f -> 'locale', '^(es|en)$');
  end if;
  if p_module = 'subscribers' then
    v_sources := guide.export_f_text_array('sources', v_f -> 'sources', 20, '^[a-z0-9_]{1,40}$');
    if v_f -> 'consent_version' is not null and jsonb_typeof(v_f -> 'consent_version') <> 'null' then
      if jsonb_typeof(v_f -> 'consent_version') <> 'array' or jsonb_array_length(v_f -> 'consent_version') not between 1 and 50
         or exists (select 1 from jsonb_array_elements(v_f -> 'consent_version') x
                    where jsonb_typeof(x) <> 'number' or (x #>> '{}') !~ '^\d{1,6}$') then
        raise exception 'invalid filter: consent_version' using errcode = '22023';
      end if;
      select array_agg(distinct (x #>> '{}')::integer) into v_versions from jsonb_array_elements(v_f -> 'consent_version') x;
    end if;
    v_purpose := guide.export_f_text('purpose', v_f -> 'purpose', '^[a-z_]{1,20}$');
    if v_purpose is not null and not (v_purpose = any (c_purposes)) then
      raise exception 'invalid filter: purpose' using errcode = '22023';
    end if;
    -- §12.3: la finalidad es obligatoria para descargar (no para contar).
    if not p_count_only and v_purpose is null then
      raise exception 'purpose required' using errcode = '22023';
    end if;
  end if;
  if p_module = 'events' then
    v_source := guide.export_f_text('source', v_f -> 'source', '^(manual|agent)$');
    v_types  := guide.export_f_text_array('event_types', v_f -> 'event_types', 20, '^[a-z0-9_]{1,40}$');
  end if;

  -- D-A: el cuerpo solo en JSON. D-B: el CSV de fichas va por categoría.
  if not p_count_only and p_format = 'csv' and v_with_body then
    raise exception 'with_body only in json' using errcode = '22023';
  end if;
  if not p_count_only and p_format = 'csv' and p_module = 'items' and v_category is null then
    raise exception 'csv needs category' using errcode = '22023';
  end if;

  -- Columnas: las de la vista en su orden; las del cuerpo solo con with_body; suscriptores con preajuste.
  select array_agg(a.attname::text order by a.attnum) into v_all_cols
  from pg_attribute a
  where a.attrelid = ('guide.' || v_view)::regclass and a.attnum > 0 and not a.attisdropped;
  v_permitted := case
    when p_module = 'articles' and not v_with_body then array_remove(array_remove(v_all_cols, 'body_html_es'), 'body_html_en')
    when p_module = 'items' and not v_with_body then array_remove(array_remove(v_all_cols, 'author_body_html_es'), 'author_body_html_en')
    else v_all_cols end;
  v_default := case when p_module = 'subscribers' then c_sub_min else v_permitted end;

  if v_f -> 'columns' is null or jsonb_typeof(v_f -> 'columns') = 'null' then
    v_cols := v_default;
  elsif jsonb_typeof(v_f -> 'columns') = 'string' then
    v_cols := case
      when p_module = 'subscribers' and v_f ->> 'columns' = 'min' then c_sub_min
      when v_f ->> 'columns' = 'all' or (p_module = 'subscribers' and v_f ->> 'columns' = 'proof') then v_permitted
    end;
    if v_cols is null then raise exception 'invalid filter: columns' using errcode = '22023'; end if;
  else
    v_cols := guide.export_f_text_array('columns', v_f -> 'columns', 80, '^[a-z0-9_]{1,40}$');
    if exists (select 1 from unnest(v_cols) c where not (c = any (v_permitted))) then
      raise exception 'invalid filter: columns' using errcode = '22023';
    end if;
  end if;
  select array_agg(c order by o) into v_cols from unnest(v_permitted) with ordinality p(c, o) where c = any (v_cols);
  -- O4 (leona-lia): defensa en profundidad; sin columnas no se exporta (nunca «todas» por omisión).
  if coalesce(cardinality(v_cols), 0) = 0 then
    raise exception 'invalid filter: columns' using errcode = '22023';
  end if;
  select coalesce(array_agg(c), '{}') into v_drop from unnest(v_all_cols) c where not (c = any (v_cols));
  v_take := case when p_count_only then 0 else v_cap end;   -- el recuento no construye filas

  -- Filas
  if p_module = 'articles' then
    with b as (
      select v.*, row_number() over (order by v.published_at desc nulls last, v.created_at desc, v.id) as rn
      from guide.export_articles v
      where (v_statuses is null or v.status::text = any (v_statuses))
        and (v_cat_id is null or v.category_id = v_cat_id)
        and (v_has_en is null or v.has_en = v_has_en)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                          else v.updated_at end) >= v_from)
        and (v_to is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                        else v.updated_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'items' then
    with b as (
      select v.*, row_number() over (order by v.category, v.name, v.id) as rn
      from guide.export_items v
      where (v_category is null or v.category = v_category)
        and (v_published is null or v.published = v_published)
        and (v_has_en is null or v.has_en = v_has_en)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'created_at' then v.created_at when 'updated_at' then v.updated_at
                                          when 'published_at' then v.published_at
                                          else v.verified_at::timestamp at time zone 'Europe/Madrid' end) >= v_from)
        and (v_to is null or (case v_df when 'created_at' then v.created_at when 'updated_at' then v.updated_at
                                        when 'published_at' then v.published_at
                                        else v.verified_at::timestamp at time zone 'Europe/Madrid' end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'user_reviews' then
    with b as (
      select v.*, row_number() over (order by v.created_at desc, v.id) as rn
      from guide.export_user_reviews v
      where (v.status::text = any (v_statuses))
        and (v_category is null or v.category = v_category)
        and (v_locale is null or v.locale::text = v_locale)
        and (v_item_id is null or v.item_id = v_item_id)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'created_at' then v.created_at when 'moderated_at' then v.moderated_at
                                          else v.edited_at end) >= v_from)
        and (v_to is null or (case v_df when 'created_at' then v.created_at when 'moderated_at' then v.moderated_at
                                        else v.edited_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'subscribers' then
    with b as (
      select v.*, row_number() over (order by v.consent_at desc nulls last, v.id) as rn
      from guide.export_subscribers v
      where v.status::text = any (v_statuses)
        and (v_locale is null or v.locale::text = v_locale)
        and (v_sources is null or v.consent_source = any (v_sources))
        and (v_versions is null or v.consent_version = any (v_versions))
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'consent' then v.consent_at when 'confirmed' then v.confirmed_at
                                          else v.unsubscribed_at end) >= v_from)
        and (v_to is null or (case v_df when 'consent' then v.consent_at when 'confirmed' then v.confirmed_at
                                        else v.unsubscribed_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'news' then
    with b as (
      select v.*, row_number() over (order by v.published_at desc nulls last, v.created_at desc, v.id) as rn
      from guide.export_news v
      where (v_statuses is null or v.status::text = any (v_statuses))
        and (v_source is null or v.source::text = v_source)
        and (v_news_cat is null or v.category_id = v_news_cat)
        and (v_scopes is null or v.scope::text = any (v_scopes))
        and (v_has_en is null or v.has_en = v_has_en)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                          else v.updated_at end) >= v_from)
        and (v_to is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                        else v.updated_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  else
    with b as (
      select v.*, row_number() over (order by v.starts_at, v.id) as rn
      from guide.export_events v
      where (v_statuses is null or v.status::text = any (v_statuses))
        and (v_source is null or v.source::text = v_source)
        and (v_types is null or v.event_type = any (v_types))
        and (v_item_id is null or v.item_id = v_item_id)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'starts_at' then v.starts_at when 'created_at' then v.created_at
                                          else v.approved_at end) >= v_from)
        and (v_to is null or (case v_df when 'starts_at' then v.starts_at when 'created_at' then v.created_at
                                        else v.approved_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  end if;

  -- Filtros saneados para el registro: valores ya validados; ids solo como número; nunca texto libre.
  v_clean := jsonb_strip_nulls(jsonb_build_object(
    'statuses', to_jsonb(v_statuses), 'date_field', v_df,
    'from', to_jsonb(v_from), 'to', to_jsonb(v_to),
    'ids_count', case when v_ids is not null then cardinality(v_ids) end,
    'category', v_category, 'category_id', coalesce(v_cat_id, v_news_cat), 'item_id', v_item_id,
    'has_en', v_has_en, 'published', v_published, 'with_body', case when v_with_body then true end,
    'locale', v_locale, 'sources', to_jsonb(v_sources), 'consent_version', to_jsonb(v_versions),
    'source', v_source, 'event_types', to_jsonb(v_types), 'scopes', to_jsonb(v_scopes)));

  if p_count_only then
    return jsonb_build_object('module', p_module, 'total', v_n,
                              'row_count', least(v_n, v_cap), 'truncated', v_n > v_cap,
                              'columns', to_jsonb(v_cols), 'filters', v_clean);
  end if;

  return jsonb_build_object(
    'export', jsonb_build_object(
      'module', p_module, 'view', v_view, 'format', p_format, 'exported_at', now(),
      'filters', v_clean, 'columns', to_jsonb(v_cols),
      'row_count', jsonb_array_length(v_rows), 'total', v_n, 'truncated', v_n > jsonb_array_length(v_rows),
      'personal_data', p_module = 'subscribers', 'purpose', v_purpose, 'format_version', 1),
    'rows', v_rows);
end;
$$;

revoke all on function guide.export_build(text, text, jsonb, boolean) from public, anon, authenticated, service_role;
revoke all on function guide.admin_export(text, text, jsonb), guide.admin_export_count(text, jsonb)
  from public, anon, service_role;
grant execute on function guide.admin_export(text, text, jsonb), guide.admin_export_count(text, jsonb)
  to authenticated;
