-- F8 · Fuentes con dominio raíz (sin «www.»): la allowlist J24 acepta host = domain o subdominio de domain,
-- así que con la raíz pasan el host con y sin www. Solo datos. Aprobado por Xavi (2026-11-14).
update guide.news_sources s
set domain = substr(s.domain, 5)
where s.domain like 'www.%'
  and not exists (select 1 from guide.news_sources o where o.domain = substr(s.domain, 5));
