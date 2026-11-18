-- F6.15b (D50): importación de fichas desde Excel/CSV (el navegador lee el archivo; aquí llega JSON).
-- Todo INVOKER con assert_admin: la RLS de admin y las guardas de lo vivo actúan igual que en el panel.
-- Contrato y códigos: docs/security/F6.15b-import-audit.md (§ Implementación).

-- Una incidencia del informe.
create or replace function guide.import_issue(p_column text, p_code text, p_level text default 'error', p_params jsonb default null)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object('column', p_column, 'code', p_code, 'level', p_level, 'params', p_params));
$$;

-- Texto plano → documento del editor ({json, html}). Todo se escapa: el HTML del archivo llega como texto literal.
-- Línea en blanco = párrafo nuevo; salto simple = hardBreak (<br>). Sin Markdown ni enlaces. NULL si queda vacío.
create or replace function guide.plain_text_doc(p_text text)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text  text;
  v_para  text;
  v_line  text;
  v_nodes jsonb;
  v_html  text;
  v_paras jsonb := '[]'::jsonb;
  v_out   text := '';
begin
  if p_text is null then
    return null;
  end if;
  v_text := replace(replace(p_text, E'\r\n', E'\n'), E'\r', E'\n');
  -- Fuera controles de dirección (U+202A–202E, U+2066–2069) y de ancho cero.
  v_text := regexp_replace(v_text, '[' || chr(8234) || '-' || chr(8238) || chr(8294) || '-' || chr(8297)
                                   || chr(8203) || chr(65279) || ']', '', 'g');
  for v_para in select p from regexp_split_to_table(v_text, E'\\n[[:space:]]*\\n') p loop
    v_nodes := '[]'::jsonb;
    v_html := '';
    for v_line in select l from regexp_split_to_table(v_para, E'\\n') l loop
      v_line := btrim(regexp_replace(v_line, '[[:cntrl:]]+', ' ', 'g'));
      continue when v_line = '';
      if jsonb_array_length(v_nodes) > 0 then
        v_nodes := v_nodes || '{"type":"hardBreak"}'::jsonb;
        v_html := v_html || '<br>';
      end if;
      v_nodes := v_nodes || jsonb_build_object('type', 'text', 'text', v_line);
      v_html := v_html || replace(replace(replace(replace(replace(v_line, '&', '&amp;'), '<', '&lt;'), '>', '&gt;'),
                                          '"', '&quot;'), '''', '&#39;');
    end loop;
    if jsonb_array_length(v_nodes) > 0 then
      v_paras := v_paras || jsonb_build_object('type', 'paragraph', 'content', v_nodes);
      v_out := v_out || '<p>' || v_html || '</p>';
    end if;
  end loop;
  if jsonb_array_length(v_paras) = 0 then
    return null;
  end if;
  return jsonb_build_object('json', jsonb_build_object('type', 'doc', 'content', v_paras), 'html', v_out);
end;
$$;

-- ¿Reseña sin texto? (ni texto ni imágenes ni vídeos). Equivale a isEmptyDoc del editor.
create or replace function guide.review_body_is_empty(p_html text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_html is null
      or (p_html !~* '<(img|iframe)\M'
          and regexp_replace(regexp_replace(p_html, '<[^>]*>', '', 'g'), '&nbsp;|[[:space:]]', '', 'g') = '');
$$;

-- Referencia a una foto del archivo → fila de guide.media. Orden: uuid, URL pública del bucket `media`,
-- ruta de Storage (<uuid>/...), nombre original (sin distinguir mayúsculas). Nunca descarga nada.
-- status: ok | not_found | ambiguous | external_url | invalid.
create or replace function guide.import_resolve_media(p_ref text)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  c_uuid     constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  -- Proyecto eqtjlafxtrzbjazhhyin. Otro proyecto o dominio propio: añadir su prefijo aquí.
  c_prefixes constant text[] := array[
    'https://eqtjlafxtrzbjazhhyin.supabase.co/storage/v1/object/public/media/',
    'https://eqtjlafxtrzbjazhhyin.supabase.co/storage/v1/render/image/public/media/'];
  v_ref   text := btrim(coalesce(p_ref, ''));
  v_path  text;
  v_pref  text;
  v_id    uuid;
  v_alt   text;
  v_n     integer;
begin
  perform guide.assert_admin();
  if v_ref = '' or char_length(v_ref) > 2048 then
    return jsonb_build_object('status', 'invalid');
  end if;

  if v_ref ~ c_uuid then
    select m.id, m.alt_es into v_id, v_alt from guide.media m where m.id = lower(v_ref)::uuid;
  elsif v_ref ~* '^[a-z][a-z0-9+.-]*:' or v_ref ~ '^//' then
    foreach v_pref in array c_prefixes loop
      if left(v_ref, char_length(v_pref)) = v_pref then
        v_path := substr(v_ref, char_length(v_pref) + 1);
      end if;
    end loop;
    if v_path is null then
      return jsonb_build_object('status', 'external_url');
    end if;
    v_path := split_part(split_part(v_path, '?', 1), '#', 1);
    if v_path = '' or v_path ~* '\.\.|\\|%2e|%2f|%5c' then
      return jsonb_build_object('status', 'invalid');
    end if;
    select m.id, m.alt_es into v_id, v_alt from guide.media m where m.storage_path = v_path;
  elsif v_ref ~ '/' then
    -- Ruta de Storage (empieza por el id del medio); cualquier otra cosa con barras es una web ajena.
    if split_part(v_ref, '/', 1) !~ c_uuid then
      return jsonb_build_object('status', 'external_url');
    end if;
    if v_ref ~* '\.\.|\\|%2e|%2f|%5c' then
      return jsonb_build_object('status', 'invalid');
    end if;
    select m.id, m.alt_es into v_id, v_alt from guide.media m where m.storage_path = v_ref;
  else
    select count(*) into v_n from guide.media m where lower(m.original_filename) = lower(v_ref);
    if v_n > 1 then
      return jsonb_build_object('status', 'ambiguous', 'count', v_n);
    end if;
    select m.id, m.alt_es into v_id, v_alt from guide.media m where lower(m.original_filename) = lower(v_ref);
  end if;

  if v_id is null then
    return jsonb_build_object('status', 'not_found');
  end if;
  return jsonb_build_object('status', 'ok', 'media_id', v_id, 'alt_missing', guide.alt_is_missing(v_alt));
end;
$$;

-- Valor de una celda (JSON) → valor normalizado de la columna, o incidencia. Genérico por tipo de columna:
-- texto/enum = string limpio y no vacío; número = number; booleano = boolean; fecha = "YYYY-MM-DD";
-- lista = array de strings (repetidos fuera, con aviso); jsonb = objeto. La conversión real la hace
-- jsonb_populate_record sobre la tabla (dominios, numeric(p,s), enteros), como al escribir.
create or replace function guide.import_check_value(p_table text, p_column text, p_value jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  c_trim  constant text := '^[[:space:]' || chr(160) || chr(8203) || chr(65279) || ']+|[[:space:]' || chr(160) || chr(8203) || chr(65279) || ']+$';
  v_cat   "char";
  v_type  text;
  v_kind  text := jsonb_typeof(p_value);
  v_clean jsonb := p_value;
  v_out   jsonb;
  v_state text;
  v_warn  jsonb := '[]'::jsonb;
  v_arr   text[];
  v_txt   text;
begin
  perform guide.assert_admin();
  -- p_table va a SQL dinámico: solo las tablas que importa la ficha.
  if p_table is null or p_table not in ('items', 'gyms', 'resolers', 'shoes', 'author_reviews') then
    raise exception 'invalid table' using errcode = '22023';
  end if;
  select coalesce(bt.typcategory, t.typcategory), coalesce(bt.typname, t.typname)
    into v_cat, v_type
  from pg_catalog.pg_attribute a
  join pg_catalog.pg_type t on t.oid = a.atttypid
  left join pg_catalog.pg_type bt on t.typtype = 'd' and bt.oid = t.typbasetype
  where a.attrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(p_table))
    and a.attname = p_column and a.attnum > 0 and not a.attisdropped;
  if not found then
    return jsonb_build_object('issue', guide.import_issue(p_column, 'unknown_column'));
  end if;

  case
    when v_cat in ('S', 'E') then
      if v_kind <> 'string' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"string"}'));
      end if;
      v_txt := regexp_replace(regexp_replace(p_value #>> '{}', '[[:cntrl:]]+', ' ', 'g'), c_trim, '', 'g');
      if v_txt = '' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'empty_value'));
      end if;
      v_clean := to_jsonb(v_txt);
    when v_cat = 'N' then
      if v_kind <> 'number' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error',
          jsonb_build_object('expected', case when v_type in ('int2', 'int4', 'int8') then 'integer' else 'number' end)));
      end if;
      if v_type in ('int2', 'int4', 'int8') and (p_value #>> '{}')::numeric <> trunc((p_value #>> '{}')::numeric) then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"integer"}'));
      end if;
    when v_cat = 'B' then
      if v_kind <> 'boolean' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"boolean"}'));
      end if;
    when v_cat = 'D' then
      if v_kind <> 'string' or (p_value #>> '{}') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"date"}'));
      end if;
    when v_cat = 'A' then
      if v_kind <> 'array' or jsonb_array_length(p_value) > 50
         or exists (select 1 from jsonb_array_elements(p_value) e where jsonb_typeof(e) <> 'string') then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"string_list"}'));
      end if;
      select coalesce(array_agg(x order by o), '{}') into v_arr
      from (select distinct on (x) x, o
            from (select regexp_replace(regexp_replace(e #>> '{}', '[[:cntrl:]]+', ' ', 'g'), c_trim, '', 'g') x, o
                  from jsonb_array_elements(p_value) with ordinality as a(e, o)) s
            where x <> ''
            order by x, o) d;
      if cardinality(v_arr) < jsonb_array_length(p_value) then
        v_warn := v_warn || guide.import_issue(p_column, 'duplicates_removed', 'warning');
      end if;
      v_clean := to_jsonb(v_arr);
    when v_type = 'jsonb' then
      if v_kind <> 'object' then
        return jsonb_build_object('issue', guide.import_issue(p_column, 'invalid_type', 'error', '{"expected":"object"}'));
      end if;
    else
      return jsonb_build_object('issue', guide.import_issue(p_column, 'unknown_column'));
  end case;

  begin
    execute format('select to_jsonb(r.%I) from jsonb_populate_record(null::guide.%I, $1) r', p_column, p_table)
      into v_out using jsonb_build_object(p_column, v_clean);
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate;
    return jsonb_build_object('issue', guide.import_issue(p_column,
      case v_state
        when '22003' then 'out_of_range'
        when '22008' then 'invalid_date'
        when '22007' then 'invalid_date'
        when '22001' then 'too_long'
        when '23514' then 'invalid_value'
        else 'invalid_value'
      end));
  end;

  if v_cat = 'N' and (v_out #>> '{}')::numeric <> (v_clean #>> '{}')::numeric then
    v_warn := v_warn || guide.import_issue(p_column, 'rounded', 'warning', jsonb_build_object('value', v_out));
  end if;
  return jsonb_build_object('value', v_out, 'warnings', v_warn);
end;
$$;

-- CHECK de la tabla sobre la fila mezclada (lo que hay + el archivo). Devuelve incidencias por columna (conkey).
-- Salta las restricciones cuyas columnas ya tienen un error (p_skip_cols) para no repetir el mismo problema.
create or replace function guide.import_check_constraints(p_table text, p_merged jsonb, p_given text[], p_skip_cols text[])
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_con   record;
  v_ok    boolean;
  v_cols  text[];
  v_hit   text[];
  v_max   text;
  v_allow text[];
  v_out   jsonb := '[]'::jsonb;
  v_issue_code text;
  v_params jsonb;
begin
  perform guide.assert_admin();
  if p_table is null or p_table not in ('items', 'gyms', 'resolers', 'shoes', 'author_reviews') then
    raise exception 'invalid table' using errcode = '22023';
  end if;
  for v_con in
    select c.conname, pg_catalog.pg_get_constraintdef(c.oid) as def,
           array(select a.attname::text from pg_catalog.pg_attribute a
                 where a.attrelid = c.conrelid and a.attnum = any (c.conkey) order by a.attnum) as cols
    from pg_catalog.pg_constraint c
    where c.conrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(p_table))
      and c.contype = 'c' and c.convalidated
    order by c.conname
  loop
    v_cols := v_con.cols;
    continue when v_cols && coalesce(p_skip_cols, '{}');
    continue when not (v_cols && coalesce(p_given, '{}'));
    begin
      execute format('select coalesce((%s), true) from (select (jsonb_populate_record(null::guide.%I, $1)).*) s',
                     regexp_replace(v_con.def, '^CHECK \((.*)\)$', '\1'), p_table)
        into v_ok using p_merged;
    exception when others then
      v_ok := false;
    end;
    continue when v_ok;

    v_params := jsonb_build_object('constraint', v_con.conname);
    v_issue_code := 'check';
    if v_con.def ~ 'char_length\(' and v_con.def ~ '<= [0-9]+' and cardinality(v_cols) = 1 then
      v_issue_code := 'too_long';
      v_max := substring(v_con.def from '<= ([0-9]+)');
      v_params := v_params || jsonb_build_object('max', v_max::integer);
    elsif (v_con.def ~ '= ANY \(ARRAY\[' or v_con.def ~ '<@ ARRAY\[') and cardinality(v_cols) = 1 then
      v_issue_code := 'not_allowed_value';
      select array_agg(m[1]) into v_allow from regexp_matches(v_con.def, '''([a-z_]+)''::text', 'g') m;
      v_params := v_params || jsonb_build_object('allowed', to_jsonb(v_allow));
    end if;
    v_hit := array(select x from unnest(v_cols) x where x = any (p_given));
    if cardinality(v_hit) = 0 then
      v_hit := v_cols[1:1];
    end if;
    select v_out || coalesce(jsonb_agg(guide.import_issue(h, v_issue_code, 'error', v_params)), '[]'::jsonb)
      into v_out from unnest(v_hit) h;
  end loop;
  return v_out;
end;
$$;

-- Una fila del archivo. Valida, identifica y escribe (o deja el informe). La llama admin_import_items, que deshace
-- todo en la validación en seco y si alguna fila tiene error. Llamarla suelta no da más poder que el panel
-- (assert_admin, RLS y guardas), pero no deja lote ni registro de lote.
create or replace function guide.import_row(p_category text, p_row jsonb, p_dup_slug boolean, p_dup_brand_model boolean,
                                            p_batch_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  c_special   constant text[] := array['_row', 'scores', 'cover', 'og_image', 'gallery', 'review_text_es', 'review_text_en'];
  c_owned_only constant text[] := array['author_size_eu', 'author_street_size_eu', 'author_size_note_es', 'author_size_note_en',
                                        'headline_es', 'headline_en', 'visit_date', 'visit_type', 'disclosure_note_es',
                                        'disclosure_note_en', 'scores', 'review_text_es', 'review_text_en'];
  v_detail    text := guide.draft_section_table('item', 'detail', p_category);
  v_items_cols text[] := array(select c from unnest(guide.draft_allowed_columns('items')) c
                               where c not in ('cover_media_id', 'og_media_id', 'attributes'));
  v_det_cols  text[];
  v_rev_cols  text[] := array(select c from unnest(guide.draft_allowed_columns('author_reviews')) c where c !~ '^body_');
  v_rownum    integer;
  v_issues    jsonb := '[]'::jsonb;
  v_key       text;
  v_val       jsonb;
  v_chk       jsonb;
  v_res       jsonb;
  v_item      jsonb := '{}'::jsonb;
  v_det       jsonb := '{}'::jsonb;
  v_rev       jsonb := '{}'::jsonb;
  v_scores    jsonb;
  v_gallery   uuid[];
  v_text      jsonb := '{}'::jsonb;  -- {es: {json, html}, en: ...}
  v_err_cols  text[] := '{}';
  v_slug      text;
  v_brand     text;
  v_model     text;
  v_id        uuid;
  v_published boolean := false;
  v_cur_item  jsonb;
  v_cur_det   jsonb;
  v_cur_rev   jsonb;
  v_cur_scores jsonb := '{}'::jsonb;
  v_cur_gallery uuid[] := '{}';
  v_bm_id     uuid;
  v_bm_slug   text;
  v_owned     boolean;
  v_ch_item   jsonb := '{}'::jsonb;
  v_ch_det    jsonb := '{}'::jsonb;
  v_ch_rev    jsonb := '{}'::jsonb;
  v_ch_scores jsonb := '{}'::jsonb;
  v_gallery_changed boolean := false;
  v_payload   jsonb;
  v_draft     guide.content_drafts%rowtype;
  v_review_id uuid;
  v_action    text;
  v_version   timestamptz;
  v_cols      text[];
  v_crit      record;
  v_lang      text;
  v_i         integer;
  v_m         jsonb;
  v_state     text;
  v_con       text;
  v_colname   text;
  v_blockers  text[];
  v_tok       text := 'new';  -- estado de partida de la ficha, para la huella (admin_import_items)
begin
  perform guide.assert_admin();
  if v_detail is null then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  v_det_cols := guide.draft_allowed_columns(v_detail);
  if jsonb_typeof(p_row -> '_row') = 'number' and (p_row ->> '_row') ~ '^[0-9]{1,7}$' then
    v_rownum := (p_row ->> '_row')::integer;
  end if;

  -- 1. Claves y tipos ---------------------------------------------------------------------------
  for v_key, v_val in select e.key, e.value from jsonb_each(p_row) e loop
    continue when v_key = '_row';
    if jsonb_typeof(v_val) = 'null' then
      v_issues := v_issues || guide.import_issue(v_key, 'null_not_allowed');
      v_err_cols := v_err_cols || v_key;
      continue;
    end if;
    if v_key = any (c_special) then
      continue;
    end if;
    if v_key = any (v_items_cols) then
      v_chk := guide.import_check_value('items', v_key, v_val);
    elsif v_key = any (v_det_cols) then
      v_chk := guide.import_check_value(v_detail, v_key, v_val);
    elsif v_key = any (v_rev_cols) then
      v_chk := guide.import_check_value('author_reviews', v_key, v_val);
    else
      v_issues := v_issues || guide.import_issue(v_key, 'unknown_column');
      continue;
    end if;
    if v_chk ? 'issue' then
      v_issues := v_issues || (v_chk -> 'issue');
      v_err_cols := v_err_cols || v_key;
      continue;
    end if;
    v_issues := v_issues || coalesce(v_chk -> 'warnings', '[]'::jsonb);
    if v_key = any (v_items_cols) then
      v_item := v_item || jsonb_build_object(v_key, v_chk -> 'value');
    elsif v_key = any (v_det_cols) then
      v_det := v_det || jsonb_build_object(v_key, v_chk -> 'value');
    else
      v_rev := v_rev || jsonb_build_object(v_key, v_chk -> 'value');
    end if;
    if v_key ~ '_url$' and (v_chk ->> 'value') !~ '^https?://[^[:space:]"''<>]+$' then
      v_issues := v_issues || guide.import_issue(v_key, 'invalid_url');
      v_err_cols := v_err_cols || v_key;
    end if;
  end loop;

  -- Texto plano de la reseña.
  foreach v_lang in array array['es', 'en'] loop
    v_val := p_row -> ('review_text_' || v_lang);
    continue when v_val is null or jsonb_typeof(v_val) = 'null';
    if jsonb_typeof(v_val) <> 'string' then
      v_issues := v_issues || guide.import_issue('review_text_' || v_lang, 'invalid_type', 'error', '{"expected":"string"}');
    elsif char_length(v_val #>> '{}') > 20000 then
      v_issues := v_issues || guide.import_issue('review_text_' || v_lang, 'too_long', 'error', '{"max":20000}');
    else
      v_res := guide.plain_text_doc(v_val #>> '{}');
      if v_res is null then
        v_issues := v_issues || guide.import_issue('review_text_' || v_lang, 'empty_value');
      else
        v_text := v_text || jsonb_build_object(v_lang, v_res);
        if (v_val #>> '{}') ~ '<[A-Za-z/!]' then
          v_issues := v_issues || guide.import_issue('review_text_' || v_lang, 'looks_like_html', 'warning');
        end if;
      end if;
    end if;
  end loop;

  -- Fotos.
  foreach v_key in array array['cover', 'og_image'] loop
    v_val := p_row -> v_key;
    continue when v_val is null or jsonb_typeof(v_val) = 'null';
    if jsonb_typeof(v_val) <> 'string' then
      v_issues := v_issues || guide.import_issue(v_key, 'invalid_type', 'error', '{"expected":"string"}');
      continue;
    end if;
    v_m := guide.import_resolve_media(v_val #>> '{}');
    case v_m ->> 'status'
      when 'ok' then
        v_item := v_item || jsonb_build_object(case v_key when 'cover' then 'cover_media_id' else 'og_media_id' end, v_m -> 'media_id');
        if (v_m ->> 'alt_missing')::boolean then
          v_issues := v_issues || guide.import_issue(v_key, 'media_no_alt', 'warning', jsonb_build_object('media_id', v_m -> 'media_id'));
        end if;
      when 'not_found' then v_issues := v_issues || guide.import_issue(v_key, 'media_not_found', 'warning');
      when 'ambiguous' then v_issues := v_issues || guide.import_issue(v_key, 'media_ambiguous', 'warning', jsonb_build_object('count', v_m -> 'count'));
      when 'external_url' then v_issues := v_issues || guide.import_issue(v_key, 'media_external_url');
      else v_issues := v_issues || guide.import_issue(v_key, 'invalid_value');
    end case;
  end loop;
  v_val := p_row -> 'gallery';
  if v_val is not null and jsonb_typeof(v_val) <> 'null' then
    if jsonb_typeof(v_val) <> 'array' or jsonb_array_length(v_val) > 50
       or exists (select 1 from jsonb_array_elements(v_val) e where jsonb_typeof(e) <> 'string') then
      v_issues := v_issues || guide.import_issue('gallery', 'invalid_type', 'error', '{"expected":"string_list"}');
    else
      v_gallery := '{}';
      for v_i in 0 .. jsonb_array_length(v_val) - 1 loop
        v_m := guide.import_resolve_media(v_val ->> v_i);
        case v_m ->> 'status'
          when 'ok' then
            if not ((v_m ->> 'media_id')::uuid = any (v_gallery)) then
              v_gallery := v_gallery || (v_m ->> 'media_id')::uuid;
            end if;
            if (v_m ->> 'alt_missing')::boolean then
              v_issues := v_issues || guide.import_issue('gallery', 'media_no_alt', 'warning',
                                                         jsonb_build_object('index', v_i, 'media_id', v_m -> 'media_id'));
            end if;
          when 'not_found' then v_issues := v_issues || guide.import_issue('gallery', 'media_not_found', 'warning', jsonb_build_object('index', v_i));
          when 'ambiguous' then v_issues := v_issues || guide.import_issue('gallery', 'media_ambiguous', 'warning', jsonb_build_object('index', v_i, 'count', v_m -> 'count'));
          when 'external_url' then v_issues := v_issues || guide.import_issue('gallery', 'media_external_url', 'error', jsonb_build_object('index', v_i));
          else v_issues := v_issues || guide.import_issue('gallery', 'invalid_value', 'error', jsonb_build_object('index', v_i));
        end case;
      end loop;
      if cardinality(v_gallery) = 0 then
        v_gallery := null;  -- nada encontrado: no se toca la galería
      end if;
    end if;
  end if;

  -- 2. Identidad --------------------------------------------------------------------------------
  v_slug := v_item ->> 'slug';
  if not (p_row ? 'slug') then
    v_issues := v_issues || guide.import_issue('slug', 'required');
  elsif v_slug is not null then
    if v_slug ~ '^sin-nombre(-[0-9]+)?$' then
      v_issues := v_issues || guide.import_issue('slug', 'slug_placeholder');
      v_slug := null;
    elsif p_dup_slug then
      v_issues := v_issues || guide.import_issue('slug', 'duplicate_in_file');
      v_slug := null;
    end if;
  end if;
  if p_dup_brand_model then
    v_issues := v_issues || guide.import_issue('brand', 'duplicate_in_file');
  end if;

  if v_slug is not null then
    select i.id, i.published, to_jsonb(i) into v_id, v_published, v_cur_item
    from guide.items i where i.category = p_category and i.slug = v_slug::guide.slug for update;

    if p_category = 'shoe' and v_det ? 'brand' and v_det ? 'model' then
      v_brand := v_det ->> 'brand';
      v_model := v_det ->> 'model';
      select s.item_id, i.slug::text into v_bm_id, v_bm_slug
      from guide.shoes s join guide.items i on i.id = s.item_id
      where lower(btrim(s.brand)) = lower(btrim(v_brand)) and lower(btrim(s.model)) = lower(btrim(v_model));
      if v_id is not null and v_bm_id is not null and v_bm_id <> v_id then
        v_issues := v_issues || guide.import_issue('brand', 'identity_conflict', 'error', jsonb_build_object('slug', v_bm_slug));
      elsif v_id is null and v_bm_id is not null then
        v_issues := v_issues || guide.import_issue('slug', 'exists_as', 'error', jsonb_build_object('slug', v_bm_slug));
      end if;
    end if;

    if v_id is null then
      if exists (select 1 from guide.slug_redirects r
                 where r.kind = 'item' and r.item_category = p_category and r.old_slug = v_slug) then
        v_issues := v_issues || guide.import_issue('slug', 'slug_is_redirect');
      end if;
      if not (v_item ? 'name') and not ('name' = any (v_err_cols)) then
        v_issues := v_issues || guide.import_issue('name', 'required');
      elsif v_item ? 'name' then
        select i.slug::text into v_bm_slug from guide.items i
        where i.category = p_category and lower(i.name) = lower(v_item ->> 'name') limit 1;
        if found then
          v_issues := v_issues || guide.import_issue('name', 'same_name', 'warning', jsonb_build_object('slug', v_bm_slug));
        end if;
      end if;
    else
      execute format('select to_jsonb(d) from guide.%I d where d.item_id = $1', v_detail) into v_cur_det using v_id;
      select to_jsonb(r) into v_cur_rev from guide.author_reviews r where r.item_id = v_id;
      select coalesce(jsonb_object_agg(s.criterion_id::text, s.score), '{}'::jsonb) into v_cur_scores
      from guide.author_review_scores s join guide.author_reviews r on r.id = s.review_id where r.item_id = v_id;
      select coalesce(array_agg(im.media_id order by im.sort_order, im.media_id), '{}') into v_cur_gallery
      from guide.item_media im where im.item_id = v_id;
      v_tok := v_id::text || '@' || coalesce(guide.draft_entity_version('item', v_id)::text, '')
               || '@' || coalesce((select d.updated_at::text from guide.content_drafts d
                                   where d.entity = 'item' and d.entity_id = v_id), '');
    end if;
  end if;

  -- 3. Reglas que la BD no tiene y CHECK sobre la fila mezclada -----------------------------------
  if p_category = 'shoe' then
    v_owned := coalesce((v_det ->> 'owned_by_author')::boolean, (v_cur_det ->> 'owned_by_author')::boolean, false);
    if not v_owned then
      for v_key in select k from unnest(c_owned_only) k where p_row ? k loop
        v_issues := v_issues || guide.import_issue(v_key, 'owned_only');
        v_err_cols := v_err_cols || v_key;
      end loop;
    else
      if (v_det ? 'author_size_eu' or v_det ? 'author_street_size_eu')
         and (coalesce(v_det -> 'author_size_eu', v_cur_det -> 'author_size_eu', 'null'::jsonb) = 'null'::jsonb)
             <> (coalesce(v_det -> 'author_street_size_eu', v_cur_det -> 'author_street_size_eu', 'null'::jsonb) = 'null'::jsonb) then
        v_issues := v_issues || guide.import_issue(
          case when v_det ? 'author_size_eu' then 'author_street_size_eu' else 'author_size_eu' end, 'sizes_pair');
      end if;
      if v_det ? 'author_size_note_en'
         and coalesce(v_det ->> 'author_size_note_es', v_cur_det ->> 'author_size_note_es', '') = '' then
        v_issues := v_issues || guide.import_issue('author_size_note_en', 'needs_es');
      end if;
    end if;
  end if;
  if p_category = 'gym' and v_det ? 'opening_hours' and not guide.opening_hours_valid(v_det -> 'opening_hours') then
    v_issues := v_issues || guide.import_issue('opening_hours', 'invalid_hours');
    v_err_cols := v_err_cols || 'opening_hours';
  end if;

  if v_item <> '{}'::jsonb then
    v_issues := v_issues || guide.import_check_constraints('items',
      coalesce(v_cur_item, jsonb_build_object('category', p_category)) || v_item,
      array(select jsonb_object_keys(v_item)), v_err_cols);
  end if;
  if v_det <> '{}'::jsonb then
    v_issues := v_issues || guide.import_check_constraints(v_detail,
      coalesce(v_cur_det, jsonb_build_object('category', p_category)) || v_det,
      array(select jsonb_object_keys(v_det)), v_err_cols);
  end if;
  if v_rev <> '{}'::jsonb then
    v_issues := v_issues || guide.import_check_constraints('author_reviews',
      coalesce(v_cur_rev, jsonb_build_object('category', p_category)) || v_rev,
      array(select jsonb_object_keys(v_rev)), v_err_cols);
  end if;

  -- Notas por clave de criterio.
  v_val := p_row -> 'scores';
  if v_val is not null and jsonb_typeof(v_val) <> 'null' and not ('scores' = any (v_err_cols)) then
    if jsonb_typeof(v_val) <> 'object' or (select count(*) from jsonb_object_keys(v_val)) > 50 then
      v_issues := v_issues || guide.import_issue('scores', 'invalid_type', 'error', '{"expected":"object"}');
    else
      v_scores := '{}'::jsonb;
      for v_key, v_res in select e.key, e.value from jsonb_each(v_val) e loop
        select c.id, c.is_active into v_crit from guide.criteria c where c.category = p_category and c.key = v_key;
        if not found then
          v_issues := v_issues || guide.import_issue('scores.' || left(v_key, 40), 'unknown_criterion');
        elsif jsonb_typeof(v_res) <> 'number' or (v_res #>> '{}') !~ '^[1-5]$' then
          v_issues := v_issues || guide.import_issue('scores.' || v_key, 'out_of_range', 'error', '{"min":1,"max":5}');
        elsif not v_crit.is_active and (v_cur_scores -> v_crit.id::text) is distinct from v_res then
          v_issues := v_issues || guide.import_issue('scores.' || v_key, 'inactive_criterion');
        else
          v_scores := v_scores || jsonb_build_object(v_crit.id::text, v_res);
        end if;
      end loop;
    end if;
  end if;

  if exists (select 1 from jsonb_array_elements(v_issues) x where x ->> 'level' = 'error') then
    return jsonb_build_object('row', v_rownum, 'key', v_item ->> 'slug', 'action', 'error', 'issues', v_issues,
                              'state', v_tok);
  end if;

  -- 4. Diferencias --------------------------------------------------------------------------------
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_ch_item
  from jsonb_each(v_item) e where v_cur_item is null or (v_cur_item -> e.key) is distinct from e.value;
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_ch_det
  from jsonb_each(v_det) e where v_cur_det is null or (v_cur_det -> e.key) is distinct from e.value;
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_ch_rev
  from jsonb_each(v_rev) e where v_cur_rev is null or (v_cur_rev -> e.key) is distinct from e.value;
  foreach v_lang in array array['es', 'en'] loop
    continue when not (v_text ? v_lang);
    if v_cur_rev is null or guide.review_body_is_empty(v_cur_rev ->> ('body_html_' || v_lang)) then
      v_ch_rev := v_ch_rev || jsonb_build_object('body_json_' || v_lang, v_text -> v_lang -> 'json',
                                                 'body_html_' || v_lang, v_text -> v_lang -> 'html');
    else
      v_issues := v_issues || guide.import_issue('review_text_' || v_lang, 'review_body_kept', 'warning');
    end if;
  end loop;
  if v_scores is not null then
    select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v_ch_scores
    from jsonb_each(v_scores) e where (v_cur_scores -> e.key) is distinct from e.value;
  end if;
  v_gallery_changed := v_gallery is not null and v_gallery is distinct from v_cur_gallery;

  -- 5. Escritura ----------------------------------------------------------------------------------
  begin
    if v_id is null then
      v_cols := array(select jsonb_object_keys(v_item) order by 1);
      execute format('insert into guide.items (category, published%s) select $1, false%s from jsonb_populate_record(null::guide.items, $2) r returning id',
                     (select string_agg(format(', %I', c), '') from unnest(v_cols) c),
                     (select string_agg(format(', r.%I', c), '') from unnest(v_cols) c))
        into v_id using p_category, v_item;
      v_cols := array(select jsonb_object_keys(v_det) order by 1);
      execute format('insert into guide.%I (item_id, category%s) select $1, $2%s from jsonb_populate_record(null::guide.%I, $3) r',
                     v_detail,
                     coalesce((select string_agg(format(', %I', c), '') from unnest(v_cols) c), ''),
                     coalesce((select string_agg(format(', r.%I', c), '') from unnest(v_cols) c), ''),
                     v_detail)
        using v_id, p_category, v_det;
      v_action := 'created';
    elsif v_ch_item = '{}'::jsonb and v_ch_det = '{}'::jsonb and v_ch_rev = '{}'::jsonb and v_ch_scores = '{}'::jsonb
          and not v_gallery_changed then
      v_action := 'unchanged';
    elsif v_published then
      v_payload := jsonb_strip_nulls(jsonb_build_object(
        'item', nullif(v_ch_item, '{}'::jsonb),
        'detail', nullif(v_ch_det, '{}'::jsonb),
        'author_review', nullif(case when v_cur_rev is null and v_ch_rev = '{}'::jsonb and v_ch_scores <> '{}'::jsonb
                                     then '{"visit_type":"paid"}'::jsonb else v_ch_rev end, '{}'::jsonb),
        'scores', case when v_ch_scores <> '{}'::jsonb then v_cur_scores || v_scores end,
        'gallery', case when v_gallery_changed then to_jsonb(v_gallery) end));
      select d.* into v_draft from guide.content_drafts d where d.entity = 'item' and d.entity_id = v_id for update;
      if found then
        if v_draft.payload = v_payload then
          v_action := 'unchanged';
        else
          v_issues := v_issues || guide.import_issue(null, 'pending_draft');
          v_action := 'error';
        end if;
      else
        select s.updated_at into v_version
        from guide.save_draft('item', v_id, v_payload, guide.draft_entity_version('item', v_id)) s;
        v_action := 'drafted';
      end if;
    else
      if v_ch_item <> '{}'::jsonb then
        v_cols := array(select jsonb_object_keys(v_ch_item) order by 1);
        execute format('update guide.items t set (%s) = (select %s from jsonb_populate_record(t, $1) r) where t.id = $2',
                       (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
                       (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
          using v_ch_item, v_id;
      end if;
      if v_ch_det <> '{}'::jsonb then
        v_cols := array(select jsonb_object_keys(v_ch_det) order by 1);
        execute format('update guide.%I t set (%s) = (select %s from jsonb_populate_record(t, $1) r) where t.item_id = $2',
                       v_detail,
                       (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
                       (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
          using v_ch_det, v_id;
      end if;
      v_action := 'updated';
    end if;

    -- Reseña, notas y galería (alta o sin publicar: directo; publicada: ya van en el borrador).
    if v_action in ('created', 'updated') then
      if v_ch_rev <> '{}'::jsonb or v_ch_scores <> '{}'::jsonb then
        select r.id into v_review_id from guide.author_reviews r where r.item_id = v_id;
        if v_review_id is null then
          v_res := jsonb_build_object('body_json_es', '{"type":"doc","content":[]}'::jsonb, 'body_html_es', '', 'visit_type', 'paid') || v_ch_rev;
          v_cols := array(select jsonb_object_keys(v_res) order by 1);
          execute format('insert into guide.author_reviews (item_id, category, %s) select $2, $3, %s from jsonb_populate_record(null::guide.author_reviews, $1) r returning id',
                         (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
                         (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
            into v_review_id using v_res, v_id, p_category;
        elsif v_ch_rev <> '{}'::jsonb then
          v_cols := array(select jsonb_object_keys(v_ch_rev) order by 1);
          execute format('update guide.author_reviews t set (%s) = (select %s from jsonb_populate_record(t, $1) r) where t.id = $2',
                         (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
                         (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
            using v_ch_rev, v_review_id;
        end if;
        insert into guide.author_review_scores (review_id, criterion_id, category, score)
        select v_review_id, e.key::uuid, p_category, (e.value #>> '{}')::smallint from jsonb_each(v_ch_scores) e
        on conflict (review_id, criterion_id) do update set score = excluded.score;
      end if;
      if v_gallery_changed then
        delete from guide.item_media im where im.item_id = v_id;
        insert into guide.item_media (item_id, media_id, sort_order)
        select v_id, g.m, g.o::integer from unnest(v_gallery) with ordinality as g(m, o);
      end if;
      v_version := guide.draft_entity_version('item', v_id);
    end if;

    if p_batch_id is not null and v_action in ('created', 'updated', 'drafted') then
      insert into guide.import_batch_items (batch_id, item_id, action, version_after)
      values (p_batch_id, v_id, v_action, v_version)
      on conflict (batch_id, item_id) do update
        set action = case when guide.import_batch_items.action = 'created' then 'created' else excluded.action end,
            version_after = excluded.version_after, undone_at = null;
    end if;
    if not v_published and v_action <> 'error' then
      v_blockers := guide.item_publish_blockers(v_id);
    end if;
  exception
    when insufficient_privilege then
      raise;
    when others then
      get stacked diagnostics v_state = returned_sqlstate, v_con = constraint_name, v_colname = column_name;
      v_issues := v_issues || case
        when v_state = '23505' and v_con = 'items_category_slug_key' then guide.import_issue('slug', 'slug_taken')
        when v_state = '23505' and v_con = 'shoes_brand_model_key' then guide.import_issue('brand', 'brand_model_taken')
        when v_state = '23514' then guide.import_issue(
          (select a.attname::text from pg_catalog.pg_constraint c join pg_catalog.pg_attribute a
             on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.conname = v_con and c.connamespace = 'guide'::regnamespace limit 1),
          'check', 'error', jsonb_build_object('constraint', v_con))
        when v_state = '23502' then guide.import_issue(nullif(v_colname, ''), 'required')
        when v_state = '23503' then guide.import_issue(null, 'reference_missing')
        when v_state = 'PT423' then guide.import_issue(null, 'live_guard')
        when v_state = 'PT409' then guide.import_issue(null, 'draft_conflict')
        when v_state = 'PT422' then guide.import_issue(null, 'media_no_alt')
        else guide.import_issue(null, 'unexpected', 'error', jsonb_build_object('sqlstate', v_state))
      end;
      v_action := 'error';
      v_id := case when v_cur_item is not null then v_id end;
  end;

  return jsonb_strip_nulls(jsonb_build_object(
    'row', v_rownum, 'key', v_item ->> 'slug', 'action', v_action, 'item_id', v_id, 'published', v_published,
    'blockers', to_jsonb(v_blockers), 'issues', v_issues, 'state', v_tok));
end;
$$;

-- RPC principal. p_mode: 'dry_run' (no escribe nada; devuelve informe y huella) | 'apply' (exige la huella del dry_run;
-- todo o nada por llamada). Máx. 100 filas por llamada; con p_batch_id se suman trozos al mismo lote (máx. 500).
-- Huella = md5(categoría + filas + estado de partida de cada ficha y lo que pasará con ella). Si en apply no coincide
-- (otras filas, o la BD cambió desde la revisión), no se escribe nada y vuelve el informe nuevo con stale = true.
create or replace function guide.admin_import_items(p_category text, p_rows jsonb, p_mode text default 'dry_run',
                                                    p_hash text default null, p_batch_id uuid default null)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_detail   text;
  v_n        integer;
  v_hash     text;
  v_batch    guide.import_batches%rowtype;
  v_rows     jsonb := '[]'::jsonb;
  v_res      jsonb;
  v_row      jsonb;
  v_slugs    jsonb;
  v_bms      jsonb;
  v_slug     text;
  v_bm       text;
  v_errors   integer := 0;
  v_warnings integer := 0;
  v_created  integer := 0;
  v_updated  integer := 0;
  v_drafted  integer := 0;
  v_unchanged integer := 0;
  v_applied  boolean := false;
  v_stale    boolean := false;
  v_states   text := '';
  v_t0       timestamptz := clock_timestamp();
begin
  perform guide.assert_admin();
  if p_mode is null or p_mode not in ('dry_run', 'apply') then
    raise exception 'invalid mode' using errcode = '22023', hint = 'p_mode: dry_run | apply';
  end if;
  v_detail := guide.draft_section_table('item', 'detail', p_category);
  if v_detail is null or not exists (select 1 from guide.item_categories c where c.key = p_category) then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0
     or exists (select 1 from jsonb_array_elements(p_rows) e where jsonb_typeof(e) <> 'object') then
    raise exception 'invalid rows' using errcode = '22023', hint = 'p_rows: array of objects';
  end if;
  v_n := jsonb_array_length(p_rows);
  if v_n > 100 then
    raise exception 'too many rows' using errcode = '22023', hint = 'max 100 rows per call';
  end if;
  if octet_length(p_rows::text) > 2000000 then
    raise exception 'payload too large' using errcode = '22023';
  end if;
  if p_mode = 'apply' and (p_hash is null or p_hash !~ '^[0-9a-f]{32}$') then
    raise exception 'hash required' using errcode = '22023', hint = 'apply needs the hash returned by dry_run for the same rows';
  end if;
  if p_batch_id is not null then
    select b.* into v_batch from guide.import_batches b where b.id = p_batch_id for update;
    if not found then
      raise exception 'batch not found' using errcode = 'P0002';
    end if;
    if v_batch.category <> p_category or v_batch.status <> 'applied' or v_batch.created_by is distinct from (select auth.uid())
       or v_batch.created_at < now() - interval '1 day' then
      raise exception 'invalid batch' using errcode = '22023';
    end if;
    if v_batch.row_count + v_n > 500 then
      raise exception 'batch too large' using errcode = '22023', hint = 'max 500 rows per file';
    end if;
  end if;

  -- Sin exenciones heredadas de la sesión.
  perform set_config('guide.draft_op', '', true);
  perform set_config('guide.unpublish_op', '', true);

  -- Repetidos dentro del archivo (slug; en pies de gato, marca + modelo).
  select coalesce(jsonb_object_agg(s, n), '{}'::jsonb) into v_slugs
  from (select btrim(e ->> 'slug') s, count(*) n from jsonb_array_elements(p_rows) e
        where jsonb_typeof(e -> 'slug') = 'string' group by 1 having count(*) > 1) x;
  select coalesce(jsonb_object_agg(s, n), '{}'::jsonb) into v_bms
  from (select lower(btrim(e ->> 'brand')) || '|' || lower(btrim(e ->> 'model')) s, count(*) n
        from jsonb_array_elements(p_rows) e
        where p_category = 'shoe' and jsonb_typeof(e -> 'brand') = 'string' and jsonb_typeof(e -> 'model') = 'string'
        group by 1 having count(*) > 1) x;

  begin
    if p_mode = 'apply' then
      if v_batch.id is null then
        insert into guide.import_batches (category) values (p_category) returning * into v_batch;
      end if;
      perform set_config('guide.import_batch', v_batch.id::text, true);
    end if;

    for v_row in select e from jsonb_array_elements(p_rows) e loop
      v_slug := btrim(v_row ->> 'slug');
      v_bm := lower(btrim(v_row ->> 'brand')) || '|' || lower(btrim(v_row ->> 'model'));
      v_res := guide.import_row(p_category, v_row, coalesce(v_slugs ? v_slug, false), coalesce(v_bms ? v_bm, false),
                                case when p_mode = 'apply' then v_batch.id end);
      case v_res ->> 'action'
        when 'created' then v_created := v_created + 1;
        when 'updated' then v_updated := v_updated + 1;
        when 'drafted' then v_drafted := v_drafted + 1;
        when 'unchanged' then v_unchanged := v_unchanged + 1;
        else v_errors := v_errors + 1;
      end case;
      v_warnings := v_warnings + (select count(*) from jsonb_array_elements(v_res -> 'issues') x where x ->> 'level' = 'warning');
      v_states := v_states || coalesce(v_res ->> 'state', '') || '>' || (v_res ->> 'action') || ';';
      v_res := v_res - 'state';
      -- En seco los ids de las fichas nuevas no existirán: no se devuelven.
      if p_mode = 'dry_run' and v_res ->> 'action' = 'created' then
        v_res := v_res - 'item_id';
      end if;
      v_rows := v_rows || v_res;
    end loop;

    v_hash := md5(p_category || ':' || p_rows::text || '|' || v_states);
    v_stale := p_mode = 'apply' and v_hash <> p_hash;
    if p_mode = 'dry_run' or v_stale or v_errors > 0 or v_created + v_updated + v_drafted = 0 then
      raise exception using errcode = 'PIR01', message = 'import rollback';
    end if;

    update guide.import_batches b
    set row_count = b.row_count + v_n,
        chunks = b.chunks + 1,
        counts = jsonb_build_object(
          'created', coalesce((b.counts ->> 'created')::integer, 0) + v_created,
          'updated', coalesce((b.counts ->> 'updated')::integer, 0) + v_updated,
          'drafted', coalesce((b.counts ->> 'drafted')::integer, 0) + v_drafted,
          'unchanged', coalesce((b.counts ->> 'unchanged')::integer, 0) + v_unchanged)
    where b.id = v_batch.id;
    perform set_config('guide.import_batch', '', true);
    v_applied := true;
  exception when sqlstate 'PIR01' then
    v_applied := false;
  end;

  return jsonb_build_object(
    'mode', p_mode,
    'applied', v_applied,
    'stale', v_stale,
    'hash', v_hash,
    'batch_id', case when v_applied then v_batch.id end,
    'noop', v_errors = 0 and v_created + v_updated + v_drafted = 0,
    'summary', jsonb_build_object('rows', v_n, 'created', v_created, 'updated', v_updated, 'drafted', v_drafted,
                                  'unchanged', v_unchanged, 'errors', v_errors, 'warnings', v_warnings),
    'elapsed_ms', round(extract(epoch from clock_timestamp() - v_t0) * 1000),
    'rows', v_rows);
end;
$$;

-- Deshacer un lote: borra las fichas creadas que nadie ha tocado (sin publicar, misma versión, sin artículos, agenda
-- ni opiniones) y descarta los borradores nuevos que siguen igual. Las actualizaciones no se deshacen.
create or replace function guide.undo_import_batch(p_batch_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_batch   guide.import_batches%rowtype;
  v_bi      record;
  v_item    record;
  v_draft_at timestamptz;
  v_result  text;
  v_out     jsonb := '[]'::jsonb;
  v_counts  jsonb := '{}'::jsonb;
  v_left    boolean;
  v_state   text;
begin
  perform guide.assert_admin();
  select b.* into v_batch from guide.import_batches b where b.id = p_batch_id for update;
  if not found then
    raise exception 'batch not found' using errcode = 'P0002';
  end if;
  if v_batch.status = 'undone' then
    raise exception 'batch already undone' using errcode = '22023';
  end if;
  perform set_config('guide.draft_op', '', true);
  perform set_config('guide.unpublish_op', '', true);

  for v_bi in select bi.* from guide.import_batch_items bi
              where bi.batch_id = p_batch_id and bi.undone_at is null order by bi.action, bi.item_id loop
    v_result := null;
    begin
      if v_bi.action = 'updated' then
        v_result := 'not_undoable';
      elsif v_bi.action = 'created' then
        select i.published, i.published_at, i.name into v_item from guide.items i where i.id = v_bi.item_id for update;
        if v_item.published or v_item.published_at is not null then
          v_result := 'published';
        elsif guide.draft_entity_version('item', v_bi.item_id) is distinct from v_bi.version_after then
          v_result := 'modified';
        elsif exists (select 1 from guide.article_items ai where ai.item_id = v_bi.item_id) then
          v_result := 'in_article';
        elsif exists (select 1 from guide.events e where e.item_id = v_bi.item_id) then
          v_result := 'in_events';
        elsif exists (select 1 from guide.user_reviews ur where ur.item_id = v_bi.item_id) then
          v_result := 'has_reviews';
        else
          delete from guide.items i where i.id = v_bi.item_id;
          v_result := 'deleted';
        end if;
      else
        select d.updated_at into v_draft_at from guide.content_drafts d
        where d.entity = 'item' and d.entity_id = v_bi.item_id for update;
        if not found then
          v_result := 'gone';
          update guide.import_batch_items bi set undone_at = now() where bi.batch_id = p_batch_id and bi.item_id = v_bi.item_id;
        elsif v_draft_at is distinct from v_bi.version_after then
          v_result := 'modified';
        else
          perform guide.discard_draft('item', v_bi.item_id);
          update guide.import_batch_items bi set undone_at = now() where bi.batch_id = p_batch_id and bi.item_id = v_bi.item_id;
          v_result := 'discarded';
        end if;
      end if;
    exception
      when insufficient_privilege then
        raise;
      when others then
        get stacked diagnostics v_state = returned_sqlstate;
        v_result := 'error:' || v_state;
    end;
    v_out := v_out || jsonb_build_object('item_id', v_bi.item_id, 'action', v_bi.action, 'result', v_result);
    v_counts := v_counts || jsonb_build_object(v_result, coalesce((v_counts ->> v_result)::integer, 0) + 1);
  end loop;

  v_left := exists (select 1 from guide.import_batch_items bi
                    where bi.batch_id = p_batch_id and bi.undone_at is null and bi.action in ('created', 'drafted'));
  update guide.import_batches b
  set status = case when v_left then 'partially_undone' else 'undone' end,
      counts = b.counts || jsonb_build_object('undo', coalesce(b.counts -> 'undo', '{}'::jsonb) || v_counts
                                                       || jsonb_build_object('at', now()))
  where b.id = p_batch_id
  returning * into v_batch;

  return jsonb_build_object('batch_id', p_batch_id, 'status', v_batch.status, 'summary', v_counts, 'results', v_out);
end;
$$;

-- Permisos: solo authenticated (assert_admin dentro); nada para anon.
revoke all on function guide.import_issue(text, text, text, jsonb) from public, anon;
revoke all on function guide.plain_text_doc(text) from public, anon;
revoke all on function guide.review_body_is_empty(text) from public, anon;
revoke all on function guide.import_resolve_media(text) from public, anon;
revoke all on function guide.import_check_value(text, text, jsonb) from public, anon;
revoke all on function guide.import_check_constraints(text, jsonb, text[], text[]) from public, anon;
revoke all on function guide.import_row(text, jsonb, boolean, boolean, uuid) from public, anon;
revoke all on function guide.admin_import_items(text, jsonb, text, text, uuid) from public, anon;
revoke all on function guide.undo_import_batch(uuid) from public, anon;
grant execute on function guide.import_issue(text, text, text, jsonb) to authenticated;
grant execute on function guide.plain_text_doc(text) to authenticated;
grant execute on function guide.review_body_is_empty(text) to authenticated;
grant execute on function guide.import_resolve_media(text) to authenticated;
grant execute on function guide.import_check_value(text, text, jsonb) to authenticated;
grant execute on function guide.import_check_constraints(text, jsonb, text[], text[]) to authenticated;
grant execute on function guide.import_row(text, jsonb, boolean, boolean, uuid) to authenticated;
grant execute on function guide.admin_import_items(text, jsonb, text, text, uuid) to authenticated;
grant execute on function guide.undo_import_batch(uuid) to authenticated;
