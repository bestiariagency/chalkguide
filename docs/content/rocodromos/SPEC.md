# Ficha de rocódromo · formato de investigación

Un archivo `grupo-N.json` = array de objetos, uno por rocódromo. **Fuente: la web oficial de cada
centro** (decisión de Xavi, 2026-11-06). Excepciones: coordenadas (`lat`, `lng`) y paradas de
metro salen de OpenStreetMap (Nominatim / mapa) a partir de la dirección oficial. Nada de Google
Maps, directorios ni webs de terceros. Lo que la web oficial no diga = omitido (no inventar).
Si la web oficial no se puede abrir, el centro no entra; lístalo en el informe.

No rellenar: `cover`, `gallery`, `og_image`, `is_featured`, `noindex`, grados, estilo, reseña,
notas, visita, transparencia, SEO. Eso es de Xavi.

| clave | regla |
| --- | --- |
| name | nombre comercial con sede: `Climbat La Foixarda`, ≤120 |
| slug | el del censo |
| summary_es | ≤400. 1 o 2 frases útiles: qué tiene (bloque, cuerda), para quién. Sin superlativos ni guiones largos. Sin opinión. |
| summary_en | ≤400, inglés británico, mismo contenido |
| verified_at | `2026-11-06` |
| source | `Web oficial` (+ `OpenStreetMap` si usaste coordenadas o metro) |
| source_url | URL de la página oficial principal consultada |
| address | calle y número, como la web oficial |
| city | municipio: `Barcelona`, `L'Hospitalet de Llobregat`… |
| district | barrio (Barcelona) o municipio |
| postal_code | texto de 5 cifras |
| lat, lng | números con 6 decimales, de OpenStreetMap |
| metro_stations | array: paradas de metro, a menos de ~10 min a pie (OSM) |
| website_url | web oficial |
| instagram_url | URL completa, solo si la web oficial la enlaza |
| phone | como la web oficial, ≤30 |
| opening_hours_mon … opening_hours_sun | `10:00-23:00`; varios tramos separados por coma; `Cerrado`. Si rellenas uno, rellena los 7 |
| opening_hours_note_es / _en | festivos, horario de verano, etc., si la web lo dice |
| price_registration_eur | matrícula, número |
| price_day_eur | entrada de día adulto, tarifa general |
| price_10_pass_eur | bono de 10 entradas adulto |
| price_monthly_eur | cuota mensual adulto, horario completo, sin permanencia si hay opción |
| discounts_es / _en | descuentos que publique (estudiantes, menores, horario valle…), breve |
| prices_verified_at | `2026-11-06` si hay algún precio |
| surface_m2, max_height_m, routes_count, autobelays_count, kids_min_age | números, solo si la web los da |
| has_lead, has_boulder, has_training_area, belay_test_required, gear_rental, has_beginner_courses, has_cafe, serves_beer, has_kids_area, has_showers, has_wifi | `Sí` o `No` solo si la web lo dice de forma clara; si no, omitido |

Formato de salida: claves exactas de la tabla; arrays como arrays JSON; números como números.
Valida con node: JSON parsea, slugs únicos, longitudes, horarios con el formato `HH:MM-HH:MM`.
