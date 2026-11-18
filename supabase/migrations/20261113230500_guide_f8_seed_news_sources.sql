-- F8 (D81) · Siembra de guide.news_sources con la lista validada por Xavi (docs/copy/f8/fuentes-semilla.md, §7).
-- Solo datos: no toca funciones, policies ni grants. Idempotente: ON CONFLICT (domain) DO NOTHING
-- para no pisar cambios hechos después desde el panel (p. ej. desactivar una fuente tras el piloto).
-- domain = host exacto tras redirecciones (allowlist J24: host igual o subdominio).
-- trusted = solo confianza A de la v0.1. Sin columna de feed: RSS/iCal/agenda van en instructions.
-- Fuentes que comparten dominio (FEEC + Vèrtex + Copa Catalana; Sharma Poblenou + Gavà) van en una sola fila.
-- Fuera: descartadas, sin verificar (salvo las 4 del piloto), salas sin web, Montserrat. Instagram en 8.7b.

insert into guide.news_sources (name, domain, url, kind, scope, lang, instructions, trusted, active)
values
  -- Federaciones e instituciones
  ('FEEC', 'www.feec.cat', 'https://www.feec.cat', 'both', 'cat', 'ca',
   'RSS https://www.feec.cat/feed/ · Agenda https://www.feec.cat/agenda/competicions/ (Copa Catalana). Filtrar solo escalada. Incluye la revista Vèrtex.',
   true, true),
  ('FEDME', 'fedme.es', 'https://fedme.es', 'both', 'es', 'es',
   'RSS https://fedme.es/feed/ · Calendario https://fedme.es/calendario/ · Escalada https://fedme.es/escalada/',
   true, true),
  ('World Climbing', 'www.worldclimbing.com', 'https://www.worldclimbing.com', 'both', 'intl', 'en',
   'Sin RSS. Noticias https://www.worldclimbing.com/news/index · Calendario https://www.worldclimbing.com/calendar/index',
   true, true),
  ('Olympics.com (escalada)', 'olympics.com', 'https://olympics.com/en/sports/sport-climbing/', 'news', 'intl', 'en',
   'Piloto 8.8: posible bloqueo anti-bots. Solo noticias de escalada olímpica.',
   false, true),
  -- Medios
  ('Desnivel', 'www.desnivel.com', 'https://www.desnivel.com', 'news', 'es', 'es',
   'RSS https://www.desnivel.com/feed/ · Piloto 8.8: a ratos filtra bots. Solo contenido abierto.',
   true, true),
  ('WOGU', 'woguclimbing.com', 'https://woguclimbing.com', 'news', 'es', 'es',
   'RSS https://woguclimbing.com/feed/ · Noticias https://woguclimbing.com/category/noticias-escalada/',
   true, true),
  ('PlanetMountain', 'www.planetmountain.com', 'https://www.planetmountain.com/en/', 'news', 'intl', 'en',
   'Piloto 8.8: devuelve 403 a bots aunque robots.txt permite. Versión en inglés.',
   true, true),
  ('Gripped', 'gripped.com', 'https://gripped.com', 'news', 'intl', 'en',
   'RSS https://gripped.com/feed/',
   true, true),
  ('8a.nu', 'www.8a.nu', 'https://www.8a.nu', 'news', 'intl', 'en',
   'Piloto 8.8: devuelve 403 a bots. Parte del contenido es premium: solo lo abierto.',
   false, true),
  ('Alpinist', 'alpinist.com', 'https://alpinist.com', 'news', 'intl', 'en',
   'RSS https://alpinist.com/feed/ · Ritmo bajo; solo vías destacadas.',
   false, true),
  ('Grimper', 'www.grimper.com', 'https://www.grimper.com', 'news', 'intl', 'fr',
   'RSS https://www.grimper.com/feed/all · Útil para Pirineo y Francia.',
   false, true),
  ('Climbing.de', 'www.climbing.de', 'https://www.climbing.de', 'news', 'intl', 'de',
   'RSS https://www.climbing.de/feed · Ritmo bajo.',
   false, true),
  ('Parcs de la Diputació de Barcelona (avisos)', 'parcs.diba.cat',
   'https://parcs.diba.cat/ca/web/santllorenc/avisos-i-alertes', 'news', 'cat', 'ca',
   'Sin feed: leer la página de avisos. Mismo patrón para Garraf, Montseny, etc. Regulación de escalada y cierres por nidificación.',
   false, true),
  -- Rocódromos
  ('Sharma Climbing Barcelona', 'sharmaclimbing.com', 'https://sharmaclimbing.com/espana/barcelona-poble-nou/', 'both', 'cat', 'es',
   'Agenda común a todas las sedes: https://sharmaclimbing.com/eventos/ (RSS vacío). Solo Poblenou y Gavà.',
   false, true),
  ('Climbat La Foixarda', 'climbat.com', 'https://climbat.com/centro/la-foixarda/', 'both', 'cat', 'es',
   'RSS https://climbat.com/feed/ · Novedades https://climbat.com/novedades/ · El RSS mezcla sedes: solo La Foixarda.',
   false, true),
  ('Monobloc', 'www.monobloc.es', 'https://www.monobloc.es', 'both', 'cat', null,
   'Sin RSS ni agenda visibles. Salas La Sagrera y Sants.',
   false, true),
  ('Indoorwall', 'www.indoorwall.com', 'https://www.indoorwall.com', 'both', 'cat', 'es',
   'iCal https://www.indoorwall.com/calendarioeventos/?ical=1 · RSS https://www.indoorwall.com/feed/ · Solo salas de Cataluña.',
   false, true),
  ('Bloc District', 'www.blocdistrict.com', 'https://www.blocdistrict.com', 'both', 'cat', null,
   'RSS https://www.blocdistrict.com/feed/ · Blog https://www.blocdistrict.com/blog/ (Open Bloc de Barcelona).',
   false, true),
  ('Freebloc', 'freebloc.com', 'https://freebloc.com', 'both', 'cat', null,
   'RSS https://freebloc.com/feed/ (casi parado). Prioridad baja; eventos suelen ser cursos.',
   false, true),
  -- Festivales
  ('Torelló Mountain Film', 'www.torellomountainfilm.cat', 'https://www.torellomountainfilm.cat', 'events', 'cat', 'ca',
   'Sin RSS. Noticias https://www.torellomountainfilm.cat/publicacions/noticies/',
   false, true),
  ('Banff Mountain Film Festival World Tour Spain', 'banffspain.com', 'https://banffspain.com', 'events', 'es', 'es',
   'Sin RSS: fechas por ciudad en la portada. Solo Barcelona y Cataluña.',
   false, true)
on conflict (domain) do nothing;
