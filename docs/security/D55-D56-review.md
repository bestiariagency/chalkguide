# Revisión de seguridad · D55 / D56

Revisora: leona-lia · 2026-11-06 · Proyecto `eqtjlafxtrzbjazhhyin`, schema `guide` · Veredicto: **APROBADO** (sin vetos)

Migraciones revisadas: `20261106073940_guide_d56_consent_v3_en`, `20261106074211_guide_d55_dashboard_stats_v2` (sustituida), `20261106074522_guide_d55_dashboard_event_agent_info`, `20261106074754_guide_d55_admin_search`, `20261106074905_guide_d55_admin_search_body_min_word` y `20261106075624_guide_d55_admin_search_snippet_spaces`. El código vivo coincide con la última migración de cada función.

## 1. `admin_events_agent_info(p_ids uuid[])`

- SECURITY DEFINER, `search_path=''`; la primera sentencia es `assert_admin()`. EXECUTE solo para `authenticated` y `postgres`. anon, no admin y service_role sin claims reciben 42501.
- Ids arbitrarios: sin fuga. Solo el admin pasa la guarda, y la ocultación de F6.12 sigue intacta (authenticated sin SELECT en `source`, `source_url`, `dedupe_key` ni `agent_meta`). Devuelve solo `id`, `source` y `duplicate_of`.
- `duplicate_of`: CASE con regex, más el CHECK `events_agent_meta_shape` al insertar (23514). Dos capas.

## 2. `admin_search(p_query, p_kinds, p_limit)`

- INVOKER, `search_path=''`, `assert_admin()`. anon y no admin reciben 42501.
- tsquery: las palabras se reducen a `[[:alnum:]]`, de 3 o más; los operadores los pone el código. Probado con payloads hostiles y con stopwords.
- LIKE: escapa `\`, `%` y `_`. `100%` y `a_b` son literales.
- Límites: `left(…,400)` y después 100; menos de 2 caracteres → 22023; `p_kinds` con más de 20, fuera de la lista blanca o con null → 22023; `p_limit` acotado a 1–20.
- No lee `user_reviews`, `subscribers`, `user_profiles`, `admins` ni `activity_log`. Lee `content_drafts` solo para `has_draft`. Los eventos `rejected` quedan excluidos.
- **Requisito del front:** `snippet` es texto plano con las entidades decodificadas (puede traer `<`, `>`, `"` y `&`). Se pinta solo con interpolación, **nunca con `v-html` ni `innerHTML`**. Lo mismo para `title`, `key` y `data`.

## 3. `admin_dashboard_stats()`

- INVOKER, `search_path=''`, `assert_admin()`. Los campos nuevos son agregados. `events_drafts_duplicates` usa el helper (corrige el 42501 de 07:42–07:45 UTC).
- EXECUTE de `service_role`: es previo y queda neutralizado por `assert_admin`. Opcional: revocarlo.
- Observación de 6.19 sobre `recent_activity`: **mantener**. Hoy solo registra tablas de contenido. Condición: si algún día se auditan `subscribers`, `user_reviews` o `user_profiles`, esas filas quedan fuera o se enmascaran, con nueva revisión.

## 4. D56 · consentimiento v3

- v2 cerrada en `2026-11-06 07:39:40.729186+00`; la v3 empieza en ese mismo instante, `preserved`, y es la única vigente.
- Textos exactos: es igual que la v2; en «I'd like to receive news from ChalkGuide by email. I can unsubscribe at any time.». `site_settings` coincide.
- Guardas intactas; la v3 no se puede editar ni borrar. Un alta nueva registra la v3. Un no admin no puede versionar.
- RGPD art. 7.1: se cumple.
- Nota: las altas en inglés anteriores a la v3 tienen `text_en` null. Al lanzar, no debe haber suscriptores reales `en` con la v2.

## 5. Pruebas

Bloque «D56 · D55» de `guide_rls_leaks.sql` (líneas 7916–8187) en BEGIN…ROLLBACK: **PASSED**. Las pruebas extra también OK. Tras el rollback no quedan fixtures. La suite completa no se ha ejecutado entera: hay que hacerlo en local.

## 6. Advisors y `public`

Único aviso nuevo: 0029 en `admin_events_agent_info`, esperado y mitigado. `public` intacto (7 tablas, 19 policies).

## Pendientes (no bloquean)

1. Front de ⌘K sin `v-html` (comprobarlo en la revisión de UI).
2. Opcional: revocar el EXECUTE de `service_role` en `admin_dashboard_stats`.
3. `recent_activity`: mantener, con la condición anterior.
4. Ejecutar en local la suite completa.
5. Antes de lanzar: ningún suscriptor real `en` con la v2.
6. `20261106080255_guide_d51_body_limits_legal_v2` necesita su propia revisión.

_Guardado por SúperXavi a partir del informe de leona-lia (no tiene herramienta de escritura)._
