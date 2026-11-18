-- F6.19 punto 4 (O2 de F6.13, n1/n2; docs/security/F6.19-panel-review.md). Idempotente.
-- Lista blanca de esquemas en href/src/action/formaction de las legales (es y en), regla nueva de leona-lia:
--   · n2: sin «\s*» tras «=» fuera del lookahead, el backtracking ya no rechaza href= "https://…" ni href = "https://…".
--   · n1: «/» seguido de «/», «\», «&» o espacio en blanco se rechaza (/&#47;, /\t/, /\n/, /&#92;, //host).
--   · Falso positivo aceptado: /&amp;x. Inocuo y aceptado: /%2f/evil (el parser de URL no lo convierte en //).
-- Las tres legales actuales (es y en) pasan con la expresión nueva (comprobado antes de aplicar). Sigue siendo pura (F6.8).
-- Resto del CHECK sin cambios respecto a 20261106080255.
alter table guide.pages drop constraint if exists pages_legal_text_only;
alter table guide.pages add constraint pages_legal_text_only
  check (key not in ('legal_notice', 'privacy', 'cookies') or (
    coalesce(body_html_es, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_en, '') !~* '<\s*/?\s*(?!(p|br|h2|h3|h4|strong|b|em|i|u|s|a|ul|ol|li|blockquote|sub|sup|span|code|hr)([\s/>]|$))[^\s/]'
    and coalesce(body_html_es, '') !~* '([\s/"''](style|on[a-z]+)\s*=|data-item-card)'
    and coalesce(body_html_en, '') !~* '([\s/"''](style|on[a-z]+)\s*=|data-item-card)'
    and coalesce(body_html_es, '') !~* '[\s/"''](href|src|action|formaction)\s*=(?!\s*["'']?(https?://|mailto:|/(?![/\\&\s])|#))'
    and coalesce(body_html_en, '') !~* '[\s/"''](href|src|action|formaction)\s*=(?!\s*["'']?(https?://|mailto:|/(?![/\\&\s])|#))'
    and not coalesce(jsonb_path_exists(body_json_es,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard" || @.type == "imageFigure"
                   || @.type == "caption" || @.type == "table" || @.type == "tableRow" || @.type == "tableCell"
                   || @.type == "tableHeader" || @.type == "authorNote")'), false)
    and not coalesce(jsonb_path_exists(body_json_en,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard" || @.type == "imageFigure"
                   || @.type == "caption" || @.type == "table" || @.type == "tableRow" || @.type == "tableCell"
                   || @.type == "tableHeader" || @.type == "authorNote")'), false)));
