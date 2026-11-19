-- F8.20b · Aporte propio en cada noticia (D91, D92; spec docs/marketing/noticias-seo-spec.md §19.7).
-- 1. author_note_es/en pasan a insight_es/en (rename: se conservan datos y grants). Texto plano ≤ 1.400 caracteres,
--    CHECK puros J13/J14 (controles salvo saltos, C1, bidi, zero-width, U+2028/2029) y NFC. La guarda normaliza
--    (NFC + btrim) antes del CHECK.
-- 2. Columnas nuevas: seo_keyword_es/en (2–60, interna: sin SELECT para anon ni authenticated; el panel la lee por
--    admin_list_news) y meta_description_es/en (≤ 160, pública, override que solo escribe Xavi).
-- 3. indexable / indexable_en = publicada + aporte del idioma con ≥ 80 palabras (D92, sin exigir enlace interno).
--    search_es/en: el aporte entra con peso C.
-- 4. search_news: has_note → has_insight. admin_list_news: insight_*, seo_keyword_*, meta_description_*.
--    admin_search: has_insight y búsqueda en insight_es/en.
-- 5. Ingesta (J11 ampliada): ingest_submit_news acepta insight_es/en y seo_keyword_es/en con J12–J17. Siguen fuera
--    (unknown_key) author_note_* y meta_description_*. La guarda news_before_write (J21) deja al agente escribir el
--    aporte y la keyword en su borrador, nunca meta_description_*.
-- newsletter_compose e ingest_newsletter_context no leen la nota: sin cambios. news_log_activity es genérico
-- (to_jsonb): registra los campos nuevos sin cambios. Sin tocar public (J40). Idempotente.

-- ── 1. Rename (conserva datos, grants por columna y dependencias) ──
do $$
begin
  if exists (select 1 from pg_attribute where attrelid = 'guide.news'::regclass and attname = 'author_note_es' and not attisdropped) then
    alter table guide.news rename column author_note_es to insight_es;
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'guide.news'::regclass and attname = 'author_note_en' and not attisdropped) then
    alter table guide.news rename column author_note_en to insight_en;
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'guide.export_news'::regclass and attname = 'author_note_es') then
    alter view guide.export_news rename column author_note_es to insight_es;
  end if;
  if exists (select 1 from pg_attribute where attrelid = 'guide.export_news'::regclass and attname = 'author_note_en') then
    alter view guide.export_news rename column author_note_en to insight_en;
  end if;
end $$;

-- ── 2. Columnas nuevas ──
alter table guide.news
  add column if not exists seo_keyword_es text,
  add column if not exists seo_keyword_en text,
  add column if not exists meta_description_es text,
  add column if not exists meta_description_en text;

-- ── CHECK puros (J13/J14 + NFC) ──
alter table guide.news
  drop constraint if exists news_author_note_es_check,
  drop constraint if exists news_author_note_en_check,
  drop constraint if exists news_insight_es_check,
  drop constraint if exists news_insight_en_check,
  drop constraint if exists news_seo_keyword_es_check,
  drop constraint if exists news_seo_keyword_en_check,
  drop constraint if exists news_meta_description_es_check,
  drop constraint if exists news_meta_description_en_check;

alter table guide.news
  add constraint news_insight_es_check check (
    char_length(insight_es) between 1 and 1400
    and insight_es !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]'
    and insight_es !~ U&'[\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and insight_es is nfc normalized),
  add constraint news_insight_en_check check (
    char_length(insight_en) between 1 and 1400
    and insight_en !~ '[\u0001-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]'
    and insight_en !~ U&'[\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and insight_en is nfc normalized),
  add constraint news_seo_keyword_es_check check (
    char_length(seo_keyword_es) between 2 and 60
    and seo_keyword_es = btrim(seo_keyword_es)
    and seo_keyword_es !~ '[\u0001-\u001F\u007F-\u009F]'
    and seo_keyword_es !~ U&'[\00AD\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and seo_keyword_es is nfc normalized),
  add constraint news_seo_keyword_en_check check (
    char_length(seo_keyword_en) between 2 and 60
    and seo_keyword_en = btrim(seo_keyword_en)
    and seo_keyword_en !~ '[\u0001-\u001F\u007F-\u009F]'
    and seo_keyword_en !~ U&'[\00AD\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and seo_keyword_en is nfc normalized),
  add constraint news_meta_description_es_check check (
    char_length(meta_description_es) between 1 and 160
    and meta_description_es !~ '[\u0001-\u001F\u007F-\u009F]'
    and meta_description_es !~ U&'[\00AD\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and meta_description_es is nfc normalized),
  add constraint news_meta_description_en_check check (
    char_length(meta_description_en) between 1 and 160
    and meta_description_en !~ '[\u0001-\u001F\u007F-\u009F]'
    and meta_description_en !~ U&'[\00AD\200B-\200D\202A-\202E\2066-\2069\2028\2029\FEFF]'
    and meta_description_en is nfc normalized);

-- ── 3. Columnas generadas (D92: N = 80; el front usa la misma constante, MIN_NEWS_INSIGHT_WORDS) ──
alter table guide.news alter column indexable set expression as (
  status = 'published'::guide.news_status
  and insight_es is not null
  and coalesce(array_length(regexp_split_to_array(btrim(insight_es), '\s+'), 1), 0) >= 80);

alter table guide.news alter column indexable_en set expression as (
  status = 'published'::guide.news_status
  and title_en is not null and summary_en is not null
  and insight_en is not null
  and coalesce(array_length(regexp_split_to_array(btrim(insight_en), '\s+'), 1), 0) >= 80);

alter table guide.news alter column search_es set expression as (
  setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(title_es, '')), 'A')
  || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(summary_es, '')), 'B')
  || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(insight_es, '')), 'C')
  || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(source_name, '')), 'D'));

alter table guide.news alter column search_en set expression as (
  setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(title_en, '')), 'A')
  || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(summary_en, '')), 'B')
  || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(insight_en, '')), 'C')
  || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(source_name, '')), 'D'));

-- ── Grants por columna (J27): aporte y meta description públicos con la noticia publicada; keyword interna ──
grant select (insight_es, insight_en, meta_description_es, meta_description_en) on guide.news to anon, authenticated;
revoke select (seo_keyword_es, seo_keyword_en) on guide.news from public, anon, authenticated;
grant insert (insight_es, insight_en, seo_keyword_es, seo_keyword_en, meta_description_es, meta_description_en),
      update (insight_es, insight_en, seo_keyword_es, seo_keyword_en, meta_description_es, meta_description_en)
  on guide.news to authenticated;
revoke insert (seo_keyword_es, seo_keyword_en, meta_description_es, meta_description_en),
       update (seo_keyword_es, seo_keyword_en, meta_description_es, meta_description_en)
  on guide.news from public, anon;

-- ── Exportación (solo admin, security_invoker): columnas nuevas al final ──
create or replace view guide.export_news with (security_invoker = true) as
select n.id, n.status, n.source, n.scope, n.category_id, c.key as category_key, c.label_es as category_es, n.slug,
       n.title_es, n.title_en, n.summary_es, n.summary_en, n.insight_es, n.insight_en, n.has_en, n.indexable,
       n.indexable_en, array_to_string(n.tags, ', ') as tags, n.source_id, n.source_name, n.source_title, n.source_url,
       n.source_published_on, n.source_lang, n.media_id, n.image_license, n.image_credit, n.reject_reason,
       n.published_at, n.first_published_at, n.created_at, n.updated_at,
       n.seo_keyword_es, n.seo_keyword_en, n.meta_description_es, n.meta_description_en
from guide.news n
left join guide.news_categories c on c.id = n.category_id
where (select guide.is_admin());

-- ── J21: guarda de noticias ──
create or replace function guide.news_before_write()
returns trigger
language plpgsql
set search_path = ''
as $fn$
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
  -- D91: NFC antes del CHECK, para que un texto pegado en NFD no falle al guardar.
  new.insight_es          := nullif(btrim(normalize(new.insight_es, NFC), E' \t\r\n'), '');
  new.insight_en          := nullif(btrim(normalize(new.insight_en, NFC), E' \t\r\n'), '');
  new.seo_keyword_es      := nullif(btrim(normalize(new.seo_keyword_es, NFC)), '');
  new.seo_keyword_en      := nullif(btrim(normalize(new.seo_keyword_en, NFC)), '');
  new.meta_description_es := nullif(btrim(normalize(new.meta_description_es, NFC)), '');
  new.meta_description_en := nullif(btrim(normalize(new.meta_description_en, NFC)), '');
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
    -- D91: el aporte (insight_*) y la keyword los propone el agente; meta_description_* es solo de Xavi.
    if tg_op <> 'INSERT' or new.status <> 'draft' or new.source <> 'agent'
       or new.published_at is not null or new.first_published_at is not null or new.approved_by is not null
       or new.meta_description_es is not null or new.meta_description_en is not null or new.reject_reason is not null
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
$fn$;

-- ── 4a. search_news: has_note → has_insight (cambia el tipo de retorno: drop + create) ──
drop function if exists guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope);
create function guide.search_news(p_query text, p_locale guide.locale, p_category_id uuid default null,
                                  p_limit integer default 20, p_offset integer default 0,
                                  p_scope guide.news_scope default null)
returns table(id uuid, slug text, title text, summary text, category_id uuid, category_key text, category_label text,
              scope guide.news_scope, source_name text, source_url text, published_at timestamptz,
              has_insight boolean, indexable boolean, rank real, headline text, total_count bigint)
language plpgsql
stable
set search_path = ''
as $fn$
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
             n.published_at, n.insight_es is not null, n.indexable, m.r,
             ts_headline(v_cfg, concat_ws(' ', n.summary_es, n.insight_es), v_tsq, c_opts), m.t
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
             n.published_at, n.insight_en is not null, n.indexable_en, m.r,
             ts_headline(v_cfg, concat_ws(' ', n.summary_en, n.insight_en), v_tsq, c_opts), m.t
      from m
      join guide.news n on n.id = m.nid
      left join guide.news_categories c on c.id = n.category_id
      order by m.r desc, n.published_at desc, n.id;
  end if;
end;
$fn$;
revoke all on function guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope) from public, service_role;
grant execute on function guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope) to anon, authenticated;

-- ── 4b. admin_list_news: aporte, keyword y meta description (cambia el retorno: drop + create) ──
drop function if exists guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer);
create function guide.admin_list_news(p_status guide.news_status default null, p_category_id uuid default null,
                                      p_scope guide.news_scope default null, p_source_id uuid default null,
                                      p_run_id uuid default null, p_query text default null, p_id uuid default null,
                                      p_limit integer default 50, p_offset integer default 0)
returns table(id uuid, slug text, status guide.news_status, source guide.event_source, title_es text, title_en text,
              summary_es text, summary_en text, insight_es text, insight_en text, seo_keyword_es text,
              seo_keyword_en text, meta_description_es text, meta_description_en text, category_id uuid,
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
as $fn$
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
         n.insight_es, n.insight_en, n.seo_keyword_es, n.seo_keyword_en, n.meta_description_es, n.meta_description_en,
         n.category_id, c.key, n.scope, n.tags,
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
$fn$;
revoke all on function guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)
  from public, anon, service_role;
grant execute on function guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)
  to authenticated;

-- ── 4c. admin_search (⌘K): parche acotado de la rama news. Solo cambian 3 fragmentos; se comprueba que no queda
--     ninguna referencia vieja. CREATE OR REPLACE conserva los EXECUTE.
do $$
declare
  v_def text := pg_get_functiondef('guide.admin_search(text, text[], integer)'::regprocedure);
begin
  if position('author_note' in v_def) = 0 and position('has_note' in v_def) = 0 then
    return;
  end if;
  v_def := replace(v_def, '''has_note'', n.author_note_es is not null', '''has_insight'', n.insight_es is not null');
  v_def := replace(v_def, '''summary_en'', ''author_note_es'', ''source_name''',
                          '''summary_en'', ''insight_es'', ''insight_en'', ''source_name''');
  v_def := replace(v_def, 'n.summary_en, n.author_note_es, n.source_name',
                          'n.summary_en, n.insight_es, n.insight_en, n.source_name');
  if position('author_note' in v_def) > 0 or position('has_note' in v_def) > 0 then
    raise exception 'admin_search: parche incompleto';
  end if;
  execute v_def;
end $$;

-- ── 5. Ingesta (J11 ampliada, J12–J17) ──
create or replace function guide.ingest_submit_news(p_token text, p_run_id uuid, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  -- J11: author_note_* y meta_description_* quedan fuera (unknown_key); meta_description_* solo la escribe Xavi.
  c_keys    constant text[] := array['title_es', 'title_en', 'summary_es', 'summary_en', 'category',
                                     'published_on_source', 'source_url', 'source_name', 'confidence', 'note', 'excerpt',
                                     'videos', 'insight_es', 'insight_en', 'seo_keyword_es', 'seo_keyword_en'];
  c_vkeys   constant text[] := array['url', 'title', 'channel', 'lang'];
  c_reasons constant text[] := array['not_object', 'too_large', 'unknown_key', 'secret', 'missing_field', 'invalid_type',
                                     'bad_chars', 'too_long', 'too_short', 'bad_url', 'shortener', 'pii', 'invalid_date',
                                     'stale', 'category', 'source', 'confidence', 'video', 'constraint'];
  v_token    uuid;
  v_run      guide.ingest_runs;
  v_reason   text;
  v_field    text;
  v_title_es text;
  v_title_en text;
  v_sum_es   text;
  v_sum_en   text;
  v_ins_es   text;
  v_ins_en   text;
  v_kw_es    text;
  v_kw_en    text;
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
    -- J17 sobre el payload entero (vídeos y aporte incluidos).
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
    -- D91: aporte (texto plano, saltos de línea permitidos) y keyword SEO (una línea, 2–60).
    v_ins_es   := guide.ingest_field_text(p_payload, 'insight_es', 1400, true, false);
    v_ins_en   := guide.ingest_field_text(p_payload, 'insight_en', 1400, true, false);
    v_kw_es    := guide.ingest_field_text(p_payload, 'seo_keyword_es', 60, false, false);
    v_kw_en    := guide.ingest_field_text(p_payload, 'seo_keyword_en', 60, false, false);
    if char_length(v_kw_es) < 2 then
      raise exception 'too_short' using detail = 'seo_keyword_es';
    end if;
    if char_length(v_kw_en) < 2 then
      raise exception 'too_short' using detail = 'seo_keyword_en';
    end if;

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

    -- J16 sobre todos los textos, aporte y keyword incluidos.
    if guide.ingest_has_pii(concat_ws(E'\n|\n', v_title_es, v_title_en, v_sum_es, v_sum_en, v_name, v_note, v_excerpt,
                                      v_ins_es, v_ins_en, v_kw_es, v_kw_en,
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
    insert into guide.news (slug, status, source, title_es, title_en, summary_es, summary_en,
                            insight_es, insight_en, seo_keyword_es, seo_keyword_en, category_id, scope,
                            source_name, source_url, source_published_on, source_lang, source_id, run_id,
                            dedupe_key, url_key, agent_meta)
    values ('pending', 'draft', 'agent', v_title_es, v_title_en, v_sum_es, v_sum_en,
            v_ins_es, v_ins_en, v_kw_es, v_kw_en, v_cat, v_source.scope,
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
$fn$;
revoke all on function guide.ingest_submit_news(text, uuid, jsonb) from public, authenticated, service_role;
grant execute on function guide.ingest_submit_news(text, uuid, jsonb) to anon;
