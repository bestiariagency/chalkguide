-- F8 (8.5) · Guardas y registro: news_before_write (J21), newsletter (D77), ajuste de events (J18b, J27b, J36).
-- Las guardas no dependen del rol: validan también lo que escriba una función DEFINER (las ingest_*).
-- Ninguna lee ni escribe la GUC guide.draft_op salvo la exención atada a la fila «release_dedupe:<id>» (J18b),
-- que solo ponen las RPC de admin admin_release_*_dedupe. Idempotente.

-- ───────────── 1. Noticias: guarda de escritura ─────────────
create or replace function guide.news_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_admin   boolean := guide.is_admin();
  v_maint   boolean := guide.item_live_exempt(null);
  v_from    guide.news_status;
  v_release boolean := false;
  v_base    text;
begin
  if tg_op = 'DELETE' then
    if v_maint then
      return old;
    end if;
    if not v_admin then
      raise exception 'news_write_forbidden' using errcode = '42501';
    end if;
    if old.status = 'published' then
      raise exception 'news is live' using errcode = 'PT423', detail = 'delete', hint = 'Retire it first (reopen_news).';
    end if;
    -- Lo del agente no se borra: su dedupe_key evita que lo vuelva a proponer. Se rechaza.
    if old.source = 'agent' then
      raise exception 'news from agent' using errcode = 'PT423', detail = 'agent', hint = 'Reject it instead.';
    end if;
    return old;
  end if;

  new.title_es       := btrim(new.title_es);
  new.title_en       := nullif(btrim(new.title_en), '');
  new.summary_es     := btrim(new.summary_es);
  new.summary_en     := nullif(btrim(new.summary_en), '');
  new.author_note_es := nullif(btrim(new.author_note_es), '');
  new.author_note_en := nullif(btrim(new.author_note_en), '');
  new.source_name    := btrim(new.source_name);
  new.source_url     := btrim(new.source_url);
  new.source_title   := nullif(btrim(new.source_title), '');
  new.image_credit   := nullif(btrim(new.image_credit), '');
  new.tags := coalesce(array(select distinct lower(btrim(t)) from unnest(new.tags) t
                             where t is not null and btrim(t) <> '' order by 1), '{}');

  if v_maint then
    if new.status = 'published' then
      new.published_at := coalesce(new.published_at, now());
      new.first_published_at := coalesce(new.first_published_at, new.published_at);
    else
      new.published_at := null;
    end if;
    if new.status <> 'rejected' then
      new.reject_reason := null;
    end if;
    return new;
  end if;

  if not v_admin then
    -- Agente (ingest_submit_news, DEFINER) o cualquier rol que salte RLS: solo INSERT de borradores propios.
    if tg_op <> 'INSERT' or new.status <> 'draft' or new.source <> 'agent'
       or new.published_at is not null or new.first_published_at is not null or new.approved_by is not null
       or new.author_note_es is not null or new.author_note_en is not null or new.reject_reason is not null
       or new.media_id is not null or new.image_license is not null or new.image_credit is not null then
      raise exception 'news_write_forbidden' using errcode = '42501';
    end if;
    new.id := gen_random_uuid();
    new.created_at := now();
    new.updated_at := now();
    new.slug := null;
  elsif tg_op = 'INSERT' then
    new.source := 'manual';
    new.dedupe_key := null;
    new.url_key := null;
    new.agent_meta := null;
    new.run_id := null;
    new.similarity := null;
    new.approved_by := null;
    new.first_published_at := null;
    if new.status not in ('draft', 'published') then
      raise exception 'news_invalid_transition' using errcode = '55000', detail = 'insert>' || new.status::text;
    end if;
  else
    v_from := old.status;
    new.created_at := old.created_at;
    new.first_published_at := old.first_published_at;
    new.approved_by := old.approved_by;
    new.similarity := old.similarity;
    if new.id is distinct from old.id then
      raise exception 'news_id_immutable' using errcode = '42501';
    end if;
    -- J18b: única excepción a la procedencia inmutable, atada a la fila y solo para rechazadas por datos incorrectos.
    v_release := coalesce(current_setting('guide.draft_op', true), '') = 'release_dedupe:' || old.id::text
                 and old.status = 'rejected' and old.reject_reason = 'wrong_data' and new.status = 'rejected'
                 and new.dedupe_key = 'released:' || old.id::text and new.url_key = 'released:' || old.id::text;
    if new.source is distinct from old.source or new.run_id is distinct from old.run_id
       or new.agent_meta is distinct from old.agent_meta
       or (not v_release and (new.dedupe_key is distinct from old.dedupe_key or new.url_key is distinct from old.url_key))
       or (old.source = 'agent' and new.source_url is distinct from old.source_url) then
      raise exception 'news_provenance_immutable' using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and (old.status::text || '>' || new.status::text) <> all (array[
             'draft>published', 'draft>rejected', 'published>draft', 'rejected>draft']) then
      raise exception 'news_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
    -- La URL se fija al publicar por primera vez.
    if old.first_published_at is not null and new.slug is distinct from old.slug then
      raise exception 'news_slug_fixed' using errcode = '55000';
    end if;
  end if;

  if new.slug is null then
    v_base := btrim(regexp_replace(lower(extensions.unaccent('extensions.unaccent'::regdictionary, new.title_es)),
                                   '[^a-z0-9]+', '-', 'g'), '-');
    v_base := btrim(left(v_base, 80), '-');
    new.slug := case when v_base = '' then 'noticia' else v_base end || '-' || left(replace(new.id::text, '-', ''), 6);
  end if;

  if v_admin then
    if new.status = 'published' then
      if v_from is distinct from 'published' then
        new.published_at := now();
        new.approved_by := (select auth.uid());
        new.first_published_at := coalesce(new.first_published_at, now());
      else
        new.published_at := old.published_at;
      end if;
    else
      new.published_at := null;
    end if;
    if new.status <> 'rejected' then
      new.reject_reason := null;
    end if;
    -- J27b (O5/D33-3): al salir de borrador, la evidencia del agente se reduce a la confianza.
    if tg_op = 'UPDATE' and old.source = 'agent' and old.status = 'draft' and new.status <> 'draft' then
      new.agent_meta := jsonb_build_object('confidence', old.agent_meta -> 'confidence');
    end if;
    if new.status = 'published' then
      if (new.title_en is null) <> (new.summary_en is null) then
        raise exception 'news_en_incomplete' using errcode = '23514';
      end if;
      if new.media_id is not null
         and guide.alt_is_missing((select m.alt_es from guide.media m where m.id = new.media_id)) then
        raise exception 'news_media_alt' using errcode = '23514';
      end if;
    end if;
  end if;

  -- Parecido resumen ↔ cita de la fuente (pg_trgm, 0–1). Solo informa; la UI avisa desde 0,35.
  if new.agent_meta ? 'excerpt' and (tg_op = 'INSERT' or new.summary_es is distinct from old.summary_es) then
    new.similarity := extensions.similarity(lower(new.summary_es), lower(new.agent_meta ->> 'excerpt'));
  end if;

  return new;
end;
$$;
revoke all on function guide.news_before_write() from public, anon, authenticated, service_role;

drop trigger if exists news_before_write on guide.news;
create trigger news_before_write
  before insert or update or delete on guide.news
  for each row execute function guide.news_before_write();

drop trigger if exists news_set_updated_at on guide.news;
create trigger news_set_updated_at before update on guide.news
  for each row execute function guide.set_updated_at();

-- ───────────── 2. Noticias: registro (J36: by = agent; nunca agent_meta, dedupe_key ni url_key) ─────────────
create or replace function guide.news_log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_skip    constant text[] := array['agent_meta', 'dedupe_key', 'url_key', 'search_es', 'search_en', 'updated_at', 'similarity'];
  v_admin   boolean := guide.is_admin();
  v_by      text;
  v_src     guide.event_source := case when tg_op = 'DELETE' then old.source else new.source end;
  v_new     jsonb;
  v_old     jsonb;
  v_changed text[];
  v_action  guide.activity_action := lower(tg_op)::guide.activity_action;
  v_det     jsonb;
begin
  v_by := case when v_admin then 'admin'
               when guide.item_live_exempt(null) then 'system'
               when v_src = 'agent' then 'agent'
               else 'system' end;
  if tg_op = 'UPDATE' then
    v_new := to_jsonb(new) - c_skip;
    v_old := to_jsonb(old) - c_skip;
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n where n.value is distinct from (v_old -> n.key);
    if v_changed is null then
      return null;
    end if;
    v_det := jsonb_build_object('by', v_by, 'source', new.source);
    if old.status is distinct from new.status then
      v_det := v_det || jsonb_build_object('from', old.status, 'to', new.status);
      if old.status = 'published' and new.status = 'draft' then
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
          'news',
          (case when tg_op = 'DELETE' then old.id else new.id end)::text,
          left(case when tg_op = 'DELETE' then old.title_es else new.title_es end, 200),
          v_changed,
          case when tg_op = 'DELETE' then to_jsonb(old) - c_skip end,
          v_det);
  return null;
end;
$$;
revoke all on function guide.news_log_activity() from public, anon, authenticated, service_role;

drop trigger if exists news_log_activity on guide.news;
create trigger news_log_activity
  after insert or update or delete on guide.news
  for each row execute function guide.news_log_activity();

-- ───────────── 3. Categorías, fuentes, config: updated_at y registro genérico ─────────────
drop trigger if exists news_categories_set_updated_at on guide.news_categories;
create trigger news_categories_set_updated_at before update on guide.news_categories
  for each row execute function guide.set_updated_at();
drop trigger if exists news_sources_set_updated_at on guide.news_sources;
create trigger news_sources_set_updated_at before update on guide.news_sources
  for each row execute function guide.set_updated_at();
drop trigger if exists ingest_config_set_updated_at on guide.ingest_config;
create trigger ingest_config_set_updated_at before update on guide.ingest_config
  for each row execute function guide.set_updated_at();

drop trigger if exists news_categories_log on guide.news_categories;
create trigger news_categories_log after insert or update or delete on guide.news_categories
  for each row execute function guide.log_activity('id', 'label_es');
drop trigger if exists news_sources_log on guide.news_sources;
create trigger news_sources_log after insert or update or delete on guide.news_sources
  for each row execute function guide.log_activity('id', 'name');

-- Fuentes: dominio siempre en minúsculas y sin espacios; textos recortados.
create or replace function guide.news_sources_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := btrim(new.name);
  new.domain := lower(btrim(new.domain));
  new.url := btrim(new.url);
  new.instructions := nullif(btrim(new.instructions), '');
  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;
revoke all on function guide.news_sources_before_write() from public, anon, authenticated, service_role;
drop trigger if exists news_sources_before_write on guide.news_sources;
create trigger news_sources_before_write before insert or update on guide.news_sources
  for each row execute function guide.news_sources_before_write();

-- ───────────── 4. Tokens: registro de alta y revocación (sin token_hash ni last_used_at; J36) ─────────────
create or replace function guide.ingest_tokens_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, details)
    values ((select auth.uid()), 'insert', 'ingest_tokens', new.id::text, left(new.label, 200),
            jsonb_build_object('by', 'admin', 'expires_at', new.expires_at));
  elsif old.revoked_at is null and new.revoked_at is not null then
    insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
    values ((select auth.uid()), 'update', 'ingest_tokens', new.id::text, left(new.label, 200), array['revoked_at'],
            jsonb_build_object('by', 'admin', 'to', 'revoked'));
  end if;
  return null;
end;
$$;
revoke all on function guide.ingest_tokens_log() from public, anon, authenticated, service_role;
drop trigger if exists ingest_tokens_log on guide.ingest_tokens;
create trigger ingest_tokens_log after insert or update on guide.ingest_tokens
  for each row execute function guide.ingest_tokens_log();

-- ───────────── 5. Newsletter: guarda de la carta (estados D75/D77) ─────────────
-- Admin: edita el contenido solo en borrador; transiciones draft>scheduled (aprobar: +1 h), scheduled>draft
-- (desprogramar, hasta 1 min antes de la hora), draft|scheduled>cancelled, cancelled>draft. sending/sent/failed
-- las pondrá la función de envío (8.13); el admin no sale de ellos.
-- Agente (ingest_submit_newsletter_intro, DEFINER): crea el borrador de la semana o rellena asunto, preheader e
-- intro de un borrador cuya intro no haya escrito Xavi.
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
    if old.intro_es is not null and not old.intro_by_agent then
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

  if (to_jsonb(new) -> 'subject_es', to_jsonb(new) -> 'subject_en', to_jsonb(new) -> 'preheader_es',
      to_jsonb(new) -> 'preheader_en', to_jsonb(new) -> 'intro_es', to_jsonb(new) -> 'intro_en')
     is distinct from
     (to_jsonb(old) -> 'subject_es', to_jsonb(old) -> 'subject_en', to_jsonb(old) -> 'preheader_es',
      to_jsonb(old) -> 'preheader_en', to_jsonb(old) -> 'intro_es', to_jsonb(old) -> 'intro_en') then
    -- D77: una carta programada no se edita; primero vuelve a borrador (unschedule_issue).
    if old.status <> 'draft' or new.status <> 'draft' then
      raise exception 'newsletter_not_draft' using errcode = '55000';
    end if;
    if new.intro_es is distinct from old.intro_es or new.intro_en is distinct from old.intro_en then
      new.intro_by_agent := false;
    end if;
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

drop trigger if exists newsletter_issues_before_write on guide.newsletter_issues;
create trigger newsletter_issues_before_write
  before insert or update or delete on guide.newsletter_issues
  for each row execute function guide.newsletter_issues_before_write();
drop trigger if exists newsletter_issues_set_updated_at on guide.newsletter_issues;
create trigger newsletter_issues_set_updated_at before update on guide.newsletter_issues
  for each row execute function guide.set_updated_at();
drop trigger if exists newsletter_issues_log on guide.newsletter_issues;
create trigger newsletter_issues_log after insert or update or delete on guide.newsletter_issues
  for each row execute function guide.log_activity('id', 'subject_es');

-- Ítems: solo en cartas en borrador y solo contenido público (noticia publicada, evento aprobado, artículo vivo).
create or replace function guide.newsletter_items_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_status guide.newsletter_status;
  v_issue  uuid := case when tg_op = 'DELETE' then old.issue_id else new.issue_id end;
begin
  if guide.item_live_exempt(null) then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  select i.status into v_status from guide.newsletter_issues i where i.id = v_issue;
  if tg_op = 'DELETE' then
    -- Borrado en cascada de una carta borrador/cancelada, o quitar un ítem de un borrador.
    if v_status is not null and v_status not in ('draft', 'cancelled') then
      raise exception 'newsletter_not_draft' using errcode = '55000';
    end if;
    return old;
  end if;
  if v_status is distinct from 'draft' then
    raise exception 'newsletter_not_draft' using errcode = '55000';
  end if;
  new.blurb_es := nullif(btrim(new.blurb_es), '');
  new.blurb_en := nullif(btrim(new.blurb_en), '');
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id or new.issue_id is distinct from old.issue_id or new.kind is distinct from old.kind
       or new.ref_id is distinct from old.ref_id then
      raise exception 'newsletter_item_immutable' using errcode = '42501';
    end if;
    new.created_at := old.created_at;
  else
    new.id := gen_random_uuid();
    new.created_at := now();
    new.updated_at := now();
    if not (case new.kind
              when 'news' then exists (select 1 from guide.news n where n.id = new.ref_id and n.status = 'published')
              when 'event' then exists (select 1 from guide.events e where e.id = new.ref_id and e.status = 'approved')
              else exists (select 1 from guide.articles a where a.id = new.ref_id
                           and guide.article_is_live(a.status, a.published_at))
            end) then
      raise exception 'newsletter_item_not_public' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function guide.newsletter_items_before_write() from public, anon, authenticated, service_role;

drop trigger if exists newsletter_items_before_write on guide.newsletter_issue_items;
create trigger newsletter_items_before_write
  before insert or update or delete on guide.newsletter_issue_items
  for each row execute function guide.newsletter_items_before_write();
drop trigger if exists newsletter_items_set_updated_at on guide.newsletter_issue_items;
create trigger newsletter_items_set_updated_at before update on guide.newsletter_issue_items
  for each row execute function guide.set_updated_at();

-- ───────────── 6. Events: J18b (liberar clave), J27b (reducir agent_meta) ─────────────
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
    if new.source is distinct from old.source
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

-- J36: by = 'agent' cuando no es admin ni mantenimiento y la fila es del agente (antes salía 'system' con anon).
create or replace function guide.events_log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_skip    constant text[] := array['agent_meta', 'dedupe_key', 'updated_at'];
  v_admin   boolean := guide.is_admin();
  v_by      text;
  v_src     guide.event_source := case when tg_op = 'DELETE' then old.source else new.source end;
  v_new     jsonb;
  v_old     jsonb;
  v_changed text[];
  v_action  guide.activity_action := lower(tg_op)::guide.activity_action;
  v_det     jsonb;
begin
  v_by := case when v_admin then 'admin'
               when guide.item_live_exempt(null) then 'system'
               when v_src = 'agent' then 'agent'
               else 'system' end;
  if tg_op = 'UPDATE' then
    v_new := to_jsonb(new) - c_skip;
    v_old := to_jsonb(old) - c_skip;
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
          case when tg_op = 'DELETE' then to_jsonb(old) - c_skip end,
          v_det);
  return null;
end;
$$;
revoke all on function guide.events_log_activity() from public, anon, authenticated, service_role;
