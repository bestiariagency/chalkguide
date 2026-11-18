# Revisión de seguridad D21 · búsqueda del blog, tallas y dificultad (leona-lia, 2026-10-08)

Migraciones: `20261008171607_guide_article_search`, `20261008171639_guide_shoe_sizes_gym_grading`,
`20261008171821_guide_search_plain_text_no_angle`.

## Veredicto: **APROBADO** (sin vetos)

## Comprobaciones

- `guide_rls_leaks.sql` completo (incluidos bloques D21 para anon, usuario, JWT forjado y admin): pasa.
- `search_articles`: SECURITY INVOKER, `search_path=''`; filtra `article_is_live()` y `has_en` en `en`;
  el fragmento solo se calcula sobre ids filtrados. Ni borradores ni programados salen, tampoco para admin.
- Inyección en `p_query` (`' | :* & ! <-> (`): 0 filas, sin error; U+0002/U+0003 eliminados; límites
  recortados a 1..50 y 0..1000; > 200 caracteres → 22023; consulta compleja ~9 ms.
- `search_plain_text`: elimina caracteres de control; `<`/`>` nunca sobreviven (`‹ ›`); sin doble
  decodificación de entidades.
- Grants: `search_articles` y `search_plain_text` solo anon/authenticated, PUBLIC revocado.
- `search_es/en` legibles por API: protegidas por la RLS de fila de `articles`.
- `public` no tocado; configs de texto en `guide`. Advisors sin novedades.
- CHECKs de tallas y `grading_difficulty` verificados.

## Hallazgos (ninguno bloqueante)

| # | Severidad | Hallazgo | Corrección |
|---|---|---|---|
| 1 | Baja · condición frontend | El componente del buscador debe escapar todo y solo después convertir U+0002/U+0003 en `<mark>`, únicamente en `headline`; `title` y `excerpt` siempre con interpolación, nunca `v-html`. | Revisión de leona-lia cuando exista el componente. |
| 2 | Baja · ruido | `activity_log` incluye `search_es/en` en columnas cambiadas y en el snapshot de DELETE. | Excluirlas en `guide.log_activity`. |
| 3 | Baja · operativa | Las configs dependen de `extensions.unaccent`, compartida con Chalk app: un `DROP EXTENSION … CASCADE` las tiraría. | Anotarlo en `docs/data-model.md` §8 y en `docs/chalk-app-pendientes.md`. |
| 4 | Info · DoS | Consulta solo negativa (`-xyz`) devuelve todos los artículos vivos con `ts_headline` sobre el cuerpo completo. Barato hoy. | Limitar el texto de `ts_headline` o exigir un término positivo. |
| 5 | Info · funcional | La regex `<[^>]*>` borra texto entre `<` y `>` sueltos (no ocurre con TipTap). | Ninguna. |

## Apéndice · `20261008173142_guide_search_review_fixes` (leona-lia, 2026-10-08)

**Veredicto: APROBADO.** Hallazgos 2 y 4 cerrados; el 3 documentado por jabali-javi. Queda abierto el 1
(escapado en el componente del buscador) hasta que exista y se revise.

- `log_activity`: DEFINER, `search_path=''`, solo `postgres`; 16 triggers intactos; snapshot de
  `items` completo (23 columnas); en `articles` sin `search_*`.
- `search_articles`: INVOKER, firma y grants sin cambios; consultas sin término positivo → 0 filas;
  `left(…, 20000)` antes de `ts_headline`.
- `guide_rls_leaks.sql`: ALL RLS TESTS PASSED. Advisors sin novedades. `public` sin tocar.

## Apéndice 2 · Componente del buscador del blog (leona-lia, 2026-10-09)

**Veredicto: APROBADO. Hallazgo 1 cerrado.** `headline` se trocea por U+0002/U+0003 en texto + `<mark>` sin
`v-html` (`app/utils/search-headline.ts`, `ArticleSearchHeadline.vue`); `title`/`excerpt` por interpolación;
`?q=` recortado y solo interpolado, búsqueda solo en cliente, `noindex` con `q`; filas sin slug descartadas y
enlaces por ruta con nombre. De paso: `dominant_color` validado y recalculado antes de ir a CSS
(`app/utils/ambient.ts`); tarjetas de newsletter con consentimiento desmarcado y obligatorio, sin `v-html`.

Pendiente aparte: revisar el saneado del HTML editorial que pinta `app/components/ui/Prose.vue` (único `v-html`)
cuando exista el editor del panel (F6.4) — incluido en F6.19.
