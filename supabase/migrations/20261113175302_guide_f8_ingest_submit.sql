-- F8 (8.5) · Ingesta: funciones internas y RPC guide.ingest_* (docs/security/F8.1-ingest-spec.md, J1–J34).
-- Las ingest_* son SECURITY DEFINER (postgres), VOLATILE (J8), con EXECUTE solo para anon (J9) y comprueban, por
-- este orden: formato del token (J3), que no haya usuario (J10), token vigente (J4) con error uniforme (J6).
-- Las internas no tienen EXECUTE para ningún rol de la API (J9). Ninguna toca guide.draft_op (J22) ni hace red
-- (J25). Solo insertan borradores (J20); las guardas events_before_write / news_before_write lo validan otra vez.
-- Las respuestas de negocio son JSON ({"result": ...}) y no lanzan error, para que los contadores del run
-- (llamadas, inválidas, duplicados) queden guardados. Idempotente.

-- ───────────── 4. ingest_submit_event (J11–J20, J23, J24, J32, J34) ─────────────
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
                              dedupe_key, agent_meta)
    values (v_title_es, v_title_en, v_desc_es, v_desc_en, v_type, v_starts, v_ends, v_all_day, v_loc, v_item,
            v_url ->> 'url', v_price, 'draft', 'agent', v_src ->> 'url', v_key,
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

-- ───────────── 5. ingest_submit_news (J11–J24, J32, J34) ─────────────
create or replace function guide.ingest_submit_news(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_keys    constant text[] := array['title_es', 'title_en', 'summary_es', 'summary_en', 'category',
                                     'published_on_source', 'source_url', 'source_name', 'confidence', 'note', 'excerpt'];
  c_reasons constant text[] := array['not_object', 'too_large', 'unknown_key', 'secret', 'missing_field', 'invalid_type',
                                     'bad_chars', 'too_long', 'bad_url', 'shortener', 'pii', 'invalid_date', 'stale',
                                     'category', 'source', 'confidence', 'constraint'];
  v_token    uuid;
  v_run      guide.ingest_runs;
  v_reason   text;
  v_field    text;
  v_title_es text;
  v_title_en text;
  v_sum_es   text;
  v_sum_en   text;
  v_name     text;
  v_note     text;
  v_excerpt  text;
  v_tmp      text;
  v_cat      uuid;
  v_day      date;
  v_today    date := (now() at time zone 'Europe/Madrid')::date;
  v_src      jsonb;
  v_source   guide.news_sources;
  v_conf     numeric;
  v_key      text;
  v_dup_rej  boolean;
begin
  v_token := guide.ingest_auth(p_token);
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  v_run := guide.ingest_run_for(v_token, p_run_id, 'news');

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
    v_sum_es   := guide.ingest_field_text(p_payload, 'summary_es', 1200, true, true);
    v_sum_en   := guide.ingest_field_text(p_payload, 'summary_en', 1200, true, false);
    v_name     := guide.ingest_field_text(p_payload, 'source_name', 120, false, false);
    v_note     := guide.ingest_field_text(p_payload, 'note', 500, true, false);
    v_excerpt  := guide.ingest_field_text(p_payload, 'excerpt', 1000, true, false);

    v_tmp := guide.ingest_field_text(p_payload, 'category', 40, false, true);
    select c.id into v_cat from guide.news_categories c where c.key = v_tmp and c.active;
    if v_cat is null then
      raise exception 'category' using detail = 'category';
    end if;

    -- J15: fecha de la fuente entre hace 30 días y mañana (Madrid).
    if jsonb_typeof(p_payload -> 'published_on_source') is distinct from 'string'
       or (p_payload ->> 'published_on_source') !~ '^\d{4}-\d{2}-\d{2}($|T)' then
      raise exception 'invalid_date' using detail = 'published_on_source';
    end if;
    begin
      v_day := left(p_payload ->> 'published_on_source', 10)::date;
    exception when others then
      raise exception 'invalid_date' using detail = 'published_on_source';
    end;
    if v_day < v_today - 30 or v_day > v_today + 1 then
      raise exception 'stale' using detail = 'published_on_source';
    end if;

    v_tmp := guide.ingest_field_text(p_payload, 'source_url', 1000, false, true);
    begin
      v_src := guide.ingest_url(v_tmp);
    exception when raise_exception then
      get stacked diagnostics v_reason = message_text;
      raise exception '%', v_reason using detail = 'source_url';
    end;
    -- J24: el host debe ser una fuente de noticias activa o subdominio suyo.
    select s.* into v_source from guide.news_sources s
    where s.active and s.kind in ('news', 'both')
      and ((v_src ->> 'host') = s.domain or (v_src ->> 'host') like '%.' || s.domain)
    order by char_length(s.domain) desc
    limit 1;
    if v_source.id is null then
      raise exception 'source' using detail = 'source_url';
    end if;

    if (case when jsonb_typeof(p_payload -> 'confidence') is distinct from 'number' then true
             else (p_payload ->> 'confidence')::numeric not between 0 and 1 end) then
      raise exception 'confidence' using detail = 'confidence';
    end if;
    v_conf := (p_payload ->> 'confidence')::numeric;

    if guide.ingest_has_pii(concat_ws(E'\n|\n', v_title_es, v_title_en, v_sum_es, v_sum_en, v_name, v_note, v_excerpt)) then
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

  if (case when v_run.dry_run then v_run.would_insert else v_run.inserted end) >= 40 then
    return jsonb_build_object('result', 'rejected', 'reason', 'row_limit');
  end if;

  -- J18: duplicada si coincide la clave (host|fecha|título) o la URL canónica, en cualquier estado.
  v_key := guide.ingest_dedupe_key(v_src ->> 'host', v_day, v_title_es);
  select bool_or(n.status = 'rejected') into v_dup_rej
  from guide.news n
  where n.dedupe_key = v_key
     or n.url_key = (v_src ->> 'key')
     or (n.source = 'manual'
         and lower(rtrim(split_part(split_part(n.source_url, '#', 1), '?', 1), '/'))
             = lower(rtrim(split_part(v_src ->> 'url', '?', 1), '/')));
  if v_dup_rej is not null then
    update guide.ingest_runs r
    set duplicates = r.duplicates + case when v_dup_rej then 0 else 1 end,
        duplicate_rejected = r.duplicate_rejected + case when v_dup_rej then 1 else 0 end
    where r.id = v_run.id;
    return jsonb_build_object('result', 'duplicate');
  end if;

  if v_run.dry_run then
    update guide.ingest_runs r set would_insert = r.would_insert + 1 where r.id = v_run.id;
    return jsonb_build_object('result', 'would_insert');
  end if;

  if (v_src ->> 'punycode')::boolean then
    v_note := left(concat_ws(' · ', 'dominio punycode', v_note), 500);
  end if;

  begin
    insert into guide.news (slug, status, source, title_es, title_en, summary_es, summary_en, category_id, scope,
                            source_name, source_url, source_published_on, source_lang, source_id, run_id,
                            dedupe_key, url_key, agent_meta)
    values ('pending', 'draft', 'agent', v_title_es, v_title_en, v_sum_es, v_sum_en, v_cat, v_source.scope,
            coalesce(v_name, v_source.name), v_src ->> 'url', v_day, v_source.lang, v_source.id, v_run.id,
            v_key, v_src ->> 'key',
            jsonb_strip_nulls(jsonb_build_object(
              'confidence', v_conf, 'note', v_note, 'excerpt', v_excerpt,
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
  set inserted = r.inserted + 1, inserted_news = r.inserted_news + 1
  where r.id = v_run.id;
  update guide.news_sources s set last_seen_at = now() where s.id = v_source.id;
  return jsonb_build_object('result', 'inserted');
end;
$$;

-- ───────────── 6. ingest_submit_newsletter_intro (prompt-rutina §7; D75) ─────────────
-- Una por run. Crea el borrador de la semana si no existe; no pisa una intro escrita por Xavi.
create or replace function guide.ingest_submit_newsletter_intro(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_keys    constant text[] := array['subject_es', 'preheader_es', 'intro_es', 'subject_en', 'preheader_en', 'intro_en'];
  c_reasons constant text[] := array['not_object', 'too_large', 'unknown_key', 'secret', 'missing_field', 'invalid_type',
                                     'bad_chars', 'too_long', 'pii'];
  v_token  uuid;
  v_run    guide.ingest_runs;
  v_reason text;
  v_field  text;
  v_sub_es text;
  v_pre_es text;
  v_int_es text;
  v_sub_en text;
  v_pre_en text;
  v_int_en text;
  v_week   date := date_trunc('week', now() at time zone 'Europe/Madrid')::date;
  v_issue  guide.newsletter_issues;
begin
  v_token := guide.ingest_auth(p_token);
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  v_run := guide.ingest_run_for(v_token, p_run_id, 'any');

  update guide.ingest_runs r set calls = r.calls + 1 where r.id = v_run.id and r.calls < 80;
  if not found then
    return jsonb_build_object('result', 'rejected', 'reason', 'call_limit');
  end if;
  if v_run.newsletter_intro then
    return jsonb_build_object('result', 'rejected', 'reason', 'already_sent');
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
    v_sub_es := guide.ingest_field_text(p_payload, 'subject_es', 80, false, true);
    v_pre_es := guide.ingest_field_text(p_payload, 'preheader_es', 110, false, false);
    v_int_es := guide.ingest_field_text(p_payload, 'intro_es', 600, true, true);
    v_sub_en := guide.ingest_field_text(p_payload, 'subject_en', 80, false, false);
    v_pre_en := guide.ingest_field_text(p_payload, 'preheader_en', 110, false, false);
    v_int_en := guide.ingest_field_text(p_payload, 'intro_en', 600, true, false);
    if guide.ingest_has_pii(concat_ws(E'\n|\n', v_sub_es, v_pre_es, v_int_es, v_sub_en, v_pre_en, v_int_en)) then
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

  select * into v_issue from guide.newsletter_issues i where i.week_start = v_week;
  if v_issue.id is not null and v_issue.status <> 'draft' then
    return jsonb_build_object('result', 'rejected', 'reason', 'issue_locked');
  end if;
  if v_issue.id is not null and v_issue.intro_es is not null and not v_issue.intro_by_agent then
    return jsonb_build_object('result', 'rejected', 'reason', 'intro_owned');
  end if;
  if v_run.dry_run then
    return jsonb_build_object('result', 'would_insert');
  end if;

  if v_issue.id is null then
    perform guide.newsletter_compose(v_week);
  end if;
  update guide.newsletter_issues i
  set subject_es = v_sub_es, preheader_es = v_pre_es, intro_es = v_int_es,
      subject_en = v_sub_en, preheader_en = v_pre_en, intro_en = v_int_en, intro_by_agent = true
  where i.week_start = v_week;
  update guide.ingest_runs r set newsletter_intro = true where r.id = v_run.id;
  return jsonb_build_object('result', 'inserted');
end;
$$;

-- ───────────── 7. ingest_finish_run (J17, J28) ─────────────
create or replace function guide.ingest_finish_run(p_token text, p_run_id uuid, p_stats jsonb, p_errors text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  c_stat_keys constant text[] := array['sources_checked', 'sources_failed', 'events_found', 'news_found',
                                       'events_submitted', 'news_submitted', 'duplicates', 'discarded',
                                       'injection_attempts', 'pending_next_run', 'newsletter_intro', 'failed'];
  v_token  uuid;
  v_run    guide.ingest_runs;
  v_err    text;
  v_status guide.ingest_run_status;
begin
  v_token := guide.ingest_auth(p_token);
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  v_run := guide.ingest_run_for(v_token, p_run_id, 'any');

  if p_stats is not null and (
       jsonb_typeof(p_stats) <> 'object' or octet_length(p_stats::text) > 4096
       or exists (select 1 from jsonb_each(p_stats) e
                  where e.key <> all (c_stat_keys)
                     or case when jsonb_typeof(e.value) <> 'number' then true
                             else (e.value #>> '{}')::numeric not between 0 and 100000 end)) then
    raise exception 'ingest_invalid_stats' using errcode = '22023';
  end if;
  v_err := nullif(btrim(p_errors, E' \n'), '');
  if v_err is not null and (octet_length(v_err) > 4096
                            or v_err ~ '[\u0001-\u0009\u000B-\u001F\u007F-\u009F]'
                            or v_err ~ U&'[\200B-\200D\202A-\202E\2066-\2069\FEFF]') then
    raise exception 'ingest_invalid_errors' using errcode = '22023';
  end if;
  if guide.ingest_has_secret(p_stats::text, p_token) or guide.ingest_has_secret(v_err, p_token) then
    raise exception 'ingest_secret_echo' using errcode = '22023';
  end if;

  v_status := case when coalesce((p_stats ->> 'failed')::numeric, 0) >= 1 then 'error' else 'ok' end;
  update guide.ingest_runs r
  set status = v_status, finished_at = now(), stats = p_stats, errors = v_err
  where r.id = v_run.id
  returning * into v_run;

  return jsonb_build_object(
    'result', 'ok', 'status', v_run.status, 'dry_run', v_run.dry_run, 'calls', v_run.calls,
    'inserted', v_run.inserted, 'would_insert', v_run.would_insert, 'duplicates', v_run.duplicates,
    'duplicate_rejected', v_run.duplicate_rejected, 'invalid', v_run.invalid);
end;
$$;

-- ───────────── 8. Permisos (J9): firma exacta, solo anon ─────────────
revoke all on function guide.ingest_start_run(text, text, boolean) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_context(text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_submit_event(text, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_submit_news(text, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_submit_newsletter_intro(text, uuid, jsonb) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_finish_run(text, uuid, jsonb, text) from public, anon, authenticated, service_role;
grant execute on function guide.ingest_start_run(text, text, boolean) to anon;
grant execute on function guide.ingest_context(text) to anon;
grant execute on function guide.ingest_submit_event(text, uuid, jsonb) to anon;
grant execute on function guide.ingest_submit_news(text, uuid, jsonb) to anon;
grant execute on function guide.ingest_submit_newsletter_intro(text, uuid, jsonb) to anon;
grant execute on function guide.ingest_finish_run(text, uuid, jsonb, text) to anon;
