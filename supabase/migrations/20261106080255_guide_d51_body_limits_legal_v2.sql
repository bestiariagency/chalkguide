-- D51 · Observaciones de leona-lia (docs/security/D51-prose-sanitize-review.md). Idempotente. CHECK puros.
-- O3: tope de tamaño del HTML editorial: char_length(body_html_*) <= 300000 en articles, pages y author_reviews
--     (y page_versions.body_html, copia de pages). Datos a 2026-11-06: máximo 4.552 caracteres (pages); 300.000 deja
--     margen para un artículo muy largo con tablas (~65× lo actual) y corta un DoS de render/saneado en SSR.
-- O7: el jsonpath de pages_legal_text_only añade los nodos del editor v2: imageFigure (+ caption), table (+ tableRow,
--     tableCell, tableHeader) y authorNote, coherente con la lista blanca de etiquetas HTML (figure/table/aside fuera).
-- F6.13 O2 (pendiente de 6.19, docs/security/F6.13-pages-review.md): en legales,
--     · style= / on*= también tras «/» o comilla (<p/onclick=…>, <a href="x"onclick=…>) y fuera del ancla «<[^>]*»
--       (un «>» entre comillas ya no lo esquiva): se busca en todo el cuerpo;
--     · lista blanca de esquemas en href/src/action/formaction: solo https?://, mailto:, /ruta (no //) y #ancla.
--       Rechaza entidades y tabuladores en el esquema (&#106;avascript:, &colon;, java\tscript:) y valores vacíos.

-- ── O3 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
alter table guide.articles drop constraint if exists articles_body_html_size;
alter table guide.articles add constraint articles_body_html_size
  check (coalesce(char_length(body_html_es), 0) <= 300000 and coalesce(char_length(body_html_en), 0) <= 300000);

alter table guide.pages drop constraint if exists pages_body_html_size;
alter table guide.pages add constraint pages_body_html_size
  check (coalesce(char_length(body_html_es), 0) <= 300000 and coalesce(char_length(body_html_en), 0) <= 300000);

alter table guide.author_reviews drop constraint if exists author_reviews_body_html_size;
alter table guide.author_reviews add constraint author_reviews_body_html_size
  check (coalesce(char_length(body_html_es), 0) <= 300000 and coalesce(char_length(body_html_en), 0) <= 300000);

alter table guide.page_versions drop constraint if exists page_versions_body_html_size;
alter table guide.page_versions add constraint page_versions_body_html_size
  check (coalesce(char_length(body_html), 0) <= 300000);

-- ── O7 + F6.13 O2 ───────────────────────────────────────────────────────────────────────────────────────────────
-- Etiquetas permitidas en una legal: p br h2 h3 h4 strong b em i u s a ul ol li blockquote sub sup span code hr.
alter table guide.pages drop constraint if exists pages_legal_text_only;
alter table guide.pages add constraint pages_legal_text_only
  check (key not in ('legal_notice', 'privacy', 'cookies') or (
    coalesce(body_html_es, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_en, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_es, '') !~* '([\s/"''](style|on[a-z]+)\s*=|data-item-card)'
    and coalesce(body_html_en, '') !~* '([\s/"''](style|on[a-z]+)\s*=|data-item-card)'
    and coalesce(body_html_es, '') !~* '[\s/"''](href|src|action|formaction)\s*=\s*(?!["'']?(https?://|mailto:|/(?![/\\])|#))'
    and coalesce(body_html_en, '') !~* '[\s/"''](href|src|action|formaction)\s*=\s*(?!["'']?(https?://|mailto:|/(?![/\\])|#))'
    and not coalesce(jsonb_path_exists(body_json_es,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard" || @.type == "imageFigure"
                   || @.type == "caption" || @.type == "table" || @.type == "tableRow" || @.type == "tableCell"
                   || @.type == "tableHeader" || @.type == "authorNote")'), false)
    and not coalesce(jsonb_path_exists(body_json_en,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard" || @.type == "imageFigure"
                   || @.type == "caption" || @.type == "table" || @.type == "tableRow" || @.type == "tableCell"
                   || @.type == "tableHeader" || @.type == "authorNote")'), false)));
