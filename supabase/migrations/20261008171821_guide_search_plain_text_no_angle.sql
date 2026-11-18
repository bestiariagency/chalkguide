-- D21 / 3.19 · Defensa en profundidad del fragmento de search_articles: el texto plano nunca contiene
-- `<` ni `>` (ni los que quedan sueltos en el HTML ni los que vendrían de decodificar &lt; / &gt;); se
-- sustituyen por ‹ › (U+2039/U+203A). Así, aunque un componente olvidara escapar, el fragmento no puede
-- formar etiquetas. El contrato no cambia: el frontend escapa todo y luego convierte U+0002/U+0003 en <mark>.
create or replace function guide.search_plain_text(p_excerpt text, p_body_html text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select btrim(regexp_replace(
    replace(replace(replace(replace(replace(replace(replace(
      translate(
        regexp_replace(coalesce(p_excerpt, '') || ' ' || coalesce(p_body_html, ''), '<[^>]*>', ' ', 'g'),
        '<>', '‹›'),
      '&nbsp;', ' '), '&lt;', '‹'), '&gt;', '›'), '&quot;', '"'), '&#39;', ''''), '&apos;', ''''), '&amp;', '&'),
    '[[:cntrl:][:space:]]+', ' ', 'g'));
$$;

revoke all on function guide.search_plain_text(text, text) from public;
grant execute on function guide.search_plain_text(text, text) to anon, authenticated;
