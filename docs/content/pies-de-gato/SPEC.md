# Ficha de pie de gato · formato de investigación

Un archivo `grupo-N.json` = array de objetos, uno por modelo. **Fuente única: Barrabes
(barrabes.com, ficha de producto abierta).** Decisión de Xavi (2026-11-06). Nada de otras tiendas,
webs de marca ni buscadores. Campo que Barrabes no publique = omitido (no inventar ni inferir de
otra fuente). Modelo que no esté en Barrabes = no entra; lístalo en `omitidos` del informe.

| clave | regla |
| --- | --- |
| name | «Marca Modelo», ≤120 |
| slug | minúsculas, números y guiones, sin tildes: `la-sportiva-tc-pro` |
| brand | ≤60, como la escribe la marca (`La Sportiva`, `Ocún`) |
| model | ≤80 |
| summary_es | ≤400. 1 o 2 frases útiles: para quién y para qué. Sin superlativos ni guiones largos. |
| summary_en | ≤400, inglés británico, mismo contenido |
| fit | Unisex · Mujer · Hombre · Niños |
| profile | Plano · Moderado · Agresivo |
| asymmetry | Ninguna · Ligera · Moderada · Fuerte |
| closure | Cordones · Velcro · Slipper |
| rubber | nombre comercial de la goma, ≤80 (`Vibram XS Edge`) |
| rubber_thickness_mm | número (`4`, `3.5`), solo si la marca lo publica |
| stiffness | Muy blanda · Blanda · Media · Rígida · Muy rígida |
| recommended_use | array de: Rocódromo, Bloque, Deportiva, Clásica, Vías largas, Entrenamiento |
| levels | array de: Inicio, Intermedio, Avanzado |
| price_min_eur | número: precio actual en Barrabes (el más bajo de la ficha) |
| price_max_eur | número: precio original/PVP que muestra Barrabes (tachado); sin descuento = igual a price_min |
| price_checked_at | `2026-11-06` si hay precio |
| source | `Barrabes` |
| source_url | URL de la ficha en barrabes.com |
| verified_at | `2026-11-06` |

Enums con mayúscula y tilde exactas. Perfil, asimetría, rigidez, horma, uso y nivel: traduce lo que diga
Barrabes a la lista cerrada con criterio claro (p. ej. «agresivo» = Agresivo) y anótalo en el
informe. Si Barrabes no lo dice, omítelo.
