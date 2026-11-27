-- 8.13 · Envío semanal por campañas de Brevo (docs/security/F4.6-brevo-spec.md §3.5, §7.8; B22–B27; L3, L7, L10, L11;
-- decisión 4 de Xavi: si no cabe en el cupo, ES ese día y EN al día siguiente).
-- Lock por edición (send_lock_id) con exención del guard atada a la fila `guide.newsletter_op = 'send:<id>:<lock>'`
-- (no reutiliza item_live_exempt ni draft_op). Solo service_role vía svc_newsletter_*. Cron cada 10 min, inerte hasta
-- que exista el secreto de Vault `newsletter_send_secret`. Idempotente. Cero cambios en public.

alter table guide.newsletter_issues
  add column if not exists send_lock_id uuid,
  add column if not exists send_locked_at timestamptz,
  add column if not exists send_attempts smallint not null default 0,
  add column if not exists send_next_at timestamptz;
alter table guide.newsletter_issues drop constraint if exists newsletter_issues_send_attempts_check;
alter table guide.newsletter_issues add constraint newsletter_issues_send_attempts_check check (send_attempts between 0 and 5);
alter table guide.newsletter_issues drop constraint if exists newsletter_issues_send_lock_check;
alter table guide.newsletter_issues add constraint newsletter_issues_send_lock_check
  check ((send_lock_id is null) = (send_locked_at is null) and (send_lock_id is null or status = 'sending'));

-- ───────────── Guard: exención send:<id>:<lock> ─────────────
create or replace function guide.newsletter_issues_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_content constant text[] := array['subject_es', 'subject_en', 'preheader_es', 'preheader_en', 'intro_es', 'intro_en'];
  c_send    constant text[] := array['status', 'send_lock_id', 'send_locked_at', 'send_attempts', 'send_next_at', 'sent_at',
                                     'sent_counts', 'error_code', 'brevo_campaign_ids', 'updated_at'];
  v_op    text := coalesce(current_setting('guide.newsletter_op', true), '');
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

  -- 8.13 (B14, L11): exención de envío atada a la fila y al lock. Solo columnas de envío y solo
  -- scheduled→sending, sending→sending|sent|failed. El contenido sigue inmutable.
  if tg_op = 'UPDATE' and v_op like 'send:%' then
    if not (coalesce(v_op = 'send:' || old.id::text || ':' || new.send_lock_id::text, false)
            or coalesce(v_op = 'send:' || old.id::text || ':' || old.send_lock_id::text, false)) then
      raise exception 'newsletter_send_op_mismatch' using errcode = '42501';
    end if;
    if (to_jsonb(new) - c_send) is distinct from (to_jsonb(old) - c_send) then
      raise exception 'newsletter_field_immutable' using errcode = '42501';
    end if;
    if (old.status::text || '>' || new.status::text)
       <> all (array['scheduled>sending', 'sending>sending', 'sending>sent', 'sending>failed']) then
      raise exception 'newsletter_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
    return new;
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
         or new.error_code is not null or new.send_lock_id is not null or new.send_attempts <> 0
         or new.send_next_at is not null then
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
    new.send_lock_id := null;
    new.send_locked_at := null;
    new.send_attempts := 0;
    new.send_next_at := null;
    return new;
  end if;

  if new.id is distinct from old.id or new.week_start is distinct from old.week_start
     or new.created_at is distinct from old.created_at or new.composed_by is distinct from old.composed_by
     or new.sent_at is distinct from old.sent_at or new.sent_counts is distinct from old.sent_counts
     or new.error_code is distinct from old.error_code or new.brevo_campaign_ids is distinct from old.brevo_campaign_ids
     or new.send_lock_id is distinct from old.send_lock_id or new.send_locked_at is distinct from old.send_locked_at
     or new.send_attempts is distinct from old.send_attempts or new.send_next_at is distinct from old.send_next_at then
    raise exception 'newsletter_field_immutable' using errcode = '42501';
  end if;

  if (new.subject_es, new.subject_en, new.preheader_es, new.preheader_en, new.intro_es, new.intro_en)
     is distinct from
     (old.subject_es, old.subject_en, old.preheader_es, old.preheader_en, old.intro_es, old.intro_en) then
    if old.status <> 'draft' or new.status <> 'draft' then
      raise exception 'newsletter_not_draft' using errcode = '55000';
    end if;
    new.intro_by_agent := false;
  end if;
  if new.intro_by_agent and not old.intro_by_agent then
    new.intro_by_agent := false;
  end if;

  if new.status is distinct from old.status then
    -- B23 / L11: cancelar solo desde scheduled; sending → cancelled da 55000.
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

-- ───────────── Envíos reales de hoy (L7: contador interno) ─────────────
create or replace function guide.newsletter_sent_today()
returns integer
language sql
stable
set search_path = ''
as $$
  with d as (select date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid' as t)
  select (select count(*)::integer from guide.subscriber_consent_events e, d
          where e.event = 'confirm_sent' and e.occurred_at >= d.t)
       + coalesce((select sum((x.value ->> 'count')::integer)::integer
                   from guide.newsletter_issues i, d, jsonb_each(coalesce(i.brevo_campaign_ids, '{}'::jsonb)) x
                   where jsonb_typeof(x.value) = 'object' and x.value ->> 'state' = 'sent'
                     and (x.value ->> 'sent_at')::timestamptz >= d.t), 0);
$$;
revoke all on function guide.newsletter_sent_today() from public, anon, authenticated, service_role;

-- Cupo (panel): envíos reales de hoy + reserva de 30 para confirmaciones. Con la partición por idioma (decisión 4),
-- cabe si el español cabe hoy y el inglés cabe solo en un día.
create or replace function guide.newsletter_quota_today()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_limit   constant integer := 300;
  c_reserve constant integer := 30;
  v_day     timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v_conf    integer;
  v_used    integer;
  v_es      integer;
  v_en      integer;
begin
  perform guide.assert_admin();
  select count(*) into v_conf from guide.subscriber_consent_events e where e.event = 'confirm_sent' and e.occurred_at >= v_day;
  v_used := guide.newsletter_sent_today();
  select count(*) filter (where s.locale = 'es'), count(*) filter (where s.locale = 'en')
  into v_es, v_en
  from guide.subscribers s where s.status = 'active';
  return jsonb_build_object(
    'limit', c_limit, 'warn_from', 250, 'reserve', c_reserve, 'approximate', true,
    'confirmations_today', v_conf, 'newsletter_sent_today', v_used - v_conf, 'used_today', v_used,
    'recipients_es', v_es, 'recipients_en', v_en, 'recipients', v_es + v_en,
    'after_issue', v_used + v_es + v_en,
    'fits', v_used + c_reserve + v_es <= c_limit and c_reserve + v_en <= c_limit,
    'will_split', v_used + c_reserve + v_es + v_en > c_limit,
    'split_recommended', v_es + v_en > 250);
end;
$$;

-- ───────────── RPC del envío (solo service_role) ─────────────
create or replace function guide.newsletter_send_locked(p_id uuid, p_lock_id uuid)
returns guide.newsletter_issues
language plpgsql
set search_path = ''
as $$
declare
  r guide.newsletter_issues;
begin
  select * into r from guide.newsletter_issues i
  where i.id = p_id and i.status = 'sending' and i.send_lock_id = p_lock_id and p_lock_id is not null
  for update;
  if not found then
    raise exception 'newsletter lock lost' using errcode = '55000';
  end if;
  return r;
end;
$$;
revoke all on function guide.newsletter_send_locked(uuid, uuid) from public, anon, authenticated, service_role;

-- B22/B26: toma una edición vencida (o una sending con lock caducado > 20 min) y devuelve solo contenido público
-- re-filtrado al enviar. null si no hay nada.
create or replace function guide.svc_newsletter_claim(p_lock_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r       guide.newsletter_issues;
  v_items jsonb;
  c_init  constant jsonb := '{"es": {"id": null, "state": "pending", "count": 0}, "en": {"id": null, "state": "pending", "count": 0}}';
begin
  perform guide.svc_assert();
  if p_lock_id is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  select * into r from guide.newsletter_issues i
  where (i.status = 'scheduled' and i.scheduled_for <= now())
     or (i.status = 'sending' and coalesce(i.send_next_at, '-infinity'::timestamptz) <= now()
         and (i.send_lock_id is null or i.send_locked_at < now() - interval '20 minutes'))
  order by i.scheduled_for
  limit 1
  for update skip locked;
  if not found then
    return null;
  end if;

  perform set_config('guide.newsletter_op', 'send:' || r.id::text || ':' || p_lock_id::text, true);
  -- B22: tope de 5 tomas por edición (cuentan las recuperaciones de un lock caducado y los reintentos del preflight).
  if r.status = 'sending' and r.send_attempts >= 5 then
    update guide.newsletter_issues set send_lock_id = p_lock_id, send_locked_at = now() where id = r.id;
    update guide.newsletter_issues
    set status = 'failed', error_code = 'max_attempts', send_lock_id = null, send_locked_at = null, send_next_at = null
    where id = r.id;
    perform set_config('guide.newsletter_op', '', true);
    return jsonb_build_object('id', r.id, 'result', 'failed');
  end if;
  update guide.newsletter_issues
  set status = 'sending', send_lock_id = p_lock_id, send_locked_at = now(), send_next_at = null,
      send_attempts = r.send_attempts + 1,
      brevo_campaign_ids = case when r.brevo_campaign_ids ? 'es' and r.brevo_campaign_ids ? 'en' then r.brevo_campaign_ids
                                else c_init end
  where id = r.id
  returning * into r;
  perform set_config('guide.newsletter_op', '', true);

  select coalesce(jsonb_agg(x.j order by x.pos), '[]'::jsonb) into v_items
  from (
    select it.position as pos,
           case it.kind
             when 'article' then (
               select jsonb_build_object('kind', 'article', 'blurb_es', it.blurb_es, 'blurb_en', it.blurb_en,
                        'title_es', a.title_es, 'title_en', case when a.has_en then a.title_en end,
                        'excerpt_es', a.excerpt_es, 'excerpt_en', case when a.has_en then a.excerpt_en end,
                        'path_es', '/blog/' || a.slug_es::text,
                        'path_en', case when a.has_en and a.slug_en is not null then '/en/blog/' || a.slug_en::text end)
               from guide.articles a where a.id = it.ref_id and guide.article_is_live(a.status, a.published_at))
             when 'news' then (
               select jsonb_build_object('kind', 'news', 'blurb_es', it.blurb_es, 'blurb_en', it.blurb_en,
                        'title_es', n.title_es, 'title_en', case when n.has_en then n.title_en end,
                        'excerpt_es', n.summary_es, 'excerpt_en', case when n.has_en then n.summary_en end,
                        'path_es', '/noticias/' || n.slug, 'path_en', '/en/news/' || n.slug,
                        'source_name', n.source_name, 'source_url', n.source_url)
               from guide.news n where n.id = it.ref_id and n.status = 'published')
             else (
               select jsonb_build_object('kind', 'event', 'blurb_es', it.blurb_es, 'blurb_en', it.blurb_en,
                        'title_es', e.title_es, 'title_en', case when e.has_en then e.title_en end,
                        'starts_at', e.starts_at, 'ends_at', e.ends_at, 'all_day', e.all_day,
                        'location', e.location_text, 'path_es', '/agenda', 'path_en', '/en/events')
               from guide.events e where e.id = it.ref_id and e.status = 'approved'
                 and coalesce(e.ends_at, e.starts_at) >= now())
           end as j
    from guide.newsletter_issue_items it
    where it.issue_id = r.id
  ) x
  where x.j is not null;

  return jsonb_build_object(
    'id', r.id, 'result', 'claimed', 'week_start', r.week_start, 'scheduled_for', r.scheduled_for, 'attempts', r.send_attempts,
    'has_en', r.has_en, 'state', r.brevo_campaign_ids,
    'subject_es', r.subject_es, 'subject_en', r.subject_en, 'preheader_es', r.preheader_es, 'preheader_en', r.preheader_en,
    'intro_es', r.intro_es, 'intro_en', r.intro_en, 'items', v_items,
    'active_es', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'es'),
    'active_en', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'en'),
    'sent_today', guide.newsletter_sent_today());
end;
$$;

-- L3/B24/L10: datos del preflight de un idioma (solo en memoria de la EF): activos de ese idioma y trabajos de
-- sincronización sin cerrar. Lock obligatorio.
create or replace function guide.svc_newsletter_audience(p_id uuid, p_lock_id uuid, p_locale guide.locale)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r guide.newsletter_issues;
begin
  perform guide.svc_assert();
  r := guide.newsletter_send_locked(p_id, p_lock_id);
  if p_locale is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'open_sync', (select count(*) from guide.email_outbox o
                  where o.kind in ('brevo_sync', 'brevo_delete') and o.status in ('pending', 'processing')),
    'failed_sync', (select count(*) from guide.email_outbox o where o.kind = 'brevo_sync' and o.status = 'failed'),
    'failed_deletes', (select count(*) from guide.email_outbox o where o.kind = 'brevo_delete' and o.status = 'failed'),
    'audience', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'email', s.email, 'contact_id', s.brevo_contact_id)
                                           order by s.id)
                          from guide.subscribers s where s.status = 'active' and s.locale = p_locale), '[]'::jsonb));
end;
$$;

-- Estado por idioma. p_state: created | sent | skipped_empty | deferred_quota | failed | retry.
create or replace function guide.svc_newsletter_record(p_id uuid, p_lock_id uuid, p_locale guide.locale, p_campaign_id bigint,
                                                       p_state text, p_count integer, p_error text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r        guide.newsletter_issues;
  v_loc    text := p_locale::text;
  v_cur    jsonb;
  v_new    jsonb;
  v_ids    jsonb;
  v_since  timestamptz;
  v_tomorrow timestamptz := (date_trunc('day', now() at time zone 'Europe/Madrid') + interval '1 day 9 hours') at time zone 'Europe/Madrid';
  v_result text;
begin
  perform guide.svc_assert();
  r := guide.newsletter_send_locked(p_id, p_lock_id);
  if p_locale is null or p_state is null
     or p_state not in ('created', 'sent', 'skipped_empty', 'deferred_quota', 'failed', 'retry')
     or (p_error is not null and p_error not in ('sync_mismatch', 'quota_exceeded', 'quota_unknown', 'brevo_error', 'config',
                                                 'not_allowed_test', 'delete_failed', 'max_attempts'))
     or (p_state in ('failed', 'retry') and p_error is null)
     or (p_state in ('created', 'sent') and (p_campaign_id is null or p_campaign_id <= 0))
     or (p_count is not null and (p_count < 0 or p_count > 100000)) then
    raise exception 'invalid argument' using errcode = '22023';
  end if;

  v_cur := coalesce(r.brevo_campaign_ids -> v_loc, '{"id": null, "state": "pending", "count": 0}'::jsonb);
  if v_cur ->> 'state' in ('sent', 'skipped_empty') then
    raise exception 'newsletter locale already closed' using errcode = '55000';
  end if;
  v_since := coalesce((v_cur ->> 'retry_since')::timestamptz, now());
  v_new := jsonb_strip_nulls(jsonb_build_object(
    'id', coalesce(p_campaign_id, (v_cur ->> 'id')::bigint),
    'state', case when p_state = 'retry' then coalesce(v_cur ->> 'state', 'pending') else p_state end,
    'count', coalesce(p_count, (v_cur ->> 'count')::integer, 0),
    'sent_at', case when p_state = 'sent' then now() end,
    'retry_since', case when p_state = 'retry' then v_since end,
    'error', case when p_state in ('failed', 'retry') then p_error end));
  -- Tras 30 min reintentando el preflight (o un error de Brevo), el idioma falla (§7.8.2).
  if p_state = 'retry' and v_since < now() - interval '30 minutes' then
    v_new := jsonb_set(v_new - 'retry_since', '{state}', '"failed"');
  end if;
  v_ids := jsonb_set(coalesce(r.brevo_campaign_ids, '{}'::jsonb), array[v_loc], v_new);

  perform set_config('guide.newsletter_op', 'send:' || r.id::text || ':' || p_lock_id::text, true);
  if (v_ids -> 'es' ->> 'state') in ('sent', 'skipped_empty') and (v_ids -> 'en' ->> 'state') in ('sent', 'skipped_empty') then
    update guide.newsletter_issues
    set status = 'sent', sent_at = now(), error_code = null, brevo_campaign_ids = v_ids,
        sent_counts = jsonb_build_object('es', coalesce((v_ids -> 'es' ->> 'count')::integer, 0),
                                         'en', coalesce((v_ids -> 'en' ->> 'count')::integer, 0)),
        send_lock_id = null, send_locked_at = null, send_next_at = null
    where id = r.id;
    v_result := 'sent';
  elsif (v_ids -> 'es' ->> 'state') = 'failed' or (v_ids -> 'en' ->> 'state') = 'failed' then
    update guide.newsletter_issues
    set status = 'failed', error_code = coalesce(v_new ->> 'error', p_error, 'brevo_error'), brevo_campaign_ids = v_ids,
        sent_counts = jsonb_build_object(
          'es', case when (v_ids -> 'es' ->> 'state') = 'sent' then coalesce((v_ids -> 'es' ->> 'count')::integer, 0) else 0 end,
          'en', case when (v_ids -> 'en' ->> 'state') = 'sent' then coalesce((v_ids -> 'en' ->> 'count')::integer, 0) else 0 end),
        send_lock_id = null, send_locked_at = null, send_next_at = null
    where id = r.id;
    v_result := 'failed';
  elsif p_state = 'deferred_quota' then
    update guide.newsletter_issues
    set brevo_campaign_ids = v_ids, send_lock_id = null, send_locked_at = null, send_next_at = v_tomorrow, send_attempts = 0
    where id = r.id;
    v_result := 'deferred';
  elsif p_state = 'retry' then
    update guide.newsletter_issues
    set brevo_campaign_ids = v_ids, send_lock_id = null, send_locked_at = null, send_next_at = now() + interval '10 minutes'
    where id = r.id;
    v_result := 'retry';
  else
    update guide.newsletter_issues set brevo_campaign_ids = v_ids, send_locked_at = now() where id = r.id;
    v_result := 'recorded';
  end if;
  perform set_config('guide.newsletter_op', '', true);
  return jsonb_build_object('result', v_result, 'state', v_ids);
end;
$$;

-- Fin de una pasada sin cambios de estado (p. ej. idioma aplazado hasta mañana): suelta el lock.
create or replace function guide.svc_newsletter_release(p_id uuid, p_lock_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r      guide.newsletter_issues;
  v_next timestamptz;
begin
  perform guide.svc_assert();
  r := guide.newsletter_send_locked(p_id, p_lock_id);
  -- Si un idioma está aplazado por cupo, la edición no vuelve hasta mañana; si no, al siguiente tick.
  v_next := case when (r.brevo_campaign_ids -> 'es' ->> 'state') = 'deferred_quota'
                      or (r.brevo_campaign_ids -> 'en' ->> 'state') = 'deferred_quota'
                 then greatest(coalesce(r.send_next_at, now()),
                               (date_trunc('day', now() at time zone 'Europe/Madrid') + interval '1 day 9 hours') at time zone 'Europe/Madrid')
                 else now() + interval '10 minutes' end;
  perform set_config('guide.newsletter_op', 'send:' || r.id::text || ':' || p_lock_id::text, true);
  update guide.newsletter_issues set send_lock_id = null, send_locked_at = null, send_next_at = v_next where id = r.id;
  perform set_config('guide.newsletter_op', '', true);
end;
$$;

-- Cron: solo llama a la EF si hay una edición vencida o una sending lista para seguir.
create or replace function guide.run_newsletter_send()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_secret text;
  v_id     bigint;
begin
  if not exists (select 1 from guide.newsletter_issues i
                 where (i.status = 'scheduled' and i.scheduled_for <= now())
                    or (i.status = 'sending' and coalesce(i.send_next_at, '-infinity'::timestamptz) <= now()
                        and (i.send_lock_id is null or i.send_locked_at < now() - interval '20 minutes'))) then
    return null;
  end if;
  select ds.decrypted_secret into v_secret from vault.decrypted_secrets ds where ds.name = 'newsletter_send_secret' limit 1;
  if v_secret is not null and char_length(v_secret) >= 32 then
    select net.http_post(
             url := 'https://eqtjlafxtrzbjazhhyin.supabase.co/functions/v1/newsletter-send',
             body := '{}'::jsonb,
             headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', v_secret),
             timeout_milliseconds := 120000)
      into v_id;
  end if;
  insert into guide.job_health (job, request_id) values ('newsletter-send', v_id)
  on conflict (job) do update set request_id = excluded.request_id;
  return v_id;
end;
$$;

do $$
declare
  f text;
begin
  foreach f in array array['guide.svc_newsletter_claim(uuid)', 'guide.svc_newsletter_audience(uuid, uuid, guide.locale)',
                           'guide.svc_newsletter_record(uuid, uuid, guide.locale, bigint, text, integer, text)',
                           'guide.svc_newsletter_release(uuid, uuid)'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
  execute 'revoke all on function guide.run_newsletter_send() from public, anon, authenticated, service_role';
  execute 'revoke all on function guide.newsletter_issues_before_write() from public, anon, authenticated, service_role';
  execute 'revoke all on function guide.newsletter_quota_today() from public, anon, authenticated, service_role';
  execute 'grant execute on function guide.newsletter_quota_today() to authenticated';
end $$;

select cron.schedule('guide-newsletter-send', '*/10 * * * *', $$select guide.run_newsletter_send()$$);
