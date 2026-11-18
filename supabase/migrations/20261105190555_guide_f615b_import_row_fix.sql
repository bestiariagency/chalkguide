-- F6.15b: guide.import_row corregida tras la primera prueba.
-- * En fichas nuevas v_published quedaba NULL (select into sin fila) y no salían los bloqueos de publicación.
-- * `text[] || 'literal'` tomaba el literal como array (22P02) con un horario no válido.
-- * El informe añade `hidden` (oculta: se actualiza directamente y sigue oculta) y `changes` (antes → después).

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
  v_crit_keys jsonb := '{}'::jsonb;  -- criterion_id -> clave
  v_changes   jsonb := '[]'::jsonb;
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
    v_published := coalesce(v_published, false);  -- sin fila, el select deja NULL

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
    v_err_cols := array_append(v_err_cols, 'opening_hours');
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
          v_crit_keys := v_crit_keys || jsonb_build_object(v_crit.id::text, v_key);
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

  -- Cambios para «N cambios ▾» (antes → después) de la revisión. Solo fichas existentes; la RPC es solo admin.
  if v_id is not null then
    select v_changes || coalesce(jsonb_agg(jsonb_build_object('column', x.col, 'before', x.bef, 'after', x.aft) order by x.ord, x.col), '[]'::jsonb)
      into v_changes
    from (
      select 1 ord, e.key col, v_cur_item -> e.key bef, e.value aft from jsonb_each(v_ch_item) e
      union all select 2, e.key, v_cur_det -> e.key, e.value from jsonb_each(v_ch_det) e
      union all select 3, e.key, v_cur_rev -> e.key, e.value from jsonb_each(v_ch_rev) e where e.key !~ '^body_'
      union all select 4, 'review_text_' || right(e.key, 2), null, null from jsonb_each(v_ch_rev) e where e.key ~ '^body_html_'
      union all select 5, 'scores.' || (v_crit_keys ->> e.key), v_cur_scores -> e.key, e.value from jsonb_each(v_ch_scores) e
      union all select 6, 'gallery', to_jsonb(v_cur_gallery), to_jsonb(v_gallery) where v_gallery_changed
    ) x;
  end if;

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
    'hidden', not v_published and v_cur_item ->> 'published_at' is not null,
    'blockers', to_jsonb(v_blockers), 'issues', v_issues, 'changes', nullif(v_changes, '[]'::jsonb), 'state', v_tok));
end;
$$;

revoke all on function guide.import_row(text, jsonb, boolean, boolean, uuid) from public, anon;
grant execute on function guide.import_row(text, jsonb, boolean, boolean, uuid) to authenticated;
