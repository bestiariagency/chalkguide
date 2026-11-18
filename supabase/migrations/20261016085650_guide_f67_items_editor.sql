-- F6.7 · Rocódromos (backend del editor de fichas). Genérico por categoría: sirve para gym, resoler y shoe.
--
-- 1. guide.unpublish_item(p_item_id): ocultar una ficha publicada, atómico. Oculta primero y después aplica
--    (y borra) el borrador de cambios pendiente: así la ficha ya no está publicada cuando se aplica y D27 no
--    necesita ninguna exención (ni GUC ni rol). Registra 'unpublish' en activity_log.
-- 2. guide.create_item(p_category, p_name, p_slug, p_detail): alta atómica de items (no publicada) + su fila de
--    detalle (gyms/resolers/shoes según la categoría; p_detail con columnas de su lista blanca, p. ej. brand/model
--    que shoes exige). Slug libre: si está cogido añade -2, -3…
-- 3. guide.gym_indices_preview(p_item_id, p_detail, p_scores): índices de una ficha aunque no esté publicada,
--    con los valores guardados o con los del editor/borrador superpuestos. Solo admin. Misma fórmula que la
--    vista gym_indices (el test F6.7 comprueba que coinciden en una ficha publicada).
-- 4. draft_check_payload: las notas de 'scores' solo pueden ser de criterios de la categoría de la ficha
--    (antes lo frenaba la FK al publicar, con 23503; ahora save_draft responde 22023 'invalid section: scores').
--    content_drafts_log: no duplica el registro cuando unpublish_item aplica el borrador (igual que artículos).

-- ───────────── 4. Validación de scores y log de borradores ─────────────
create or replace function guide.draft_check_payload(p_entity text, p_entity_id uuid, p_payload jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  c_uuid     constant text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
  v_category text;
  v_section  text;
  v_value    jsonb;
  v_table    text;
  v_col      text;
  v_attr     record;
begin
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
    raise exception 'invalid payload' using errcode = '22023';
  end if;
  if p_entity = 'item' then
    select i.category into v_category from guide.items i where i.id = p_entity_id;
    if v_category is null then
      raise exception 'entity not found' using errcode = 'P0002';
    end if;
  end if;

  for v_section, v_value in select e.key, e.value from jsonb_each(p_payload) e loop
    v_table := guide.draft_section_table(p_entity, v_section, v_category);

    if v_table is not null then
      if jsonb_typeof(v_value) <> 'object' or v_value = '{}'::jsonb then
        raise exception 'invalid section: %', left(v_section, 40) using errcode = '22023';
      end if;
      for v_col in select jsonb_object_keys(v_value) loop
        if not (v_col = any (guide.draft_allowed_columns(v_table))) then
          raise exception 'column not allowed: %.%', left(v_section, 40), left(v_col, 64) using errcode = '22023';
        end if;
        select a.attnotnull, a.attgenerated into v_attr
        from pg_catalog.pg_attribute a
        where a.attrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(v_table))
          and a.attname = v_col and a.attnum > 0 and not a.attisdropped;
        if not found or v_attr.attgenerated <> '' then
          raise exception 'draft whitelist out of sync: %.%', v_table, v_col using errcode = 'XX000';
        end if;
        if v_attr.attnotnull and jsonb_typeof(v_value -> v_col) = 'null' then
          raise exception 'column not nullable: %.%', v_section, v_col using errcode = '23502';
        end if;
      end loop;
      -- Tipos: el cast lanza 22P02/22007/22003… si un valor no encaja. v_table viene de la lista fija.
      execute format('select jsonb_populate_record(null::guide.%I, $1)', v_table) using v_value;

    elsif (p_entity = 'article' and v_section = 'item_ids') or (p_entity = 'item' and v_section = 'gallery') then
      if jsonb_typeof(v_value) <> 'array' or jsonb_array_length(v_value) > 100
         or exists (select 1 from jsonb_array_elements(v_value) e
                    where jsonb_typeof(e) <> 'string' or (e #>> '{}') !~ c_uuid)
         or (select count(distinct e) from jsonb_array_elements(v_value) e) <> jsonb_array_length(v_value) then
        raise exception 'invalid section: %', v_section using errcode = '22023';
      end if;

    elsif p_entity = 'item' and v_section = 'scores' then
      if jsonb_typeof(v_value) <> 'object'
         or (select count(*) from jsonb_object_keys(v_value)) > 50
         or exists (select 1 from jsonb_each(v_value) e
                    where e.key !~ c_uuid or jsonb_typeof(e.value) <> 'number' or e.value::text !~ '^[1-5]$') then
        raise exception 'invalid section: scores' using errcode = '22023';
      end if;
      -- F6.7: solo criterios de la categoría de la ficha.
      if exists (select 1 from jsonb_object_keys(v_value) k
                 where not exists (select 1 from guide.criteria c where c.id = k::uuid and c.category = v_category)) then
        raise exception 'invalid section: scores' using errcode = '22023';
      end if;

    else
      raise exception 'section not allowed: %', left(v_section, 40) using errcode = '22023';
    end if;
  end loop;
end;
$$;

create or replace function guide.content_drafts_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_label   text;
  v_table   text := case old.entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end;
  v_changed text[];
begin
  -- unpublish_article / unpublish_item aplican el borrador sin publicar: ya registran su propia entrada 'unpublish'.
  if old.entity in ('article', 'item') and coalesce(current_setting('guide.unpublish_op', true), '') = old.entity_id::text then
    return null;
  end if;

  select coalesce(
           (select a.title_es from guide.articles a where old.entity = 'article' and a.id = old.entity_id),
           (select p.title_es from guide.pages p where old.entity = 'page' and p.id = old.entity_id),
           (select i.name from guide.items i where old.entity = 'item' and i.id = old.entity_id))
    into v_label;
  if v_label is null then
    return null;
  end if;

  select array_agg(k order by k) into v_changed
  from (
    select s.key || coalesce('.' || c.key, '') as k
    from jsonb_each(old.payload) s
    left join lateral jsonb_each(case when jsonb_typeof(s.value) = 'object' and s.key <> 'scores'
                                      then s.value else '{}'::jsonb end) c on true
  ) x;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns)
  values (
    (select auth.uid()),
    case when current_setting('guide.draft_op', true) = 'publish'
         then 'draft_publish'::guide.activity_action else 'draft_discard'::guide.activity_action end,
    v_table,
    old.entity_id::text,
    left(v_label, 200),
    v_changed);
  return null;
end;
$$;

-- ───────────── 1. Ocultar una ficha ─────────────
create or replace function guide.unpublish_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_published boolean;
  v_has_draft boolean;
  v_label     text;
begin
  perform guide.assert_admin();

  select i.published into v_published from guide.items i where i.id = p_item_id for update;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  if not v_published then
    raise exception 'item not live' using errcode = '22023',
      hint = 'Only a published item can be unpublished.';
  end if;

  v_has_draft := exists (select 1 from guide.content_drafts d where d.entity = 'item' and d.entity_id = p_item_id);

  -- Primero se oculta: el borrador se aplica ya sobre una ficha no publicada (D27 no entra; sin exenciones).
  update guide.items i set published = false where i.id = p_item_id
  returning i.name into v_label;

  perform set_config('guide.unpublish_op', p_item_id::text, true);
  if v_has_draft then
    perform guide.publish_draft('item', p_item_id, true);
  end if;
  perform set_config('guide.unpublish_op', '', true);
  perform set_config('guide.draft_op', '', true);

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'unpublish'::guide.activity_action, 'items', p_item_id::text, left(v_label, 200),
          array['published'], jsonb_build_object('draft_applied', v_has_draft));
end;
$$;

-- ───────────── 2. Alta atómica ─────────────
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

  return query select i.id, i.slug, i.updated_at from guide.items i where i.id = v_id;
end;
$$;

-- ───────────── 3. Índices de una ficha no publicada ─────────────
-- p_detail: columnas de gyms (las de draft_allowed_columns('gyms')) que sustituyen a las guardadas.
-- p_scores: {criterion_id: 1..5} que sustituye a las notas guardadas (completo, como en el borrador).
-- price_index se calcula frente a los rocódromos publicados (excluida esta ficha) más esta.
create or replace function guide.gym_indices_preview(p_item_id uuid, p_detail jsonb default null, p_scores jsonb default null)
returns table (monthly_cost_2pw_eur numeric, price_index smallint, beginner_index numeric,
               beginner_index_complete boolean, family_index numeric)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_payload jsonb := '{}'::jsonb;
  v_g       guide.gyms;
  v_cost    numeric;
  v_beg     smallint;
  v_fam     smallint;
  v_bw      numeric;
  v_fw      numeric;
  v_rank    smallint;
begin
  perform guide.assert_admin();
  select g.* into v_g from guide.gyms g where g.item_id = p_item_id;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;

  if p_detail is not null then v_payload := v_payload || jsonb_build_object('detail', p_detail); end if;
  if p_scores is not null then v_payload := v_payload || jsonb_build_object('scores', p_scores); end if;
  if v_payload <> '{}'::jsonb then
    perform guide.draft_check_payload('item', p_item_id, v_payload);
  end if;
  if p_detail is not null then
    v_g := jsonb_populate_record(v_g, p_detail);
  end if;

  if p_scores is not null then
    select (p_scores ->> c.id::text)::smallint into v_beg from guide.criteria c
    where c.category = 'gym' and c.key = 'beginner_friendly';
    select (p_scores ->> c.id::text)::smallint into v_fam from guide.criteria c
    where c.category = 'gym' and c.key = 'family_friendly';
  else
    select s.score into v_beg from guide.author_reviews r
    join guide.author_review_scores s on s.review_id = r.id join guide.criteria c on c.id = s.criterion_id
    where r.item_id = p_item_id and c.key = 'beginner_friendly';
    select s.score into v_fam from guide.author_reviews r
    join guide.author_review_scores s on s.review_id = r.id join guide.criteria c on c.id = s.criterion_id
    where r.item_id = p_item_id and c.key = 'family_friendly';
  end if;

  v_cost := least(v_g.price_monthly_eur + coalesce(v_g.price_registration_eur, 0) / 12,
                  v_g.price_day_eur * (104.0 / 12),
                  v_g.price_10_pass_eur / 10 * (104.0 / 12));

  v_bw := 0.50 * coalesce((v_beg - 1)::numeric / 4.0, 0)
        + 0.20 * coalesce(v_g.has_beginner_courses, false)::integer
        + 0.15 * coalesce(v_g.gear_rental, false)::integer
        + 0.15 * coalesce((not v_g.belay_test_required) or v_g.has_boulder, false)::integer;
  v_fw := (0.40 * coalesce(v_g.has_kids_area, false)::integer
         + 0.20 * coalesce(v_g.kids_min_age <= 6, false)::integer
         + 0.20 * coalesce(v_g.has_cafe, false)::integer
         + 0.20 * coalesce((v_fam - 1)::numeric / 4.0, 0))
        / case when v_fam is null then 0.8 else 1.0 end;

  if v_cost is not null then
    select (6 - t.nt)::smallint into v_rank
    from (
      select x.self, ntile(5) over (order by x.cost) as nt
      from (
        select vi.monthly_cost_2pw_eur as cost, false as self
        from guide.gym_indices vi
        where vi.item_id <> p_item_id and vi.monthly_cost_2pw_eur is not null
        union all
        select round(v_cost, 2), true
      ) x
    ) t
    where t.self;
  end if;

  return query select round(v_cost, 2), v_rank, round(1 + 4 * v_bw, 1),
    (v_beg is not null and v_g.has_beginner_courses is not null and v_g.gear_rental is not null
     and v_g.belay_test_required is not null and v_g.has_boulder is not null),
    round(1 + 4 * v_fw, 1);
end;
$$;

-- ───────────── Grants ─────────────
revoke execute on function guide.unpublish_item(uuid) from public;
revoke execute on function guide.create_item(text, text, text, jsonb) from public;
revoke execute on function guide.gym_indices_preview(uuid, jsonb, jsonb) from public;
grant execute on function guide.unpublish_item(uuid) to authenticated;
grant execute on function guide.create_item(text, text, text, jsonb) to authenticated;
grant execute on function guide.gym_indices_preview(uuid, jsonb, jsonb) to authenticated;
