-- F6.7 · Corrección de guide.create_item (20261016085650): items.slug es del dominio guide.slug y RETURN QUERY
-- exige text exacto en la columna 2 (42804). Solo cambia el cast; firma, validación y grants iguales.

create or replace function guide.create_item(p_category text, p_name text default 'Sin nombre', p_slug text default null,
                                             p_detail jsonb default '{}'::jsonb)
returns table (id uuid, slug text, updated_at timestamptz)
language plpgsql
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_detail text;
  v_name   text;
  v_base   text;
  v_slug   text;
  v_n      integer := 1;
  v_id     uuid;
  v_cols   text[];
begin
  perform guide.assert_admin();
  v_detail := guide.draft_section_table('item', 'detail', p_category);
  if v_detail is null or not exists (select 1 from guide.item_categories c where c.key = p_category) then
    raise exception 'invalid category' using errcode = '22023';
  end if;
  if p_detail is null or jsonb_typeof(p_detail) <> 'object' then
    raise exception 'invalid section: detail' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_detail) k where not (k = any (guide.draft_allowed_columns(v_detail)))) then
    raise exception 'column not allowed: detail' using errcode = '22023';
  end if;
  select array_agg(k order by k) into v_cols from jsonb_object_keys(p_detail) k;
  v_name := coalesce(guide.media_clean_text(p_name, 120), 'Sin nombre');
  v_base := coalesce(nullif(btrim(p_slug), ''), 'sin-nombre');
  if v_base !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or char_length(v_base) > 100 then
    raise exception 'invalid slug' using errcode = '22023';
  end if;

  v_slug := v_base;
  while exists (select 1 from guide.items i where i.category = p_category and i.slug = v_slug) loop
    v_n := v_n + 1;
    if v_n > 200 then
      raise exception 'slug taken' using errcode = '23505';
    end if;
    v_slug := v_base || '-' || v_n;
  end loop;

  insert into guide.items (category, name, slug, published)
  values (p_category, v_name, v_slug, false)
  returning id into v_id;

  -- v_detail sale de la lista fija de draft_section_table (gyms/resolers/shoes); v_cols, de su lista blanca.
  execute format('insert into guide.%I (item_id, category%s) select $1, $2%s from jsonb_populate_record(null::guide.%I, $3) r',
                 v_detail,
                 coalesce((select string_agg(format(', %I', c), '') from unnest(v_cols) c), ''),
                 coalesce((select string_agg(format(', r.%I', c), '') from unnest(v_cols) c), ''),
                 v_detail)
    using v_id, p_category, p_detail;

  return query select i.id, i.slug::text, i.updated_at from guide.items i where i.id = v_id;
end;
$$;
