-- F6.15 · O4 de leona-lia: export_build rechaza (22023) una proyección vacía o nula en vez de dejar salir todas las
-- columnas (cuerpo incluido). Hoy no es alcanzable; es defensa en profundidad. Misma firma; el resto sin cambios.
-- Idempotente.

create or replace function guide.export_build(p_module text, p_format text, p_filters jsonb, p_count_only boolean)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  c_cap_max   constant integer := 50000;
  c_uuid      constant text := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
  c_purposes  constant text[] := array['backup', 'send_tool', 'data_request', 'audit', 'other'];
  c_sub_min   constant text[] := array['email', 'locale', 'status', 'consent_at', 'confirmed_at'];
  v_cap_set   text := current_setting('guide.export_cap', true);
  v_cap       integer := c_cap_max;
  v_take      integer;
  v_f         jsonb := coalesce(p_filters, '{}'::jsonb);
  v_view      text;
  v_allowed   text[];
  v_key       text;
  v_all_cols  text[];
  v_permitted text[];
  v_default   text[];
  v_cols      text[];
  v_drop      text[];
  v_clean     jsonb := '{}'::jsonb;
  -- filtros ya validados
  v_statuses  text[];
  v_df        text;
  v_from      timestamptz;
  v_to        timestamptz;
  v_ids       uuid[];
  v_category  text;
  v_cat_id    uuid;
  v_item_id   uuid;
  v_has_en    boolean;
  v_published boolean;
  v_with_body boolean;
  v_locale    text;
  v_source    text;
  v_sources   text[];
  v_types     text[];
  v_versions  integer[];
  v_purpose   text;
  v_n         bigint;
  v_rows      jsonb;
begin
  if v_cap_set ~ '^\d{1,6}$' then
    v_cap := least(c_cap_max, greatest(1, v_cap_set::integer));
  end if;

  if p_module is null or p_module not in ('articles', 'items', 'user_reviews', 'subscribers', 'events') then
    raise exception 'invalid module' using errcode = '22023';
  end if;
  if not p_count_only and (p_format is null or p_format not in ('csv', 'json')) then
    raise exception 'invalid format' using errcode = '22023';
  end if;
  if jsonb_typeof(v_f) <> 'object' then
    raise exception 'invalid filters' using errcode = '22023';
  end if;
  v_view := 'export_' || p_module;

  v_allowed := array['statuses', 'date_field', 'from', 'to', 'ids', 'columns'] ||
    case p_module
      when 'articles'     then array['category_id', 'has_en', 'with_body']
      when 'items'        then array['category', 'published', 'has_en', 'with_body']
      when 'user_reviews' then array['category', 'locale', 'item_id']
      when 'subscribers'  then array['sources', 'locale', 'consent_version', 'purpose']
      when 'events'       then array['source', 'event_types', 'item_id']
    end;
  for v_key in select jsonb_object_keys(v_f) loop
    if not (v_key = any (v_allowed)) then
      raise exception 'invalid filter: %', left(v_key, 40) using errcode = '22023';
    end if;
  end loop;

  -- Comunes
  v_statuses := guide.export_f_text_array('statuses', v_f -> 'statuses', 10, '^[a-z_]{1,20}$');
  if v_statuses is not null and exists (
       select 1 from unnest(v_statuses) x
       where x not in (select unnest(case p_module
                                       when 'articles'     then array['draft', 'scheduled', 'published']
                                       when 'items'        then array[]::text[]
                                       when 'user_reviews' then array['pending', 'visible', 'hidden']
                                       when 'subscribers'  then array['pending', 'active', 'unsubscribed', 'bounced', 'expired']
                                       when 'events'       then array['draft', 'approved', 'cancelled', 'rejected']
                                     end))) then
    raise exception 'invalid filter: statuses' using errcode = '22023';
  end if;
  -- D-C: suscriptores, por defecto solo activos. Opiniones: por defecto visibles (§12.2). Los suprimidos nunca.
  if v_statuses is null and p_module = 'subscribers' then v_statuses := array['active']; end if;
  if v_statuses is null and p_module = 'user_reviews' then v_statuses := array['visible']; end if;

  v_df := guide.export_f_text('date_field', v_f -> 'date_field', '^[a-z_]{1,20}$');
  v_df := coalesce(v_df, case p_module when 'articles' then 'published_at' when 'items' then 'created_at'
                                      when 'user_reviews' then 'created_at' when 'subscribers' then 'consent'
                                      when 'events' then 'starts_at' end);
  if not (v_df = any (case p_module
                        when 'articles'     then array['published_at', 'created_at', 'updated_at']
                        when 'items'        then array['created_at', 'updated_at', 'published_at', 'verified_at']
                        when 'user_reviews' then array['created_at', 'moderated_at', 'edited_at']
                        when 'subscribers'  then array['consent', 'confirmed', 'unsubscribed']
                        when 'events'       then array['starts_at', 'created_at', 'approved_at']
                      end)) then
    raise exception 'invalid filter: date_field' using errcode = '22023';
  end if;
  v_from := guide.export_f_ts('from', v_f -> 'from', false);
  v_to   := guide.export_f_ts('to', v_f -> 'to', true);
  if v_from is not null and v_to is not null and v_from >= v_to then
    raise exception 'invalid filter: range' using errcode = '22023';
  end if;
  v_ids := guide.export_f_text_array('ids', v_f -> 'ids', 5000, c_uuid)::uuid[];

  -- Por módulo
  if p_module in ('items', 'user_reviews') then
    v_category := guide.export_f_text('category', v_f -> 'category', '^[a-z_]{1,40}$');
    if v_category is not null and not exists (select 1 from guide.item_categories c where c.key = v_category) then
      raise exception 'invalid filter: category' using errcode = '22023';
    end if;
  end if;
  if p_module = 'articles' then
    v_cat_id := guide.export_f_text('category_id', v_f -> 'category_id', c_uuid)::uuid;
  end if;
  if p_module in ('user_reviews', 'events') then
    v_item_id := guide.export_f_text('item_id', v_f -> 'item_id', c_uuid)::uuid;
  end if;
  if p_module in ('articles', 'items') then
    v_has_en := guide.export_f_bool('has_en', v_f -> 'has_en');
    v_with_body := coalesce(guide.export_f_bool('with_body', v_f -> 'with_body'), false);
  end if;
  if p_module = 'items' then
    v_published := guide.export_f_bool('published', v_f -> 'published');
  end if;
  if p_module in ('user_reviews', 'subscribers') then
    v_locale := guide.export_f_text('locale', v_f -> 'locale', '^(es|en)$');
  end if;
  if p_module = 'subscribers' then
    v_sources := guide.export_f_text_array('sources', v_f -> 'sources', 20, '^[a-z0-9_]{1,40}$');
    if v_f -> 'consent_version' is not null and jsonb_typeof(v_f -> 'consent_version') <> 'null' then
      if jsonb_typeof(v_f -> 'consent_version') <> 'array' or jsonb_array_length(v_f -> 'consent_version') not between 1 and 50
         or exists (select 1 from jsonb_array_elements(v_f -> 'consent_version') x
                    where jsonb_typeof(x) <> 'number' or (x #>> '{}') !~ '^\d{1,6}$') then
        raise exception 'invalid filter: consent_version' using errcode = '22023';
      end if;
      select array_agg(distinct (x #>> '{}')::integer) into v_versions from jsonb_array_elements(v_f -> 'consent_version') x;
    end if;
    v_purpose := guide.export_f_text('purpose', v_f -> 'purpose', '^[a-z_]{1,20}$');
    if v_purpose is not null and not (v_purpose = any (c_purposes)) then
      raise exception 'invalid filter: purpose' using errcode = '22023';
    end if;
    -- §12.3: la finalidad es obligatoria para descargar (no para contar).
    if not p_count_only and v_purpose is null then
      raise exception 'purpose required' using errcode = '22023';
    end if;
  end if;
  if p_module = 'events' then
    v_source := guide.export_f_text('source', v_f -> 'source', '^(manual|agent)$');
    v_types  := guide.export_f_text_array('event_types', v_f -> 'event_types', 20, '^[a-z0-9_]{1,40}$');
  end if;

  -- D-A: el cuerpo solo en JSON. D-B: el CSV de fichas va por categoría.
  if not p_count_only and p_format = 'csv' and v_with_body then
    raise exception 'with_body only in json' using errcode = '22023';
  end if;
  if not p_count_only and p_format = 'csv' and p_module = 'items' and v_category is null then
    raise exception 'csv needs category' using errcode = '22023';
  end if;

  -- Columnas: las de la vista en su orden; las del cuerpo solo con with_body; suscriptores con preajuste.
  select array_agg(a.attname::text order by a.attnum) into v_all_cols
  from pg_attribute a
  where a.attrelid = ('guide.' || v_view)::regclass and a.attnum > 0 and not a.attisdropped;
  v_permitted := case
    when p_module = 'articles' and not v_with_body then array_remove(array_remove(v_all_cols, 'body_html_es'), 'body_html_en')
    when p_module = 'items' and not v_with_body then array_remove(array_remove(v_all_cols, 'author_body_html_es'), 'author_body_html_en')
    else v_all_cols end;
  v_default := case when p_module = 'subscribers' then c_sub_min else v_permitted end;

  if v_f -> 'columns' is null or jsonb_typeof(v_f -> 'columns') = 'null' then
    v_cols := v_default;
  elsif jsonb_typeof(v_f -> 'columns') = 'string' then
    v_cols := case
      when p_module = 'subscribers' and v_f ->> 'columns' = 'min' then c_sub_min
      when v_f ->> 'columns' = 'all' or (p_module = 'subscribers' and v_f ->> 'columns' = 'proof') then v_permitted
    end;
    if v_cols is null then raise exception 'invalid filter: columns' using errcode = '22023'; end if;
  else
    v_cols := guide.export_f_text_array('columns', v_f -> 'columns', 80, '^[a-z0-9_]{1,40}$');
    if exists (select 1 from unnest(v_cols) c where not (c = any (v_permitted))) then
      raise exception 'invalid filter: columns' using errcode = '22023';
    end if;
  end if;
  select array_agg(c order by o) into v_cols from unnest(v_permitted) with ordinality p(c, o) where c = any (v_cols);
  -- O4 (leona-lia): defensa en profundidad; sin columnas no se exporta (nunca «todas» por omisión).
  if coalesce(cardinality(v_cols), 0) = 0 then
    raise exception 'invalid filter: columns' using errcode = '22023';
  end if;
  select coalesce(array_agg(c), '{}') into v_drop from unnest(v_all_cols) c where not (c = any (v_cols));
  v_take := case when p_count_only then 0 else v_cap end;   -- el recuento no construye filas

  -- Filas
  if p_module = 'articles' then
    with b as (
      select v.*, row_number() over (order by v.published_at desc nulls last, v.created_at desc, v.id) as rn
      from guide.export_articles v
      where (v_statuses is null or v.status::text = any (v_statuses))
        and (v_cat_id is null or v.category_id = v_cat_id)
        and (v_has_en is null or v.has_en = v_has_en)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                          else v.updated_at end) >= v_from)
        and (v_to is null or (case v_df when 'published_at' then v.published_at when 'created_at' then v.created_at
                                        else v.updated_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'items' then
    with b as (
      select v.*, row_number() over (order by v.category, v.name, v.id) as rn
      from guide.export_items v
      where (v_category is null or v.category = v_category)
        and (v_published is null or v.published = v_published)
        and (v_has_en is null or v.has_en = v_has_en)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'created_at' then v.created_at when 'updated_at' then v.updated_at
                                          when 'published_at' then v.published_at
                                          else v.verified_at::timestamp at time zone 'Europe/Madrid' end) >= v_from)
        and (v_to is null or (case v_df when 'created_at' then v.created_at when 'updated_at' then v.updated_at
                                        when 'published_at' then v.published_at
                                        else v.verified_at::timestamp at time zone 'Europe/Madrid' end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'user_reviews' then
    with b as (
      select v.*, row_number() over (order by v.created_at desc, v.id) as rn
      from guide.export_user_reviews v
      where (v.status::text = any (v_statuses))
        and (v_category is null or v.category = v_category)
        and (v_locale is null or v.locale::text = v_locale)
        and (v_item_id is null or v.item_id = v_item_id)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'created_at' then v.created_at when 'moderated_at' then v.moderated_at
                                          else v.edited_at end) >= v_from)
        and (v_to is null or (case v_df when 'created_at' then v.created_at when 'moderated_at' then v.moderated_at
                                        else v.edited_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  elsif p_module = 'subscribers' then
    with b as (
      select v.*, row_number() over (order by v.consent_at desc nulls last, v.id) as rn
      from guide.export_subscribers v
      where v.status::text = any (v_statuses)
        and (v_locale is null or v.locale::text = v_locale)
        and (v_sources is null or v.consent_source = any (v_sources))
        and (v_versions is null or v.consent_version = any (v_versions))
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'consent' then v.consent_at when 'confirmed' then v.confirmed_at
                                          else v.unsubscribed_at end) >= v_from)
        and (v_to is null or (case v_df when 'consent' then v.consent_at when 'confirmed' then v.confirmed_at
                                        else v.unsubscribed_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  else
    with b as (
      select v.*, row_number() over (order by v.starts_at, v.id) as rn
      from guide.export_events v
      where (v_statuses is null or v.status::text = any (v_statuses))
        and (v_source is null or v.source::text = v_source)
        and (v_types is null or v.event_type = any (v_types))
        and (v_item_id is null or v.item_id = v_item_id)
        and (v_ids is null or v.id = any (v_ids))
        and (v_from is null or (case v_df when 'starts_at' then v.starts_at when 'created_at' then v.created_at
                                          else v.approved_at end) >= v_from)
        and (v_to is null or (case v_df when 'starts_at' then v.starts_at when 'created_at' then v.created_at
                                        else v.approved_at end) < v_to))
    select count(*), coalesce(jsonb_agg(to_jsonb(b) - 'rn' - v_drop order by b.rn) filter (where b.rn <= v_take), '[]'::jsonb)
      into v_n, v_rows from b;
  end if;

  -- Filtros saneados para el registro: valores ya validados; ids solo como número; nunca texto libre.
  v_clean := jsonb_strip_nulls(jsonb_build_object(
    'statuses', to_jsonb(v_statuses), 'date_field', v_df,
    'from', to_jsonb(v_from), 'to', to_jsonb(v_to),
    'ids_count', case when v_ids is not null then cardinality(v_ids) end,
    'category', v_category, 'category_id', v_cat_id, 'item_id', v_item_id,
    'has_en', v_has_en, 'published', v_published, 'with_body', case when v_with_body then true end,
    'locale', v_locale, 'sources', to_jsonb(v_sources), 'consent_version', to_jsonb(v_versions),
    'source', v_source, 'event_types', to_jsonb(v_types)));

  if p_count_only then
    return jsonb_build_object('module', p_module, 'total', v_n,
                              'row_count', least(v_n, v_cap), 'truncated', v_n > v_cap,
                              'columns', to_jsonb(v_cols), 'filters', v_clean);
  end if;

  return jsonb_build_object(
    'export', jsonb_build_object(
      'module', p_module, 'view', v_view, 'format', p_format, 'exported_at', now(),
      'filters', v_clean, 'columns', to_jsonb(v_cols),
      'row_count', jsonb_array_length(v_rows), 'total', v_n, 'truncated', v_n > jsonb_array_length(v_rows),
      'personal_data', p_module = 'subscribers', 'purpose', v_purpose, 'format_version', 1),
    'rows', v_rows);
end;
$$;

revoke all on function guide.export_build(text, text, jsonb, boolean) from public, anon, authenticated, service_role;
