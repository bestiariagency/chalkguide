-- F6.10 · Criterios de nota del panel (crear, editar ES/EN, activar/desactivar, ordenar por categoría de ficha).
--
-- Auditoría (sin cambios, verificado): RLS de guide.criteria → SELECT anon/authenticated solo activos (is_active),
-- admin todos; INSERT/UPDATE/DELETE solo admin (guide.is_admin()). Categoría válida por FK a item_categories (23503).
-- Notas del autor (author_review_scores) y de usuarios (user_review_scores) referencian (criterion_id, category) con
-- ON DELETE RESTRICT. submit_user_review ya exige criterios activos de la categoría.
--
-- Hallazgos que corrige esta migración:
--   H1. Borrar un criterio con notas fallaba solo por la FK (23503 genérico) y uno citado en borradores de fichas
--       (payload.scores) se borraba y rompía después publish_draft.
--       → criteria_before_write (BEFORE DELETE): 23503 'criterion has scores' con detail
--         'author_review_scores: N, user_review_scores: M, content_drafts: K' y hint de desactivarlo. Sin notas ni
--         borradores, se borra. La FK RESTRICT sigue de red.
--   H2. Las fórmulas de índices (gym_indices y gym_indices_preview) buscan el criterio por key ('beginner_friendly'
--       → beginner_index, 'family_friendly' → family_index). Cambiar la key, la categoría, desactivarlo (RLS lo
--       oculta a anon en vistas security_invoker) o borrarlo degradaba los índices en silencio (beginner pierde el
--       50 %; family reescala) y además distinto para anon y admin.
--       → Columna generada used_in_formula (gym + esas dos keys). id, category y key son inmutables siempre
--         (22023 'criterion <col> is immutable'): la key es el identificador público (item_author_scores.criterion_key,
--         item_user_ratings.avg_by_criterion) y la categoría forma parte de la FK de las notas. Un criterio
--         used_in_formula no se desactiva ni se borra (22023 'criterion used by an index formula').
--         Exención única: mantenimiento explícito (guide.draft_op = 'maintenance' y rolbypassrls, como
--         guide_dummy_purge.sql, que borra los criterios dummy).
--   H3. reorder_criteria no validaba la lista (ids de menos → sort_order duplicados; duplicados/nulos → orden
--       indefinido) y reescribía todas las filas (actividad de más).
--       → Como reorder_article_categories (F6.5): categoría inexistente P0002; lista completa de la categoría
--         (activos e inactivos) sin nulos ni duplicados, si no 22023. Solo se escriben las filas cuyo sort_order
--         cambia: activity_log recibe un 'update' por fila movida (criteria_log_activity, changed_columns
--         {sort_order}).
--   H4. Las vistas públicas (security_invoker) dependían de la RLS para quitar criterios inactivos: anon veía la media
--       del autor sin ellos y el admin con ellos.
--       → item_author_scores e item_user_ratings filtran c.is_active explícitamente: mismo resultado para todos.
--         Efecto de desactivar (configuración, sin borrador): el criterio sale de la ficha pública, la media del
--         autor (avg_overall de item_author_scores) se recalcula sobre los activos y avg_by_criterion pierde su key;
--         la media global de usuarios (overall_score) no cambia; gym_indices no cambia (sus criterios no se
--         desactivan). Las notas se conservan: reactivar lo restaura todo.
--   H5. draft_check_payload aceptaba notas de criterios inactivos.
--       → Un criterio inactivo solo admite la nota que la ficha ya tenía guardada (el editor reenvía las notas
--         guardadas al cambiar otras); una nota nueva → 22023 'invalid section: scores', detail 'inactive criterion'.
--         (Fuera de categoría: mismo mensaje, detail 'criterion not in category'.)
--   H6. Validación: key '^[a-z][a-z0-9]*(_[a-z0-9]+)*$' (2..40); name_es y name_en obligatorios (1..80, sin
--       controles, sin espacios ni invisibles Unicode en los extremos); descripciones opcionales (1..300, recortadas).
--       Alta sin sort_order (o <= 0) → al final de su categoría.
-- Idempotente.

-- ───────────── H2. Columna generada: criterio usado por una fórmula ─────────────
alter table guide.criteria add column if not exists used_in_formula boolean
  generated always as (category = 'gym' and key in ('beginner_friendly', 'family_friendly')) stored;
comment on column guide.criteria.used_in_formula is
  'F6.10. true si gym_indices/gym_indices_preview lo usa por key (beginner_friendly → beginner_index, '
  'family_friendly → family_index). No se desactiva ni se borra. Ampliar la lista al añadir una fórmula.';

-- ───────────── H6. Validación ─────────────
alter table guide.criteria drop constraint if exists criteria_key_check;
alter table guide.criteria add constraint criteria_key_check
  check (key ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$' and char_length(key) between 2 and 40);

alter table guide.criteria alter column name_en set not null;

alter table guide.criteria drop constraint if exists criteria_name_es_check;
alter table guide.criteria add constraint criteria_name_es_check
  check (char_length(name_es) between 1 and 80 and name_es !~ '[[:cntrl:]]');
alter table guide.criteria drop constraint if exists criteria_name_en_check;
alter table guide.criteria add constraint criteria_name_en_check
  check (char_length(name_en) between 1 and 80 and name_en !~ '[[:cntrl:]]');
alter table guide.criteria drop constraint if exists criteria_name_es_trimmed;
alter table guide.criteria add constraint criteria_name_es_trimmed check (
  name_es !~ '^[[:space:]  ᠎ -‏ -  -⁤　﻿]|[[:space:]  ᠎ -‏ -  -⁤　﻿]$'
);
alter table guide.criteria drop constraint if exists criteria_name_en_trimmed;
alter table guide.criteria add constraint criteria_name_en_trimmed check (
  name_en !~ '^[[:space:]  ᠎ -‏ -  -⁤　﻿]|[[:space:]  ᠎ -‏ -  -⁤　﻿]$'
);
alter table guide.criteria drop constraint if exists criteria_description_es_check;
alter table guide.criteria add constraint criteria_description_es_check check (
  char_length(description_es) between 1 and 300
  and description_es !~ '^[[:space:]  ᠎ -‏ -  -⁤　﻿]|[[:space:]  ᠎ -‏ -  -⁤　﻿]$'
);
alter table guide.criteria drop constraint if exists criteria_description_en_check;
alter table guide.criteria add constraint criteria_description_en_check check (
  char_length(description_en) between 1 and 300
  and description_en !~ '^[[:space:]  ᠎ -‏ -  -⁤　﻿]|[[:space:]  ᠎ -‏ -  -⁤　﻿]$'
);

-- ───────────── H1/H2/H6. Guardas en BD ─────────────
-- SECURITY INVOKER: solo admin llega aquí por RLS (y ve todas las notas y borradores); la exención de mantenimiento
-- mira rolbypassrls de current_user, que en DEFINER sería siempre el dueño.
create or replace function guide.criteria_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_maint boolean := coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
                     and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false);
  v_formula boolean;
  v_author  bigint;
  v_user    bigint;
  v_drafts  bigint;
begin
  if tg_op = 'INSERT' then
    if new.sort_order is null or new.sort_order <= 0 then
      select coalesce(max(c.sort_order), 0) + 1 into new.sort_order
      from guide.criteria c where c.category = new.category;
    end if;
    return new;
  end if;

  v_formula := old.category = 'gym' and old.key in ('beginner_friendly', 'family_friendly');

  if tg_op = 'UPDATE' then
    if not v_maint then
      if new.id is distinct from old.id then
        raise exception 'criterion id is immutable' using errcode = '22023';
      end if;
      if new.category is distinct from old.category then
        raise exception 'criterion category is immutable' using errcode = '22023',
          hint = 'Create a new criterion in the other category.';
      end if;
      if new.key is distinct from old.key then
        raise exception 'criterion key is immutable' using errcode = '22023',
          hint = 'The key identifies the criterion in public data and index formulas; edit name_es/name_en instead.';
      end if;
      if v_formula and old.is_active and not new.is_active then
        raise exception 'criterion used by an index formula' using errcode = '22023',
          detail = old.category || '.' || old.key,
          hint = 'gym_indices uses this criterion: it cannot be deactivated or deleted.';
      end if;
    end if;
    return new;
  end if;

  if v_formula and not v_maint then
    raise exception 'criterion used by an index formula' using errcode = '22023',
      detail = old.category || '.' || old.key,
      hint = 'gym_indices uses this criterion: it cannot be deactivated or deleted.';
  end if;
  select count(*) into v_author from guide.author_review_scores s where s.criterion_id = old.id;
  select count(*) into v_user from guide.user_review_scores s where s.criterion_id = old.id;
  select count(*) into v_drafts from guide.content_drafts d
  where d.entity = 'item' and jsonb_typeof(d.payload -> 'scores') = 'object' and (d.payload -> 'scores') ? old.id::text;
  if v_author + v_user + v_drafts > 0 then
    raise exception 'criterion has scores' using errcode = '23503',
      detail = format('author_review_scores: %s, user_review_scores: %s, content_drafts: %s', v_author, v_user, v_drafts),
      hint = 'Deactivate it instead (is_active = false): scores are kept.';
  end if;
  return old;
end;
$$;

revoke execute on function guide.criteria_before_write() from public, anon, authenticated;

drop trigger if exists criteria_before_write on guide.criteria;
create trigger criteria_before_write before insert or update or delete on guide.criteria
  for each row execute function guide.criteria_before_write();

-- ───────────── H3. reorder_criteria ─────────────
create or replace function guide.reorder_criteria(p_category text, p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if not exists (select 1 from guide.item_categories ic where ic.key = p_category) then
    raise exception 'category not found' using errcode = 'P0002';
  end if;
  if p_ids is null or array_position(p_ids, null) is not null then
    raise exception 'ids required' using errcode = '22023';
  end if;
  if (select count(distinct u) from unnest(p_ids) u) <> cardinality(p_ids) then
    raise exception 'duplicate ids' using errcode = '22023';
  end if;
  if exists (
    select 1 from unnest(p_ids) as u(id)
    left join guide.criteria c on c.id = u.id and c.category = p_category
    where c.id is null
  ) then
    raise exception 'criteria must belong to the category' using errcode = '22023';
  end if;
  if (select count(*) from guide.criteria c where c.category = p_category) <> cardinality(p_ids) then
    raise exception 'list must include every criterion of the category' using errcode = '22023';
  end if;

  update guide.criteria c
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where c.id = x.id and c.sort_order is distinct from x.ord::integer;
end;
$$;

revoke execute on function guide.reorder_criteria(text, uuid[]) from public, anon;
grant execute on function guide.reorder_criteria(text, uuid[]) to authenticated, service_role;
comment on function guide.reorder_criteria(text, uuid[]) is
  'F6.10. Orden de los criterios de una categoría (1..n), activos e inactivos. Categoría inexistente P0002; lista '
  'incompleta, ajena, con nulos o duplicados 22023 (ids required, duplicate ids, criteria must belong to the category, '
  'list must include every criterion of the category). Solo escribe las filas que cambian. Solo admin (42501).';

-- ───────────── H4. Vistas públicas: solo criterios activos, igual para todos ─────────────
create or replace view guide.item_author_scores with (security_invoker = true) as
select r.item_id,
  c.id as criterion_id,
  c.key as criterion_key,
  c.name_es,
  c.name_en,
  c.sort_order,
  s.score,
  round(avg(s.score) over (partition by r.item_id), 2) as avg_overall
from guide.author_reviews r
join guide.author_review_scores s on s.review_id = r.id
join guide.criteria c on c.id = s.criterion_id
where c.is_active;

create or replace view guide.item_user_ratings with (security_invoker = true) as
with settings as (
  select coalesce((select s_1.min_user_reviews_for_average from guide.site_settings s_1 where s_1.id = 1)::integer, 3) as min_n
), visible as (
  select ur.id, ur.item_id, ur.overall_score
  from guide.user_reviews ur
  where ur.status = 'visible'::guide.review_status
), counts as (
  select v.item_id, count(*)::integer as review_count, round(avg(v.overall_score), 2) as avg_overall
  from visible v
  group by v.item_id
), by_criterion as (
  select x.item_id, jsonb_object_agg(x.key, x.avg_score) as avg_by_criterion
  from (
    select v.item_id, c_1.key, round(avg(sc.score), 2) as avg_score
    from visible v
    join guide.user_review_scores sc on sc.review_id = v.id
    join guide.criteria c_1 on c_1.id = sc.criterion_id
    where c_1.is_active
    group by v.item_id, c_1.key
    having count(*) >= (select s_1.min_n from settings s_1)
  ) x
  group by x.item_id
)
select c.item_id,
  c.review_count,
  case when c.review_count >= s.min_n then c.avg_overall else null::numeric end as avg_overall,
  case when c.review_count >= s.min_n then b.avg_by_criterion else null::jsonb end as avg_by_criterion
from counts c
cross join settings s
left join by_criterion b on b.item_id = c.item_id;

-- ───────────── H5. draft_check_payload: notas de criterios inactivos ─────────────
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
  v_con      record;
  v_key      text;
  v_ok       boolean;
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
      execute format('select jsonb_populate_record(null::guide.%I, $1)', v_table) using v_value;
      v_key := case when v_table in ('articles', 'pages', 'items') then 'id' else 'item_id' end;
      for v_con in select c.conname, pg_catalog.pg_get_constraintdef(c.oid) as def
                   from pg_catalog.pg_constraint c
                   where c.conrelid = pg_catalog.to_regclass('guide.' || pg_catalog.quote_ident(v_table))
                     and c.contype = 'c' and c.convalidated
                   order by c.conname loop
        execute format(
          'select coalesce(bool_and(coalesce((%s), true)), true) from (select (jsonb_populate_record(t, $1)).* from guide.%I t where t.%I = $2) s',
          regexp_replace(v_con.def, '^CHECK \((.*)\)$', '\1'), v_table, v_key)
          into v_ok using v_value, p_entity_id;
        if not v_ok then
          raise exception 'check violation: %', v_con.conname using errcode = '23514', constraint = v_con.conname;
        end if;
      end loop;

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
      if exists (select 1 from jsonb_object_keys(v_value) k
                 where not exists (select 1 from guide.criteria c where c.id = k::uuid and c.category = v_category)) then
        raise exception 'invalid section: scores' using errcode = '22023', detail = 'criterion not in category';
      end if;
      if exists (select 1 from jsonb_object_keys(v_value) k
                 join guide.criteria c on c.id = k::uuid
                 where not c.is_active
                   and not exists (select 1 from guide.author_reviews r
                                   join guide.author_review_scores s on s.review_id = r.id
                                   where r.item_id = p_entity_id and s.criterion_id = c.id)) then
        raise exception 'invalid section: scores' using errcode = '22023', detail = 'inactive criterion';
      end if;

    else
      raise exception 'section not allowed: %', left(v_section, 40) using errcode = '22023';
    end if;
  end loop;
end;
$$;
