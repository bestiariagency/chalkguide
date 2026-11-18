# Fuentes semilla · ChalkGuide F8 v2

Tarea 8.3 · Versión 0.2 (2026-11-13, verificada navegando, D81). Para sembrar `guide.news_sources`
(jabali-javi, 8.5).

La versión 0.1 salió de conocimiento general, sin navegar. En la 0.2 se ha comprobado cada fuente el
13-11-2026: que la URL carga y es la oficial (https), el dominio canónico tras redirecciones, la
fecha del último contenido, si hay RSS o página de agenda, si hay muro de pago y qué dice
`robots.txt`. La columna **Conf.** se mantiene como histórico; manda la columna **Estado**.

Leyenda de confianza (v0.1): **A** = la entidad existe y la URL es la oficial que conozco; **B** = la
entidad existe pero la URL exacta o su actividad hay que confirmar; **C** = dudo de que exista tal
cual, de su nombre o de que siga operativa.

Leyenda de estado (v0.2):

- **OK**: carga, es oficial, publica contenido reciente y `robots.txt` no la bloquea.
- **corregida**: la entidad existe pero la URL de la v0.1 era incorrecta; la columna URL ya lleva la
  buena.
- **sin verificar**: no se ha podido confirmar (bloqueo anti-bots, web no encontrada o sin datos).
  No se siembra hasta que Xavi la confirme.
- **descartada**: no existe, ha cerrado, no es lo que se creía, o `robots.txt` prohíbe el acceso.
  No se siembra.

**Dominio** es el host exacto tras redirecciones, para la allowlist del agente (sin `www` cuando la
web redirige a la versión sin `www`). **Feed** recoge el RSS o, si no hay, la página de agenda o
noticias más útil, con la fecha del último contenido visto.

Tipos: `news` (noticias), `events` (agenda), `gym` (rocódromo, novedades y eventos propios).
Alcance: `cat` (Cataluña), `es` (España), `intl` (internacional).

## 1. Federaciones e instituciones

| Nombre | URL | Alcance | Tipo | Conf. | Notas | Estado | Dominio | Feed | Notas de verificación |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Federació d'Entitats Excursionistes de Catalunya (FEEC) | https://www.feec.cat | cat | news + events | A | Competiciones (Copa Catalana de escalada y bloque), regulaciones de zonas, comunicados. Contenido en catalán: el agente resume en español. Buscar sección de escalada y calendario. | OK | www.feec.cat | RSS https://www.feec.cat/feed/ (actualizado 13-11-2026). Agenda de competiciones: https://www.feec.cat/agenda/competicions/ | Noticias del día. Sección de escalada deportiva: https://www.feec.cat/esports-de-muntanya/esport/escalada-esportiva/. `robots.txt` permite todo. Sin muro de pago. Mucho contenido de excursionismo y carreras: filtrar por escalada. |
| Federación Española de Deportes de Montaña y Escalada (FEDME) | https://fedme.es | es | news + events | A | Campeonatos de España, selección, normativa. | OK | fedme.es | RSS https://fedme.es/feed/ (último 11-11-2026). Calendario: https://fedme.es/calendario/ | `www.fedme.es` redirige a `fedme.es`. Sección escalada: https://fedme.es/escalada/. `robots.txt` permite. Sin muro de pago. |
| World Climbing (antes IFSC) | https://www.worldclimbing.com | intl | news + events | A | Calendario, resultados y comunicados de Copa del Mundo y Campeonatos del Mundo. | corregida | www.worldclimbing.com | Sin RSS visible. Noticias: https://www.worldclimbing.com/news/index (último 08-11-2026). Calendario: https://www.worldclimbing.com/calendar/index | La IFSC ha pasado a llamarse World Climbing; `ifsc-climbing.org` redirige a `worldclimbing.com`. `robots.txt` permite (solo bloquea rutas internas). Sin muro de pago. |
| Olympics.com (sección escalada) | https://olympics.com/en/sports/sport-climbing/ | intl | news | B | Solo noticias de escalada olímpica. Revisar términos de uso. | sin verificar | olympics.com | — | No responde ni a curl ni a WebFetch (timeout), tampoco `robots.txt`. Probable bloqueo anti-bots. World Climbing ya cubre la escalada olímpica: se puede prescindir. |
| Parc Natural de la Muntanya de Montserrat | — | cat | news | B | Regulaciones de escalada y cierres por nidificación. Confirmar URL actual (Diputació de Barcelona). | sin verificar | — | — | La URL de la v0.1 (`parcs.diba.cat/web/montserrat`) da 404: Montserrat no es de la red de la Diputació, lo gestiona el Patronat de la Muntanya de Montserrat. No se ha encontrado su web oficial. En 2026 hubo cierres de vías (sector Columpi, abril) que solo se han visto en prensa (3Cat, NacióDigital, VilaWeb). |
| Parcs de Catalunya (Generalitat) | https://parcsnaturals.gencat.cat | cat | news | B | Cierres y normativa en espacios protegidos. Confirmar URL. | descartada | parcsnaturals.gencat.cat | — | La web existe y carga (`/ca/inici`), pero `robots.txt` tiene `Disallow: /` para todos los agentes salvo buscadores concretos. No se puede leer de forma automática. |
| Ajuntament de Barcelona, esports | https://ajuntament.barcelona.cat/esports/ca | cat | events | C | Solo por si hay competiciones o jornadas municipales. Dudo de la ruta. | descartada | ajuntament.barcelona.cat | — | `barcelona.cat/esports` redirige a `ajuntament.barcelona.cat/esports/ca`. `robots.txt` bloquea expresamente ClaudeBot, Claude-SearchBot, anthropic-ai y otros agentes de IA. Además aporta poco a la escalada. |

## 2. Medios de escalada y montaña

| Nombre | URL | Alcance | Tipo | Conf. | Notas | Estado | Dominio | Feed | Notas de verificación |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Desnivel | https://www.desnivel.com | es | news | A | Medio de referencia en España. Parte de su contenido es de pago: usar solo lo abierto. | OK | www.desnivel.com | RSS https://www.desnivel.com/feed/ (último 13-11-2026) | `robots.txt` permite (solo bloquea `/wp-admin/`). La web no muestra muro de pago en artículos; la suscripción es a la revista impresa. Ojo: curl directo da timeout (posible filtro anti-bots), aunque WebFetch sí carga. Probar en el piloto. |
| WOGU | https://woguclimbing.com | es | news | A | Cultura de escalada en español: noticias de roca, competición y comunidad. Añadida por Xavi (2026-11-13). | OK | woguclimbing.com | RSS https://woguclimbing.com/feed/ (último 12-11-2026); categoría noticias: /category/noticias-escalada/ | `robots.txt` permite (solo bloquea wp-admin, búsqueda, paginación y feeds de etiquetas). Sin muro de pago. |
| Escalando (Escalando.net) | — | es | news | C | Dudo del dominio actual y de su actividad. Comprobar. | descartada | — | — | `escalando.net` redirige a `escalando.mx`, una guía de zonas de escalada de México, sin noticias fechadas. No es un medio español. |
| Vèrtex (revista de la FEEC) | https://www.feec.cat/actualitat/revista-vertex/ | cat | news | B | Revista catalana de montaña. Confirmar dominio y si es abierta. | corregida | www.feec.cat | Sin feed propio; lo publicado online entra por el RSS de la FEEC | `vertex.cat` es una empresa de software de calidad, nada que ver. Vèrtex es la revista trimestral impresa de la FEEC (último número visto: 320, 2026), por suscripción. No hace falta como fuente aparte: basta con la FEEC. |
| Revista Oxígeno / Grande Montaña | — | es | news | C | Dudo de que sigan operativas; descartar salvo que Xavi las conozca. | descartada | — | — | No se ha buscado; se descarta como proponía la v0.1. |
| UKClimbing | https://www.ukclimbing.com | intl | news | A | Noticias de roca y competición, en inglés. | descartada | www.ukclimbing.com | — | `robots.txt` bloquea ClaudeBot, Claude-Web y anthropic-ai (`Disallow: /`) y declara `ai-train=no`. WebFetch recibe `402 Payment Required` (cobro por rastreo) y curl `403`. No usable por la rutina. |
| Climbing (Climbing.com) | https://www.climbing.com | intl | news | A | Parte tras suscripción. Usar solo lo abierto. | descartada | www.climbing.com | (RSS https://www.climbing.com/feed/ existe, último 12-11-2026) | `robots.txt` bloquea expresamente ClaudeBot, anthropic-ai, GPTBot y otros agentes de IA con `Disallow: /`. Mientras la rutina funcione con un modelo de Anthropic, no se usa. Ver dudas para Xavi. |
| Rock and Ice | — | intl | news | B | Mismo grupo que Climbing; comprobar si sigue activo con contenido propio. | descartada | — | — | `rockandice.com` redirige a `climbing.com`: ya no tiene web propia. |
| PlanetMountain | https://www.planetmountain.com/en/ | intl | news | A | Italia; muy bueno en vías y competición. Versión en inglés. | sin verificar | www.planetmountain.com | — | `robots.txt` permite todo (`Allow: /`), pero la web devuelve `403` a curl y a WebFetch (filtro anti-bots). Confirmar en el piloto si la rutina puede leerla; si no, descartar. |
| Gripped | https://gripped.com | intl | news | A | Canadá; noticias de ascensiones y material. | OK | gripped.com | RSS https://gripped.com/feed/ (último 12-11-2026) | `robots.txt` permite todo. Sin muro de pago. |
| 8a.nu | https://www.8a.nu | intl | news | B | Ascensiones y noticias; parte de contenido es de pago o para socios. | sin verificar | www.8a.nu | — | `robots.txt` no bloquea a agentes de Anthropic (sí a GPTBot y Google-Extended), pero la web devuelve `403` a curl y WebFetch. Contenido premium. Confirmar en el piloto. |
| Alpinist | https://alpinist.com | intl | news | B | Más alpinismo que escalada deportiva; solo vías destacadas. | OK | alpinist.com | RSS https://alpinist.com/feed/ (último 06-11-2026) | `www.alpinist.com` redirige a `alpinist.com`. `robots.txt` permite todo. Ritmo de publicación bajo (cada 1-2 semanas). |
| Rock Climbing Mountain Project news | — | intl | news | C | No lo conozco como fuente de noticias; descartar. | descartada | — | — | No se ha buscado; se descarta como proponía la v0.1. |

## 3. Rocódromos de Barcelona y área metropolitana

Esta lista **no sale de la base de datos** (el contenido dummy no es fuente). En la v0.2 se ha
rehecho con lo encontrado navegando (webs oficiales, la guía de rocódromos de Time Out de enero de
2025 y fichas de Urban Sports Club). Xavi conoce las salas de su zona mejor: confirma o completa.

| Nombre | URL | Alcance | Tipo | Conf. | Notas | Estado | Dominio | Feed | Notas de verificación |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sharma Climbing Barcelona (Poblenou) | https://sharmaclimbing.com/espana/barcelona-poble-nou/ | cat | gym | B | Cadena con sala en Barcelona. Confirmar sede, URL de la sala y de su blog o agenda. | corregida | sharmaclimbing.com | Agenda: https://sharmaclimbing.com/eventos/ (el RSS `/feed/` existe pero sale vacío) | `www.` redirige a sin `www`. C/ Marroc, 206. Sedes: Barcelona Poblenou, Gavà, Madrid y Zaragoza; la agenda es común a todas. `robots.txt` permite. |
| Sharma Climbing Gavà | https://sharmaclimbing.com/espana/barcelona-gava/ | cat | gym | — | Nueva en v0.2. | OK | sharmaclimbing.com | Agenda común: https://sharmaclimbing.com/eventos/ | Misma web y agenda que Poblenou. |
| Climbat La Foixarda | https://climbat.com/centro/la-foixarda/ | cat | gym | C | Dudo del dominio y de las sedes. Comprobar. | corregida | climbat.com | RSS https://climbat.com/feed/ (último 29-10-2026). Novedades: https://climbat.com/novedades/ | Existe. Montjuïc (Av. Miramar). Es la única sede de Climbat en la provincia de Barcelona según su web (el resto: Avilés, Barakaldo, Madrid, Zaragoza, Murcia, París). El RSS mezcla todas las sedes. `robots.txt` permite (bloquea `/category/`). |
| Climbat Magnesio (El Clot) | — | cat | gym | — | Nueva en v0.2. | sin verificar | — | — | Time Out (enero 2025) la cita en C/ Gabriel y Galán, 3, pero ya no aparece en la lista de centros de climbat.com. Puede haber cerrado o cambiado de nombre. |
| Monobloc (La Sagrera y Sants) | https://www.monobloc.es | cat | gym | — | Nueva en v0.2. | OK | www.monobloc.es | Sin RSS ni agenda visibles | Salas en La Sagrera y Sants (también Reus y, al parecer, Sabadell). `robots.txt` no bloquea. Fuente pobre para la rutina: solo si se añade a mano su página de novedades. |
| Indoorwall (El Clot y L'Hospitalet) | https://www.indoorwall.com | cat | gym | — | Nueva en v0.2. | OK | www.indoorwall.com | RSS https://www.indoorwall.com/feed/ (último 23-06-2026). Agenda: https://www.indoorwall.com/eventos/ con iCal https://www.indoorwall.com/calendarioeventos/?ical=1 | Cadena con salas en El Clot, L'Hospitalet, Vic, Vilanova y fuera de Cataluña. El iCal es la mejor fuente estructurada de eventos de sala encontrada. `robots.txt` no bloquea. |
| Bloc District (Marina y Sagrada Família) | https://www.blocdistrict.com | cat | gym | — | Nueva en v0.2. | OK | www.blocdistrict.com | RSS https://www.blocdistrict.com/feed/. Blog: https://www.blocdistrict.com/blog/ | C/ Zamora, 96-106 y C/ Nàpols, 128. Organiza el Open Bloc de Barcelona. Blog sin fechas visibles: comprobar ritmo en el piloto. `robots.txt` no bloquea. |
| Freebloc (Sants) | https://freebloc.com | cat | gym | — | Nueva en v0.2. | OK | freebloc.com | RSS https://freebloc.com/feed/ (último 27-02-2025, casi parado). Eventos: cursos en `/event/` | Sala pequeña (C/ Rossend Arús, 11). Sus "eventos" son sobre todo cursos. Prioridad baja. |
| Rocódromos municipales (Espai Jove Boca Nord, Can Batlló y otros) | — | cat | gym | C | Hay salas municipales; dudo de la ruta exacta y de que publiquen novedades. | descartada | — | — | Existen (Boca Nord en Nou Barris, Can Batlló autogestionado), pero publican solo en Instagram o en la guía municipal, cuyo `robots.txt` bloquea agentes de IA. Sus eventos entran a mano. |
| Otras salas citadas sin web encontrada (Deu Dits, Els Bous de La Salle, Kimera Climbing Gavà, Blocat, Climbing Wall Baix Llobregat) | — | cat | gym | C | Hay salas en el área metropolitana; no recuerdo con certeza nombres ni webs. **[XAVI: lista de salas que sigues]** | sin verificar | — | — | Aparecen en Time Out o Urban Sports Club, pero no se ha encontrado web oficial que cargue. **[XAVI: confirmar cuáles siguen abiertas y su web.]** |

Recomendación: sembrar solo las salas que ya estén (o vayan a estar) en `guide.items` como
rocódromos, para que `venue_hint` y fuente casen. Así la fuente y el catálogo se alimentan entre sí.

## 4. Festivales, cine y eventos

| Nombre | URL | Alcance | Tipo | Conf. | Notas | Estado | Dominio | Feed | Notas de verificación |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Torelló Mountain Film (Festival Internacional de Cine de Montaña) | https://www.torellomountainfilm.cat | cat | events | B | Festival catalán de cine de montaña. Confirmar dominio y fechas de cada edición. | OK | www.torellomountainfilm.cat | Sin RSS. Noticias: https://www.torellomountainfilm.cat/publicacions/noticies/ (último 12-11-2026) | 44.ª edición del 13 al 22 de noviembre de 2026. `robots.txt` permite todo. |
| Banff Mountain Film Festival World Tour Spain | https://banffspain.com | es | events | C | La gira pasa por Cataluña con organizadores locales, que cambian cada año. Mejor buscar el organizador local. | corregida | banffspain.com | Sin RSS ni noticias; solo fechas por ciudad en la portada | La gira española la produce Banff Ibérica Events S.L. Próxima fecha en Barcelona: 11-03-2027. `www.banffspain.es` redirige aquí. `robots.txt` permite. |
| Copa Catalana de escalada de dificultad y bloque | https://www.feec.cat/agenda/competicions/ | cat | events | B | Calendario en la web de la FEEC (ver arriba). | OK | www.feec.cat | https://www.feec.cat/agenda/competicions/ | Misma web que la FEEC; no hace falta sembrarla como fuente aparte si la FEEC ya está. |
| Open o campeonatos de bloque organizados por salas | — | cat | events | C | Salen en la web o redes de cada sala. Solo web; no Instagram. | sin verificar | — | — | Quedan cubiertos por las fuentes de sala de la sección 3 (sobre todo el iCal de Indoorwall y el blog de Bloc District). |

## 5. Fuentes nuevas propuestas (v0.2)

| Nombre | URL | Alcance | Tipo | Estado | Dominio | Feed | Notas de verificación |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Parcs de la Diputació de Barcelona, avisos y alertas | https://parcs.diba.cat/ca/web/santllorenc/avisos-i-alertes | cat | news | OK | parcs.diba.cat | Página de avisos por parque (Sant Llorenç del Munt i l'Obac; mismo patrón para Garraf, Montseny, etc.) | Sustituye en parte a la fila de Montserrat: regulación de escalada y cierres por nidificación (Sant Llorenç, del 1 de enero al 31 de julio). `robots.txt` solo bloquea rutas sueltas. Sin feed: hay que leer la página. |
| Grimper | https://www.grimper.com | intl | news | OK | www.grimper.com | RSS https://www.grimper.com/feed/all (último 12-11-2026) | Revista francesa de escalada, en francés. `robots.txt` no bloquea agentes de Anthropic. Útil para Pirineo y Francia. |
| Climbing.de | https://www.climbing.de | intl | news | OK | www.climbing.de | RSS https://www.climbing.de/feed (último 29-09-2026) | Revista alemana; ritmo bajo. Opcional. `robots.txt` no bloquea. |
| Indoorwall, agenda iCal | https://www.indoorwall.com/calendarioeventos/?ical=1 | cat + es | events | OK | www.indoorwall.com | iCal | Ya listada en la sección 3; se destaca porque es un formato estructurado que la rutina puede leer sin interpretar HTML. |
| Banff Mountain Film Festival World Tour Spain | https://banffspain.com | es | events | OK | banffspain.com | — | Ya listada en la sección 4 (sustituye a la web de Banff Centre). |

## 6. Consideraciones para la rutina

- **Catalán.** FEEC, Vèrtex y muchas salas publican en catalán. El agente lee en catalán y
  resume en español (y en inglés si procede). Las claves de dedupe usan el texto normalizado.
- **Contenido de pago.** Desnivel, Climbing y 8a.nu mezclan abierto y de pago. La rutina usa solo
  lo accesible sin registro (regla 10 del prompt).
- **Redes sociales.** Muchas salas publican su agenda solo en Instagram: no se usan (regla 9).
  Esos eventos entran a mano por el panel.
- **Bloqueos a agentes de IA.** Varias webs (UKClimbing, Climbing.com, Ajuntament de Barcelona)
  prohíben en `robots.txt` a ClaudeBot y anthropic-ai. Se respetan: quedan descartadas. Otras
  (PlanetMountain, 8a.nu, Olympics.com, y a ratos Desnivel) filtran bots por cortafuegos aunque su
  `robots.txt` lo permita: probarlas en el piloto antes de darlas por buenas.
- **Preferir feeds.** Donde hay RSS o iCal, la rutina los usa antes que leer la portada.
- **Fuentes que cambian.** El panel Ingesta (8.9) debe permitir desactivar fuentes. Revisar la
  lista cada trimestre y tras cada piloto.
- **Atribución.** Cada ítem cita su fuente (`source_name` + `source_url`); la lista de aquí fija el
  `source_name` canónico.

## 7. Decisiones de Xavi (2026-11-14)

- **Climbing.com y UKClimbing:** se respeta su bloqueo a agentes de IA. Quedan descartadas.
- **PlanetMountain, 8a.nu, Olympics.com y Desnivel:** se siembran activas y se prueban en el piloto (8.8). Si fallan de forma sistemática, se desactivan.
- **Climbat Magnesio, Deu Dits, Kimera Gavà, Blocat y Climbing Wall Baix Llobregat:** fuera hasta confirmar que siguen abiertas y tienen web propia.
- **Montserrat:** sin fuente propia; se sigue por prensa (Desnivel, WOGU, FEEC).
- **Fuentes nuevas de la §5** (avisos de parcs.diba.cat, Grimper, Climbing.de): aceptadas.
- **WOGU:** añadida por Xavi.
- **Instagram:** por API oficial en 8.7b (D82). X fuera (D83).
