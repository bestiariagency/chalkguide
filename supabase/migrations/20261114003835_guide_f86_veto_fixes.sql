-- F8.6 · Correcciones de la revisión de leona-lia (docs/security/F8.6-ingest-review.md). Idempotente (CREATE OR REPLACE).
-- C1: la propiedad de la intro pasa a ser de toda la carta (asunto, preheader e intro, es/en).
--     · Guarda, rama admin: cualquier cambio de subject_*, preheader_* o intro_* pone intro_by_agent := false.
--     · Guarda, rama no admin, y RPC ingest_submit_newsletter_intro: si not intro_by_agent y alguno de los 6 campos
--       de contenido no es null → intro_owned.
-- O1: la comprobación de cupo (Brevo 300/día) pasa a la guarda en la transición draft → scheduled; approve_issue
--     ya no la duplica. Un UPDATE directo de status no se la salta.
-- Decisión 1 (J26): ingest_context añade url e instructions de las fuentes activas.
-- O2: el contexto del jueves sale a guide.ingest_newsletter_context(p_now) (interna, sin EXECUTE para la API) para
--     poder probarlo con fecha inyectada.
-- Sin cambios de grants salvo los de la función nueva (todo revocado). Nada en public.

-- ───────────── O2: contexto del jueves con fecha inyectable ─────────────
create or replace function guide.ingest_newsletter_context(p_now timestamptz)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_local timestamp := p_now at time zone 'Europe/Madrid';
begin
  -- Jueves: contexto público para la intro de la carta (prompt-rutina §7). Solo contenido ya publicado.
  if p_now is null or extract(isodow from v_local) <> 4 then
    return null;
  end if;
  return jsonb_build_object(
    'week_start', to_char(date_trunc('week', v_local)::date, 'YYYY-MM-DD'),
    'news', (select coalesce(jsonb_agg(jsonb_build_object('title_es', x.title_es, 'summary_es', left(x.summary_es, 300),
                                                          'source_name', x.source_name, 'published_at', x.published_at)
                                       order by x.published_at desc), '[]'::jsonb)
             from (select n.title_es, n.summary_es, n.source_name, n.published_at from guide.news n
                   where n.status = 'published' and n.published_at >= p_now - interval '7 days'
                   order by n.published_at desc limit 20) x),
    'events', (select coalesce(jsonb_agg(jsonb_build_object('title_es', x.title_es, 'starts_at', x.starts_at,
                                                            'location_text', x.location_text) order by x.starts_at), '[]'::jsonb)
               from (select e.title_es, e.starts_at, e.location_text from guide.events e
                     where e.status = 'approved' and e.starts_at >= p_now and e.starts_at < p_now + interval '14 days'
                     order by e.starts_at limit 20) x),
    'article', (select jsonb_build_object('title_es', a.title_es, 'excerpt_es', left(a.excerpt_es, 300),
                                          'published_at', a.published_at)
                from guide.articles a where guide.article_is_live(a.status, a.published_at)
                order by a.published_at desc limit 1));
end;
$$;
revoke all on function guide.ingest_newsletter_context(timestamptz) from public, anon, authenticated, service_role;

-- ───────────── Decisión 1 + O2: ingest_context ─────────────
create or replace function guide.ingest_context(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token uuid;
  v_local timestamp := now() at time zone 'Europe/Madrid';
  v_run   guide.ingest_runs;
  v       jsonb;
begin
  v_token := guide.ingest_auth(p_token);

  select * into v_run from guide.ingest_runs r
  where r.token_id = v_token and r.status = 'open' and r.started_at > now() - interval '2 hours'
  order by r.started_at desc limit 1;

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
    -- J26 (decisión 1 de F8.6): url e instructions de las fuentes activas; configuración del admin, sin datos personales.
    'sources', (select coalesce(jsonb_agg(jsonb_build_object('name', s.name, 'domain', s.domain, 'url', s.url,
                                                             'kind', s.kind, 'region', s.scope,
                                                             'instructions', s.instructions) order by s.name), '[]'::jsonb)
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
    'newsletter_context', guide.ingest_newsletter_context(now()));

  if octet_length(v::text) > 65536 then
    v := v - 'upcoming_events';
  end if;
  if octet_length(v::text) > 65536 then
    v := v - 'gyms';
  end if;
  return v;
end;
$$;
revoke all on function guide.ingest_context(text) from public, anon, authenticated, service_role;
grant execute on function guide.ingest_context(text) to anon;

-- ───────────── C1: RPC del agente ─────────────
create or replace function guide.ingest_submit_newsletter_intro(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
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
  -- C1 (F8.6): la carta es de Xavi en cuanto él ha escrito cualquiera de los 6 campos de contenido.
  if v_issue.id is not null and not v_issue.intro_by_agent
     and num_nonnulls(v_issue.subject_es, v_issue.subject_en, v_issue.preheader_es, v_issue.preheader_en,
                      v_issue.intro_es, v_issue.intro_en) > 0 then
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
revoke all on function guide.ingest_submit_newsletter_intro(text, uuid, jsonb) from public, anon, authenticated, service_role;
grant execute on function guide.ingest_submit_newsletter_intro(text, uuid, jsonb) to anon;

-- ───────────── C1 + O1: guarda de newsletter_issues ─────────────
create or replace function guide.newsletter_issues_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_content constant text[] := array['subject_es', 'subject_en', 'preheader_es', 'preheader_en', 'intro_es', 'intro_en'];
  v_admin boolean := guide.is_admin();
  v_maint boolean := guide.item_live_exempt(null);
  v_bad   integer;
begin
  if tg_op = 'DELETE' then
    if v_maint then
      return old;
    end if;
    if not v_admin then
      raise exception 'newsletter_write_forbidden' using errcode = '42501';
    end if;
    if old.status not in ('draft', 'cancelled') then
      raise exception 'newsletter is locked' using errcode = 'PT423', detail = 'delete';
    end if;
    return old;
  end if;

  new.subject_es   := nullif(btrim(new.subject_es), '');
  new.subject_en   := nullif(btrim(new.subject_en), '');
  new.preheader_es := nullif(btrim(new.preheader_es), '');
  new.preheader_en := nullif(btrim(new.preheader_en), '');
  new.intro_es     := nullif(btrim(new.intro_es), '');
  new.intro_en     := nullif(btrim(new.intro_en), '');

  if v_maint then
    return new;
  end if;

  if not v_admin then
    if tg_op = 'INSERT' then
      if new.status <> 'draft' or new.approved_at is not null or new.scheduled_for is not null
         or new.sent_at is not null or new.sent_counts is not null or new.brevo_campaign_ids is not null
         or new.error_code is not null then
        raise exception 'newsletter_write_forbidden' using errcode = '42501';
      end if;
      new.id := gen_random_uuid();
      new.composed_by := 'agent';
      new.composed_at := now();
      new.created_at := now();
      new.updated_at := now();
      return new;
    end if;
    if old.status <> 'draft' or new.status <> 'draft'
       or (to_jsonb(new) - c_content - 'intro_by_agent' - 'updated_at' - 'has_en')
          is distinct from (to_jsonb(old) - c_content - 'intro_by_agent' - 'updated_at' - 'has_en') then
      raise exception 'newsletter_write_forbidden' using errcode = '42501';
    end if;
    -- C1 (F8.6): cualquier campo de contenido escrito por Xavi protege toda la carta.
    if not old.intro_by_agent
       and num_nonnulls(old.subject_es, old.subject_en, old.preheader_es, old.preheader_en, old.intro_es, old.intro_en) > 0 then
      raise exception 'newsletter_intro_owned' using errcode = '42501';
    end if;
    new.intro_by_agent := true;
    new.updated_at := now();
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'draft' then
      raise exception 'newsletter_invalid_transition' using errcode = '55000', detail = 'insert>' || new.status::text;
    end if;
    new.composed_by := 'admin';
    new.composed_at := now();
    new.intro_by_agent := false;
    new.approved_at := null;
    new.approved_by := null;
    new.scheduled_for := null;
    new.sent_at := null;
    new.sent_counts := null;
    new.error_code := null;
    new.brevo_campaign_ids := null;
    return new;
  end if;

  if new.id is distinct from old.id or new.week_start is distinct from old.week_start
     or new.created_at is distinct from old.created_at or new.composed_by is distinct from old.composed_by
     or new.sent_at is distinct from old.sent_at or new.sent_counts is distinct from old.sent_counts
     or new.error_code is distinct from old.error_code or new.brevo_campaign_ids is distinct from old.brevo_campaign_ids then
    raise exception 'newsletter_field_immutable' using errcode = '42501';
  end if;

  if (new.subject_es, new.subject_en, new.preheader_es, new.preheader_en, new.intro_es, new.intro_en)
     is distinct from
     (old.subject_es, old.subject_en, old.preheader_es, old.preheader_en, old.intro_es, old.intro_en) then
    -- D77: una carta programada no se edita; primero vuelve a borrador (unschedule_issue).
    if old.status <> 'draft' or new.status <> 'draft' then
      raise exception 'newsletter_not_draft' using errcode = '55000';
    end if;
    -- C1 (F8.6): si Xavi toca asunto, preheader o intro, la carta pasa a ser suya.
    new.intro_by_agent := false;
  end if;
  if new.intro_by_agent and not old.intro_by_agent then
    new.intro_by_agent := false;
  end if;

  if new.status is distinct from old.status then
    if (old.status::text || '>' || new.status::text) <> all (array[
          'draft>scheduled', 'scheduled>draft', 'draft>cancelled', 'scheduled>cancelled', 'cancelled>draft']) then
      raise exception 'newsletter_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
    if old.status = 'scheduled' and now() >= old.scheduled_for - interval '1 minute' then
      raise exception 'newsletter_locked' using errcode = '55000';
    end if;
    if new.status = 'scheduled' then
      if new.subject_es is null or new.intro_es is null then
        raise exception 'newsletter_incomplete' using errcode = '23514';
      end if;
      if not exists (select 1 from guide.newsletter_issue_items i where i.issue_id = new.id) then
        raise exception 'newsletter_empty' using errcode = '23514';
      end if;
      -- Nada que no sea público entra en la carta (regla 6).
      select count(*) into v_bad
      from guide.newsletter_issue_items i
      where i.issue_id = new.id
        and not (case i.kind
          when 'news' then exists (select 1 from guide.news n where n.id = i.ref_id and n.status = 'published')
          when 'event' then exists (select 1 from guide.events e where e.id = i.ref_id and e.status = 'approved')
          else exists (select 1 from guide.articles a where a.id = i.ref_id
                       and guide.article_is_live(a.status, a.published_at))
        end);
      if v_bad > 0 then
        raise exception 'newsletter_item_not_public' using errcode = '23514';
      end if;
      -- O1 (F8.6): el cupo diario de Brevo se comprueba aquí, para cualquier camino de draft → scheduled.
      if not coalesce((guide.newsletter_quota_today() ->> 'fits')::boolean, false) then
        raise exception 'newsletter_quota' using errcode = '23514';
      end if;
      new.approved_at := now();
      new.approved_by := (select auth.uid());
      new.scheduled_for := now() + interval '1 hour';
    else
      new.approved_at := null;
      new.approved_by := null;
      new.scheduled_for := null;
    end if;
  else
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    new.scheduled_for := old.scheduled_for;
  end if;
  return new;
end;
$$;
revoke all on function guide.newsletter_issues_before_write() from public, anon, authenticated, service_role;

-- ───────────── O1: approve_issue ya no duplica el cupo (lo hace la guarda) ─────────────
create or replace function guide.approve_issue(p_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  return guide.newsletter_set_status(p_id, array['draft']::guide.newsletter_status[], 'scheduled');
end;
$$;
