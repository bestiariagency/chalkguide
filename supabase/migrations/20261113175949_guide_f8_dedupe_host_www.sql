-- F8 (8.5) · J18: la clave de dedupe ignora el prefijo «www.» del host (www.x.org y x.org son la misma fuente).
-- Más estricto que la fórmula de la spec: solo puede convertir en duplicado lo que antes no lo era. Idempotente.
create or replace function guide.ingest_dedupe_key(p_host text, p_day date, p_title text)
returns text
language sql
stable
set search_path = ''
as $$
  select 'v1:' || encode(extensions.digest(convert_to(
           regexp_replace(lower(p_host), '^www\.', '') || '|' || to_char(p_day, 'YYYY-MM-DD') || '|'
           || guide.ingest_norm_title(p_title), 'UTF8'),
           'sha256'), 'hex');
$$;
revoke all on function guide.ingest_dedupe_key(text, date, text) from public, anon, authenticated, service_role;
