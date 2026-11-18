-- F8 (8.5) · Ingesta: funciones internas y RPC guide.ingest_* (docs/security/F8.1-ingest-spec.md, J1–J34).
-- Las ingest_* son SECURITY DEFINER (postgres), VOLATILE (J8), con EXECUTE solo para anon (J9) y comprueban, por
-- este orden: formato del token (J3), que no haya usuario (J10), token vigente (J4) con error uniforme (J6).
-- Las internas no tienen EXECUTE para ningún rol de la API (J9). Ninguna toca guide.draft_op (J22) ni hace red
-- (J25). Solo insertan borradores (J20); las guardas events_before_write / news_before_write lo validan otra vez.
-- Las respuestas de negocio son JSON ({"result": ...}) y no lanzan error, para que los contadores del run
-- (llamadas, inválidas, duplicados) queden guardados. Idempotente.

-- ───────────── 1. Internas ─────────────
-- J3, J4, J6, J10. Devuelve el id del token o lanza el error uniforme. Nunca guarda el intento (J7).
create or replace function guide.ingest_auth(p_token text)
returns uuid
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_token is null or p_token !~ '^cgi_[0-9a-f]{64}$' then
    raise exception 'ingest_unauthorized' using errcode = '42501';
  end if;
  if (select auth.uid()) is not null then
    raise exception 'ingest_unauthorized' using errcode = '42501';
  end if;
  select t.id into v_id
  from guide.ingest_tokens t
  where t.token_hash = extensions.digest(convert_to(p_token, 'UTF8'), 'sha256')
    and t.revoked_at is null
    and t.expires_at > now();
  if v_id is null then
    raise exception 'ingest_unauthorized' using errcode = '42501';
  end if;
  update guide.ingest_tokens t set last_used_at = now() where t.id = v_id;
  return v_id;
end;
$$;

-- J29. Run del mismo token, abierto, de menos de 2 h y del tipo pedido ('events' | 'news' | 'any').
create or replace function guide.ingest_run_for(p_token_id uuid, p_run_id uuid, p_need text)
returns guide.ingest_runs
language plpgsql
volatile
set search_path = ''
as $$
declare
  v guide.ingest_runs;
begin
  select * into v from guide.ingest_runs r where r.id = p_run_id for update;
  if not found or v.token_id is distinct from p_token_id then
    raise exception 'ingest_unauthorized' using errcode = '42501';
  end if;
  if v.status <> 'open' or v.started_at <= now() - interval '2 hours' then
    raise exception 'ingest_run_closed' using errcode = '55000';
  end if;
  if p_need <> 'any' and v.kind <> 'both' and v.kind::text <> p_need then
    raise exception 'ingest_kind_mismatch' using errcode = '22023';
  end if;
  return v;
end;
$$;

-- J12–J14. Texto de una clave del payload: tipo string, sin controles (en multilínea solo \n), sin bidi ni
-- zero-width, NFC, recortado (vacío = null) y con longitud máxima. Errores: código en MESSAGE, clave en DETAIL.
create or replace function guide.ingest_field_text(p jsonb, p_key text, p_max integer, p_multiline boolean, p_required boolean)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v jsonb := p -> p_key;
  t text;
begin
  if v is null or jsonb_typeof(v) = 'null' then
    if p_required then
      raise exception 'missing_field' using detail = p_key;
    end if;
    return null;
  end if;
  if jsonb_typeof(v) <> 'string' then
    raise exception 'invalid_type' using detail = p_key;
  end if;
  t := v #>> '{}';
  if (not p_multiline and t ~ '[[:cntrl:]]')
     or (p_multiline and t ~ '[\u0001-\u0009\u000B-\u001F\u007F-\u009F]')
     or t ~ U&'[\200B-\200D\202A-\202E\2066-\2069\FEFF]' then
    raise exception 'bad_chars' using detail = p_key;
  end if;
  t := nullif(btrim(normalize(t, NFC), E' \n'), '');
  if t is null then
    if p_required then
      raise exception 'missing_field' using detail = p_key;
    end if;
    return null;
  end if;
  if char_length(t) > p_max then
    raise exception 'too_long' using detail = p_key;
  end if;
  return t;
end;
$$;

-- J16. Email o teléfono (≥ 9 dígitos con separadores opcionales) en un texto.
create or replace function guide.ingest_has_pii(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null
     and (p ~* '[^[:space:]@]+@[^[:space:]@]+\.[a-z]{2,}' or p ~ '\+?[0-9]([ .-]?[0-9]){8,}');
$$;

-- J17. Eco del token (con o sin prefijo) o de otros secretos de Supabase / JWT.
create or replace function guide.ingest_has_secret(p text, p_token text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null and (
    (p_token is not null and (position(p_token in p) > 0 or position(substr(p_token, 5) in p) > 0))
    or p ~ 'sb_secret_|sb_publishable_'
    or p ~ 'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}');
$$;

-- J23. Valida y limpia una URL: solo https, host con TLD alfabético, sin userinfo, puerto, IP ni nombres internos;
-- sin acortadores; quita parámetros de tracking y el fragmento. Devuelve {url, host, punycode, key}; key es la
-- clave canónica de la URL para el dedupe de noticias (J18).
create or replace function guide.ingest_url(p_url text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  m      text[];
  v_host text;
  v_path text;
  v_q    text;
begin
  if p_url is null or char_length(p_url) > 1000 or p_url ~ '[[:space:][:cntrl:]"<>\\`{}|^]' then
    raise exception 'bad_url';
  end if;
  m := regexp_match(p_url, '^[Hh][Tt][Tt][Pp][Ss]://([^/?#]*)([^?#]*)(\?[^#]*)?(#.*)?$');
  if m is null then
    raise exception 'bad_url';
  end if;
  v_host := lower(m[1]);
  if v_host ~ '[@:%\[\]]' or char_length(v_host) > 253
     or v_host !~ '^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$'
     or v_host ~ '(^|\.)(localhost|local|internal)$' then
    raise exception 'bad_url';
  end if;
  if v_host = any (array['bit.ly', 't.co', 'tinyurl.com', 'goo.gl', 'ow.ly', 'buff.ly', 'lnkd.in'])
     or v_host ~ '\.(bit\.ly|t\.co|tinyurl\.com|goo\.gl|ow\.ly|buff\.ly|lnkd\.in)$' then
    raise exception 'shortener';
  end if;
  v_path := coalesce(m[2], '');
  if m[3] is not null then
    select string_agg(x.p, '&' order by x.o) into v_q
    from unnest(string_to_array(substr(m[3], 2), '&')) with ordinality as x(p, o)
    where x.p <> ''
      and lower(split_part(x.p, '=', 1))
          !~ '^(utm_.*|fbclid|gclid|dclid|msclkid|mc_cid|mc_eid|_hsenc|_hsmi|igshid|ref|ref_src)$';
  end if;
  return jsonb_build_object(
    'url', 'https://' || v_host || v_path || coalesce('?' || v_q, ''),
    'host', v_host,
    'punycode', v_host ~ '(^|\.)xn--',
    'key', 'u1:' || encode(extensions.digest(
             convert_to(lower(v_host || rtrim(v_path, '/') || coalesce('?' || v_q, '')), 'UTF8'), 'sha256'), 'hex'));
end;
$$;

-- J18. Título normalizado (sin tildes, minúsculas, solo [a-z0-9] y espacios simples) y clave de dedupe del servidor.
create or replace function guide.ingest_norm_title(p text)
returns text
language sql
stable
set search_path = ''
as $$
  select btrim(regexp_replace(
           regexp_replace(lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(p, ''))),
                          '[^a-z0-9]+', ' ', 'g'),
           ' +', ' ', 'g'));
$$;

create or replace function guide.ingest_dedupe_key(p_host text, p_day date, p_title text)
returns text
language sql
stable
set search_path = ''
as $$
  select 'v1:' || encode(extensions.digest(convert_to(
           lower(p_host) || '|' || to_char(p_day, 'YYYY-MM-DD') || '|' || guide.ingest_norm_title(p_title), 'UTF8'),
           'sha256'), 'hex');
$$;

-- Borradores pendientes del agente (J33): eventos no caducados + noticias.
create or replace function guide.ingest_queue_pending()
returns integer
language sql
stable
set search_path = ''
as $$
  select ((select count(*) from guide.events e
           where e.status = 'draft' and e.source = 'agent'
             and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day))
          + (select count(*) from guide.news n where n.status = 'draft' and n.source = 'agent'))::integer;
$$;

-- Suma 1 al contador de inválidas del motivo dado (lista cerrada).
create or replace function guide.ingest_count_invalid(p_run_id uuid, p_reason text)
returns void
language sql
volatile
set search_path = ''
as $$
  update guide.ingest_runs r
  set invalid = jsonb_set(r.invalid, array[p_reason], to_jsonb(coalesce((r.invalid ->> p_reason)::integer, 0) + 1))
  where r.id = p_run_id;
$$;

-- Borrador semanal de la carta (D75): último artículo, noticias publicadas 7 días atrás y eventos aprobados 14 días
-- adelante. Si la semana ya tiene borrador, lo recompone (solo en draft). Lo llaman compose_issue (admin) y
-- ingest_submit_newsletter_intro (agente); las guardas de newsletter validan cada camino.
create or replace function guide.newsletter_compose(p_week date)
returns uuid
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_id     uuid;
  v_status guide.newsletter_status;
begin
  if p_week is null or extract(isodow from p_week) <> 1 then
    raise exception 'invalid week' using errcode = '22023';
  end if;
  select i.id, i.status into v_id, v_status from guide.newsletter_issues i where i.week_start = p_week for update;
  if v_id is null then
    insert into guide.newsletter_issues (week_start) values (p_week) returning id into v_id;
  elsif v_status <> 'draft' then
    raise exception 'newsletter_not_draft' using errcode = '55000';
  else
    delete from guide.newsletter_issue_items i where i.issue_id = v_id;
  end if;

  insert into guide.newsletter_issue_items (issue_id, kind, ref_id, position)
  select v_id, 'article', a.id, 1
  from guide.articles a
  where guide.article_is_live(a.status, a.published_at)
  order by a.published_at desc
  limit 1;

  insert into guide.newsletter_issue_items (issue_id, kind, ref_id, position)
  select v_id, 'news', x.id, row_number() over (order by x.published_at desc, x.id)
  from (select n.id, n.published_at from guide.news n
        where n.status = 'published' and n.published_at >= now() - interval '7 days'
        order by n.published_at desc, n.id limit 20) x;

  insert into guide.newsletter_issue_items (issue_id, kind, ref_id, position)
  select v_id, 'event', x.id, row_number() over (order by x.starts_at, x.id)
  from (select e.id, e.starts_at from guide.events e
        where e.status = 'approved' and e.starts_at >= now() and e.starts_at < now() + interval '14 days'
        order by e.starts_at, e.id limit 20) x;

  return v_id;
end;
$$;

revoke all on function guide.ingest_auth(text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_run_for(uuid, uuid, text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_field_text(jsonb, text, integer, boolean, boolean) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_has_pii(text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_has_secret(text, text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_url(text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_norm_title(text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_dedupe_key(text, date, text) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_queue_pending() from public, anon, authenticated, service_role;
revoke all on function guide.ingest_count_invalid(uuid, text) from public, anon, authenticated, service_role;
revoke all on function guide.newsletter_compose(date) from public, anon, authenticated, service_role;

-- ───────────── 2. ingest_start_run (J29–J34, R1) ─────────────
create or replace function guide.ingest_start_run(p_token text, p_kind text, p_dry_run boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_token  uuid;
  v_local  timestamp;
  v_in     boolean;
  v_manual boolean;
  v_id     uuid;
begin
  v_token := guide.ingest_auth(p_token);
  if p_kind is null or p_kind not in ('events', 'news', 'both') or p_dry_run is null then
    raise exception 'ingest_invalid_argument' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));

  -- J31: un run colgado no bloquea la rutina.
  update guide.ingest_runs r set status = 'abandoned', finished_at = now()
  where r.status = 'open' and r.started_at <= now() - interval '2 hours';

  -- R1: lunes y jueves de 03:00 a 12:00 en Madrid, o ventana abierta por el admin (2 h).
  v_local := now() at time zone 'Europe/Madrid';
  v_in := extract(isodow from v_local) in (1, 4) and v_local::time >= time '03:00' and v_local::time < time '12:00';
  v_manual := coalesce((select c.window_open_until > now() from guide.ingest_config c where c.id), false);
  if not v_in and not v_manual then
    return jsonb_build_object('result', 'outside_window');
  end if;

  if exists (select 1 from guide.ingest_runs r where r.status = 'open') then
    return jsonb_build_object('result', 'run_open');
  end if;
  if (select count(*) from guide.ingest_runs r where r.started_at > now() - interval '24 hours') >= 3 then
    return jsonb_build_object('result', 'rate_limited');
  end if;
  if guide.ingest_queue_pending() > 150 then
    return jsonb_build_object('result', 'queue_full');
  end if;

  insert into guide.ingest_runs (token_id, kind, dry_run, outside_window)
  values (v_token, p_kind::guide.ingest_kind, p_dry_run, not v_in)
  returning id into v_id;

  return jsonb_build_object(
    'result', 'ok', 'run_id', v_id, 'kind', p_kind, 'dry_run', p_dry_run,
    'limits', jsonb_build_object('max_rows', 40, 'max_calls', 80, 'run_ttl_minutes', 120));
end;
$$;

-- ───────────── 3. ingest_context (J26: solo datos públicos o de configuración; ≤ 64 KB) ─────────────
create or replace function guide.ingest_context(p_token text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_token uuid;
  v_local timestamp := now() at time zone 'Europe/Madrid';
  v_run   guide.ingest_runs;
  v_nl    jsonb;
  v       jsonb;
begin
  v_token := guide.ingest_auth(p_token);

  select * into v_run from guide.ingest_runs r
  where r.token_id = v_token and r.status = 'open' and r.started_at > now() - interval '2 hours'
  order by r.started_at desc limit 1;

  -- Jueves: contexto público para la intro de la carta (prompt-rutina §7). Solo contenido ya publicado.
  if extract(isodow from v_local) = 4 then
    v_nl := jsonb_build_object(
      'week_start', to_char(date_trunc('week', v_local)::date, 'YYYY-MM-DD'),
      'news', (select coalesce(jsonb_agg(jsonb_build_object('title_es', x.title_es, 'summary_es', left(x.summary_es, 300),
                                                            'source_name', x.source_name, 'published_at', x.published_at)
                                         order by x.published_at desc), '[]'::jsonb)
               from (select n.title_es, n.summary_es, n.source_name, n.published_at from guide.news n
                     where n.status = 'published' and n.published_at >= now() - interval '7 days'
                     order by n.published_at desc limit 20) x),
      'events', (select coalesce(jsonb_agg(jsonb_build_object('title_es', x.title_es, 'starts_at', x.starts_at,
                                                              'location_text', x.location_text) order by x.starts_at), '[]'::jsonb)
                 from (select e.title_es, e.starts_at, e.location_text from guide.events e
                       where e.status = 'approved' and e.starts_at >= now() and e.starts_at < now() + interval '14 days'
                       order by e.starts_at limit 20) x),
      'article', (select jsonb_build_object('title_es', a.title_es, 'excerpt_es', left(a.excerpt_es, 300),
                                            'published_at', a.published_at)
                  from guide.articles a where guide.article_is_live(a.status, a.published_at)
                  order by a.published_at desc limit 1));
  end if;

  v := jsonb_build_object(
    'today', to_char(v_local::date, 'YYYY-MM-DD'),
    'now', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'timezone', 'Europe/Madrid',
    'weekday', extract(isodow from v_local)::integer,
    'limits', jsonb_build_object(
      'max_runs_24h', 3,
      'runs_24h', (select count(*) from guide.ingest_runs r where r.started_at > now() - interval '24 hours'),
      'max_rows_per_run', 40,
      'max_calls_per_run', 80,
      'run_ttl_minutes', 120,
      'queue_max', 150,
      'queue_pending', guide.ingest_queue_pending(),
      'run', case when v_run.id is null then null else jsonb_build_object(
               'run_id', v_run.id, 'kind', v_run.kind, 'dry_run', v_run.dry_run,
               'rows_left', 40 - case when v_run.dry_run then v_run.would_insert else v_run.inserted end,
               'calls_left', 80 - v_run.calls) end),
    'sources', (select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'domain', s.domain, 'kind', s.kind,
                                                             'region', s.scope) order by s.name), '[]'::jsonb)
                from guide.news_sources s where s.active),
    'news_categories', (select coalesce(jsonb_agg(jsonb_build_object('key', c.key, 'label_es', c.label_es)
                                                  order by c.sort_order, c.key), '[]'::jsonb)
                        from guide.news_categories c where c.active),
    'event_types', '["competition", "workshop", "outing", "social", "course", "other"]'::jsonb,
    'gyms', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'slug', x.slug, 'city', x.city)
                                       order by x.name), '[]'::jsonb)
             from (select i.id, i.name, i.slug, g.city from guide.items i join guide.gyms g on g.item_id = i.id
                   where i.category = 'gym' and i.published order by i.name limit 200) x),
    'upcoming_events', (select coalesce(jsonb_agg(jsonb_build_object('title_es', x.title_es, 'starts_at', x.starts_at,
                                                                     'location_text', x.location_text)
                                                  order by x.starts_at), '[]'::jsonb)
                        from (select e.title_es, e.starts_at, e.location_text from guide.events e
                              where e.status = 'approved' and e.starts_at >= now()
                              order by e.starts_at limit 150) x),
    'newsletter_context', v_nl);

  if octet_length(v::text) > 65536 then
    v := v - 'upcoming_events';
  end if;
  if octet_length(v::text) > 65536 then
    v := v - 'gyms';
  end if;
  return v;
end;
$$;

-- J9 (firma exacta, solo anon). Se repite en la siguiente migración junto al resto de ingest_*.
revoke all on function guide.ingest_start_run(text, text, boolean) from public, anon, authenticated, service_role;
revoke all on function guide.ingest_context(text) from public, anon, authenticated, service_role;
grant execute on function guide.ingest_start_run(text, text, boolean) to anon;
grant execute on function guide.ingest_context(text) to anon;
