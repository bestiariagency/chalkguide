-- F8.18c · Vídeos de YouTube en noticias (D84, D88; spec docs/security/F8.18-videos-spec.md V1–V16).
-- D88 manda sobre la spec: tabla hija guide.news_videos (hasta 2 por noticia, en orden) con youtube_id, title,
-- channel y lang. title y channel son públicos con la noticia publicada (la «columna aparte» de V10), con CHECK puros
-- J13/J14. Sin red (V9): ni oEmbed ni duración. La procedencia (qué IDs propuso la rutina) va solo en
-- news.agent_meta.videos (privado, J27; J27b la borra al salir de borrador).
-- Idempotente.

-- ── V3: normalizador interno (sin EXECUTE para la API) ──
create or replace function guide.youtube_video_id(p text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  c_id   constant text := '^[A-Za-z0-9_-]{11}$';
  v      text;
  m      text[];
  v_host text;
  v_path text;
  v_ids  text[];
begin
  if p is null or char_length(p) > 200 then
    return null;
  end if;
  v := btrim(p);
  if v ~ c_id then
    return v;
  end if;
  -- Solo ASCII imprimible: fuera espacios, controles, bidi, zero-width y homógrafos.
  if v !~ '^[!-~]+$' then
    return null;
  end if;
  m := regexp_match(v, '^https://([^/?#]+)(/[^?#]*)?(\?[^#]*)?(#.*)?$');
  if m is null then
    return null;
  end if;
  -- Host exacto: con userinfo (@), puerto (:) o cualquier otro host no coincide.
  v_host := lower(m[1]);
  v_path := coalesce(m[2], '');
  if v_host in ('youtube.com', 'www.youtube.com', 'm.youtube.com') then
    if v_path = '/watch' then
      select array_agg(substr(kv, 3)) into v_ids
      from unnest(string_to_array(coalesce(substr(m[3], 2), ''), '&')) kv
      where left(kv, 2) = 'v=';
      if cardinality(v_ids) = 1 and v_ids[1] ~ c_id then
        return v_ids[1];
      end if;
      return null;
    end if;
    return (regexp_match(v_path, '^/shorts/([A-Za-z0-9_-]{11})/?$'))[1];
  elsif v_host = 'youtu.be' then
    return (regexp_match(v_path, '^/([A-Za-z0-9_-]{11})/?$'))[1];
  end if;
  return null;
end;
$$;

revoke all on function guide.youtube_video_id(text) from public, anon, authenticated, service_role;

-- ── V1/V2 (adaptados a tabla hija): solo el ID, CHECK puros, máximo 2 por noticia ──
create table if not exists guide.news_videos (
  news_id    uuid        not null references guide.news (id) on delete cascade,
  position   smallint    not null,
  youtube_id text        not null,
  title      text,
  channel    text,
  lang       text,
  created_at timestamptz not null default now(),
  constraint news_videos_pkey primary key (news_id, position),
  constraint news_videos_position_check check (position between 1 and 2),
  constraint news_videos_youtube_id_check check (youtube_id ~ '^[A-Za-z0-9_-]{11}$'),
  constraint news_videos_unique_id unique (news_id, youtube_id),
  constraint news_videos_title_check check (
    title is null or (
      char_length(title) between 1 and 200
      and title = btrim(title)
      and title !~ '[\u0001-\u001F\u007F-\u009F]'
      and title !~ U&'[\061C\200B-\200F\202A-\202E\2060\2066-\2069\FEFF]'
      and title is nfc normalized)),
  constraint news_videos_channel_check check (
    channel is null or (
      char_length(channel) between 1 and 120
      and channel = btrim(channel)
      and channel !~ '[\u0001-\u001F\u007F-\u009F]'
      and channel !~ U&'[\061C\200B-\200F\202A-\202E\2060\2066-\2069\FEFF]'
      and channel is nfc normalized)),
  constraint news_videos_lang_check check (lang is null or lang ~ '^[a-z]{2}$')
);

comment on table guide.news_videos is
  'F8.18 (D84/D88): hasta 2 vídeos de YouTube por noticia. Solo el ID; title/channel en texto plano, públicos con la noticia publicada. Escritura: ingest_submit_news (borrador del agente) y admin_set_news_videos.';

-- ── Guarda (no depende del rol: también valida a las DEFINER) ──
create or replace function guide.news_videos_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_admin boolean := guide.is_admin();
  v_maint boolean := guide.item_live_exempt(null);
  v_news  guide.news;
begin
  if tg_op = 'DELETE' then
    if v_admin or v_maint then
      return old;
    end if;
    raise exception 'news_video_write_forbidden' using errcode = '42501';
  end if;

  new.title   := nullif(btrim(normalize(new.title, NFC)), '');
  new.channel := nullif(btrim(normalize(new.channel, NFC)), '');
  new.lang    := nullif(lower(btrim(new.lang)), '');
  if tg_op = 'UPDATE' then
    if new.news_id is distinct from old.news_id then
      raise exception 'news_video_write_forbidden' using errcode = '42501';
    end if;
    new.created_at := old.created_at;
  else
    new.created_at := now();
  end if;

  select n.* into v_news from guide.news n where n.id = new.news_id;
  if not v_admin and not v_maint then
    -- Agente (ingest_submit_news, DEFINER): solo INSERT en el borrador que acaba de crear en esta transacción.
    if tg_op <> 'INSERT' or v_news.id is null or v_news.source <> 'agent' or v_news.status <> 'draft'
       or v_news.created_at <> now() then
      raise exception 'news_video_write_forbidden' using errcode = '42501';
    end if;
  end if;
  -- Lo público lleva crédito completo.
  if v_news.status = 'published' and (new.title is null or new.channel is null) then
    raise exception 'news_video_meta' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function guide.news_videos_before_write() from public, anon, authenticated, service_role;

drop trigger if exists news_videos_before_write on guide.news_videos;
create trigger news_videos_before_write
  before insert or update or delete on guide.news_videos
  for each row execute function guide.news_videos_before_write();

-- ── V5 (adaptado): RLS heredada de la noticia; SELECT por columna; sin escritura directa ──
alter table guide.news_videos enable row level security;

revoke all on table guide.news_videos from public, anon, authenticated, service_role;
grant select (news_id, position, youtube_id, title, channel, lang) on guide.news_videos to anon, authenticated;

drop policy if exists news_videos_select on guide.news_videos;
create policy news_videos_select on guide.news_videos
  for select to anon, authenticated
  using ((select guide.is_admin())
         or exists (select 1 from guide.news n where n.id = news_videos.news_id and n.status = 'published'));

-- Sin grants de escritura: el admin escribe con admin_set_news_videos. Policies explícitas por defensa en profundidad.
drop policy if exists news_videos_insert on guide.news_videos;
create policy news_videos_insert on guide.news_videos
  for insert to authenticated with check ((select guide.is_admin()));
drop policy if exists news_videos_update on guide.news_videos;
create policy news_videos_update on guide.news_videos
  for update to authenticated using ((select guide.is_admin())) with check ((select guide.is_admin()));
drop policy if exists news_videos_delete on guide.news_videos;
create policy news_videos_delete on guide.news_videos
  for delete to authenticated using ((select guide.is_admin()));

-- ── V10 (adaptado): agent_meta.videos = IDs que propuso la rutina (procedencia; privado) ──
alter table guide.news drop constraint if exists news_agent_meta_shape;
alter table guide.news add constraint news_agent_meta_shape check (
  agent_meta is null or (
    jsonb_typeof(agent_meta) = 'object'
    and octet_length(agent_meta::text) <= 4000
    and (agent_meta - array['confidence', 'note', 'excerpt', 'found_at', 'inferred', 'duplicate_of', 'videos']) = '{}'::jsonb
    and case when jsonb_typeof(agent_meta -> 'confidence') = 'number'
             then (agent_meta ->> 'confidence')::numeric between 0 and 1
             else false end
    and (not (agent_meta ? 'note')
         or (jsonb_typeof(agent_meta -> 'note') = 'string' and char_length(agent_meta ->> 'note') <= 500))
    and (not (agent_meta ? 'excerpt')
         or (jsonb_typeof(agent_meta -> 'excerpt') = 'string' and char_length(agent_meta ->> 'excerpt') <= 1000))
    and (not (agent_meta ? 'found_at')
         or (jsonb_typeof(agent_meta -> 'found_at') = 'string'
             and (agent_meta ->> 'found_at') ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}'))
    and (not (agent_meta ? 'inferred')
         or (jsonb_typeof(agent_meta -> 'inferred') = 'array'
             and jsonb_array_length(agent_meta -> 'inferred') <= 10
             and (agent_meta -> 'inferred') <@ '["title_en", "summary_en", "category", "published_on", "source_name"]'::jsonb))
    and (not (agent_meta ? 'duplicate_of')
         or jsonb_typeof(agent_meta -> 'duplicate_of') = 'null'
         or (jsonb_typeof(agent_meta -> 'duplicate_of') = 'string'
             and (agent_meta ->> 'duplicate_of') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'))
    and (not (agent_meta ? 'videos')
         or (jsonb_typeof(agent_meta -> 'videos') = 'array'
             and (agent_meta -> 'videos')::text ~ '^\[("[A-Za-z0-9_-]{11}"(, "[A-Za-z0-9_-]{11}")?)?\]$'))));

-- ── news_before_write: publicar exige título y canal en cada vídeo (resto idéntico) ──
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
    -- F8.18 V11: con ella desaparece agent_meta.videos; los vídeos (news_videos) se quedan.
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
      -- F8.18 (D88): el crédito del vídeo (título y canal) es público; sin él no se publica.
      if exists (select 1 from guide.news_videos v
                 where v.news_id = new.id and (v.title is null or v.channel is null)) then
        raise exception 'news_video_meta' using errcode = '23514';
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

-- ── V4/V8/V11–V14: ingesta con clave opcional `videos` ──
create or replace function guide.ingest_submit_news(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_keys    constant text[] := array['title_es', 'title_en', 'summary_es', 'summary_en', 'category',
                                     'published_on_source', 'source_url', 'source_name', 'confidence', 'note', 'excerpt',
                                     'videos'];
  c_vkeys   constant text[] := array['url', 'title', 'channel', 'lang'];
  c_reasons constant text[] := array['not_object', 'too_large', 'unknown_key', 'secret', 'missing_field', 'invalid_type',
                                     'bad_chars', 'too_long', 'bad_url', 'shortener', 'pii', 'invalid_date', 'stale',
                                     'category', 'source', 'confidence', 'video', 'constraint'];
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
  v_news_id  uuid;
  v_el       jsonb;
  v_vid      text;
  v_vtitle   text;
  v_vchan    text;
  v_vlang    text;
  v_vids     text[] := '{}';
  v_vtitles  text[] := '{}';
  v_vchans   text[] := '{}';
  v_vlangs   text[] := '{}';
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
    -- J17 sobre el payload entero (vídeos incluidos).
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

    -- F8.18 V4/V8: videos = array de 0–2 objetos {url, title?, channel?, lang?}; un vídeo malo invalida la fila.
    if jsonb_typeof(p_payload -> 'videos') is distinct from 'null' and p_payload ? 'videos' then
      if jsonb_typeof(p_payload -> 'videos') <> 'array' or jsonb_array_length(p_payload -> 'videos') > 2 then
        raise exception 'video' using detail = 'videos';
      end if;
      for v_el in select t.e from jsonb_array_elements(p_payload -> 'videos') with ordinality t(e, o) order by t.o loop
        if jsonb_typeof(v_el) <> 'object'
           or exists (select 1 from jsonb_object_keys(v_el) k where k <> all (c_vkeys))
           or jsonb_typeof(v_el -> 'url') is distinct from 'string'
           or exists (select 1 from unnest(array['title', 'channel', 'lang']) k
                      where v_el ? k and jsonb_typeof(v_el -> k) not in ('string', 'null')) then
          raise exception 'video' using detail = 'videos';
        end if;
        v_vid := guide.youtube_video_id(v_el ->> 'url');
        if v_vid is null or v_vid = any (v_vids) then
          raise exception 'video' using detail = 'videos';
        end if;
        begin
          v_vtitle := guide.ingest_field_text(v_el, 'title', 200, false, false);
          v_vchan  := guide.ingest_field_text(v_el, 'channel', 120, false, false);
          v_vlang  := lower(guide.ingest_field_text(v_el, 'lang', 2, false, false));
        exception when raise_exception then
          get stacked diagnostics v_reason = message_text;
          raise exception '%', v_reason using detail = 'videos';
        end;
        if v_vlang is not null and v_vlang !~ '^[a-z]{2}$' then
          raise exception 'video' using detail = 'videos';
        end if;
        v_vids    := array_append(v_vids, v_vid);
        v_vtitles := array_append(v_vtitles, v_vtitle);
        v_vchans  := array_append(v_vchans, v_vchan);
        v_vlangs  := array_append(v_vlangs, v_vlang);
      end loop;
    end if;

    if guide.ingest_has_pii(concat_ws(E'\n|\n', v_title_es, v_title_en, v_sum_es, v_sum_en, v_name, v_note, v_excerpt,
                                      array_to_string(v_vtitles, E'\n|\n'), array_to_string(v_vchans, E'\n|\n'))) then
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
  -- V12: los vídeos no entran en la clave.
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
              'found_at', to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
              'videos', case when cardinality(v_vids) > 0 then to_jsonb(v_vids) end)))
    returning id into v_news_id;
    -- Título y canal del agente: propuesta en borrador (no pública hasta aprobar), editable por el admin.
    insert into guide.news_videos (news_id, position, youtube_id, title, channel, lang)
    select v_news_id, o::smallint, v_vids[o], v_vtitles[o], v_vchans[o], v_vlangs[o]
    from generate_subscripts(v_vids, 1) o;
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

revoke all on function guide.ingest_submit_news(text, uuid, jsonb) from public, authenticated, service_role;
grant execute on function guide.ingest_submit_news(text, uuid, jsonb) to anon;

-- ── V6: admin_list_news devuelve los vídeos (cambia el tipo de retorno: drop + create) ──
drop function if exists guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer);
create function guide.admin_list_news(
  p_status guide.news_status default null, p_category_id uuid default null, p_scope guide.news_scope default null,
  p_source_id uuid default null, p_run_id uuid default null, p_query text default null, p_id uuid default null,
  p_limit integer default 50, p_offset integer default 0)
returns table(id uuid, slug text, status guide.news_status, source guide.event_source, title_es text, title_en text,
              summary_es text, summary_en text, author_note_es text, author_note_en text, category_id uuid,
              category_key text, scope guide.news_scope, tags text[], source_name text, source_url text,
              source_title text, source_published_on date, source_lang text, source_id uuid, source_trusted boolean,
              source_approval_rate numeric, media_id uuid, image_license text, image_credit text, run_id uuid,
              agent_meta jsonb, similarity real, warnings text[], reject_reason text, indexable boolean,
              indexable_en boolean, has_en boolean, published_at timestamptz, first_published_at timestamptz,
              created_at timestamptz, updated_at timestamptz, videos jsonb, total_count bigint)
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
         coalesce((select jsonb_agg(jsonb_build_object('position', v.position, 'youtube_id', v.youtube_id,
                                                       'title', v.title, 'channel', v.channel, 'lang', v.lang)
                                    order by v.position)
                   from guide.news_videos v where v.news_id = n.id), '[]'::jsonb),
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

revoke all on function guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)
  from public, anon, service_role;
grant execute on function guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)
  to authenticated;

-- ── Escritura del admin: reemplaza los ≤ 2 vídeos de una noticia de forma atómica ──
create or replace function guide.admin_set_news_videos(p_news_id uuid, p_videos jsonb)
returns table(news_id uuid, "position" smallint, youtube_id text, title text, channel text, lang text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  c_vkeys  constant text[] := array['youtube_id', 'title', 'channel', 'lang'];
  v_status guide.news_status;
  v_label  text;
  v_el     jsonb;
  v_i      bigint;
  v_id     text;
  v_t      text;
  v_c      text;
  v_l      text;
  v_ids    text[] := '{}';
  v_ts     text[] := '{}';
  v_cs     text[] := '{}';
  v_ls     text[] := '{}';
  v_old    jsonb;
  v_new    jsonb;
begin
  perform guide.assert_admin();
  select n.status, n.title_es into v_status, v_label from guide.news n where n.id = p_news_id for update;
  if not found then
    raise exception 'news not found' using errcode = 'P0002';
  end if;
  p_videos := coalesce(p_videos, '[]'::jsonb);
  if jsonb_typeof(p_videos) <> 'array' or jsonb_array_length(p_videos) > 2 then
    raise exception 'invalid videos' using errcode = '22023', detail = 'videos';
  end if;

  for v_el, v_i in select t.e, t.o from jsonb_array_elements(p_videos) with ordinality t(e, o) order by t.o loop
    if jsonb_typeof(v_el) <> 'object'
       or exists (select 1 from jsonb_object_keys(v_el) k where k <> all (c_vkeys))
       or jsonb_typeof(v_el -> 'youtube_id') is distinct from 'string'
       or exists (select 1 from unnest(array['title', 'channel', 'lang']) k
                  where v_el ? k and jsonb_typeof(v_el -> k) not in ('string', 'null')) then
      raise exception 'invalid video' using errcode = '22023', detail = 'videos[' || v_i || ']';
    end if;
    v_id := guide.youtube_video_id(v_el ->> 'youtube_id');
    if v_id is null then
      raise exception 'invalid youtube id' using errcode = '22023', detail = 'videos[' || v_i || '].youtube_id';
    end if;
    if v_id = any (v_ids) then
      raise exception 'duplicate video' using errcode = '22023', detail = 'videos[' || v_i || '].youtube_id';
    end if;
    v_t := nullif(btrim(normalize(v_el ->> 'title', NFC)), '');
    v_c := nullif(btrim(normalize(v_el ->> 'channel', NFC)), '');
    v_l := nullif(lower(btrim(v_el ->> 'lang')), '');
    if char_length(v_t) > 200 then
      raise exception 'title too long' using errcode = '22023', detail = 'videos[' || v_i || '].title';
    end if;
    if char_length(v_c) > 120 then
      raise exception 'channel too long' using errcode = '22023', detail = 'videos[' || v_i || '].channel';
    end if;
    if v_l is not null and v_l !~ '^[a-z]{2}$' then
      raise exception 'invalid lang' using errcode = '22023', detail = 'videos[' || v_i || '].lang';
    end if;
    v_ids := array_append(v_ids, v_id);
    v_ts  := array_append(v_ts, v_t);
    v_cs  := array_append(v_cs, v_c);
    v_ls  := array_append(v_ls, v_l);
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object('youtube_id', v.youtube_id, 'title', v.title, 'channel', v.channel,
                                               'lang', v.lang) order by v.position), '[]'::jsonb)
  into v_old from guide.news_videos v where v.news_id = p_news_id;

  delete from guide.news_videos v where v.news_id = p_news_id;
  -- La guarda exige título y canal si la noticia está publicada (23514 news_video_meta); los CHECK, el texto limpio.
  insert into guide.news_videos (news_id, position, youtube_id, title, channel, lang)
  select p_news_id, o::smallint, v_ids[o], v_ts[o], v_cs[o], v_ls[o]
  from generate_subscripts(v_ids, 1) o;

  select coalesce(jsonb_agg(jsonb_build_object('youtube_id', v.youtube_id, 'title', v.title, 'channel', v.channel,
                                               'lang', v.lang) order by v.position), '[]'::jsonb)
  into v_new from guide.news_videos v where v.news_id = p_news_id;

  -- V7: registro como un campo más de la noticia, sin agent_meta.
  if v_new is distinct from v_old then
    insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row, details)
    values ((select auth.uid()), 'update', 'news', p_news_id::text, left(v_label, 200), array['videos'],
            jsonb_build_object('videos', v_old),
            jsonb_build_object('by', 'admin', 'status', v_status, 'videos', v_new));
  end if;

  return query
  select v.news_id, v.position, v.youtube_id, v.title, v.channel, v.lang
  from guide.news_videos v where v.news_id = p_news_id order by v.position;
end;
$$;

revoke all on function guide.admin_set_news_videos(uuid, jsonb) from public, anon, service_role;
grant execute on function guide.admin_set_news_videos(uuid, jsonb) to authenticated;
