-- F6.4 · observación (1) de leona-lia: un admin podía crear un "publicado invisible" (status = 'published'
-- con published_at futura): no sale en la web, no lo publica publish_due_articles y, al no estar vivo,
-- tampoco lo protege el bloqueo de lo vivo (contenido editable en directo moviendo la fecha al futuro).
-- Decisión: 'published' significa visible ya. Si llega con fecha futura, el trigger la fija a now()
-- (como ya hacía con published_at null). Programar es 'scheduled'. Ni rechazarlo ni convertirlo en
-- 'scheduled': "Publicar ahora" del panel envía la hora del navegador y un reloj adelantado unos segundos
-- haría fallar la publicación o la dejaría programada hasta el siguiente publish_due_articles.
-- Único cambio frente a 20261009125747: la primera condición del trigger. Idempotente (create or replace).
create or replace function guide.articles_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_words   integer;
  v_op      text;
  v_changed text[];
begin
  if new.status = 'published' and (new.published_at is null or new.published_at > now()) then
    new.published_at := now();
  elsif new.status = 'scheduled' then
    if new.published_at is null then
      raise exception 'scheduled articles need published_at' using errcode = '23514';
    end if;
    if new.published_at <= now() then
      if tg_op = 'INSERT' or old.status is distinct from 'scheduled'
         or old.published_at is distinct from new.published_at then
        raise exception 'scheduled date must be in the future' using errcode = '23514';
      end if;
      new.status := 'published';
    end if;
  end if;

  -- Vivo antes y después (reloj del servidor): el contenido solo cambia vía borrador de cambios.
  if tg_op = 'UPDATE'
     and guide.article_is_live(old.status, old.published_at)
     and guide.article_is_live(new.status, new.published_at) then
    v_op := coalesce(current_setting('guide.draft_op', true), '');
    if v_op is distinct from 'apply:' || old.id::text and not (coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
         and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)) then
      select array_agg(k order by k) into v_changed
      from unnest(guide.draft_allowed_columns('articles')) k
      where (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k);
      if v_changed is not null
         and not (v_op = 'reassign_category' and v_changed = array['category_id']) then
        raise exception 'article is live'
          using errcode = 'PT423',
                detail = 'changed: ' || array_to_string(v_changed, ', '),
                hint = 'Edit a live article through save_draft/publish_draft, or unpublish/reschedule it first.';
      end if;
    end if;
  end if;

  if tg_op = 'INSERT' or new.body_html_es is distinct from old.body_html_es then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_es := case when btrim(regexp_replace(coalesce(new.body_html_es, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  if tg_op = 'INSERT' or new.body_html_en is distinct from old.body_html_en then
    v_words := coalesce(array_length(regexp_split_to_array(
      btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')), '\s+'), 1), 0);
    new.reading_minutes_en := case when btrim(regexp_replace(coalesce(new.body_html_en, ''), '<[^>]+>', ' ', 'g')) = ''
                                   then null else greatest(1, ceil(v_words / 200.0))::smallint end;
  end if;
  return new;
end;
$$;
