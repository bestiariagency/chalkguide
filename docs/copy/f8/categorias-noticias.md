# Categorías de noticias · ChalkGuide F8 v2

Tarea 8.3 · Versión 0.1 (2026-11-13). Para `guide.news_categories` (jabali-javi, 8.5) y
`ingest_context`. Slug en inglés minúsculas, sin tildes, estable (va en URL y en el prompt).
Nombres en español de España e inglés británico. Longitudes pensadas para chips y filtros (≤ 24
caracteres el nombre).

| # | Slug | Nombre es | Name en | Descripción es (≤ 90 car.) | Description en |
| --- | --- | --- | --- | --- | --- |
| 1 | `competicion` | Competición | Competition | Copas, campeonatos y resultados de escalada deportiva. | Cups, championships and results from competition climbing. |
| 2 | `roca-vias` | Roca y vías | Rock and routes | Aperturas, ascensiones destacadas y nuevas zonas de escalada. | New routes, notable ascents and newly developed crags. |
| 3 | `material` | Material | Gear | Novedades, retiradas y avisos sobre equipo de escalada. | Releases, recalls and notices about climbing gear. |
| 4 | `rocodromos` | Rocódromos | Climbing gyms | Aperturas, cierres, cambios de tarifas y novedades en salas. | Openings, closures, price changes and news from gyms. |
| 5 | `seguridad` | Seguridad | Safety | Accidentes explicados con rigor, avisos y buenas prácticas. | Carefully reported incidents, warnings and good practice. |
| 6 | `acceso-entorno` | Accesos y entorno | Access and environment | Restricciones, nidificación, cierres temporales y cuidado de la roca. | Restrictions, nesting closures, temporary bans and crag care. |
| 7 | `federaciones` | Federaciones y clubes | Federations and clubs | Noticias de la FEEC, la FEDME, clubes y normativa deportiva. | News from the FEEC, FEDME, clubs and sport regulations. |
| 8 | `comunidad` | Comunidad | Community | Festivales, cine de montaña, iniciativas y gente de la escalada. | Festivals, mountain film, initiatives and people in climbing. |

## Criterios de asignación (para el prompt)

- Una noticia lleva **una** categoría. Si dudas entre dos, elige la que explique mejor qué cambia
  para quien escala (acceso > competición cuando una competición cierra una zona).
- `competicion`: IFSC, Juegos Olímpicos, Copa Catalana, campeonatos de España y Cataluña.
  Los eventos futuros de competición van además a la agenda como evento, no solo como noticia.
- `roca-vias`: aperturas, ascensiones relevantes, nuevas zonas. Solo grandes ascensiones o
  novedades de Cataluña/España en el alcance (D71).
- `seguridad`: avisos y accidentes. Solo hechos confirmados; sin identificar a particulares.
- `acceso-entorno`: prioridad editorial alta; es lo que más afecta a quien escala en Cataluña.
- `federaciones`: no usar para competiciones (van a `competicion`).
- Una noticia sin categoría clara se descarta o se avisa en `notes`; no se inventa una nueva.

## Notas

- Orden de visualización recomendado: el de la tabla. buho-pixel decide filtros y chips.
- `rocodromos` y `acceso-entorno` casan con la voz editorial de ChalkGuide (dónde escalar y
  cuidado); `seguridad` se redacta siempre con sobriedad.
- Si Xavi quiere recortar a 6, propongo fusionar `federaciones` en `comunidad` y `seguridad` en
  `material`. No lo recomiendo: perdería el filtro de avisos de seguridad.
