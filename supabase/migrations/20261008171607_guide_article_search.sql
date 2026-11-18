-- D21 / 3.19 · Búsqueda del blog: full-text en título (A), extracto (B) y cuerpo (C), es y en por separado,
-- insensible a acentos.
--
-- Por qué columnas GENERATED y no trigger: `unaccent(text)` es STABLE (depende del diccionario por
-- search_path), pero aquí no se llama a la función: se usa el **diccionario** `extensions.unaccent` dentro
-- de una configuración de texto propia (`guide.spanish_unaccent` / `guide.english_unaccent`), y
-- `to_tsvector(regconfig, text)`, `setweight` y `regexp_replace` son IMMUTABLE. Así la columna se
-- recalcula sola en cada INSERT/UPDATE sin triggers. Si algún día se cambia la configuración de texto,
-- hay que forzar el recálculo (`update guide.articles set title_es = title_es`).
--
-- El cuerpo se indexa desde `body_html_xx` sin etiquetas (regexp) para que no entren nombres de atributos
-- ni URLs de enlaces. Las entidades (&amp; …) las ignora el parser de texto (token `entity`, sin mapeo).

create extension if not exists unaccent with schema extensions;

do $$
begin
  if not exists (
    select 1 from pg_ts_config c join pg_namespace n on n.oid = c.cfgnamespace
    where n.nspname = 'guide' and c.cfgname = 'spanish_unaccent'
  ) then
    create text search configuration guide.spanish_unaccent (copy = pg_catalog.spanish);
    alter text search configuration guide.spanish_unaccent
      alter mapping for hword, hword_part, word with extensions.unaccent, pg_catalog.spanish_stem;
  end if;
  if not exists (
    select 1 from pg_ts_config c join pg_namespace n on n.oid = c.cfgnamespace
    where n.nspname = 'guide' and c.cfgname = 'english_unaccent'
  ) then
    create text search configuration guide.english_unaccent (copy = pg_catalog.english);
    alter text search configuration guide.english_unaccent
      alter mapping for hword, hword_part, word with extensions.unaccent, pg_catalog.english_stem;
  end if;
end $$;

alter table guide.articles
  add column if not exists search_es tsvector generated always as (
    setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(title_es, '')), 'A')
    || setweight(to_tsvector('guide.spanish_unaccent'::regconfig, coalesce(excerpt_es, '')), 'B')
    || setweight(to_tsvector('guide.spanish_unaccent'::regconfig,
         regexp_replace(coalesce(body_html_es, ''), '<[^>]*>', ' ', 'g')), 'C')
  ) stored;

alter table guide.articles
  add column if not exists search_en tsvector generated always as (
    setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(title_en, '')), 'A')
    || setweight(to_tsvector('guide.english_unaccent'::regconfig, coalesce(excerpt_en, '')), 'B')
    || setweight(to_tsvector('guide.english_unaccent'::regconfig,
         regexp_replace(coalesce(body_html_en, ''), '<[^>]*>', ' ', 'g')), 'C')
  ) stored;

create index if not exists articles_search_es_idx on guide.articles using gin (search_es);
create index if not exists articles_search_en_idx on guide.articles using gin (search_en);

-- Texto plano para ts_headline: sin etiquetas, entidades básicas decodificadas (&amp; la última) y sin
-- caracteres de control (U+0002/U+0003 del contenido no pueden fingir marcas). Pura e inofensiva: la
-- necesita quien llama a search_articles (INVOKER), por eso tiene grant a anon/authenticated.
create or replace function guide.search_plain_text(p_excerpt text, p_body_html text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select btrim(regexp_replace(
    replace(replace(replace(replace(replace(replace(replace(
      regexp_replace(coalesce(p_excerpt, '') || ' ' || coalesce(p_body_html, ''), '<[^>]*>', ' ', 'g'),
      '&nbsp;', ' '), '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&#39;', ''''), '&apos;', ''''), '&amp;', '&'),
    '[[:cntrl:][:space:]]+', ' ', 'g'));
$$;

revoke all on function guide.search_plain_text(text, text) from public;
grant execute on function guide.search_plain_text(text, text) to anon, authenticated;

-- RPC pública. SECURITY INVOKER: la RLS de articles (vivos para anon/authenticated) basta; además filtra
-- explícitamente por article_is_live() para que el admin tampoco vea borradores en el buscador público.
-- Fragmento: texto plano (sin etiquetas, entidades básicas decodificadas, sin caracteres de control) con
-- las coincidencias entre U+0002 (inicio) y U+0003 (fin). El frontend escapa TODO y solo después
-- convierte U+0002/U+0003 en <mark>/</mark>. Nunca se devuelve HTML del cuerpo.
-- total_count = coincidencias totales (igual en todas las filas; sin filas si el offset se pasa).
create or replace function guide.search_articles(
  p_query text,
  p_locale guide.locale,
  p_category_id uuid default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  slug_es text,
  slug_en text,
  title text,
  excerpt text,
  category_id uuid,
  category_slug text,
  category_name text,
  published_at timestamptz,
  rank real,
  headline text,
  total_count bigint
)
language plpgsql
stable
security invoker
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

  -- Búsqueda mientras se escribe: la última palabra (≥ 3 letras, sin comillas abiertas, no negada ni
  -- precedida de "or") se busca como prefijo de su raíz. El resto va por websearch_to_tsquery.
  v_last := substring(v_q from '(?:^|\s)([[:alnum:]]{3,})$');
  v_rest := left(v_q, char_length(v_q) - coalesce(char_length(v_last), 0));
  if v_last is not null
     and (char_length(v_q) - char_length(replace(v_q, '"', ''))) % 2 = 0
     and v_rest !~* '(^|\s)or\s*$' then
    v_tsq := websearch_to_tsquery(v_cfg, v_rest) && to_tsquery(v_cfg, lower(v_last) || ':*');
  else
    v_tsq := websearch_to_tsquery(v_cfg, v_q);
  end if;

  if v_tsq is null or numnode(v_tsq) = 0 then
    return;
  end if;

  if p_locale = 'es' then
    return query
      with m as (
        select a.id as aid, ts_rank(a.search_es, v_tsq, 1) as r, count(*) over () as t
        from guide.articles a
        where a.search_es @@ v_tsq
          and guide.article_is_live(a.status, a.published_at)
          and (p_category_id is null or a.category_id = p_category_id)
        order by r desc, a.published_at desc, a.id
        limit v_limit offset v_offset
      )
      select a.id, a.slug_es::text, a.slug_es::text, a.slug_en::text, a.title_es, a.excerpt_es,
             c.id, c.slug_es::text, c.name_es, a.published_at, m.r,
             ts_headline(v_cfg, guide.search_plain_text(a.excerpt_es, a.body_html_es), v_tsq, c_opts),
             m.t
      from m
      join guide.articles a on a.id = m.aid
      join guide.article_categories c on c.id = a.category_id
      order by m.r desc, a.published_at desc, a.id;
  else
    return query
      with m as (
        select a.id as aid, ts_rank(a.search_en, v_tsq, 1) as r, count(*) over () as t
        from guide.articles a
        where a.search_en @@ v_tsq
          and a.has_en
          and guide.article_is_live(a.status, a.published_at)
          and (p_category_id is null or a.category_id = p_category_id)
        order by r desc, a.published_at desc, a.id
        limit v_limit offset v_offset
      )
      select a.id, a.slug_en::text, a.slug_es::text, a.slug_en::text, a.title_en, a.excerpt_en,
             c.id, c.slug_en::text, coalesce(c.name_en, c.name_es), a.published_at, m.r,
             ts_headline(v_cfg, guide.search_plain_text(a.excerpt_en, a.body_html_en), v_tsq, c_opts),
             m.t
      from m
      join guide.articles a on a.id = m.aid
      join guide.article_categories c on c.id = a.category_id
      order by m.r desc, a.published_at desc, a.id;
  end if;
end;
$$;

revoke all on function guide.search_articles(text, guide.locale, uuid, integer, integer) from public;
grant execute on function guide.search_articles(text, guide.locale, uuid, integer, integer) to anon, authenticated;
