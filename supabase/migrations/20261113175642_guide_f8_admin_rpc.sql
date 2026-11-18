-- F8 (8.5) · RPC de admin (tokens, ventana R1, liberar dedupe J18b, noticias en lote, categorías, fuentes,
-- newsletter) y búsqueda pública de noticias (FTS es/en como articles). Todas las de admin llevan
-- guide.assert_admin() primero; EXECUTE solo para authenticated (J9). DEFINER solo donde hace falta leer o escribir
-- columnas sin grant de cliente (token_hash, agent_meta, instrucciones de fuentes, suscriptores). Idempotente.

-- ───────────── 1. Tokens de la ingesta (J1, J4, J5) ─────────────
create or replace function guide.admin_create_ingest_token(p_label text, p_expires_days integer)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_label text := nullif(btrim(p_label), '');
  v_token text;
  v_id    uuid;
  v_exp   timestamptz;
begin
  perform guide.assert_admin();
  if v_label is null or char_length(v_label) > 60 or v_label ~ '[[:cntrl:]]' then
    raise exception 'invalid label' using errcode = '22023';
  end if;
  if p_expires_days is null or p_expires_days not between 1 and 30 then
    raise exception 'invalid expiry' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  -- J4: como mucho 2 vigentes (solape de la rotación).
  if (select count(*) from guide.ingest_tokens t where t.revoked_at is null and t.expires_at > now()) >= 2 then
    raise exception 'ingest_token_limit' using errcode = '55000';
  end if;
  v_token := 'cgi_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_exp := now() + make_interval(days => p_expires_days);
  insert into guide.ingest_tokens (token_hash, hint, label, created_by, expires_at)
  values (extensions.digest(convert_to(v_token, 'UTF8'), 'sha256'), right(v_token, 4), v_label, (select auth.uid()), v_exp)
  returning id into v_id;
  -- El texto plano sale una sola vez y no se guarda en ninguna parte.
  return jsonb_build_object('id', v_id, 'token', v_token, 'hint', right(v_token, 4), 'label', v_label, 'expires_at', v_exp);
end;
$$;

create or replace function guide.admin_revoke_ingest_token(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_runs integer;
begin
  perform guide.assert_admin();
  perform pg_advisory_xact_lock(hashtext('guide.ingest'));
  update guide.ingest_tokens t
  set revoked_at = coalesce(t.revoked_at, now()),
      revoked_by = case when t.revoked_at is null then (select auth.uid()) else t.revoked_by end
  where t.id = p_id;
  if not found then
    raise exception 'token not found' using errcode = 'P0002';
  end if;
  -- J5: los runs abiertos de ese token se cierran al momento.
  update guide.ingest_runs r set status = 'revoked', finished_at = now()
  where r.token_id = p_id and r.status = 'open';
  get diagnostics v_runs = row_count;
  return jsonb_build_object('id', p_id, 'revoked', true, 'runs_closed', v_runs);
end;
$$;

create or replace function guide.admin_list_ingest_tokens()
returns table (id uuid, label text, hint text, status text, created_at timestamptz, created_by uuid,
               expires_at timestamptz, last_used_at timestamptz, revoked_at timestamptz, runs_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform guide.assert_admin();
  return query
  select t.id, t.label, t.hint,
         case when t.revoked_at is not null then 'revoked' when t.expires_at <= now() then 'expired' else 'active' end,
         t.created_at, t.created_by, t.expires_at, t.last_used_at, t.revoked_at,
         (select count(*) from guide.ingest_runs r where r.token_id = t.id)
  from guide.ingest_tokens t
  order by t.created_at desc;
end;
$$;

-- R1: abre (2 h) o cierra la ventana manual de recogida.
create or replace function guide.admin_set_ingest_window(p_open boolean)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_until timestamptz;
begin
  perform guide.assert_admin();
  if p_open is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  update guide.ingest_config c
  set window_open_until = case when p_open then now() + interval '2 hours' end,
      updated_by = (select auth.uid())
  where c.id
  returning c.window_open_until into v_until;
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'update', 'ingest_config', 'window', 'Ventana de recogida', array['window_open_until'],
          jsonb_build_object('by', 'admin', 'to', case when p_open then 'open' else 'closed' end));
  return jsonb_build_object('window_open_until', v_until);
end;
$$;

-- ───────────── 2. J18b: liberar la clave de un rechazado por datos incorrectos ─────────────
create or replace function guide.admin_release_event_dedupe(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_prev  text := coalesce(current_setting('guide.draft_op', true), '');
  v_st    guide.event_status;
  v_rr    text;
  v_key   text;
  v_title text;
begin
  perform guide.assert_admin();
  select e.status, e.reject_reason, e.dedupe_key, e.title_es into v_st, v_rr, v_key, v_title
  from guide.events e where e.id = p_id for update;
  if not found then
    raise exception 'event not found' using errcode = 'P0002';
  end if;
  if v_st <> 'rejected' or v_rr is distinct from 'wrong_data' or v_key is null then
    raise exception 'release_not_allowed' using errcode = '55000';
  end if;
  if v_key = 'released:' || p_id::text then
    return jsonb_build_object('id', p_id, 'released', true);
  end if;
  perform set_config('guide.draft_op', 'release_dedupe:' || p_id::text, true);
  update guide.events e set dedupe_key = 'released:' || p_id::text where e.id = p_id;
  perform set_config('guide.draft_op', v_prev, true);
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'update', 'events', p_id::text, left(v_title, 200), array['dedupe_key'],
          jsonb_build_object('by', 'admin', 'source', 'agent', 'op', 'release_dedupe'));
  return jsonb_build_object('id', p_id, 'released', true);
end;
$$;

create or replace function guide.admin_release_news_dedupe(p_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_prev  text := coalesce(current_setting('guide.draft_op', true), '');
  v_st    guide.news_status;
  v_rr    text;
  v_key   text;
  v_title text;
begin
  perform guide.assert_admin();
  select n.status, n.reject_reason, n.dedupe_key, n.title_es into v_st, v_rr, v_key, v_title
  from guide.news n where n.id = p_id for update;
  if not found then
    raise exception 'news not found' using errcode = 'P0002';
  end if;
  if v_st <> 'rejected' or v_rr is distinct from 'wrong_data' or v_key is null then
    raise exception 'release_not_allowed' using errcode = '55000';
  end if;
  if v_key = 'released:' || p_id::text then
    return jsonb_build_object('id', p_id, 'released', true);
  end if;
  perform set_config('guide.draft_op', 'release_dedupe:' || p_id::text, true);
  update guide.news n set dedupe_key = 'released:' || p_id::text, url_key = 'released:' || p_id::text where n.id = p_id;
  perform set_config('guide.draft_op', v_prev, true);
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'update', 'news', p_id::text, left(v_title, 200), array['dedupe_key', 'url_key'],
          jsonb_build_object('by', 'admin', 'source', 'agent', 'op', 'release_dedupe'));
  return jsonb_build_object('id', p_id, 'released', true);
end;
$$;

-- ───────────── 3. Noticias: estados en lote (D74, D77: aprobar al momento con Deshacer) ─────────────
create or replace function guide.set_news_status(p_ids uuid[], p_status guide.news_status, p_reject_reason text default null)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_id   uuid;
  v_row  record;
  v_ok   jsonb := '[]'::jsonb;
  v_bad  jsonb := '[]'::jsonb;
  v_code text;
  v_msg  text;
begin
  perform guide.assert_admin();
  if p_ids is null or cardinality(p_ids) = 0 or cardinality(p_ids) > 100 or array_position(p_ids, null) is not null
     or cardinality(p_ids) <> (select count(distinct x) from unnest(p_ids) x) or p_status is null then
    raise exception 'invalid ids' using errcode = '22023';
  end if;
  if p_reject_reason is not null and (p_status <> 'rejected'
     or p_reject_reason not in ('duplicate', 'not_climbing', 'outside_area', 'not_relevant', 'wrong_data', 'unreliable_source')) then
    raise exception 'invalid reject reason' using errcode = '22023';
  end if;
  foreach v_id in array p_ids loop
    begin
      update guide.news n set status = p_status, reject_reason = p_reject_reason where n.id = v_id
      returning n.id, n.status, n.slug, n.published_at, n.updated_at into v_row;
      if not found then
        raise exception 'news not found' using errcode = 'P0002';
      end if;
      v_ok := v_ok || jsonb_build_array(to_jsonb(v_row));
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

create or replace function guide.approve_news(p_ids uuid[])
returns jsonb
language sql
volatile
set search_path = ''
as $$
  select guide.set_news_status(p_ids, 'published');
$$;

create or replace function guide.reject_news(p_ids uuid[], p_reason text default null)
returns jsonb
language sql
volatile
set search_path = ''
as $$
  select guide.set_news_status(p_ids, 'rejected', p_reason);
$$;

-- Retirar una publicada o recuperar una rechazada: vuelve a borrador (también es el Deshacer del lote).
create or replace function guide.reopen_news(p_ids uuid[])
returns jsonb
language sql
volatile
set search_path = ''
as $$
  select guide.set_news_status(p_ids, 'draft');
$$;

-- ───────────── 4. Noticias: recuentos y listado del panel ─────────────
create or replace function guide.admin_news_summary()
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
    'pending',             count(*) filter (where n.status = 'draft'),
    'pending_agent',       count(*) filter (where n.status = 'draft' and n.source = 'agent'),
    'pending_warnings',    count(*) filter (where n.status = 'draft' and n.source = 'agent'
                                            and ((n.agent_meta ->> 'confidence')::numeric < 0.65
                                                 or n.similarity >= 0.35
                                                 or n.agent_meta ->> 'duplicate_of' is not null)),
    'published',           count(*) filter (where n.status = 'published'),
    'published_indexable', count(*) filter (where n.status = 'published' and n.indexable),
    'published_noindex',   count(*) filter (where n.status = 'published' and not n.indexable),
    'rejected',            count(*) filter (where n.status = 'rejected'),
    'total',               count(*))
  into v
  from guide.news n;
  v := v || jsonb_build_object(
    'last_run', (select jsonb_build_object('id', r.id, 'started_at', r.started_at, 'finished_at', r.finished_at,
                                           'status', r.status, 'dry_run', r.dry_run, 'inserted_news', r.inserted_news,
                                           'inserted_events', r.inserted_events, 'duplicates', r.duplicates,
                                           'duplicate_rejected', r.duplicate_rejected)
                 from guide.ingest_runs r order by r.started_at desc limit 1),
    'health', (select jsonb_build_object('checked_at', h.checked_at, 'ok', h.status_code = 200, 'details', h.details)
               from guide.job_health h where h.job = 'ingest'),
    'newsletter_ready', exists (select 1 from guide.newsletter_issues i
                                where i.status = 'draft'
                                  and i.week_start = date_trunc('week', now() at time zone 'Europe/Madrid')::date
                                  and i.subject_es is not null and i.intro_es is not null));
  return v;
end;
$$;

create or replace function guide.admin_list_news(
  p_status      guide.news_status default null,
  p_category_id uuid default null,
  p_scope       guide.news_scope default null,
  p_source_id   uuid default null,
  p_run_id      uuid default null,
  p_query       text default null,
  p_id          uuid default null,
  p_limit       integer default 50,
  p_offset      integer default 0
)
returns table (
  id uuid, slug text, status guide.news_status, source guide.event_source,
  title_es text, title_en text, summary_es text, summary_en text, author_note_es text, author_note_en text,
  category_id uuid, category_key text, scope guide.news_scope, tags text[],
  source_name text, source_url text, source_title text, source_published_on date, source_lang text,
  source_id uuid, source_trusted boolean, source_approval_rate numeric,
  media_id uuid, image_license text, image_credit text, run_id uuid, agent_meta jsonb, similarity real,
  warnings text[], reject_reason text, indexable boolean, indexable_en boolean, has_en boolean,
  published_at timestamptz, first_published_at timestamptz, created_at timestamptz, updated_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_q      text;
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 10000);
begin
  perform guide.assert_admin();
  if char_length(coalesce(p_query, '')) > 200 then
    raise exception 'query too long' using errcode = '22023';
  end if;
  v_q := nullif(btrim(regexp_replace(coalesce(p_query, ''), '[[:cntrl:]]+', ' ', 'g')), '');
  if v_q is not null then
    v_q := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;
  return query
  select n.id, n.slug, n.status, n.source, n.title_es, n.title_en, n.summary_es, n.summary_en,
         n.author_note_es, n.author_note_en, n.category_id, c.key, n.scope, n.tags,
         n.source_name, n.source_url, n.source_title, n.source_published_on, n.source_lang,
         n.source_id, s.trusted,
         (select round(count(*) filter (where x.status = 'published')::numeric
                       / nullif(count(*) filter (where x.status in ('published', 'rejected')), 0), 3)
          from guide.news x where x.source_id = n.source_id),
         n.media_id, n.image_license, n.image_credit, n.run_id, n.agent_meta, n.similarity,
         array_remove(array[
           case when (n.agent_meta ->> 'confidence')::numeric < 0.65 then 'low_confidence' end,
           case when n.similarity >= 0.35 then 'high_similarity' end,
           case when n.agent_meta ->> 'duplicate_of' is not null then 'possible_duplicate' end], null),
         n.reject_reason, n.indexable, n.indexable_en, n.has_en,
         n.published_at, n.first_published_at, n.created_at, n.updated_at,
         count(*) over ()
  from guide.news n
  join guide.news_categories c on c.id = n.category_id
  left join guide.news_sources s on s.id = n.source_id
  where (p_id is null or n.id = p_id)
    and (p_status is null or n.status = p_status)
    and (p_category_id is null or n.category_id = p_category_id)
    and (p_scope is null or n.scope = p_scope)
    and (p_source_id is null or n.source_id = p_source_id)
    and (p_run_id is null or n.run_id = p_run_id)
    and (v_q is null or n.title_es ilike v_q or n.summary_es ilike v_q or n.source_name ilike v_q
         or n.title_en ilike v_q)
  order by case when p_status = 'draft' then n.source_published_on end desc nulls last,
           coalesce(n.published_at, n.created_at) desc, n.id
  limit v_limit offset v_offset;
end;
$$;

-- Fuentes con instrucciones, recuentos y tasa de aprobación (noticias: publicadas / decididas; eventos por dominio).
create or replace function guide.admin_list_news_sources()
returns table (
  id uuid, name text, domain text, url text, kind guide.ingest_kind, scope guide.news_scope, lang text,
  instructions text, trusted boolean, active boolean, last_seen_at timestamptz, created_at timestamptz,
  updated_at timestamptz, news_total bigint, news_published bigint, news_rejected bigint, news_pending bigint,
  events_total bigint, events_approved bigint, approval_rate numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  perform guide.assert_admin();
  return query
  with ev as (
    select lower(substring(e.source_url from '^https?://([^/?#]+)')) as host, e.status
    from guide.events e where e.source = 'agent' and e.source_url is not null
  )
  select s.id, s.name, s.domain, s.url, s.kind, s.scope, s.lang, s.instructions, s.trusted, s.active,
         s.last_seen_at, s.created_at, s.updated_at,
         coalesce(nw.total, 0), coalesce(nw.published, 0), coalesce(nw.rejected, 0), coalesce(nw.pending, 0),
         coalesce(es.total, 0), coalesce(es.approved, 0),
         round((coalesce(nw.published, 0) + coalesce(es.approved, 0))::numeric
               / nullif(coalesce(nw.published, 0) + coalesce(nw.rejected, 0)
                        + coalesce(es.approved, 0) + coalesce(es.rejected, 0), 0), 3)
  from guide.news_sources s
  left join lateral (
    select count(*) as total,
           count(*) filter (where n.status = 'published') as published,
           count(*) filter (where n.status = 'rejected') as rejected,
           count(*) filter (where n.status = 'draft') as pending
    from guide.news n where n.source_id = s.id) nw on true
  left join lateral (
    select count(*) as total,
           count(*) filter (where ev.status in ('approved', 'cancelled')) as approved,
           count(*) filter (where ev.status = 'rejected') as rejected
    from ev where ev.host = s.domain or ev.host like '%.' || s.domain) es on true
  order by s.active desc, s.name;
end;
$$;

-- ───────────── 5. Categorías de noticias: borrar con reasignación y reordenar ─────────────
create or replace function guide.delete_news_category(p_id uuid, p_reassign_to uuid default null)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_moved integer := 0;
begin
  perform guide.assert_admin();
  if p_id is null or p_id = p_reassign_to then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  if not exists (select 1 from guide.news_categories c where c.id = p_id) then
    raise exception 'category not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from guide.news n where n.category_id = p_id) then
    if p_reassign_to is null then
      raise exception 'category_in_use' using errcode = '23503';
    end if;
    if not exists (select 1 from guide.news_categories c where c.id = p_reassign_to) then
      raise exception 'target category not found' using errcode = 'P0002';
    end if;
    update guide.news n set category_id = p_reassign_to where n.category_id = p_id;
    get diagnostics v_moved = row_count;
  end if;
  delete from guide.news_categories c where c.id = p_id;
  return jsonb_build_object('deleted', p_id, 'moved', v_moved);
end;
$$;

create or replace function guide.reorder_news_categories(p_ids uuid[])
returns void
language plpgsql
volatile
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_ids is null or array_position(p_ids, null) is not null
     or cardinality(p_ids) <> (select count(distinct x) from unnest(p_ids) x)
     or cardinality(p_ids) <> (select count(*) from guide.news_categories)
     or exists (select 1 from unnest(p_ids) x where not exists (select 1 from guide.news_categories c where c.id = x)) then
    raise exception 'invalid ids' using errcode = '22023';
  end if;
  update guide.news_categories c set sort_order = o.ord
  from unnest(p_ids) with ordinality as o(id, ord)
  where c.id = o.id and c.sort_order is distinct from o.ord::integer;
end;
$$;

-- ───────────── 6. Newsletter: cupo, componer, aprobar (+1 h), desprogramar, cancelar ─────────────
-- Cupo gratuito de Brevo (D75): 300/día compartido con el doble opt-in. Las confirmaciones de hoy se aproximan con
-- las altas de hoy (Madrid) hasta que 8.13 / F4.6 guarden un registro de envíos.
create or replace function guide.newsletter_quota_today()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_day    date := (now() at time zone 'Europe/Madrid')::date;
  v_conf   integer;
  v_sent   integer;
  v_es     integer;
  v_en     integer;
begin
  perform guide.assert_admin();
  select count(*) into v_conf from guide.subscribers s
  where (s.created_at at time zone 'Europe/Madrid')::date = v_day;
  select coalesce(sum(coalesce((i.sent_counts ->> 'es')::integer, 0) + coalesce((i.sent_counts ->> 'en')::integer, 0)), 0)
  into v_sent
  from guide.newsletter_issues i
  where i.sent_at is not null and (i.sent_at at time zone 'Europe/Madrid')::date = v_day;
  select count(*) filter (where s.locale = 'es'), count(*) filter (where s.locale = 'en')
  into v_es, v_en
  from guide.subscribers s where s.status = 'active';
  return jsonb_build_object(
    'limit', 300, 'warn_from', 250, 'approximate', true,
    'confirmations_today', v_conf, 'newsletter_sent_today', v_sent, 'used_today', v_conf + v_sent,
    'recipients_es', v_es, 'recipients_en', v_en, 'recipients', v_es + v_en,
    'after_issue', v_conf + v_sent + v_es + v_en,
    'fits', v_conf + v_sent + v_es + v_en <= 300,
    'split_recommended', v_es + v_en > 250);
end;
$$;

create or replace function guide.compose_issue(p_week date default null)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_week date := coalesce(p_week, date_trunc('week', now() at time zone 'Europe/Madrid')::date);
  v_id   uuid;
begin
  perform guide.assert_admin();
  if extract(isodow from v_week) <> 1 then
    raise exception 'invalid week' using errcode = '22023';
  end if;
  v_id := guide.newsletter_compose(v_week);
  return jsonb_build_object('id', v_id, 'week_start', v_week,
                            'items', (select count(*) from guide.newsletter_issue_items i where i.issue_id = v_id));
end;
$$;

create or replace function guide.newsletter_set_status(p_id uuid, p_from guide.newsletter_status[], p_to guide.newsletter_status)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
declare
  v_row record;
begin
  perform guide.assert_admin();
  if p_id is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  update guide.newsletter_issues i set status = p_to
  where i.id = p_id and i.status = any (p_from)
  returning i.id, i.status, i.approved_at, i.scheduled_for, i.updated_at into v_row;
  if not found then
    if exists (select 1 from guide.newsletter_issues i where i.id = p_id) then
      raise exception 'newsletter_invalid_transition' using errcode = '55000';
    end if;
    raise exception 'issue not found' using errcode = 'P0002';
  end if;
  return to_jsonb(v_row);
end;
$$;

create or replace function guide.approve_issue(p_id uuid)
returns jsonb
language plpgsql
volatile
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if not coalesce((guide.newsletter_quota_today() ->> 'fits')::boolean, false) then
    raise exception 'newsletter_quota' using errcode = '23514';
  end if;
  return guide.newsletter_set_status(p_id, array['draft']::guide.newsletter_status[], 'scheduled');
end;
$$;

-- D77: editar una carta programada la devuelve a borrador; al reaprobar cuenta otra hora.
create or replace function guide.unschedule_issue(p_id uuid)
returns jsonb
language sql
volatile
set search_path = ''
as $$
  select guide.newsletter_set_status(p_id, array['scheduled']::guide.newsletter_status[], 'draft');
$$;

create or replace function guide.cancel_issue(p_id uuid)
returns jsonb
language sql
volatile
set search_path = ''
as $$
  select guide.newsletter_set_status(p_id, array['draft', 'scheduled']::guide.newsletter_status[], 'cancelled');
$$;

-- ───────────── 7. Búsqueda pública de noticias (FTS es/en, mismo patrón que search_articles) ─────────────
create or replace function guide.search_news(p_query text, p_locale guide.locale, p_category_id uuid default null,
                                             p_limit integer default 20, p_offset integer default 0)
returns table (id uuid, slug text, title text, summary text, category_id uuid, category_key text, category_label text,
               source_name text, source_url text, published_at timestamptz, indexable boolean, rank real,
               headline text, total_count bigint)
language plpgsql
stable
set search_path = ''
as $$
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
        order by r desc, n.published_at desc, n.id
        limit v_limit offset v_offset
      )
      select n.id, n.slug, n.title_es, n.summary_es, c.id, c.key, c.label_es, n.source_name, n.source_url,
             n.published_at, n.indexable, m.r,
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
        order by r desc, n.published_at desc, n.id
        limit v_limit offset v_offset
      )
      select n.id, n.slug, n.title_en, n.summary_en, c.id, c.key, c.label_en, n.source_name, n.source_url,
             n.published_at, n.indexable_en, m.r,
             ts_headline(v_cfg, concat_ws(' ', n.summary_en, n.author_note_en), v_tsq, c_opts), m.t
      from m
      join guide.news n on n.id = m.nid
      left join guide.news_categories c on c.id = n.category_id
      order by m.r desc, n.published_at desc, n.id;
  end if;
end;
$$;

-- ───────────── 8. Permisos ─────────────
do $$
declare
  f text;
begin
  foreach f in array array[
    'guide.admin_create_ingest_token(text, integer)',
    'guide.admin_revoke_ingest_token(uuid)',
    'guide.admin_list_ingest_tokens()',
    'guide.admin_set_ingest_window(boolean)',
    'guide.admin_release_event_dedupe(uuid)',
    'guide.admin_release_news_dedupe(uuid)',
    'guide.set_news_status(uuid[], guide.news_status, text)',
    'guide.approve_news(uuid[])',
    'guide.reject_news(uuid[], text)',
    'guide.reopen_news(uuid[])',
    'guide.admin_news_summary()',
    'guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)',
    'guide.admin_list_news_sources()',
    'guide.delete_news_category(uuid, uuid)',
    'guide.reorder_news_categories(uuid[])',
    'guide.newsletter_quota_today()',
    'guide.compose_issue(date)',
    'guide.newsletter_set_status(uuid, guide.newsletter_status[], guide.newsletter_status)',
    'guide.approve_issue(uuid)',
    'guide.unschedule_issue(uuid)',
    'guide.cancel_issue(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

revoke all on function guide.search_news(text, guide.locale, uuid, integer, integer) from public, anon, authenticated, service_role;
grant execute on function guide.search_news(text, guide.locale, uuid, integer, integer) to anon, authenticated;
