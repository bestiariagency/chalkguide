# Ficha de resolador · formato de investigación

Un archivo `grupo-N.json` = array de objetos, uno por resolador. **Fuente: la web oficial de cada
taller o tienda** (misma dinámica que rocódromos, 2026-11-06). Coordenadas desde OpenStreetMap
(Nominatim) a partir de la dirección oficial. Nada de Google Maps, directorios ni webs de
terceros. Lo que la web oficial no diga = omitido (no inventar). Si la web oficial no se puede
abrir, el centro no entra; lístalo en el informe.

No rellenar: `cover`, `gallery`, `og_image`, `is_featured`, `noindex`, reseña, notas, visita,
transparencia, SEO. Eso es de Xavi.

| clave | regla |
| --- | --- |
| name | nombre comercial, ≤120 |
| slug | el del censo |
| summary_es | ≤400. 1 o 2 frases útiles: qué hace, si recoge por correo o es punto de recogida, y a qué taller envía si lo dice la web. Sin superlativos ni guiones largos. Sin opinión. |
| summary_en | ≤400, inglés británico, mismo contenido |
| verified_at | `2026-11-06` |
| source | `Web oficial` (+ `OpenStreetMap` si usaste coordenadas) |
| source_url | URL de la página oficial consultada (la de resolado si existe) |
| address | calle y número, como la web oficial |
| city | municipio |
| district | barrio (Barcelona) o municipio |
| postal_code | texto de 5 cifras |
| lat, lng | números con 6 decimales, de OpenStreetMap |
| website_url | web oficial |
| instagram_url | URL completa, solo si la web oficial la enlaza |
| phone | como la web oficial, ≤30 |
| services | array de: Media suela, Suela completa, Rand, Parche de puntera, Reparación de cierres, Costuras, Otros |
| price_per_pair_eur | precio de media suela por par (el servicio estándar), número |
| price_rand_eur | suplemento o precio del rand, número |
| turnaround_days_min, turnaround_days_max | plazo en días (enteros) si la web lo da; semanas × 7 |
| rubber_brands | array: gomas que ofrece (`Vibram`, `Five Ten Stealth`…) |
| prices_verified_at | `2026-11-06` si hay algún precio |
| accepts_mail | `Sí` / `No` solo si la web lo dice |
| mail_notes_es / _en | cómo se envía (dirección, coste de vuelta, formulario), breve |

Formato de salida: claves exactas de la tabla; arrays como arrays JSON; números como números. No
uses « | » dentro de un valor (es el separador de listas de la plantilla).
Valida con node: JSON parsea, slugs únicos, longitudes, enum de `services`.
