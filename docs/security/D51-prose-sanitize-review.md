# D51 · Revisión de seguridad del saneado del HTML editorial (UiProse, editorial v2)

Revisora: leona-lia · 2026-11-06 · Proyecto `eqtjlafxtrzbjazhhyin` (solo lectura) · Veredicto: **APROBADO** (sin vetos; O1–O8 no bloquean; cerrar O1 y O2 antes de zorro-foxter)

## Conclusiones

- Sin bypass de XSS. htmlparser2 normaliza mayúsculas y entidades antes de la lista blanca; `scope`, `data-width` y `data-note` se reconstruyen desde listas cerradas.
- Esquemas `http`, `https` y `mailto` en `href`/`src` (`naughtyHref`, sin protocol-relative). `img` solo del bucket `media`, sin `srcset`/`sizes`/`style`. `iframe` solo `youtube-nocookie.com/embed/<id>`, reconstruido.
- SVG, MathML, `template`, `noscript`, `style` y `script` descartados; comentarios eliminados; sin mXSS. Los marcadores internos no se pueden falsificar.
- `id` desde `slugifyHeading` (`[a-z0-9-]`); `aria-label` y nombre del autor pasan por `escapeHtml`; índice interpolado con `{{ }}`.
- `UiProse` sanea igual en SSR y en cliente; es el único `v-html`. Todas las rutas pasan por él, incluidas las vistas previas del panel. Tiptap lee con DOMParser (inerte).
- BD: nada sanea `body_html` al guardar. `pages_legal_text_only` rechaza las etiquetas nuevas en las legales. `extract_media_ids` registra `imageFigure.attrs.mediaId`; `media_is_public`, el borrado y el alt obligatorio funcionan con las figuras.
- `public` intacto. `get_advisors` sin avisos nuevos.

## Observaciones

- **O1 (media-baja):** `blog/[slug].vue:18-19` calcula el índice sobre el HTML crudo y `UiProse` genera los ids sobre el saneado; pueden descuadrar. Hay que sanear una sola vez y compartir el resultado.
- **O2 (baja):** `RESERVED_IDS` incompleto: `keep-reading`, `article-items`, `article-title`, `site-footer`, `mobile-menu`, `contenido`, `blog-*`, `category-list` y el patrón `^v-\d`.
- **O3 (baja):** sin límites de tamaño. Proponer un CHECK `char_length(body_html_*) <= ~300000` (jabali-javi). En `markNumericColumns`, no detectar columnas por encima de 2× los máximos y quitar `Math.max(...spread)` (RangeError con ~100.000 filas).
- **O4 (baja):** la lista blanca es más ancha que el editor: `footer` sin nodo, `small` fuera de `figcaption`, tablas y `aside` anidados (`renderTables` desequilibra). Hay que ajustar o limitar el contenido de las celdas.
- **O5 (cosmética):** `stripTags` decodifica `&amp;` antes que `&lt;` (doble decodificación). Decodificar `&amp;` el último.
- **O6 (baja, panel):** `ImageFigure.getAttrs` y `FigureView` aceptan cualquier `src` (IP del admin) y un `mediaId` sin validar (22P02). Exigir el prefijo del bucket y un UUID.
- **O7 (baja, BD):** el jsonpath de `pages_legal_text_only` no incluye `imageFigure`, `table` ni `authorNote`. Unificar con la O2 de F6.13 en 6.19.
- **O8:** token roto en `Prose.vue:72` (ya corregido por SúperXavi).

## Pruebas

Los 29 casos cubren lo básico, pero el caso del `aria-label` hostil no lo prueba de verdad. Hay que mover la batería a `scripts/check-sanitizer.ts` y añadir:

- escapado del `aria-label` y del nombre del autor;
- mayúsculas y entidades;
- marcadores falsificados;
- anidamientos e idempotencia;
- `footer` y `blockquote` profundos;
- mXSS (`math`, `svg`, `xmp`, `template`, CDATA);
- `iframe` en bloques;
- `img` fuera del bucket, `srcset` y `picture`;
- `href` ofuscados;
- ids reservados y 1.000 títulos iguales;
- O1;
- DoS en tablas.

_Guardado por SúperXavi a partir del informe de leona-lia (no tiene herramienta de escritura)._
