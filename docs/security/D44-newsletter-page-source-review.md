# D44 Origen `newsletter_page` · revisión de seguridad (leona-lia)

Fecha: 2026-10-31 · Proyecto `eqtjlafxtrzbjazhhyin`, schema `guide` · Decisión D44.
(Informe dictado por leona-lia, sin herramienta de escritura; guardado por el orquestador.)

## Veredicto: APROBADO

Sin vetos abiertos. Pendiente: suite completa ejecutada por Xavi (`ALL RLS TESTS PASSED`).

## Alcance y método

Migración `20261031002531_guide_d44_newsletter_page_source` y aserciones D44 de `supabase/tests/guide_rls_leaks.sql`. Todo con SQL de solo lectura; los sondeos por rol, en `BEGIN TRANSACTION READ ONLY` con `SET ROLE`. No se ha escrito ninguna fila, así que el alta real con el nuevo origen queda sin ejecutar. La cubre la suite.

## Comprobado contra la base

- **Migración aplicada:** el texto de `schema_migrations` coincide con el fichero. Solo toca `guide.subscribers` y `guide.subscribe_newsletter`, y es la última versión aplicada.
- **Cuerpo de la función:** al quitar `, 'newsletter_page'` de `prosrc`, el resultado es idéntico al cuerpo de `20261029145232` (comparación de cadenas; diferencia de longitud 19 = 19 esperados). Un único overload.
- **Función:** misma firma, propietario postgres, SECURITY DEFINER, `search_path=""`.
- **CHECK:** validado, con la lista de `20261029143312` + `newsletter_page`. `admin_import` sigue fuera del CHECK y de `p_source`.
- **ACL de la función:** EXECUTE para postgres, anon, authenticated y service_role; PUBLIC no. La migración no contiene GRANT ni REVOKE.
- **ACL de las tablas:** anon no tiene ningún privilegio en `subscribers` ni en `subscriber_consent_events`. authenticated solo tiene SELECT por columnas en `subscribers`, sin `unsubscribe_token`, `confirm_token_hash`, `user_id` ni `brevo_*`. Sus policies de SELECT exigen `guide.is_admin()`.
- **`guide.is_admin()`:** DEFINER, `search_path=""`, sin recursión.
- **Datos:** `subscribers` 0, `subscriber_consent_events` 0, `consent_texts` 2, `consent_version` 2.
- **Otros consumidores del origen:**
  - `subscribers_log_consent` copia el valor y `events.source` solo limita a 40 caracteres.
  - `admin_list_subscribers` no usa lista cerrada de orígenes.
  - `export_build` valida con `^[a-z0-9_]{1,40}$`, que admite el valor nuevo.
  - No hay más constraints ni funciones con la lista.

## Pruebas de fuga (solo lectura)

| Consulta | anon | authenticated no admin |
| --- | --- | --- |
| `subscribers` y `subscriber_consent_events` | 42501 | 0 filas (tablas vacías; protección verificada en la policy) |
| `subscribers.unsubscribe_token` | 42501 | 42501 |
| `export_subscribers` | 42501 | 42501 |
| `items` no publicados (postgres ve 3) | 0 | 0 |
| `events` en borrador y opiniones ocultas (postgres ve 0) | 0 | 0 (no concluyente: no hay filas) |

- **Escrituras:** verificadas por privilegios, sin intentarlas. anon no tiene INSERT, UPDATE, DELETE ni TRUNCATE en ninguna tabla o vista de `guide`. authenticated no los tiene en `subscribers` ni en `subscriber_consent_events`.
- **No repetido:** editar opiniones ajenas, duplicar opinión y cambiar su moderación. D44 no toca `user_reviews`; lo cubre la suite.

## RGPD

- **Fecha, versión y página:** sin cambios. `consent_at` es `now()`, `consent_version` sale de `site_settings` y `consent_page` conserva el recorte O4 (sin query ni fragmento).
- **Exactitud:** `newsletter_page` mejora el registro; usar `footer` lo habría falseado.
- **Valor declarado:** origen y página los envía el cliente, como en todos los orígenes. Son contexto; la prueba de la alta es el doble opt-in.
- **Código actual:** ningún componente usa aún el origen; solo está en el tipo de `app/services/newsletter.ts`.

## Rate limit

D44 no lo cambia. `subscribe_newsletter` sigue sin límite propio: solo es no-op si se repite un `pending` de menos de 24 h. Esto no depende del origen, porque la RPC ya era pública. Sigue siendo condición de entrada de F4.6 (O5 de F6.14), que debe cumplirse antes de enviar emails.

## Suite

- **Aserciones añadidas:** alta como anon con `newsletter_page` y `/newsletter` (línea 308) y origen guardado (735-737).
- **Negativas que siguen:** `admin_import` (299 y 6658) y origen desconocido (309).
- **Fixture `rls-news@chalkguide.test`:** por lectura, no rompe los recuentos, que son dinámicos o filtran por `rls-f614`/`active`. Está pendiente de confirmar al ejecutar la suite.

## Observaciones (no bloquean)

1. **O1 · Panel sin el origen nuevo.** `SOURCE_OPTIONS` (`app/utils/admin-subscribers.ts:102`) no incluye `newsletter_page`.
   - **Efecto:** `sourceLabel` mostrará el valor en crudo en la tabla, en la prueba de consentimiento y en la ficha. No se podrá filtrar por él al exportar (`app/utils/admin-export.ts:90`). En el filtro del listado solo aparecerá cuando haya filas.
   - **Corrección:** añadir la opción, con etiqueta de loro-lola, antes de publicar el formulario (coneja-lucky).
2. **O2 · Aserción incompleta.** La suite comprueba `consent_source`, pero no `consent_page`, ni `consent_version`, ni el evento `subscribe` con ese origen y página. El trigger es genérico y el riesgo es bajo. Corrección sugerida a jabali-javi: ampliar la aserción de las líneas 735-737.
3. **O3 · Corrección a F6.14.** Aquel informe decía «EXECUTE solo anon/authenticated», pero service_role también lo tiene, heredado de `20261005052002`. D44 no lo introduce. Añadir a la revisión de grants de service_role en F4.6 (O3 de F6.14).

## `get_advisors` (security) y `public`

- **Advisors:** ningún aviso nuevo atribuible a D44. Los de `subscribe_newsletter` son DEFINER ejecutable por anon y authenticated, intencionados.
- **Avisos previos de `public`:** son de Chalk app. `search_path` mutable de sus funciones ya está en `docs/chalk-app-pendientes.md` (A4).
- **`public`:** la migración no lo toca (texto aplicado verificado). No hay una foto anterior de `public` con la que comparar, así que la garantía viene de ese texto.
