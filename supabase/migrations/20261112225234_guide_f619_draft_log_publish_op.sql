-- F6.19 punto 3 (a)(b), observaciones (a)/(b) de F6.7 (docs/security/F6.19-panel-review.md). Idempotente.
-- (a) publish_draft fija guide.draft_op = 'publish:<id>' al borrar el borrador; content_drafts_log_write registra
--     draft_publish solo si el valor coincide exacto con 'publish:' || p_entity_id. Cualquier otro valor (también el
--     'publish' genérico) registra draft_discard. Ningún otro consumidor de guide lee 'publish' literal (comprobado).
-- (b) content_drafts_log_write: tras pg_trigger_depth(), 42501 si no es admin ni sesión postgres, y 42501 si el
--     borrador sigue existiendo. Cuerpo de publish_draft igual al desplegado salvo esa línea. Grants intactos.

create or replace function guide.publish_draft(p_entity text, p_entity_id uuid, p_force boolean default false,
                                               p_revision text default null)
returns timestamptz
language plpgsql
set search_path = ''
as $$
declare
  v_draft    guide.content_drafts%rowtype;
  v_category text;
  v_page_key text;
  v_section  text;
  v_patch    jsonb;
  v_table    text;
  v_key_col  text;
  v_cols     text[];
  v_review   uuid;
  v_base     jsonb;
  v_n        integer;
  v_missing  text[];
begin
  perform guide.assert_admin();
  if p_entity is null or p_entity not in ('article', 'page', 'item') then
    raise exception 'invalid entity' using errcode = '22023';
  end if;
  if p_revision is not null and p_revision not in ('today', 'keep') then
    raise exception 'invalid revision' using errcode = '22023', hint = 'p_revision: today | keep';
  end if;

  -- Bloquea la fila publicada para serializar con otras ediciones.
  case p_entity
    when 'article' then perform 1 from guide.articles a where a.id = p_entity_id for update;
    when 'page' then select p.key into v_page_key from guide.pages p where p.id = p_entity_id for update;
    else select i.category into v_category from guide.items i where i.id = p_entity_id for update;
  end case;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  -- F6.13: la elección de fecha solo existe en las legales.
  if p_revision is not null and coalesce(v_page_key, '') not in ('legal_notice', 'privacy', 'cookies') then
    raise exception 'revision only for legal pages' using errcode = '22023';
  end if;

  select d.* into v_draft from guide.content_drafts d where d.entity_id = p_entity_id and d.entity = p_entity for update;
  if not found then
    raise exception 'draft not found' using errcode = 'P0002';
  end if;

  if guide.draft_entity_version(p_entity, p_entity_id) is distinct from v_draft.base_updated_at
     and p_force is not true then
    raise exception 'draft conflict' using errcode = 'PT409';
  end if;

  -- Revalida por si la lista blanca o el esquema cambiaron desde que se guardó.
  perform guide.draft_check_payload(p_entity, p_entity_id, v_draft.payload);

  -- F6.4 / F6.7 / F6.13: las guardas de lo vivo dejan escribir sobre ESTE artículo, ficha o página solo aquí.
  perform set_config('guide.draft_op', 'apply:' || p_entity_id::text, true);
  if p_entity = 'page' then
    -- Lo lee pages_before_write (solo junto a apply:<id>): 'keep' conserva revised_on aunque cambie el texto.
    perform set_config('guide.page_revision', p_entity_id::text || ':' || coalesce(p_revision, 'today'), true);
  end if;

  -- Secciones de columnas, en orden fijo (la ficha antes que su detalle/reseña).
  foreach v_section in array array['article', 'page', 'item', 'detail', 'author_review'] loop
    v_patch := v_draft.payload -> v_section;
    continue when v_patch is null;
    v_table := guide.draft_section_table(p_entity, v_section, v_category);
    v_key_col := case when v_table in ('gyms', 'resolers', 'shoes', 'author_reviews') then 'item_id' else 'id' end;

    select array_agg(k order by k) into v_cols
    from jsonb_object_keys(v_patch) k
    where k = any (guide.draft_allowed_columns(v_table));
    continue when v_cols is null;

    if v_table = 'author_reviews' and not exists (select 1 from guide.author_reviews r where r.item_id = p_entity_id) then
      -- Reseña nueva sobre una ficha publicada: se crea al publicar, con los defaults de la tabla.
      v_base := jsonb_build_object('body_json_es', '{"type":"doc","content":[]}'::jsonb, 'body_html_es', '',
                                   'visit_type', 'paid') || v_patch;
      select array_agg(k order by k) into v_cols
      from jsonb_object_keys(v_base) k
      where k = any (guide.draft_allowed_columns(v_table));
      execute format(
        'insert into guide.author_reviews (item_id, category, %s) select $2, $3, %s from jsonb_populate_record(null::guide.author_reviews, $1) r',
        (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
        (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c))
        using v_base, p_entity_id, v_category;
    else
      execute format(
        'update guide.%I t set (%s) = (select %s from jsonb_populate_record(t, $1) r) where t.%I = $2',
        v_table,
        (select string_agg(format('%I', c), ', ') from unnest(v_cols) c),
        (select string_agg(format('r.%I', c), ', ') from unnest(v_cols) c),
        v_key_col)
        using v_patch, p_entity_id;
      get diagnostics v_n = row_count;
      if v_n <> 1 then
        raise exception 'draft target row missing: %', v_table using errcode = 'P0002';
      end if;
    end if;
  end loop;
  perform set_config('guide.page_revision', '', true);

  if p_entity = 'article' and v_draft.payload ? 'item_ids' then
    delete from guide.article_items ai where ai.article_id = p_entity_id;
    insert into guide.article_items (article_id, item_id, sort_order)
    select p_entity_id, (e.v #>> '{}')::uuid, e.ord::integer
    from jsonb_array_elements(v_draft.payload -> 'item_ids') with ordinality as e(v, ord);
  end if;

  if p_entity = 'item' and v_draft.payload ? 'gallery' then
    delete from guide.item_media im where im.item_id = p_entity_id;
    insert into guide.item_media (item_id, media_id, sort_order)
    select p_entity_id, (e.v #>> '{}')::uuid, e.ord::integer
    from jsonb_array_elements(v_draft.payload -> 'gallery') with ordinality as e(v, ord);
  end if;

  if p_entity = 'item' and v_draft.payload ? 'scores' then
    select r.id into v_review from guide.author_reviews r where r.item_id = p_entity_id;
    if v_review is null then
      raise exception 'author review missing' using errcode = '22023';
    end if;
    delete from guide.author_review_scores s where s.review_id = v_review;
    insert into guide.author_review_scores (review_id, criterion_id, category, score)
    select v_review, e.key::uuid, v_category, e.value::text::smallint
    from jsonb_each(v_draft.payload -> 'scores') e;
  end if;

  -- D27: el resultado publicado no puede llevar imágenes sin alt (alt_es siempre; alt_en en cuerpos EN), salvo dentro
  -- de unpublish_article / unpublish_item / unpublish_page (V1).
  if not guide.alt_unpublish_bypassed(p_entity_id)
     and not guide.alt_guard_bypassed()
     and coalesce(guide.draft_entity_is_live(p_entity, p_entity_id)
                  or (p_entity = 'article' and exists (select 1 from guide.articles a
                                                       where a.id = p_entity_id and a.status = 'scheduled')), false) then
    v_missing := guide.entity_alt_missing(p_entity, p_entity_id);
    if cardinality(v_missing) > 0 then
      perform guide.raise_missing_alt_reqs(p_entity, p_entity_id, v_missing);
    end if;
  end if;

  -- F6.19 (3a): marca atada al id; content_drafts_log_write solo registra draft_publish si coincide exacta.
  perform set_config('guide.draft_op', 'publish:' || p_entity_id::text, true);
  delete from guide.content_drafts d where d.id = v_draft.id;
  perform set_config('guide.draft_op', '', true);

  return guide.draft_entity_version(p_entity, p_entity_id);
end;
$$;

create or replace function guide.content_drafts_log_write(p_entity text, p_entity_id uuid, p_payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_label   text;
  v_table   text := case p_entity when 'article' then 'articles' when 'page' then 'pages' else 'items' end;
  v_changed text[];
begin
  -- Solo desde el trigger de content_drafts (no por RPC: no se fabrican líneas del registro).
  if pg_catalog.pg_trigger_depth() = 0 then
    raise exception 'trigger only' using errcode = '42501';
  end if;
  -- F6.19 (3b): solo el admin (publish_draft/discard_draft, cascadas de sus borrados) o el sistema (pg_cron,
  -- mantenimiento como postgres). session_user, no current_user: dentro de DEFINER current_user es siempre postgres.
  if not (guide.is_admin() or session_user = 'postgres') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  -- Trigger AFTER DELETE: si el borrador sigue vivo, la línea sería fabricada (no viene de su borrado).
  if exists (select 1 from guide.content_drafts d where d.entity = p_entity and d.entity_id = p_entity_id) then
    raise exception 'draft still exists' using errcode = '42501';
  end if;

  select coalesce(
           (select a.title_es from guide.articles a where p_entity = 'article' and a.id = p_entity_id),
           (select p.title_es from guide.pages p where p_entity = 'page' and p.id = p_entity_id),
           (select i.name from guide.items i where p_entity = 'item' and i.id = p_entity_id))
    into v_label;
  if v_label is null then
    return;
  end if;

  select array_agg(k order by k) into v_changed
  from (
    select s.key || coalesce('.' || c.key, '') as k
    from jsonb_each(p_payload) s
    left join lateral jsonb_each(case when jsonb_typeof(s.value) = 'object' and s.key <> 'scores'
                                      then s.value else '{}'::jsonb end) c on true
  ) x;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns)
  values (
    (select auth.uid()),
    case when coalesce(current_setting('guide.draft_op', true), '') = 'publish:' || p_entity_id::text
         then 'draft_publish'::guide.activity_action else 'draft_discard'::guide.activity_action end,
    v_table,
    p_entity_id::text,
    left(v_label, 200),
    v_changed);
end;
$$;
