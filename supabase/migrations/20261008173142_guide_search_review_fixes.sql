-- D21 · Mejoras de la revisión de leona-lia (docs/security/D21-search-review.md), sin vetos.
--
-- Hallazgo 2: guide.log_activity deja fuera las columnas generadas search_es/search_en (tsvector)
--   tanto de changed_columns como del snapshot old_row. Son derivadas de título/extracto/cuerpo:
--   solo añadían ruido y volumen al registro.
-- Hallazgo 4: search_articles
--   a) Devuelve 0 filas si la consulta no tiene ningún término positivo indexable
--      (querytree(tsq) = 'T': "-xyz", "el -bar", "foo or -bar"). Esas consultas casan con casi
--      todos los artículos vivos y no son una búsqueda útil.
--   b) ts_headline recibe como mucho los primeros 20 000 caracteres del texto plano: acota el coste
--      por fila aunque el término sea positivo y el cuerpo, muy largo. Si el término solo aparece más
--      allá, ts_headline devuelve el inicio del texto (comportamiento aceptable para un fragmento).
-- Idempotente: create or replace; firmas sin cambios, así que grants y triggers se mantienen.

create or replace function guide.log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  c_skip      constant text[] := array['search_es', 'search_en'];
  v_id_col    text := coalesce(nullif(tg_argv[0], ''), 'id');
  v_label_col text := nullif(coalesce(tg_argv[1], ''), '');
  v_snapshot  boolean := coalesce(nullif(tg_argv[2], ''), 'true')::boolean;
  v_new       jsonb;
  v_old       jsonb;
  v_row       jsonb;
  v_changed   text[];
begin
  if tg_op in ('INSERT', 'UPDATE') then v_new := to_jsonb(new) - c_skip; end if;
  if tg_op in ('UPDATE', 'DELETE') then v_old := to_jsonb(old) - c_skip; end if;
  v_row := coalesce(v_new, v_old);

  if tg_op = 'UPDATE' then
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n
    where n.key not in ('updated_at', 'updated_by')
      and n.value is distinct from (v_old -> n.key);
    if v_changed is null then
      return null;
    end if;
  end if;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row)
  values (
    (select auth.uid()),
    lower(tg_op)::guide.activity_action,
    tg_table_name,
    coalesce(v_row ->> v_id_col, '?'),
    case when v_label_col is not null then left(v_row ->> v_label_col, 200) end,
    v_changed,
    case when tg_op = 'DELETE' and v_snapshot then v_old end
  );
  return null;
end;
$function$;

create or replace function guide.search_articles(
  p_query text,
  p_locale guide.locale,
  p_category_id uuid default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid, slug text, slug_es text, slug_en text, title text, excerpt text, category_id uuid,
  category_slug text, category_name text, published_at timestamptz, rank real, headline text,
  total_count bigint
)
language plpgsql
stable
set search_path = ''
as $function$
#variable_conflict use_column
declare
  c_max_len constant integer := 200;
  c_headline_len constant integer := 20000;
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

  -- Sin término positivo indexable (solo negaciones, o "x or -y"): no es una búsqueda, 0 filas.
  if v_tsq is null or numnode(v_tsq) = 0 or querytree(v_tsq) = 'T' then
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
             ts_headline(v_cfg, left(guide.search_plain_text(a.excerpt_es, a.body_html_es), c_headline_len), v_tsq, c_opts),
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
             ts_headline(v_cfg, left(guide.search_plain_text(a.excerpt_en, a.body_html_en), c_headline_len), v_tsq, c_opts),
             m.t
      from m
      join guide.articles a on a.id = m.aid
      join guide.article_categories c on c.id = a.category_id
      order by m.r desc, a.published_at desc, a.id;
  end if;
end;
$function$;
