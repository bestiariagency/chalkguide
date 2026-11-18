-- F6.4 parte 2b · Despublicar un artículo desde el panel: guide.unpublish_article(p_article_id uuid) → void.
--
-- Por qué una RPC y no un UPDATE status = 'draft': si el artículo tiene un borrador de cambios (D23) en
-- guide.content_drafts, el UPDATE lo dejaría colgando de un artículo que ya no está vivo (save_draft no
-- admite borradores sobre lo no vivo) y el editor abriría la versión publicada vieja. Aquí, en una sola
-- transacción:
--   1. Bloquea la fila del artículo (FOR UPDATE) y exige que esté vivo (guide.article_is_live, reloj del
--      servidor: publicado o programado ya vencido).
--   2. Si hay borrador de cambios, lo aplica reutilizando guide.publish_draft(..., p_force => true) mientras
--      el artículo sigue vivo (misma lista blanca, mismo 'apply:<id>', relacionados incluidos) y el propio
--      publish_draft borra el borrador. p_force: despublicar no debe fallar por PT409; el borrador es lo
--      último que Xavi estaba editando y es lo que debe quedar en la fila. Si el payload ya no valida
--      (draft_check_payload), falla todo y nada cambia.
--   3. status = 'draft', published_at = null.
--   4. Registra una entrada 'unpublish' en guide.activity_log (details: draft_applied, previous_status).
--      content_drafts_log no escribe nada para este artículo mientras guide.unpublish_op esté fijado: el
--      filtro va antes de elegir la acción, así que omite tanto 'draft_publish' como 'draft_discard' (aquí
--      sería falso: nada se publica, y dentro de unpublish_article no se descarta nada). Los UPDATE de la
--      fila siguen registrándose como 'update' por articles_log_activity, igual que con publish_draft.
--
-- Decisiones:
--   * No vivo (borrador o programado a futuro) → error 'article not live', SQLSTATE 22023 (mismo estilo que
--     'entity not published' de save_draft). No es un no-op: el panel solo ofrece despublicar sobre lo vivo
--     y un estado inesperado debe verse. Un programado a futuro se pasa a borrador con el UPDATE de siempre.
--     Artículo inexistente → 'entity not found', P0002 (como publish_draft).
--   * published_at := null, como hace hoy "Volver a borrador" del panel (useArticleEditor.backToDraft):
--     un borrador no tiene fecha de publicación, el listado/agenda del panel no lo pinta con fecha y, al
--     republicar con 'published', el trigger fija published_at = now() (fecha de la nueva publicación).
--   * Redirecciones: despublicar no cambia el slug y no crea ninguna. Única salvedad: si el borrador de
--     cambios aplicado cambia un slug, track_slug_redirects registra old → artículo exactamente como haría
--     publish_draft (la URL vieja fue pública; resolve_redirect solo resuelve hacia lo vivo, así que no
--     redirige hasta que se republique).
--
-- SECURITY DEFINER (search_path ''): admin comprobado dentro con guide.assert_admin() (42501), igual que
-- publish_draft; necesita escribir en activity_log, que no tiene grants de escritura para clientes. Los
-- bloqueos de lo vivo (articles_before_write, article_items_live_guard) siguen valiendo: el contenido solo
-- entra por el 'apply:<id>' que fija publish_draft.
-- GUC nuevo guide.unpublish_op = '<article id>' (local a la transacción): solo lo fija esta función y solo
-- lo lee content_drafts_log para no registrar 'draft_publish' ni 'draft_discard' de ese artículo. Un cliente
-- no puede fijarlo (sin set_config expuesto ni db_pre_request); falsificado (solo un admin con acceso SQL)
-- quitaría esa línea del registro, la línea 'update' se mantiene y nunca da acceso (tests X1/X1c).
-- Idempotente.

alter type guide.activity_action add value if not exists 'unpublish';

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
  -- unpublish_article aplica el borrador sin publicar: ya registra su propia entrada 'unpublish'.
  if old.entity = 'article' and coalesce(current_setting('guide.unpublish_op', true), '') = old.entity_id::text then
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

revoke execute on function guide.content_drafts_log() from public, anon, authenticated;

create or replace function guide.unpublish_article(p_article_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status   guide.article_status;
  v_pub_at   timestamptz;
  v_has_draft boolean;
  v_label    text;
begin
  perform guide.assert_admin();

  select a.status, a.published_at into v_status, v_pub_at
  from guide.articles a where a.id = p_article_id
  for update;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  if not guide.article_is_live(v_status, v_pub_at) then
    raise exception 'article not live' using errcode = '22023',
      hint = 'Only a published (or due scheduled) article can be unpublished.';
  end if;

  v_has_draft := exists (select 1 from guide.content_drafts d where d.entity = 'article' and d.entity_id = p_article_id);

  perform set_config('guide.unpublish_op', p_article_id::text, true);
  if v_has_draft then
    -- Aplica y borra el borrador (sin conflicto: lo último editado manda).
    perform guide.publish_draft('article', p_article_id, true);
  end if;

  update guide.articles a
  set status = 'draft', published_at = null
  where a.id = p_article_id
  returning a.title_es into v_label;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'unpublish'::guide.activity_action, 'articles', p_article_id::text, left(v_label, 200),
          array['published_at', 'status'],
          jsonb_build_object('draft_applied', v_has_draft, 'previous_status', v_status::text));

  perform set_config('guide.unpublish_op', '', true);
  perform set_config('guide.draft_op', '', true);
end;
$$;

revoke execute on function guide.unpublish_article(uuid) from public, anon, service_role;
grant execute on function guide.unpublish_article(uuid) to authenticated;

comment on function guide.unpublish_article(uuid) is
  'F6.4. Despublica un artículo vivo (status draft, published_at null). Si tiene borrador de cambios, lo aplica '
  'y lo borra en la misma transacción. Solo admin (42501). No vivo: 22023 ''article not live''; inexistente: P0002.';
