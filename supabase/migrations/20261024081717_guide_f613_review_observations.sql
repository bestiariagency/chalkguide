-- F6.13 · Observaciones de leona-lia (docs/security/F6.13-pages-review.md). Idempotente.
-- O1: service_role sin INSERT/DELETE/TRUNCATE en pages + guarda BEFORE TRUNCATE (TRUNCATE se salta los triggers de fila).
-- O2: pages_legal_text_only pasa a lista blanca de etiquetas (las que emite el editor en modo solo texto, con margen)
--     y rechaza atributos style / on* / esquemas javascript:, data:, vbscript:. Sigue siendo un CHECK puro.
-- O3: UPDATE por columnas para authenticated (las editables + published).
-- O4: unpublish_page limpia guide.draft_op tras assert_admin() (en DEFINER current_user es postgres).

-- ── O1 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
revoke insert, delete, truncate on guide.pages from service_role;

create or replace function guide.pages_before_truncate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not guide.page_maintenance() then
    raise exception 'pages are fixed' using errcode = '42501',
      hint = 'The five pages cannot be deleted (D34).';
  end if;
  return null;
end;
$$;
revoke all on function guide.pages_before_truncate() from public, anon, authenticated, service_role;

drop trigger if exists pages_before_truncate on guide.pages;
create trigger pages_before_truncate
  before truncate on guide.pages
  for each statement execute function guide.pages_before_truncate();

-- ── O2 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
-- Etiquetas permitidas en una legal: p br h2 h3 h4 strong b em i u s a ul ol li blockquote sub sup span code hr.
-- Cualquier otra (img, svg, image, input, link, style, iframe, object, embed, video, audio, picture, source, script…),
-- comentarios/declaraciones (<! <?), atributos style= y on*=, y href/src con javascript:/data:/vbscript: → 23514.
alter table guide.pages drop constraint if exists pages_legal_text_only;
alter table guide.pages add constraint pages_legal_text_only
  check (key not in ('legal_notice', 'privacy', 'cookies') or (
    coalesce(body_html_es, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_en, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_es, '') !~* '<[^>]*(\s(style|on[a-z]+)\s*=|data-item-card|(href|src|action|formaction)\s*=\s*["'']?\s*(javascript|data|vbscript):)'
    and coalesce(body_html_en, '') !~* '<[^>]*(\s(style|on[a-z]+)\s*=|data-item-card|(href|src|action|formaction)\s*=\s*["'']?\s*(javascript|data|vbscript):)'
    and not coalesce(jsonb_path_exists(body_json_es,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard")'), false)
    and not coalesce(jsonb_path_exists(body_json_en,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard")'), false)));

-- ── O3 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
revoke update on guide.pages from authenticated;
grant update (title_es, title_en, body_json_es, body_html_es, body_json_en, body_html_en,
              seo_title_es, seo_title_en, seo_description_es, seo_description_en, og_media_id, noindex, published)
  on guide.pages to authenticated;

-- ── O4 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
create or replace function guide.unpublish_page(p_page_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key       text;
  v_published boolean;
  v_has_draft boolean;
  v_label     text;
begin
  perform guide.assert_admin();
  -- O4: en DEFINER current_user es postgres; una GUC 'maintenance' heredada no debe valer aquí.
  perform set_config('guide.draft_op', '', true);

  select p.key, p.published into v_key, v_published from guide.pages p where p.id = p_page_id for update;
  if not found then
    raise exception 'entity not found' using errcode = 'P0002';
  end if;
  if v_key not in ('about', 'transparency') then
    raise exception 'legal_page_cannot_unpublish'
      using errcode = 'PT423',
            detail = v_key,
            hint = 'Legal pages stay published (D34); correct them through a draft of changes.';
  end if;
  if not v_published then
    raise exception 'page not live' using errcode = '22023',
      hint = 'Only a published page can be unpublished.';
  end if;

  v_has_draft := exists (select 1 from guide.content_drafts d where d.entity = 'page' and d.entity_id = p_page_id);

  perform set_config('guide.unpublish_op', p_page_id::text, true);
  -- Primero se oculta: el borrador se aplica ya sobre una página no publicada (D27 no entra; sin exenciones).
  update guide.pages p set published = false where p.id = p_page_id
  returning p.title_es into v_label;

  if v_has_draft then
    perform guide.publish_draft('page', p_page_id, true);
  end if;
  perform set_config('guide.unpublish_op', '', true);
  perform set_config('guide.draft_op', '', true);

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, details)
  values ((select auth.uid()), 'unpublish'::guide.activity_action, 'pages', p_page_id::text, left(v_label, 200),
          array['published'], jsonb_build_object('draft_applied', v_has_draft, 'key', v_key));
end;
$$;

revoke all on function guide.unpublish_page(uuid) from public, anon;
grant execute on function guide.unpublish_page(uuid) to authenticated;
