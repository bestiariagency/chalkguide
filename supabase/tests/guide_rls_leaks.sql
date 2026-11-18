-- Pruebas de fuga RLS del schema guide (F2.10, leona-lia). Incluye los casos H1–H5 de
-- docs/security/F2.10-guide-review.md y los huecos señalados (Storage list/update/insert + delete en catálogo, vistas con
-- ítems ocultos, article_items con artículo programado, JWT con claims forjados) y D23 (borradores de cambios
-- sobre lo publicado y registro de exportaciones) y D24 (última visita a Opiniones, redirecciones de slugs,
-- fichas con opiniones no borrables y O5: cascada de updated_by en borradores) y F6.4 (lo vivo no se edita
-- en directo: PT423 según el reloj del servidor; despublicar con unpublish_article) y F6.5 (categorías: crear/editar
-- con 301, ordenar sin tocar la versión de lo vivo, borrar con reasignación de artículos, borradores y 301) y F6.6
-- (medios: rutas y objetos inmutables en Storage, fila coherente con el objeto, reemplazo, borrado con usos, buscador)
-- y D27 (no se publica contenido con imágenes sin alt_es; no se vacía el alt de lo publicado)
-- y F6.7 (fichas: alta atómica con create_item, ocultar con unpublish_item, índices de no publicadas, scores por categoría).
-- y F6.8 (resoladores: servicios D18, CHECK de la tabla validados al guardar el borrador, sellos de precio).
-- y F6.9 (pies de gato: marca/modelo opcionales hasta publicar, afiliado derivado y URL validada, precio con fecha,
-- "Lo que aprendí" en borradores con D27, shoe_model_taken solo admin)
-- y F6.10 (criterios: key/categoría inmutables, fórmulas no se desactivan ni borran, borrar solo sin notas, reorden
-- completo, criteria_usage, notas de inactivos conservadas al publicar y ocultas a anon/no admin, medias solo con activos)
-- y F6.11 (opiniones del panel: bandeja admin sin user_id, búsqueda sin inyección, moderar con registro sin datos
-- personales, borrado solo por RPC con motivo, contadores desde la última visita, ayuda de criterios activos).
-- y F6.11b (fotos en opiniones: bucket privado de subidas y público de copias re-codificadas, rutas sin user_id,
-- consentimiento de derechos de imagen, máx. 3 por opinión, cupo diario, moderación con motivo visible solo al dueño,
-- registro sin datos personales, huérfanos y limpieza diaria por service_role, cascadas de opinión y cuenta).
-- y F6.12 (agenda: estados y transiciones, el agente solo inserta borradores y no repite dedupe_key, procedencia oculta a
-- clientes, agent_meta con forma fija, motivo de descarte, solo rocódromos, PT423 al borrar lo publicado, lote, contadores)
-- y D33 (descarte nocturno de borradores caducados con motivo «Caducado», reservado al sistema).
-- y F6.13 (páginas: cinco claves cerradas sin alta ni borrado, clave y slugs inmutables, PT423 con exención atada a la fila,
-- unpublish_page con registro, legales no despublicables y solo texto, revised_on al publicar, page_versions inmutable).
-- y F6.14 (suscriptores: sin escritura directa ni lectura de tokens, baja en lote con motivo y sin vuelta atrás, supresión
-- RGPD que anonimiza y conserva el historial sin email ni página, consent_texts append-only y versionado desde Ajustes,
-- confirm_newsletter neutra, caducidad y retención sin programar hasta F4.6).
-- y F6.15 (exportar: admin_export exporta y registra en una llamada con filas reales, filtros en lista blanca, finalidad
-- obligatoria y 5 columnas mínimas en suscriptores, sin suprimidos ni tokens, CSV de fichas por categoría, cuerpo solo en
-- JSON, tope y truncated, recuento sin registro, «Últimas exportaciones»).
-- y D41 (fotos del hero en Ajustes: solo admin, alt_es y alt_en, públicas mientras estén en una ranura, cuentan como medio
-- en uso para delete_media y el vaciado de alt; el borrado directo vacía la ranura por el FK on delete set null).
-- y F6.15b (importar fichas, D50: solo admin y solo por RPC; dry_run no escribe; apply exige la huella y es todo o nada;
-- lo publicado solo recibe borrador y un borrador distinto da error; null, published y URL ajenas rechazados; reseña en
-- texto plano escapada; fotos por referencia a Medios; bloqueos de publicación en servidor; publicar en lote; deshacer).
-- y F6.15b O1 (import_row vacía draft_op/unpublish_op) y D51 (datos del autor en Ajustes: lectura pública, escritura solo
-- admin, topes y forma de author_stats, foto con alt_es y alt_en, pública mientras esté elegida y «medio en uso»).
-- y D56 (consentimiento v3 con el mismo es y el en aprobado, v2 cerrada, altas nuevas con la versión vigente) y D55
-- (Inicio v2: campos nuevos de admin_dashboard_stats; ⌘K: admin_search solo admin, sin tildes, comodines escapados,
-- límite y total por tipo, orden por rango, sin tablas privadas; helper admin_events_agent_info solo admin).
-- y D51 O3/O7 + F6.13 O2 (tope de 300000 caracteres en body_html_*; legales sin nodos v2 en el JSON; atributos
-- style/on* tras «/» o comilla y lista blanca de esquemas en href/src).
-- y D57 (multiautor: guide.authors legible por todos y escrito solo por el admin, topes, slug único, un solo is_primary,
-- foto con alt_es y alt_en y «medio en uso»; articles.author_id solo por borrador en lo vivo; borrar un autor desasigna
-- sus artículos y borradores; author_id en search_articles y export_articles).
-- y F6.17 (Ajustes: una sola fila sin alta ni borrado, redes solo https con host, topes de pie/newsletter/consentimiento/email,
-- admin_update_settings solo admin, todo o nada, conflicto PT409 por columna, '' a null y consentimiento con versión nueva;
-- admin_my_sessions solo las sesiones propias, sin IP ni ids).
-- y F6.18 (Actividad: admin_activity_list solo admin, sin old_row/actor_id, etiqueta y details de tablas privadas saneados
-- también en recent_activity, búsqueda sin comodines ni emails del registro, cursor sin huecos) y F6.16 (admin_stats solo
-- admin, contrato §16.8, solo recuentos, subs_total actual = activos; rango personalizado p_from/p_to validado con 22023 y
-- tope de 24 meses por la purga de activity_log, previous/current_totals del periodo anterior de la misma duración y
-- previous null si empieza antes del corte).
-- y F6.19 (draft_op 'publish:<id>' y guardas de content_drafts_log_write, 18 casos de href en legales, guarda de lo
-- vivo con borrador también ante scheduled futuro, desempate de quintiles, invisibles en marca/modelo y «'» en afiliado,
-- job_health y cleanup_* del Inicio, purga de cron.job_run_details, EXECUTE de B1/B2).
-- y D66 (consentimiento de afines related_products: casilla opcional pending hasta el doble opt-in, dar/retirar con token
-- tras confirmar, versión de texto propia y consent_texts por finalidad, historial con purpose, retirada independiente de
-- la baja de newsletter, retención de 3 años desde la retirada, lectura en panel y exportación; veto: token conservado
-- al re-suscribir con afines vigente, admin_withdraw_related, supresión que retira afines, alta sin EXECUTE de service_role).
-- y D66 p_related (filtro de afines en admin_list_subscribers) y D69 (analítica propia guide.analytics_*: track_event con
-- lista cerrada y tope global, sin identificadores, newsletter_confirmed solo desde el servidor, purga 90 días / 24 meses,
-- RPC agregadas solo admin).
-- y F8 (ingesta, J1–J40 de docs/security/F8.1-ingest-spec.md: token, error uniforme, lista blanca, URLs, PII, eco del
-- token, dedupe del servidor y J18b, topes 40/80/1/3/150, dry_run, ventana R1, contexto sin borradores, columnas de news,
-- agent_meta reducido, registro by=agent, carta semanal +1 h y vuelta a borrador D77).
-- y F8 huecos 8.9/8.10 (origen 'noticias', events.run_id solo de la ingesta e inmutable, search_news con p_scope y
-- has_note, tipo 'news' en admin_search y módulo 'news' en admin_export/admin_export_count sin columnas internas).
-- Se ejecuta entero como postgres (execute_sql o psql) dentro de BEGIN … ROLLBACK: no deja datos
-- (los usuarios de prueba de auth.users y el objeto de Storage también se descartan).
-- Si algo falla, lanza una excepción LEAK/FAIL y la transacción se aborta.
-- ⚠ Ejecutar SIEMPRE el fichero completo (empieza por BEGIN y acaba en ROLLBACK). Nunca fragmentos sueltos ni `psql -1`:
-- fuera de una transacción explícita los fixtures harían COMMIT (p. ej. retiran las filas reales de guide.pages).
-- Las guardas F6.13 V1 (savepoint + marca guide.rls_suite) abortan antes de borrar si no hay transacción explícita.

begin;
-- F6.13 V1: marca de suite completa (local a esta transacción); la exigen los fixtures destructivos.
select set_config('guide.rls_suite', 'running', true);

-- ═════════════ Fixtures (como postgres) ═════════════
-- F6.4: los fixtures crean artículos ya publicados con relacionados → mantenimiento explícito (postgres).
select set_config('guide.draft_op', 'maintenance', true);
-- F6.9 (O1): la ficha shoe publicada va antes que su detalle (FK) → la comprobación de marca/modelo se difiere
-- hasta insertar shoes y se vuelve a inmediata justo después.
set constraints guide.items_shoe_require_brand_model deferred;
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at)
values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'rls-user2@chalkguide.test', '{"full_name":"User Dos"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'rls-user3@chalkguide.test',
   jsonb_build_object('full_name', E'<img src=x onerror=alert(1)>  Pepe\n\t"Hack"\u202Egnp.exe\u200B\uFEFF'), now(), now()),
  ('a0000000-0000-4000-8000-000000000005', 'authenticated', 'authenticated', 'rls-user4@chalkguide.test', '{"full_name":"  ÁLVARO   de la  Peña "}', now(), now()),
  -- B1-bis: nombres de Google que no son un nombre → la RPC debe caer a "Escalador/a", nunca fallar
  ('a0000000-0000-4000-8000-000000000006', 'authenticated', 'authenticated', 'rls-user5@chalkguide.test', '{"full_name":"M 612345678"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000007', 'authenticated', 'authenticated', 'rls-user6@chalkguide.test', '{"name":"pepe(at)gmail.com"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000008', 'authenticated', 'authenticated', 'rls-user7@chalkguide.test', '{"full_name":"pepe﹫gmail.com"}', now(), now());

insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test');

-- F6.6: el objeto va antes que la fila (el trigger exige el objeto y toma mime/size de sus metadatos).
insert into storage.objects (bucket_id, name, metadata) values ('media', 'b0000000-0000-4000-8000-000000000001/1-test.jpg',
  '{"mimetype":"image/jpeg","size":1000}');
-- D27: con alt_es (los bloques D23/F6.4 lo publican como portada, OG y galería).
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, alt_es)
values ('b0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001/1-test.jpg', 'test.jpg', 'image/jpeg', 1000,
        'Imagen de prueba');

insert into guide.article_categories (id, name_es, slug_es) values
  ('c0000000-0000-4000-8000-000000000001', 'Cat A', 'rls-cat-a'),
  ('c0000000-0000-4000-8000-000000000002', 'Cat B', 'rls-cat-b');

insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, cover_media_id) values
  ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'Publicado', 'rls-publicado', 'b0000000-0000-4000-8000-000000000001'),
  ('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', 'draft', null, 'Borrador', 'rls-borrador', null),
  ('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', 'scheduled', now() + interval '7 days', 'Programado', 'rls-programado', null);

-- F6.13 (D34): las cinco claves de guide.pages son cerradas y los fixtures las reutilizan, así que las filas reales se
-- retiran dentro de esta transacción (mantenimiento como postgres; el ROLLBACK final las restaura).
-- F6.13 V1: solo dentro de la suite completa. SAVEPOINT falla (25P01) fuera de una transacción explícita y el DO exige
-- la marca local guide.rls_suite; el DELETE va dentro del DO para que no corra si la guarda falla.
savepoint pages_guard;
release savepoint pages_guard;
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  delete from guide.pages;
end $$;
insert into guide.pages (id, key, title_es, slug_es, published, noindex) values
  ('e0000000-0000-4000-8000-000000000001', 'cookies', 'Página borrador', 'rls-pagina-borrador', false, true);

insert into guide.items (id, category, name, slug, published) values
  ('f0000000-0000-4000-8000-000000000001', 'gym', 'Gym publicado', 'rls-gym-pub', true),
  ('f0000000-0000-4000-8000-000000000002', 'gym', 'Gym oculto', 'rls-gym-oculto', false),
  ('f0000000-0000-4000-8000-000000000003', 'shoe', 'Shoe publicado', 'rls-shoe-pub', true),
  -- D17: ítems extra para el límite de 5 opiniones nuevas / 24 h
  ('f0000000-0000-4000-8000-000000000004', 'gym', 'Gym 4', 'rls-gym-4', true),
  ('f0000000-0000-4000-8000-000000000005', 'gym', 'Gym 5', 'rls-gym-5', true),
  ('f0000000-0000-4000-8000-000000000006', 'gym', 'Gym 6', 'rls-gym-6', true),
  ('f0000000-0000-4000-8000-000000000007', 'gym', 'Gym 7', 'rls-gym-7', true),
  ('f0000000-0000-4000-8000-000000000008', 'gym', 'Gym 8', 'rls-gym-8', true);
insert into guide.gyms (item_id, price_monthly_eur) values
  ('f0000000-0000-4000-8000-000000000001', 50), ('f0000000-0000-4000-8000-000000000002', 40);
insert into guide.shoes (item_id, brand, model) values ('f0000000-0000-4000-8000-000000000003', 'RLS', 'Test');
set constraints guide.items_shoe_require_brand_model immediate;

insert into guide.article_items (article_id, item_id) values
  ('d0000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001'),
  ('d0000000-0000-4000-8000-000000000003', 'f0000000-0000-4000-8000-000000000001');

-- D21 · Búsqueda del blog. Categoría y slugs propios (fts-*) para no alterar los recuentos de rls-*.
-- 04: publicado es+en (cuerpo con etiquetas, entidades y U+0002/U+0003 falsos); 05: publicado solo es con
-- title_en/slug_en pero sin cuerpo en (has_en = false, search_en no vacío); 06: borrador; 07: programado.
insert into guide.article_categories (id, name_es, slug_es) values
  ('c0000000-0000-4000-8000-000000000003', 'Cat FTS', 'fts-cat');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, excerpt_es, body_html_es,
                            title_en, slug_en, body_json_en, body_html_en) values
  ('d0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000003', 'published', now() - interval '2 days',
   'Rocódromo zarigüeya', 'fts-publicado', 'Extracto público',
   E'<p>Texto con rlszorro <script>alert(1)</script> &lt;b&gt;negrita&lt;/b&gt; \u0002falso\u0003 y más.</p><p><a href="https://rlsenlace.test">enlace</a></p>',
   'Possum gym', 'fts-published', '{"type":"doc","content":[]}', '<p>English rlszorro body.</p>'),
  ('d0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000003', 'published', now() - interval '3 days',
   'Solo en castellano', 'fts-solo-es', null, '<p>Otro rlszorro.</p>',
   'rlszorro english title', 'fts-only-title', null, null),
  ('d0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000003', 'draft', null,
   'Borrador rlszorro', 'fts-borrador', null, '<p>rlszorro</p>',
   'Draft rlszorro', 'fts-draft', '{"type":"doc","content":[]}', '<p>rlszorro</p>'),
  ('d0000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000003', 'scheduled', now() + interval '7 days',
   'Programado rlszorro', 'fts-programado', null, '<p>rlszorro</p>',
   'Scheduled rlszorro', 'fts-scheduled', '{"type":"doc","content":[]}', '<p>rlszorro</p>');

-- D21 · Tallas del autor y dificultad de graduación: CHECK (como postgres)
do $$
begin
  begin update guide.shoes set author_size_eu = 42 where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D21: talla del autor en un modelo que no tiene'; exception when check_violation then null; end;
  update guide.shoes set owned_by_author = true where item_id = 'f0000000-0000-4000-8000-000000000003';
  begin update guide.shoes set author_size_eu = 42.3 where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D21: talla sin paso de media'; exception when check_violation then null; end;
  begin update guide.shoes set author_street_size_eu = 29.5 where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D21: talla de calle fuera de rango'; exception when check_violation then null; end;
  begin update guide.shoes set author_size_eu = 50.5 where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D21: talla fuera de rango'; exception when check_violation then null; end;
  update guide.shoes set author_size_eu = 41.5, author_street_size_eu = 43 where item_id = 'f0000000-0000-4000-8000-000000000003';
  begin update guide.shoes set owned_by_author = false where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D21: deja de tenerlo con tallas puestas'; exception when check_violation then null; end;
  begin update guide.gyms set grading_difficulty = 6 where item_id = 'f0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D21: dificultad 6'; exception when check_violation then null; end;
  begin update guide.gyms set grading_difficulty = 0 where item_id = 'f0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D21: dificultad 0'; exception when check_violation then null; end;
  update guide.gyms set grading_difficulty = 4 where item_id = 'f0000000-0000-4000-8000-000000000001';
  update guide.gyms set grading_difficulty = 2 where item_id = 'f0000000-0000-4000-8000-000000000002';
end $$;

-- D22 · Dinamismo, nota de ajuste de talla y color dominante: CHECK (como postgres)
do $$
begin
  begin update guide.gyms set setting_dynamism = 6 where item_id = 'f0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: dinamismo 6'; exception when check_violation then null; end;
  begin update guide.gyms set setting_dynamism = 0 where item_id = 'f0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: dinamismo 0'; exception when check_violation then null; end;
  update guide.gyms set setting_dynamism = 5 where item_id = 'f0000000-0000-4000-8000-000000000001';
  update guide.gyms set setting_dynamism = 1 where item_id = 'f0000000-0000-4000-8000-000000000002';
  -- shoe f…03 ya es owned_by_author (bloque D21)
  begin update guide.shoes set author_size_note_es = repeat('a', 141) where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: nota de talla > 140'; exception when check_violation then null; end;
  begin update guide.shoes set author_size_note_es = '' where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: nota de talla vacía'; exception when check_violation then null; end;
  begin update guide.shoes set author_size_note_en = 'Tight heel' where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: nota en inglés sin original'; exception when check_violation then null; end;
  begin update guide.shoes set author_size_note_es = 'Ok', author_size_note_en = repeat('a', 141) where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: nota en inglés > 140'; exception when check_violation then null; end;
  update guide.shoes set author_size_note_es = repeat('á', 140), author_size_note_en = 'Tight heel' where item_id = 'f0000000-0000-4000-8000-000000000003';
  update guide.shoes set author_size_note_es = 'Aprieta en el talón', author_size_note_en = 'Tight heel' where item_id = 'f0000000-0000-4000-8000-000000000003';
  begin update guide.shoes set author_size_eu = null, author_street_size_eu = null, owned_by_author = false
    where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: deja de tenerlo con nota de talla puesta'; exception when check_violation then null; end;
  begin update guide.shoes set author_size_note_es = null where item_id = 'f0000000-0000-4000-8000-000000000003';
    raise exception 'FAIL D22: borra el original dejando la traducción'; exception when check_violation then null; end;
  begin update guide.media set dominant_color = '#A1B2C3' where id = 'b0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: color en mayúsculas'; exception when check_violation then null; end;
  begin update guide.media set dominant_color = '#abc' where id = 'b0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: color corto'; exception when check_violation then null; end;
  begin update guide.media set dominant_color = E'#a1b2c3\n' where id = 'b0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: color con salto de línea'; exception when check_violation then null; end;
  begin update guide.media set dominant_color = 'red;background:url(x)' where id = 'b0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D22: color no hex (inyección CSS)'; exception when check_violation then null; end;
  update guide.media set dominant_color = '#2a1f17' where id = 'b0000000-0000-4000-8000-000000000001';
end $$;

-- Si hay datos (seed), se desactivan sus criterios para que las notas de prueba sean el conjunto completo.
-- F6.10: salvo los de fórmula (used_in_formula), que no se desactivan.
update guide.criteria set is_active = false where key not like 'rls\_%' and not used_in_formula;
insert into guide.criteria (id, category, key, name_es, name_en) values
  ('10000000-0000-4000-8000-000000000001', 'gym', 'rls_setting', 'Setting', 'Setting'),
  ('10000000-0000-4000-8000-000000000002', 'gym', 'rls_crowding', 'Afluencia', 'Crowding'),
  ('10000000-0000-4000-8000-000000000003', 'shoe', 'rls_comfort', 'Comodidad', 'Comfort');

insert into guide.author_reviews (id, item_id, category, body_html_es) values
  ('40000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000002', 'gym', '<p>oculta</p>');
insert into guide.author_review_scores (review_id, criterion_id, category, score) values
  ('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'gym', 5);

-- Opinión de user2 ocultada por el admin (H1)
insert into guide.user_reviews (id, item_id, category, user_id, overall_score, body, status) values
  ('20000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000003', 1, 'oculta', 'hidden');
insert into guide.user_review_scores (review_id, criterion_id, category, score) values
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'gym', 1),
  ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'gym', 1);

insert into guide.events (id, title_es, starts_at, status) values
  ('30000000-0000-4000-8000-000000000001', 'Evento borrador', now() + interval '3 days', 'draft'),
  ('30000000-0000-4000-8000-000000000002', 'Evento aprobado', now() + interval '3 days', 'approved');

-- Suscriptores: uno normal, uno dado de baja (H2) y una víctima pendiente sin user_id (H3)
insert into guide.subscribers (email, consent_source, consent_version) values ('rls-sub@chalkguide.test', 'footer', 1);
insert into guide.subscribers (id, email, consent_at, consent_source, consent_version)
values ('50000000-0000-4000-8000-000000000001', 'rls-baja@chalkguide.test', now() - interval '90 days', 'footer', 1);
update guide.subscribers set status = 'active', confirmed_at = now() - interval '89 days'
where id = '50000000-0000-4000-8000-000000000001';
update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '10 days', unsubscribe_source = 'link'
where id = '50000000-0000-4000-8000-000000000001';
insert into guide.subscribers (id, email, consent_at, consent_source, consent_version)
values ('50000000-0000-4000-8000-000000000002', 'rls-victima@chalkguide.test', now() - interval '3 days', 'footer', 1);

select set_config('guide.draft_op', '', true);

-- ═════════════ anon ═════════════
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

do $$
declare
  v_n integer;
begin
  -- Tablas y vistas internas: sin privilegio
  begin perform 1 from guide.subscribers; raise exception 'LEAK anon: lee subscribers'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.subscriber_consent_events; raise exception 'LEAK anon: lee consentimientos'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.admins; raise exception 'LEAK anon: lee admins'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.activity_log; raise exception 'LEAK anon: lee activity_log'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.content_media_refs; raise exception 'LEAK anon: lee content_media_refs'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.gym_waitlist; raise exception 'LEAK anon: lee gym_waitlist'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.user_profiles; raise exception 'LEAK anon: lee user_profiles'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_subscribers; raise exception 'LEAK anon: lee export_subscribers'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.media_usage; raise exception 'LEAK anon: lee media_usage'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.media_library; raise exception 'LEAK anon: lee media_library'; exception when insufficient_privilege then null; end;

  -- H5: ni user_id de opiniones ni columnas de auditoría
  begin perform user_id from guide.user_reviews; raise exception 'LEAK anon: lee user_reviews.user_id'; exception when insufficient_privilege then null; end;
  begin perform * from guide.user_reviews; raise exception 'LEAK anon: select * en user_reviews'; exception when insufficient_privilege then null; end;
  begin execute 'select created_by from guide.items'; raise exception 'LEAK anon: items.created_by existe'; exception when undefined_column then null; end;
  perform * from guide.user_reviews_public;

  -- Contenido no publicado
  if exists (select 1 from guide.articles where slug_es in ('rls-borrador', 'rls-programado')) then
    raise exception 'LEAK anon: ve borrador o programado futuro';
  end if;
  if not exists (select 1 from guide.articles where slug_es = 'rls-publicado') then raise exception 'FAIL anon: no ve el publicado'; end if;
  if exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000003') then
    raise exception 'LEAK anon: ve article_items de un programado';
  end if;
  if not exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL anon: no ve article_items del publicado';
  end if;
  if exists (select 1 from guide.pages where id = 'e0000000-0000-4000-8000-000000000001') then raise exception 'LEAK anon: ve página borrador'; end if;
  if exists (select 1 from guide.items where slug = 'rls-gym-oculto') then raise exception 'LEAK anon: ve ítem no publicado'; end if;
  if exists (select 1 from guide.gyms where item_id = 'f0000000-0000-4000-8000-000000000002') then raise exception 'LEAK anon: ve detalle de ítem oculto'; end if;
  if exists (select 1 from guide.author_reviews where item_id = 'f0000000-0000-4000-8000-000000000002') then raise exception 'LEAK anon: ve reseña de ítem oculto'; end if;
  if exists (select 1 from guide.author_review_scores where review_id = '40000000-0000-4000-8000-000000000001') then raise exception 'LEAK anon: ve notas de ítem oculto'; end if;
  if exists (select 1 from guide.gym_indices where item_id = 'f0000000-0000-4000-8000-000000000002') then raise exception 'LEAK anon: gym_indices muestra ítem oculto'; end if;
  if not exists (select 1 from guide.gym_indices where item_id = 'f0000000-0000-4000-8000-000000000001') then raise exception 'FAIL anon: gym_indices sin el publicado'; end if;
  if exists (select 1 from guide.item_author_scores where item_id = 'f0000000-0000-4000-8000-000000000002') then raise exception 'LEAK anon: item_author_scores muestra ítem oculto'; end if;
  if exists (select 1 from guide.item_user_ratings where item_id::text like 'f0000000-%') then raise exception 'LEAK anon: item_user_ratings cuenta opiniones ocultas'; end if;
  if exists (select 1 from guide.events where status not in ('approved', 'cancelled')) then raise exception 'LEAK anon: ve eventos que no son públicos (borrador o descartado)'; end if;
  if exists (select 1 from guide.user_reviews where status <> 'visible') then raise exception 'LEAK anon: ve opiniones ocultas'; end if;
  if exists (select 1 from guide.user_review_scores where review_id = '20000000-0000-4000-8000-000000000001') then raise exception 'LEAK anon: ve notas de opinión oculta'; end if;

  -- Escrituras directas
  begin insert into guide.articles (category_id, title_es, slug_es) values ('c0000000-0000-4000-8000-000000000001', 'x', 'rls-x');
    raise exception 'LEAK anon: inserta artículos'; exception when insufficient_privilege then null; end;
  begin update guide.items set name = 'hack'; raise exception 'LEAK anon: actualiza items'; exception when insufficient_privilege then null; end;
  begin delete from guide.media; raise exception 'LEAK anon: borra media'; exception when insufficient_privilege then null; end;
  begin update guide.site_settings set site_name = 'hack'; raise exception 'LEAK anon: actualiza ajustes'; exception when insufficient_privilege then null; end;

  -- RPC
  begin perform guide.admin_dashboard_stats(); raise exception 'LEAK anon: admin_dashboard_stats'; exception when insufficient_privilege then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 3); raise exception 'LEAK anon: submit_user_review'; exception when insufficient_privilege then null; end;
  begin perform guide.get_my_review('f0000000-0000-4000-8000-000000000001'); raise exception 'LEAK anon: get_my_review'; exception when insufficient_privilege then null; end;
  begin perform guide.publish_due_articles(); raise exception 'LEAK anon: publish_due_articles'; exception when insufficient_privilege then null; end;
  begin perform guide.subscribe_newsletter('rls-nuevo@chalkguide.test', 'es', 'footer', false); raise exception 'FAIL anon: alta sin consentimiento'; exception when invalid_parameter_value then null; end;
  begin perform guide.subscribe_newsletter('no-es-email', 'es', 'footer', true); raise exception 'FAIL anon: email inválido'; exception when invalid_parameter_value then null; end;
  begin perform guide.subscribe_newsletter('rls-nuevo@chalkguide.test', 'es', 'admin_import', true); raise exception 'FAIL anon: origen admin_import'; exception when invalid_parameter_value then null; end;
  perform guide.subscribe_newsletter('RLS-Nuevo@chalkguide.test ', 'en', 'footer', true, '/en/blog');
  perform guide.subscribe_newsletter('rls-nuevo@chalkguide.test', 'es', 'home', true);       -- repetido < 24 h: no-op
  perform guide.subscribe_newsletter('rls-baja@chalkguide.test', 'es', 'popup', true);       -- H2: tercero re-suscribe a una baja
  -- D22: orígenes de la newsletter en artículo (mitad y final); 'article' sigue valiendo
  perform guide.subscribe_newsletter('rls-mid@chalkguide.test', 'es', 'article_mid', true, '/blog/x');
  perform guide.subscribe_newsletter('rls-end@chalkguide.test', 'en', 'article_end', true, '/en/blog/x');
  perform guide.subscribe_newsletter('rls-art@chalkguide.test', 'es', 'article', true);
  -- D44: origen de la página /newsletter
  perform guide.subscribe_newsletter('rls-news@chalkguide.test', 'es', 'newsletter_page', true, '/newsletter');
  begin perform guide.subscribe_newsletter('rls-mid2@chalkguide.test', 'es', 'article_top', true); raise exception 'FAIL anon: origen desconocido'; exception when invalid_parameter_value then null; end;
  if guide.is_admin() then raise exception 'LEAK anon: is_admin() = true'; end if;

  -- Storage: ni listar, ni modificar, ni borrar, ni subir
  if exists (select 1 from storage.objects where bucket_id = 'media') then raise exception 'LEAK anon: lista el bucket media'; end if;
  update storage.objects set name = 'hack.jpg' where bucket_id = 'media';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK anon: modifica objetos de media'; end if;
  begin insert into storage.objects (bucket_id, name) values ('media', 'rls-anon.jpg');
    raise exception 'LEAK anon: sube a media'; exception when insufficient_privilege then null; end;
end $$;

-- D21 · search_articles (anon)
do $$
declare
  v_ids uuid[];
  v_total bigint;
  v_head text;
begin
  select array_agg(s.id order by s.id), max(s.total_count) into v_ids, v_total
  from guide.search_articles('rlszorro', 'es') s;
  if v_ids is distinct from array['d0000000-0000-4000-8000-000000000004', 'd0000000-0000-4000-8000-000000000005']::uuid[] or v_total <> 2 then
    raise exception 'LEAK anon search es: % (total %)', v_ids, v_total;
  end if;
  select array_agg(s.id), max(s.total_count) into v_ids, v_total from guide.search_articles('rlszorro', 'en') s;
  if v_ids is distinct from array['d0000000-0000-4000-8000-000000000004']::uuid[] or v_total <> 1 then
    raise exception 'LEAK anon search en (borrador/programado/sin has_en): % (total %)', v_ids, v_total;
  end if;
  -- Sin acentos y por prefijo de la última palabra; atributos (href) no indexados
  if not exists (select 1 from guide.search_articles('ROCODROMO zarigueya', 'es') where id = 'd0000000-0000-4000-8000-000000000004') then
    raise exception 'FAIL search: no ignora acentos';
  end if;
  if not exists (select 1 from guide.search_articles('rlszor', 'es') where id = 'd0000000-0000-4000-8000-000000000004') then
    raise exception 'FAIL search: sin prefijo en la última palabra';
  end if;
  if exists (select 1 from guide.search_articles('rlsenlace', 'es')) then raise exception 'FAIL search: indexa atributos HTML'; end if;
  if exists (select 1 from guide.search_articles('Borrador rlszorro', 'es')) then raise exception 'LEAK search: título de borrador'; end if;
  if exists (select 1 from guide.search_articles('rlszorro', 'es', 'c0000000-0000-4000-8000-000000000001')) then
    raise exception 'FAIL search: no filtra por categoría';
  end if;
  -- Fragmento: texto plano, sin < ni >, solo las marcas U+0002/U+0003 que pone ts_headline
  select s.headline into v_head from guide.search_articles('rlszorro', 'es') s where s.id = 'd0000000-0000-4000-8000-000000000004';
  if v_head ~ '[<>]' or v_head ~ E'\u0002falso' then
    raise exception 'LEAK search: fragmento con HTML o marcas del contenido: %', v_head;
  end if;
  if v_head !~ E'\u0002rlszorro\u0003' then raise exception 'FAIL search: fragmento sin marca: %', v_head; end if;
  if (char_length(v_head) - char_length(replace(v_head, E'\u0002', ''))) <> 1 then
    raise exception 'LEAK search: marcas de inicio inyectadas: %', v_head;
  end if;
  -- Validación de entrada
  begin perform guide.search_articles(repeat('a', 201), 'es'); raise exception 'FAIL search: acepta consulta > 200';
  exception when invalid_parameter_value then null; end;
  if exists (select 1 from guide.search_articles('  ', 'es')) or exists (select 1 from guide.search_articles(null, 'es')) then
    raise exception 'FAIL search: consulta vacía devuelve filas';
  end if;
  -- Revisión D21 (hallazgo 4): sin término positivo no hay búsqueda (0 filas); con uno, la negación filtra
  if exists (select 1 from guide.search_articles('-rlsnada', 'es')) or exists (select 1 from guide.search_articles('el -rlsnada', 'es'))
     or exists (select 1 from guide.search_articles('rlszorro or -rlsnada', 'es')) or exists (select 1 from guide.search_articles('-rlsnada', 'en')) then
    raise exception 'FAIL search: consulta solo negativa devuelve filas';
  end if;
  if (select count(*) from guide.search_articles('rlszorro -rlsnada', 'es')) <> 2 then
    raise exception 'FAIL search: término positivo con negación';
  end if;
  if (select count(*) from guide.search_articles('rlszorro', 'es', null, 1, 0)) <> 1
     or (select max(total_count) from guide.search_articles('rlszorro', 'es', null, 1, 1)) <> 2 then
    raise exception 'FAIL search: paginación/total';
  end if;
  -- Vector de búsqueda de un borrador tampoco se lee directamente
  if exists (select 1 from guide.articles where search_es @@ to_tsquery('guide.spanish_unaccent', 'rlszorro') and slug_es in ('fts-borrador', 'fts-programado')) then
    raise exception 'LEAK anon: search_es de borrador/programado';
  end if;
  -- Tallas y dificultad: visibles en el ítem publicado, no en el oculto
  if not exists (select 1 from guide.shoes where item_id = 'f0000000-0000-4000-8000-000000000003' and author_size_eu = 41.5) then
    raise exception 'FAIL anon: no ve la talla del autor';
  end if;
  if exists (select 1 from guide.gyms where item_id = 'f0000000-0000-4000-8000-000000000002') then raise exception 'LEAK anon: gym oculto'; end if;
  if not exists (select 1 from guide.gyms where item_id = 'f0000000-0000-4000-8000-000000000001' and grading_difficulty = 4) then
    raise exception 'FAIL anon: no ve grading_difficulty';
  end if;
  if not exists (select 1 from guide.gyms where item_id = 'f0000000-0000-4000-8000-000000000001' and setting_dynamism = 5) then
    raise exception 'FAIL anon: no ve setting_dynamism';
  end if;
  if not exists (select 1 from guide.shoes where item_id = 'f0000000-0000-4000-8000-000000000003' and author_size_note_es = 'Aprieta en el talón') then
    raise exception 'FAIL anon: no ve la nota de talla';
  end if;
  if not exists (select 1 from guide.media where id = 'b0000000-0000-4000-8000-000000000001' and dominant_color = '#2a1f17') then
    raise exception 'FAIL anon: no ve dominant_color de la portada publicada';
  end if;
end $$;

reset role;

-- ═════════════ authenticated no admin (user1) ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);

do $$
declare
  v_id  uuid;
  v_id2 uuid;
  v_n   integer;
begin
  if guide.is_admin() then raise exception 'LEAK user: is_admin() = true'; end if;
  if exists (select 1 from guide.subscribers) then raise exception 'LEAK user: lee subscribers'; end if;
  if exists (select 1 from guide.subscriber_consent_events) then raise exception 'LEAK user: lee consentimientos'; end if;
  if exists (select 1 from guide.admins) then raise exception 'LEAK user: lee admins'; end if;
  if exists (select 1 from guide.activity_log) then raise exception 'LEAK user: lee activity_log'; end if;
  -- F6.15 O2: las vistas export_* ya no tienen grant para authenticated (solo se exporta con admin_export)
  begin perform 1 from guide.export_subscribers; raise exception 'LEAK user: lee export_subscribers'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_items; raise exception 'LEAK user: lee export_items'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_user_reviews; raise exception 'LEAK user: lee export_user_reviews'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.media_usage) or exists (select 1 from guide.media_library) then
    raise exception 'LEAK user: vistas de panel con filas';
  end if;
  if exists (select 1 from guide.articles where slug_es in ('rls-borrador', 'rls-programado')) then raise exception 'LEAK user: ve borradores'; end if;
  if exists (select 1 from guide.user_reviews where status = 'hidden') then raise exception 'LEAK user: ve opinión oculta ajena'; end if;
  if exists (select 1 from guide.user_profiles where user_id <> 'a0000000-0000-4000-8000-000000000002') then raise exception 'LEAK user: lee perfiles ajenos'; end if;
  begin perform user_id from guide.user_reviews; raise exception 'LEAK user: lee user_reviews.user_id'; exception when insufficient_privilege then null; end;

  -- Escritura editorial
  update guide.articles set title_es = 'hack' where slug_es = 'rls-publicado';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: edita artículos'; end if;
  begin insert into guide.articles (category_id, title_es, slug_es) values ('c0000000-0000-4000-8000-000000000001', 'x', 'rls-x');
    raise exception 'LEAK user: inserta artículos'; exception when insufficient_privilege then null; end;
  begin insert into guide.subscribers (email, consent_source, consent_version) values ('x@y.zz', 'footer', 1);
    raise exception 'LEAK user: inserta subscribers'; exception when insufficient_privilege then null; end;

  -- Opinión propia vía RPC (D17: nota global obligatoria, criterios opcionales)
  v_id := guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4,
    '{"10000000-0000-4000-8000-000000000001": 4, "10000000-0000-4000-8000-000000000002": 5}'::jsonb, 'Muy bien', 'es');
  v_id2 := guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 3,
    '{"10000000-0000-4000-8000-000000000001": 3}'::jsonb, 'Editada', 'es');
  if v_id <> v_id2 then raise exception 'FAIL user: la segunda opinión no editó la primera'; end if;
  if (select count(*) from guide.get_my_review('f0000000-0000-4000-8000-000000000001')) <> 1 then
    raise exception 'FAIL user: get_my_review no devuelve su opinión';
  end if;
  if (select overall_score from guide.get_my_review('f0000000-0000-4000-8000-000000000001')) <> 3 then
    raise exception 'FAIL user: overall_score no actualizado';
  end if;
  if (select count(*) from guide.user_review_scores where review_id = v_id) <> 1 then
    raise exception 'FAIL user: criterios parciales no reemplazados';
  end if;
  if (select status from guide.user_reviews where id = v_id) <> 'visible' then raise exception 'FAIL user: post-moderación no deja visible'; end if;
  if (select author_name from guide.user_reviews where id = v_id) <> 'User U.' then raise exception 'FAIL user (D17): author_name no es nombre + inicial'; end if;

  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', null);
    raise exception 'FAIL user: sin nota global'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 0);
    raise exception 'FAIL user: nota global 0'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 6);
    raise exception 'FAIL user: nota global 6'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4, '[4]'::jsonb);
    raise exception 'FAIL user: notas no objeto'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4,
      '{"10000000-0000-4000-8000-000000000001": 9}'::jsonb);
    raise exception 'FAIL user: nota fuera de rango'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4,
      '{"10000000-0000-4000-8000-000000000001": "4"}'::jsonb);
    raise exception 'FAIL user: nota no numérica'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4,
      '{"10000000-0000-4000-8000-000000000001": 4, "10000000-0000-4000-8000-000000000003": 4}'::jsonb);
    raise exception 'FAIL user: criterio de otra categoría'; exception when invalid_parameter_value then null; end;
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000002', 4);
    raise exception 'FAIL user: opinión en ítem no publicado'; exception when invalid_parameter_value then null; end;

  -- D17: pies de gato admiten opiniones (solo nota global y con criterio de shoe)
  v_id2 := guide.submit_user_review('f0000000-0000-4000-8000-000000000003', 5);
  if (select count(*) from guide.user_review_scores where review_id = v_id2) <> 0 then
    raise exception 'FAIL user: opinión sin criterios guardó notas';
  end if;
  perform guide.submit_user_review('f0000000-0000-4000-8000-000000000003', 4, '{"10000000-0000-4000-8000-000000000003": 4}'::jsonb);
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000003', 4, '{"10000000-0000-4000-8000-000000000001": 4}'::jsonb);
    raise exception 'FAIL user: criterio de gym en pie de gato'; exception when invalid_parameter_value then null; end;

  -- Sin escritura directa en opiniones ni en su estado
  begin insert into guide.user_reviews (item_id, category, user_id, status)
      values ('f0000000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000002', 'visible');
    raise exception 'LEAK user: inserta user_reviews directo'; exception when insufficient_privilege then null; end;
  update guide.user_reviews set status = 'visible' where id = '20000000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: cambia estado de opinión ajena'; end if;
  -- I3: ya sin grant de UPDATE sobre body/overall_score/user_id (antes: 0 filas por RLS)
  begin update guide.user_reviews set body = 'hack' where id = v_id;
    raise exception 'LEAK user: edita su opinión sin RPC'; exception when insufficient_privilege then null; end;
  begin update guide.user_reviews set overall_score = 5 where id = v_id;
    raise exception 'LEAK user (I3): UPDATE de overall_score'; exception when insufficient_privilege then null; end;
  delete from guide.user_reviews where id = '20000000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: borra opinión ajena'; end if;
  begin insert into guide.user_review_scores (review_id, criterion_id, category, score)
      values (v_id, '10000000-0000-4000-8000-000000000001', 'gym', 5);
    raise exception 'LEAK user: inserta notas directo'; exception when insufficient_privilege then null; end;

  -- Borrar la propia opinión visible sí se puede (y volver a opinar)
  delete from guide.user_reviews where id = v_id;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL user: no puede borrar su opinión visible'; end if;

  -- Perfil
  begin update guide.user_profiles set user_id = 'a0000000-0000-4000-8000-000000000003';
    raise exception 'LEAK user: cambia user_id del perfil'; exception when insufficient_privilege then null; end;
  update guide.user_profiles set display_name = 'Hack' where user_id = 'a0000000-0000-4000-8000-000000000003';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: edita perfil ajeno'; end if;
  begin update guide.user_profiles set display_name = '<b>x</b>' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'FAIL user (H4): display_name con etiquetas aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = E'Ab\u202Egnp.exe' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'FAIL user (N1): display_name con bidi aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = E'Ab\u200Bc' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'FAIL user (N1): display_name con ancho cero aceptado'; exception when check_violation then null; end;
  -- N2 + D17: el trigger normaliza (sin espacios extremos, nombre + inicial) en vez de rechazar
  update guide.user_profiles set display_name = 'ab' || repeat(' ', 45) where user_id = 'a0000000-0000-4000-8000-000000000002';
  if (select display_name from guide.user_profiles where user_id = 'a0000000-0000-4000-8000-000000000002') <> 'Ab' then
    raise exception 'FAIL user (N2): display_name con espacios finales no normalizado';
  end if;
  update guide.user_profiles set display_name = 'Marta García López' where user_id = 'a0000000-0000-4000-8000-000000000002';
  if (select display_name from guide.user_profiles where user_id = 'a0000000-0000-4000-8000-000000000002') <> 'Marta G.' then
    raise exception 'FAIL user (D17): el perfil admite el nombre completo';
  end if;
  -- B1: '@' (o ＠/﹫) se rechaza; antes saltaba D17 y permitía publicar un email como author_name
  begin update guide.user_profiles set display_name = 'Marta García López@' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1): display_name con @ salta D17'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = 'rls-user2@chalkguide.test' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1): display_name con email ajeno aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = 'marta＠gmail.com' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1): display_name con arroba de ancho completo aceptado'; exception when check_violation then null; end;
  -- B1-bis: si no se puede derivar "Nombre I." se rechaza (antes se guardaba el texto tal cual)
  begin update guide.user_profiles set display_name = 'M 612345678' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1-bis): display_name con teléfono aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = 'pepe(at)gmail.com' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1-bis): display_name con (at) aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = 'pepe.garcia.gmail.com' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1-bis): display_name con dominio aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = 'pepe﹫gmail.com' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1-bis): display_name con arroba pequeña aceptado'; exception when check_violation then null; end;
  begin update guide.user_profiles set display_name = '612345678' where user_id = 'a0000000-0000-4000-8000-000000000002';
    raise exception 'LEAK user (B1-bis): display_name solo dígitos aceptado'; exception when check_violation then null; end;
  if (select display_name from guide.user_profiles where user_id = 'a0000000-0000-4000-8000-000000000002') <> 'Marta G.' then
    raise exception 'FAIL user (B1): el rechazo alteró el nombre';
  end if;
  -- Nombres reales con apóstrofo, guion y punto volado siguen pasando
  update guide.user_profiles set display_name = 'Marcel·lí Puig' where user_id = 'a0000000-0000-4000-8000-000000000002';
  if (select display_name from guide.user_profiles where user_id = 'a0000000-0000-4000-8000-000000000002') <> 'Marcel·lí P.' then
    raise exception 'FAIL user (B1-bis): nombre catalán rechazado o mal derivado';
  end if;
  update guide.user_profiles set display_name = 'Marta García López' where user_id = 'a0000000-0000-4000-8000-000000000002';

  -- Lista de espera
  begin insert into guide.gym_waitlist (item_id, user_id) values ('f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003');
    raise exception 'LEAK user: apunta a otro usuario'; exception when insufficient_privilege then null; end;
  insert into guide.gym_waitlist (item_id) values ('f0000000-0000-4000-8000-000000000001');
  begin insert into guide.gym_waitlist (item_id) values ('f0000000-0000-4000-8000-000000000002');
    raise exception 'LEAK user: lista de espera en gym oculto'; exception when insufficient_privilege then null; end;

  -- H3: vincular user_id solo con su propio email
  perform guide.subscribe_newsletter('rls-victima@chalkguide.test', 'es', 'footer', true);
  perform guide.subscribe_newsletter('rls-user1@chalkguide.test', 'es', 'footer', true);

  -- RPC de panel
  begin perform guide.admin_dashboard_stats(); raise exception 'LEAK user: dashboard'; exception when insufficient_privilege then null; end;
  begin perform guide.moderate_user_review('20000000-0000-4000-8000-000000000001', 'visible'); raise exception 'LEAK user: modera'; exception when insufficient_privilege then null; end;
  begin perform guide.approve_event('30000000-0000-4000-8000-000000000001'); raise exception 'LEAK user: aprueba evento'; exception when insufficient_privilege then null; end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002');
    raise exception 'LEAK user: borra categoría'; exception when insufficient_privilege then null; end;
  begin perform guide.publish_due_articles(); raise exception 'LEAK user: publish_due_articles'; exception when insufficient_privilege then null; end;

  -- Storage
  if exists (select 1 from storage.objects where bucket_id = 'media') then raise exception 'LEAK user: lista el bucket media'; end if;
  update storage.objects set name = 'hack.jpg' where bucket_id = 'media';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: modifica objetos de media'; end if;
  begin insert into storage.objects (bucket_id, name) values ('media', 'rls-user.jpg');
    raise exception 'LEAK user: sube a media'; exception when insufficient_privilege then null; end;

  -- D22: las columnas nuevas solo las escribe admin
  update guide.media set dominant_color = '#000000' where id = 'b0000000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: cambia media.dominant_color'; end if;
  update guide.gyms set setting_dynamism = 3 where item_id = 'f0000000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: cambia gyms.setting_dynamism'; end if;
  update guide.shoes set author_size_note_es = 'hack' where item_id = 'f0000000-0000-4000-8000-000000000003';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user: cambia shoes.author_size_note_es'; end if;
end $$;

reset role;

-- ═════════════ H1: user2, autor de la opinión oculta ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);

do $$
declare
  v_n  integer;
  v_id uuid;
begin
  delete from guide.user_reviews where id = '20000000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK H1: el autor borra su opinión oculta'; end if;
  v_id := guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 5,
    '{"10000000-0000-4000-8000-000000000001": 5, "10000000-0000-4000-8000-000000000002": 5}'::jsonb, 'reabierta?', 'es');
  if v_id <> '20000000-0000-4000-8000-000000000001' then raise exception 'LEAK H1: creó una opinión nueva'; end if;
  if (select status from guide.get_my_review('f0000000-0000-4000-8000-000000000001')) <> 'hidden' then
    raise exception 'LEAK H1: la edición reabrió la opinión oculta';
  end if;
end $$;

reset role;

-- ═════════════ H4: nombre de Google malicioso ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000004","role":"authenticated"}', true);

do $$
declare
  v_id   uuid;
  v_name text;
begin
  v_id := guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 2,
    '{"10000000-0000-4000-8000-000000000001": 2, "10000000-0000-4000-8000-000000000002": 2}'::jsonb, null, 'es');
  select author_name into v_name from guide.user_reviews where id = v_id;
  if v_name ~ '[[:cntrl:]<>"`\\\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]' or char_length(v_name) > 40 then
    raise exception 'FAIL H4: author_name sin sanear: %', v_name;
  end if;
end $$;

reset role;

-- ═════════════ D17: límite de 5 opiniones nuevas / 24 h y nombre derivado ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000005","role":"authenticated"}', true);

do $$
declare
  v_id uuid;
begin
  v_id := guide.submit_user_review('f0000000-0000-4000-8000-000000000004', 4);
  if (select author_name from guide.user_reviews where id = v_id) <> 'Álvaro P.' then
    raise exception 'FAIL D17: nombre derivado = %', (select author_name from guide.user_reviews where id = v_id);
  end if;
  perform guide.submit_user_review('f0000000-0000-4000-8000-000000000005', 4);
  perform guide.submit_user_review('f0000000-0000-4000-8000-000000000006', 4);
  perform guide.submit_user_review('f0000000-0000-4000-8000-000000000007', 4);
  perform guide.submit_user_review('f0000000-0000-4000-8000-000000000008', 4);
  begin perform guide.submit_user_review('f0000000-0000-4000-8000-000000000001', 4);
    raise exception 'FAIL D17: sexta opinión nueva en 24 h aceptada';
  exception when sqlstate 'PT429' then
    if sqlerrm <> 'rate_limited' then raise exception 'FAIL D17: mensaje de límite = %', sqlerrm; end if;
  end;
  -- Editar una propia no cuenta para el límite
  if guide.submit_user_review('f0000000-0000-4000-8000-000000000004', 2, '{}'::jsonb, 'editada') <> v_id then
    raise exception 'FAIL D17: la edición no reutilizó la opinión';
  end if;
end $$;

reset role;

-- ═════════════ B1-bis: nombre de Google que no es un nombre → "Escalador/a" (la RPC no falla) ═════════════
do $$
declare
  v_uid  uuid;
  v_id   uuid;
begin
  foreach v_uid in array array['a0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000007',
                               'a0000000-0000-4000-8000-000000000008']::uuid[] loop
    perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
    v_id := guide.submit_user_review('f0000000-0000-4000-8000-000000000004', 3);
    reset role;
    if (select author_name from guide.user_reviews where id = v_id) <> 'Escalador/a' then
      raise exception 'FAIL B1-bis: author_name = % (esperado Escalador/a)', (select author_name from guide.user_reviews where id = v_id);
    end if;
  end loop;
end $$;

-- ═════════════ JWT forjado (rol de BD authenticated con claims de admin/service) ═════════════
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000002","role":"service_role","app_metadata":{"role":"admin"},"user_metadata":{"is_admin":true}}', true);

do $$
declare
  v_n integer;
begin
  if guide.is_admin() then raise exception 'LEAK jwt: is_admin() con claims forjados'; end if;
  if exists (select 1 from guide.subscribers) then raise exception 'LEAK jwt: lee subscribers'; end if;
  if exists (select 1 from guide.articles where status = 'draft') then raise exception 'LEAK jwt: ve borradores'; end if;
  update guide.site_settings set site_name = 'hack';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK jwt: edita ajustes'; end if;
  begin insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000002', 'x@y.zz');
    raise exception 'LEAK jwt: se da de alta como admin'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_dashboard_stats(); raise exception 'LEAK jwt: dashboard'; exception when insufficient_privilege then null; end;
  begin perform guide.publish_due_articles(); raise exception 'LEAK jwt: publish_due_articles'; exception when insufficient_privilege then null; end;
end $$;

reset role;

-- ═════════════ admin ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

do $$
declare
  v_stats jsonb;
begin
  if not guide.is_admin() then raise exception 'FAIL admin: is_admin() = false'; end if;
  if (select count(*) from guide.articles where slug_es like 'rls-%') <> 3 then raise exception 'FAIL admin: no ve todos los artículos'; end if;
  if not exists (select 1 from guide.user_reviews where status = 'hidden') then raise exception 'FAIL admin: no ve ocultas'; end if;

  -- Newsletter: normalización y anti-reenvío (< 24 h)
  if not exists (select 1 from guide.subscribers where email = 'rls-nuevo@chalkguide.test' and status = 'pending' and locale = 'en') then
    raise exception 'FAIL admin: alta no quedó pending/normalizada (o el repetido la sobrescribió)';
  end if;
  if (select count(*) from guide.subscriber_consent_events e join guide.subscribers s on s.id = e.subscriber_id
      where s.email = 'rls-nuevo@chalkguide.test' and e.event = 'subscribe') <> 1 then
    raise exception 'FAIL admin: el alta repetida < 24 h generó otro consentimiento';
  end if;

  -- D22: orígenes article_mid/article_end guardados; el CHECK rechaza uno fuera de lista
  if (select count(*) from guide.subscribers where (email, consent_source) in
      (('rls-mid@chalkguide.test', 'article_mid'), ('rls-end@chalkguide.test', 'article_end'), ('rls-art@chalkguide.test', 'article'))) <> 3 then
    raise exception 'FAIL admin (D22): orígenes de artículo no guardados';
  end if;
  if (select count(*) from guide.subscribers where email = 'rls-news@chalkguide.test' and consent_source = 'newsletter_page') <> 1 then
    raise exception 'FAIL admin (D44): origen newsletter_page no guardado';
  end if;
  -- F6.14: ni el admin escribe subscribers en directo (todo por RPC); el CHECK de origen se prueba como postgres en F6.14.
  begin update guide.subscribers set consent_source = 'article_top' where email = 'rls-mid@chalkguide.test';
    raise exception 'LEAK admin F6.14: UPDATE directo de subscribers'; exception when insufficient_privilege then null; end;

  -- H2 + F6.14: la re-suscripción limpia la baja y la confirmación de la fila (vuelve a Sin confirmar con doble opt-in);
  -- la baja previa queda en el historial append-only
  if not exists (select 1 from guide.subscribers where id = '50000000-0000-4000-8000-000000000001'
                 and status = 'pending' and unsubscribed_at is null and unsubscribe_source is null and confirmed_at is null) then
    raise exception 'FAIL H2/F6.14: la re-suscripción no limpió confirmed_at/unsubscribed_at/unsubscribe_source';
  end if;
  if (select array_agg(event order by id) from guide.subscriber_consent_events
      where subscriber_id = '50000000-0000-4000-8000-000000000001') <> array['subscribe', 'confirm', 'unsubscribe', 'subscribe'] then
    raise exception 'FAIL H2: historial de consentimiento incompleto';
  end if;
  begin update guide.subscriber_consent_events set source = 'hack';
    raise exception 'LEAK H2: el admin modifica el historial'; exception when insufficient_privilege then null; end;
  begin delete from guide.subscriber_consent_events;
    raise exception 'LEAK H2: el admin borra el historial'; exception when insufficient_privilege then null; end;

  -- H3
  -- F6.14: el admin ya no lee user_id (grant por columnas); se comprueba con has_account de la ficha
  if (guide.admin_get_subscriber((select id from guide.subscribers where email = 'rls-victima@chalkguide.test'))
        #>> '{subscriber,has_account}')::boolean then
    raise exception 'LEAK H3: user_id vinculado a un email ajeno';
  end if;
  if not (guide.admin_get_subscriber((select id from guide.subscribers where email = 'rls-user1@chalkguide.test'))
            #>> '{subscriber,has_account}')::boolean then
    raise exception 'FAIL H3: no vincula el email propio';
  end if;
  begin perform user_id from guide.subscribers limit 1;
    raise exception 'LEAK admin F6.14: lee user_id de subscribers'; exception when insufficient_privilege then null; end;

  v_stats := guide.admin_dashboard_stats();
  if v_stats ->> 'subscribers_total' is null then raise exception 'FAIL admin: dashboard vacío'; end if;
  perform * from guide.admin_timeseries('subscribers_new', current_date - 30, current_date, 'week');
  perform guide.admin_export_count('user_reviews', '{}');   -- F6.15 O2: sin lectura directa de export_*
  perform * from guide.media_library;

  -- Medio en uso
  if not exists (select 1 from guide.media_usage where media_id = 'b0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL admin: media_usage no detecta la portada';
  end if;
  begin delete from guide.media where id = 'b0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL admin: borró un medio en uso'; exception when foreign_key_violation then null; end;
  if not exists (select 1 from storage.objects where bucket_id = 'media') then raise exception 'FAIL admin: no lista media'; end if;

  -- D22: el admin sí escribe las columnas nuevas (panel)
  update guide.media set dominant_color = '#112233' where id = 'b0000000-0000-4000-8000-000000000001';
  -- F6.7: fichas publicadas → solo por publish_draft (el GUC que fija para cada ficha)
  begin update guide.gyms set setting_dynamism = 3 where item_id = 'f0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL F6.7: detalle de ficha publicada en directo'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'apply:f0000000-0000-4000-8000-000000000001', true);
  update guide.gyms set setting_dynamism = 3 where item_id = 'f0000000-0000-4000-8000-000000000001';
  perform set_config('guide.draft_op', 'apply:f0000000-0000-4000-8000-000000000003', true);
  update guide.shoes set author_size_note_es = 'Nota admin', author_size_note_en = null where item_id = 'f0000000-0000-4000-8000-000000000003';
  perform set_config('guide.draft_op', '', true);
  if not exists (select 1 from guide.media m join guide.gyms g on g.item_id = 'f0000000-0000-4000-8000-000000000001'
                 join guide.shoes s on s.item_id = 'f0000000-0000-4000-8000-000000000003'
                 where m.id = 'b0000000-0000-4000-8000-000000000001' and m.dominant_color = '#112233'
                   and g.setting_dynamism = 3 and s.author_size_note_es = 'Nota admin') then
    raise exception 'FAIL admin (D22): no escribe dominant_color/setting_dynamism/author_size_note_es';
  end if;

  begin insert into guide.articles (category_id, status, published_at, title_es, slug_es)
      values ('c0000000-0000-4000-8000-000000000001', 'scheduled', now() - interval '1 hour', 'x', 'rls-pasado');
    raise exception 'FAIL admin: programó en el pasado'; exception when check_violation then null; end;

  perform guide.delete_article_category('c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002');
  if exists (select 1 from guide.article_categories where id = 'c0000000-0000-4000-8000-000000000001') then raise exception 'FAIL admin: categoría no borrada'; end if;
  if (select count(*) from guide.articles where category_id = 'c0000000-0000-4000-8000-000000000002') <> 3 then raise exception 'FAIL admin: artículos no reasignados'; end if;

  perform guide.moderate_user_review('20000000-0000-4000-8000-000000000001', 'visible');
  if not exists (select 1 from guide.activity_log where entity_table = 'user_reviews') then raise exception 'FAIL admin: moderación sin activity_log'; end if;
  if not exists (select 1 from guide.user_reviews where id = '20000000-0000-4000-8000-000000000001' and status = 'visible' and moderated_at is not null) then
    raise exception 'FAIL admin (I3): la moderación no fijó status/moderated_at';
  end if;
  -- I3: UPDATE solo de (status, moderated_at); ni el admin cambia la opinión ajena por PostgREST
  begin update guide.user_reviews set overall_score = 5 where id = '20000000-0000-4000-8000-000000000001';
    raise exception 'LEAK admin (I3): UPDATE de overall_score'; exception when insufficient_privilege then null; end;
  begin update guide.user_reviews set author_name = 'Hack' where id = '20000000-0000-4000-8000-000000000001';
    raise exception 'LEAK admin (I3): UPDATE de author_name'; exception when insufficient_privilege then null; end;

  -- F6.14: el admin no borra suscriptores en directo (la supresión RGPD es admin_erase_subscriber, bloque F6.14)
  begin delete from guide.subscribers where id = '50000000-0000-4000-8000-000000000001';
    raise exception 'LEAK admin F6.14: DELETE directo de subscribers'; exception when insufficient_privilege then null; end;

  -- D21: el admin ve borradores por RLS, pero el buscador público solo devuelve vivos
  if (select count(*) from guide.articles where slug_es like 'fts-%') <> 4 then raise exception 'FAIL admin: no ve los fts-*'; end if;
  if exists (select 1 from guide.search_articles('rlszorro', 'es') where id in ('d0000000-0000-4000-8000-000000000006', 'd0000000-0000-4000-8000-000000000007'))
     or exists (select 1 from guide.search_articles('rlszorro', 'en') where id <> 'd0000000-0000-4000-8000-000000000004') then
    raise exception 'LEAK admin search: borrador/programado/sin has_en';
  end if;
  -- Revisión D21 (hallazgo 2): activity_log no guarda search_es/search_en (ni en cambios ni en el snapshot)
  update guide.articles set title_es = title_es || ' bis' where id = 'd0000000-0000-4000-8000-000000000006';
  if (select changed_columns from guide.activity_log where entity_table = 'articles' and entity_id = 'd0000000-0000-4000-8000-000000000006'
      and action = 'update' order by id desc limit 1) is distinct from array['title_es'] then
    raise exception 'FAIL admin: activity_log registra columnas generadas en el UPDATE';
  end if;
  delete from guide.articles where id = 'd0000000-0000-4000-8000-000000000006';
  if not exists (select 1 from guide.activity_log where entity_table = 'articles' and entity_id = 'd0000000-0000-4000-8000-000000000006'
                 and action = 'delete' and old_row ? 'title_es' and not (old_row ?| array['search_es', 'search_en'])) then
    raise exception 'FAIL admin: snapshot de DELETE con search_es/search_en';
  end if;
end $$;

reset role;

-- ═════════════ D23: borradores de cambios y registro de exportaciones ═════════════
-- Fixtures (como postgres): medio usado solo por un borrador y borrador "viejo" sobre el artículo
-- publicado d…001 (base anterior a su updated_at → conflicto al publicar).
insert into storage.objects (bucket_id, name, metadata) values ('media', 'b0000000-0000-4000-8000-000000000002/1-draft.jpg',
  '{"mimetype":"image/jpeg","size":1000}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, alt_es)
values ('b0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002/1-draft.jpg', 'draft.jpg', 'image/jpeg', 1000,
        'Borrador de prueba');
insert into guide.content_drafts (entity, article_id, payload, base_updated_at)
select 'article', a.id,
       '{"article":{"title_es":"Cambio pendiente","og_media_id":"b0000000-0000-4000-8000-000000000002"}}',
       a.updated_at - interval '1 minute'
from guide.articles a where a.id = 'd0000000-0000-4000-8000-000000000001';

-- O3: padres publicados con updated_at antiguo (set_updated_at solo actúa en UPDATE), sin hijos,
-- para que un cambio solo en notas/galería/relacionados se vea como versión nueva en esta transacción.
-- f…09: notas (reseña 40…02 sin notas); f…0a: galería; d…08: relacionados.
-- f…0b + reseña 40…03 + d…09: con hijos ya creados, para UPDATE/DELETE (se comprueba el toque por ctid).
-- F6.7: hijos de fichas publicadas → mantenimiento explícito.
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.items (id, category, name, slug, published, updated_at) values
  ('f0000000-0000-4000-8000-000000000009', 'gym', 'Gym O3 notas', 'rls-o3-notas', true, now() - interval '1 hour'),
  ('f0000000-0000-4000-8000-00000000000a', 'gym', 'Gym O3 galeria', 'rls-o3-galeria', true, now() - interval '1 hour'),
  ('f0000000-0000-4000-8000-00000000000b', 'gym', 'Gym O3 hijos', 'rls-o3-hijos', true, now() - interval '1 hour');
insert into guide.author_reviews (id, item_id, category, body_html_es, updated_at) values
  ('40000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000009', 'gym', '<p>o3</p>', now() - interval '1 hour'),
  ('40000000-0000-4000-8000-000000000003', 'f0000000-0000-4000-8000-00000000000b', 'gym', '<p>o3</p>', now() - interval '1 hour');
insert into guide.author_review_scores (review_id, criterion_id, category, score) values
  ('40000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'gym', 3);
insert into guide.item_media (item_id, media_id, sort_order) values
  ('f0000000-0000-4000-8000-00000000000b', 'b0000000-0000-4000-8000-000000000001', 1);
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, updated_at) values
  ('d0000000-0000-4000-8000-000000000008', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '1 day', 'O3 rel', 'rls-o3-rel', now() - interval '1 hour'),
  ('d0000000-0000-4000-8000-000000000009', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '1 day', 'O3 hijos', 'rls-o3-hijos', now() - interval '1 hour');
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_items (article_id, item_id, sort_order) values
  ('d0000000-0000-4000-8000-000000000009', 'f0000000-0000-4000-8000-00000000000b', 1);
select set_config('guide.draft_op', '', true);

-- La lista blanca coincide con el catálogo y nunca incluye claves, estado ni columnas internas.
do $$
declare
  t text;
  c text;
begin
  foreach t in array array['articles', 'pages', 'items', 'gyms', 'resolers', 'shoes', 'author_reviews'] loop
    foreach c in array guide.draft_allowed_columns(t) loop
      if not exists (select 1 from pg_attribute a where a.attrelid = ('guide.' || t)::regclass and a.attname = c
                     and a.attnum > 0 and not a.attisdropped and a.attgenerated = '') then
        raise exception 'FAIL D23: columna de la lista blanca inexistente o generada: %.%', t, c;
      end if;
      if c in ('id', 'item_id', 'category', 'status', 'published', 'published_at', 'sort_order', 'key',
               'created_at', 'updated_at', 'updated_by', 'has_en', 'is_affiliate') then
        raise exception 'LEAK D23: columna protegida en la lista blanca: %.%', t, c;
      end if;
    end loop;
  end loop;
end $$;

-- anon: ni lee ni escribe borradores, ni llama a las RPC
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform 1 from guide.content_drafts; raise exception 'LEAK anon D23: lee content_drafts'; exception when insufficient_privilege then null; end;
  begin insert into guide.content_drafts (entity, article_id, payload, base_updated_at)
      values ('article', 'd0000000-0000-4000-8000-000000000004', '{"article":{"title_es":"x"}}', now());
    raise exception 'LEAK anon D23: inserta borrador'; exception when insufficient_privilege then null; end;
  begin perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000001', '{"article":{"title_es":"x"}}', now());
    raise exception 'LEAK anon D23: save_draft'; exception when insufficient_privilege then null; end;
  begin perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000001', true);
    raise exception 'LEAK anon D23: publish_draft'; exception when insufficient_privilege then null; end;
  begin perform guide.discard_draft('article', 'd0000000-0000-4000-8000-000000000001');
    raise exception 'LEAK anon D23: discard_draft'; exception when insufficient_privilege then null; end;
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000001');
    raise exception 'LEAK anon F6.4: unpublish_article'; exception when insufficient_privilege then null; end;
  begin perform guide.log_export('export_subscribers', 'csv', '{}', 1);
    raise exception 'LEAK anon D23: log_export'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.articles where title_es = 'Cambio pendiente') then raise exception 'LEAK anon D23: el borrador se ve publicado'; end if;
end $$;
reset role;

-- authenticated no admin (user1) y JWT forjado: mismas garantías
do $$
declare
  v_claims text;
  v_n      integer;
begin
  foreach v_claims in array array[
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}',
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"service_role","app_metadata":{"role":"admin"},"user_metadata":{"is_admin":true}}'] loop
    perform set_config('request.jwt.claims', v_claims, true);
    set local role authenticated;

    if exists (select 1 from guide.content_drafts) then raise exception 'LEAK user D23 (%): lee content_drafts', v_claims; end if;
    if exists (select 1 from guide.media_usage) then raise exception 'LEAK user D23: lee media_usage'; end if;
    begin insert into guide.content_drafts (entity, article_id, payload, base_updated_at)
        values ('article', 'd0000000-0000-4000-8000-000000000004', '{"article":{"title_es":"x"}}', now());
      raise exception 'LEAK user D23: inserta borrador'; exception when insufficient_privilege then null; end;
    -- O1: el trigger rechaza al no admin antes de validar el payload (42501, no 22023/P0002)
    begin insert into guide.content_drafts (entity, item_id, payload, base_updated_at)
        values ('item', 'f0000000-0000-4000-8000-0000000000ff', '{"hack":{"x":1}}', now());
      raise exception 'LEAK user D23: inserta borrador inválido'; exception when insufficient_privilege then null; end;
    update guide.content_drafts set payload = '{"article":{"title_es":"hack"}}';
    get diagnostics v_n = row_count;
    if v_n <> 0 then raise exception 'LEAK user D23: edita borrador'; end if;
    delete from guide.content_drafts;
    get diagnostics v_n = row_count;
    if v_n <> 0 then raise exception 'LEAK user D23: borra borrador'; end if;
    begin perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000001', '{"article":{"title_es":"x"}}', now());
      raise exception 'LEAK user D23: save_draft'; exception when insufficient_privilege then null; end;
    begin perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000001', true);
      raise exception 'LEAK user D23: publish_draft'; exception when insufficient_privilege then null; end;
    begin perform guide.discard_draft('article', 'd0000000-0000-4000-8000-000000000001');
      raise exception 'LEAK user D23: discard_draft'; exception when insufficient_privilege then null; end;
    begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000001');
      raise exception 'LEAK user F6.4: unpublish_article'; exception when insufficient_privilege then null; end;
    begin perform guide.log_export('export_subscribers', 'csv', '{}', 1);
      raise exception 'LEAK user D23: log_export'; exception when insufficient_privilege then null; end;
    begin insert into guide.activity_log (action, entity_table, entity_id) values ('export', 'export_subscribers', '*');
      raise exception 'LEAK user D23: escribe activity_log'; exception when insufficient_privilege then null; end;

    reset role;
  end loop;
end $$;

-- Nada de lo anterior tocó el borrador ni lo publicado
do $$
begin
  if not exists (select 1 from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000001'
                 and payload -> 'article' ->> 'title_es' = 'Cambio pendiente') then
    raise exception 'LEAK D23: un no admin alteró o borró el borrador';
  end if;
  if exists (select 1 from guide.articles where title_es in ('Cambio pendiente', 'x', 'hack')) then
    raise exception 'LEAK D23: un no admin publicó cambios';
  end if;
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000001' and status = 'published')
     or exists (select 1 from guide.activity_log where action = 'unpublish' and occurred_at = now()) then
    raise exception 'LEAK F6.4: un no admin despublicó';
  end if;
  if exists (select 1 from guide.activity_log where action in ('export', 'draft_publish', 'draft_discard') and occurred_at = now()) then
    raise exception 'LEAK D23: un no admin escribió en activity_log';
  end if;
end $$;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

do $$
declare
  v_ts     timestamptz;
  v_new    timestamptz;
  v_bad    jsonb;
  v_n      integer;
  v_detail jsonb;
begin
  -- Columnas y secciones fuera de lista blanca → 22023 (por RPC y por escritura directa)
  v_ts := guide.draft_entity_version('item', 'f0000000-0000-4000-8000-000000000001');
  foreach v_bad in array array[
    '{"item":{"published":false}}', '{"item":{"category":"shoe"}}', '{"item":{"id":"f0000000-0000-4000-8000-000000000002"}}',
    '{"item":{"published_at":"2020-01-01T00:00:00Z"}}', '{"item":{"updated_at":"2020-01-01T00:00:00Z"}}',
    '{"item":{"has_en":true}}', '{"detail":{"item_id":"f0000000-0000-4000-8000-000000000002"}}',
    '{"detail":{"brand":"x"}}', '{"article":{"title_es":"x"}}', '{"hack":{"name":"x"}}', '{"item":{}}',
    '{"scores":{"not-a-uuid":3}}', '{"scores":{"10000000-0000-4000-8000-000000000001":6}}',
    '{"gallery":["b0000000-0000-4000-8000-000000000001","b0000000-0000-4000-8000-000000000001"]}', '{}']::jsonb[] loop
    begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', v_bad, v_ts);
      raise exception 'FAIL D23: payload no permitido aceptado: %', v_bad; exception when invalid_parameter_value then null; end;
  end loop;
  foreach v_bad in array array['{"article":{"status":"draft"}}', '{"article":{"sort_order":1}}',
                               '{"article":{"search_es":"x"}}', '{"item_ids":"x"}']::jsonb[] loop
    begin update guide.content_drafts set payload = v_bad where article_id = 'd0000000-0000-4000-8000-000000000001';
      raise exception 'FAIL D23: UPDATE directo con payload no permitido: %', v_bad; exception when invalid_parameter_value then null; end;
  end loop;
  begin update guide.content_drafts set article_id = 'd0000000-0000-4000-8000-000000000004' where article_id = 'd0000000-0000-4000-8000-000000000001';
    raise exception 'FAIL D23: cambia el destino del borrador'; exception when invalid_parameter_value then null; end;

  -- O2: por escritura directa la base sale de draft_entity_version y es inmutable; solo sobre lo vivo
  insert into guide.content_drafts (entity, item_id, payload, base_updated_at)
  values ('item', 'f0000000-0000-4000-8000-000000000003', '{"item":{"summary_es":"o2"}}', '2000-01-01T00:00:00Z');
  if (select base_updated_at from guide.content_drafts where item_id = 'f0000000-0000-4000-8000-000000000003')
     is distinct from guide.draft_entity_version('item', 'f0000000-0000-4000-8000-000000000003') then
    raise exception 'FAIL D23 O2: INSERT directo fija base_updated_at';
  end if;
  delete from guide.content_drafts where item_id = 'f0000000-0000-4000-8000-000000000003';
  select base_updated_at into v_new from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000001';
  update guide.content_drafts set base_updated_at = now() + interval '1 day' where article_id = 'd0000000-0000-4000-8000-000000000001';
  if (select base_updated_at from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000001') <> v_new then
    raise exception 'FAIL D23 O2: UPDATE directo cambia base_updated_at';
  end if;
  begin insert into guide.content_drafts (entity, article_id, payload, base_updated_at)
      values ('article', 'd0000000-0000-4000-8000-000000000002', '{"article":{"title_es":"x"}}', now());
    raise exception 'FAIL D23 O2: INSERT directo sobre artículo no publicado'; exception when invalid_parameter_value then null; end;
  begin insert into guide.content_drafts (entity, item_id, payload, base_updated_at)
      values ('item', 'f0000000-0000-4000-8000-000000000002', '{"item":{"name":"x"}}', now());
    raise exception 'FAIL D23 O2: INSERT directo sobre ficha oculta'; exception when invalid_parameter_value then null; end;

  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', '{"item":{"name":null}}', v_ts);
    raise exception 'FAIL D23: NOT NULL a null aceptado'; exception when not_null_violation then null; end;
  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', '{"detail":{"routes_count":"muchas"}}', v_ts);
    raise exception 'FAIL D23: tipo erróneo aceptado'; exception when invalid_text_representation then null; end;
  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', '{"item":{"cover_media_id":"b0000000-0000-4000-8000-0000000000ff"}}', v_ts);
    raise exception 'FAIL D23: medio inexistente aceptado'; exception when foreign_key_violation then null; end;

  -- Lo nunca publicado se edita directamente
  begin perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000002', '{"article":{"title_es":"x"}}',
                                 guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000002'));
    raise exception 'FAIL D23: borrador de cambios sobre un artículo nunca publicado'; exception when invalid_parameter_value then null; end;
  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000002', '{"item":{"name":"x"}}',
                                 guide.draft_entity_version('item', 'f0000000-0000-4000-8000-000000000002'));
    raise exception 'FAIL D23: borrador de cambios sobre una ficha no publicada'; exception when invalid_parameter_value then null; end;

  -- Conflictos de base_updated_at
  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', '{"item":{"name":"x"}}', v_ts - interval '1 second');
    raise exception 'FAIL D23: borrador nuevo con base antigua'; exception when sqlstate 'PT409' then null; end;
  begin perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001', '{"item":{"name":"x"}}', null);
    raise exception 'FAIL D23: borrador nuevo sin base'; exception when sqlstate 'PT409' then null; end;
  begin perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000001', '{"article":{"title_es":"x"}}', now() - interval '1 hour');
    raise exception 'FAIL D23: guardar con base distinta de la del borrador'; exception when sqlstate 'PT409' then null; end;
  begin perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000001');
    raise exception 'FAIL D23: publica sobre una versión más nueva sin forzar'; exception when sqlstate 'PT409' then null; end;

  -- Medio en uso por un borrador: aparece en media_usage y no se puede borrar
  if not exists (select 1 from guide.media_usage where media_id = 'b0000000-0000-4000-8000-000000000002' and usage_field = 'draft'
                 and usage_table = 'articles' and usage_id = 'd0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D23: media_usage no muestra el uso en borrador';
  end if;
  begin delete from guide.media where id = 'b0000000-0000-4000-8000-000000000002';
    raise exception 'FAIL D23: borra un medio usado por un borrador'; exception when foreign_key_violation then null; end;

  -- Ficha completa: el borrador no afecta a lo publicado hasta publicar
  perform guide.save_draft('item', 'f0000000-0000-4000-8000-000000000001',
    '{"item":{"name":"Gym cambiado","summary_es":"Nuevo"},"detail":{"price_monthly_eur":55,"has_lead":true},
      "author_review":{"headline_es":"Reseña nueva","visit_type":"invited","disclosure_note_es":"Invitado"},
      "scores":{"10000000-0000-4000-8000-000000000001":4,"10000000-0000-4000-8000-000000000002":3},
      "gallery":["b0000000-0000-4000-8000-000000000002"]}', v_ts);
  if exists (select 1 from guide.items where id = 'f0000000-0000-4000-8000-000000000001' and name = 'Gym cambiado') then
    raise exception 'FAIL D23: guardar borrador cambió lo publicado';
  end if;
  v_new := guide.publish_draft('item', 'f0000000-0000-4000-8000-000000000001');
  if not exists (
    select 1 from guide.items i
    join guide.gyms g on g.item_id = i.id
    join guide.author_reviews r on r.item_id = i.id
    where i.id = 'f0000000-0000-4000-8000-000000000001' and i.name = 'Gym cambiado' and i.published
      and g.price_monthly_eur = 55 and g.has_lead and r.headline_es = 'Reseña nueva' and r.visit_type = 'invited'
      and (select count(*) from guide.author_review_scores s where s.review_id = r.id) = 2
      and exists (select 1 from guide.item_media m where m.item_id = i.id and m.media_id = 'b0000000-0000-4000-8000-000000000002')) then
    raise exception 'FAIL D23: publish_draft no aplicó la ficha completa';
  end if;
  if v_new is null or exists (select 1 from guide.content_drafts where item_id = 'f0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D23: publish_draft no borró el borrador o no devolvió versión';
  end if;
  if not exists (select 1 from guide.activity_log where action = 'draft_publish' and entity_table = 'items'
                 and entity_id = 'f0000000-0000-4000-8000-000000000001' and 'detail.price_monthly_eur' = any (changed_columns)) then
    raise exception 'FAIL D23: publicar no quedó en activity_log';
  end if;
  if not exists (select 1 from guide.activity_log where action = 'update' and entity_table = 'gyms'
                 and entity_id = 'f0000000-0000-4000-8000-000000000001' and actor_id = 'a0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D23: el UPDATE publicado no se registró con el actor admin';
  end if;

  -- Publicar forzando sobre el conflicto aplica el parche; descartar borra y registra
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000001', true);
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000001' and title_es = 'Cambio pendiente'
                 and og_media_id = 'b0000000-0000-4000-8000-000000000002' and status = 'published') then
    raise exception 'FAIL D23: publish_draft forzado no aplicó';
  end if;
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000001', '{"article":{"excerpt_es":"Descartable"}}',
                           guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000001'));
  if not guide.discard_draft('article', 'd0000000-0000-4000-8000-000000000001') then raise exception 'FAIL D23: discard_draft'; end if;
  if exists (select 1 from guide.articles where excerpt_es = 'Descartable') then raise exception 'FAIL D23: descartar publicó'; end if;
  if not exists (select 1 from guide.activity_log where action = 'draft_discard' and entity_id = 'd0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D23: descartar no quedó en activity_log';
  end if;
  begin perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000001');
    raise exception 'FAIL D23: publica sin borrador'; exception when no_data_found then null; end;

  -- F6.15 O1: log_export retirado; ni el admin escribe líneas de exportación con filas declaradas por el cliente
  begin perform guide.log_export('export_subscribers', 'csv', '{}', 3);
    raise exception 'FAIL D23/F6.15: el admin aún ejecuta log_export'; exception when insufficient_privilege then null; end;
end $$;

-- O3 (admin): editar solo notas, galería o relacionados cuenta como versión nueva → 409 al publicar
do $$
declare
  v_base timestamptz;
  v_ctid tid;
  v_case record;
begin
  for v_case in
    select * from (values
      ('item', 'f0000000-0000-4000-8000-000000000009'::uuid, '{"item":{"summary_es":"o3"}}'::jsonb, 'notas'),
      ('item', 'f0000000-0000-4000-8000-00000000000a'::uuid, '{"item":{"summary_es":"o3"}}'::jsonb, 'galería'),
      ('article', 'd0000000-0000-4000-8000-000000000008'::uuid, '{"article":{"excerpt_es":"o3"}}'::jsonb, 'relacionados')
    ) t(entity, id, payload, label)
  loop
    v_base := guide.draft_entity_version(v_case.entity, v_case.id);
    if v_base >= now() then raise exception 'FAIL D23 O3: fixture % sin versión antigua', v_case.label; end if;
    perform guide.save_draft(v_case.entity, v_case.id, v_case.payload, v_base);
    case v_case.label
      when 'notas' then
        -- F6.7: en directo es PT423; el toque se prueba con el GUC que fija publish_draft.
        begin insert into guide.author_review_scores (review_id, criterion_id, category, score)
              values ('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'gym', 4);
          raise exception 'FAIL F6.7: notas de una ficha publicada en directo'; exception when sqlstate 'PT423' then null; end;
        perform set_config('guide.draft_op', 'apply:' || v_case.id::text, true);
        insert into guide.author_review_scores (review_id, criterion_id, category, score)
        values ('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'gym', 4);
        perform set_config('guide.draft_op', '', true);
      when 'galería' then
        begin insert into guide.item_media (item_id, media_id, sort_order) values (v_case.id, 'b0000000-0000-4000-8000-000000000001', 1);
          raise exception 'FAIL F6.7: galería de una ficha publicada en directo'; exception when sqlstate 'PT423' then null; end;
        perform set_config('guide.draft_op', 'apply:' || v_case.id::text, true);
        insert into guide.item_media (item_id, media_id, sort_order) values (v_case.id, 'b0000000-0000-4000-8000-000000000001', 1);
        perform set_config('guide.draft_op', '', true);
      else
        -- F6.4: en directo es PT423; el toque se prueba con el GUC que fija publish_draft.
        begin insert into guide.article_items (article_id, item_id, sort_order) values (v_case.id, 'f0000000-0000-4000-8000-000000000001', 1);
          raise exception 'FAIL F6.4: relacionados de un artículo vivo en directo'; exception when sqlstate 'PT423' then null; end;
        perform set_config('guide.draft_op', 'apply:' || v_case.id::text, true);
        insert into guide.article_items (article_id, item_id, sort_order) values (v_case.id, 'f0000000-0000-4000-8000-000000000001', 1);
        perform set_config('guide.draft_op', '', true);
    end case;
    if guide.draft_entity_version(v_case.entity, v_case.id) is not distinct from v_base then
      raise exception 'FAIL D23 O3: cambiar solo % no cambia la versión', v_case.label;
    end if;
    begin perform guide.publish_draft(v_case.entity, v_case.id);
      raise exception 'FAIL D23 O3: publica sin 409 tras editar solo %', v_case.label; exception when sqlstate 'PT409' then null; end;
    if (select summary_es from guide.items where id = v_case.id) = 'o3'
       or (select excerpt_es from guide.articles where id = v_case.id) = 'o3' then
      raise exception 'FAIL D23 O3: el 409 dejó aplicado el borrador de %', v_case.label;
    end if;
  end loop;

  -- UPDATE y DELETE en los hijos también tocan al padre (una fila nueva del padre → ctid distinto)
  -- F6.7: en directo es PT423; el toque se prueba con el GUC que fija publish_draft.
  begin update guide.item_media set sort_order = 2 where item_id = 'f0000000-0000-4000-8000-00000000000b';
    raise exception 'FAIL F6.7: UPDATE directo de la galería de una publicada'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.author_review_scores where review_id = '40000000-0000-4000-8000-000000000003';
    raise exception 'FAIL F6.7: DELETE directo de notas de una publicada'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003';
    raise exception 'FAIL F6.7: DELETE directo de la reseña de una publicada'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'apply:f0000000-0000-4000-8000-00000000000b', true);
  select ctid into v_ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b';
  update guide.item_media set sort_order = 2 where item_id = 'f0000000-0000-4000-8000-00000000000b';
  if (select ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b') = v_ctid then
    raise exception 'FAIL D23 O3: UPDATE en item_media no toca la ficha'; end if;
  select ctid into v_ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b';
  delete from guide.item_media where item_id = 'f0000000-0000-4000-8000-00000000000b';
  if (select ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b') = v_ctid then
    raise exception 'FAIL D23 O3: DELETE en item_media no toca la ficha'; end if;

  select ctid into v_ctid from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003';
  update guide.author_review_scores set score = 5 where review_id = '40000000-0000-4000-8000-000000000003';
  if (select ctid from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003') = v_ctid then
    raise exception 'FAIL D23 O3: UPDATE en notas no toca la reseña'; end if;
  select ctid into v_ctid from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003';
  delete from guide.author_review_scores where review_id = '40000000-0000-4000-8000-000000000003';
  if (select ctid from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003') = v_ctid then
    raise exception 'FAIL D23 O3: DELETE en notas no toca la reseña'; end if;
  perform set_config('guide.draft_op', '', true);

  begin update guide.article_items set sort_order = 2 where article_id = 'd0000000-0000-4000-8000-000000000009';
    raise exception 'FAIL F6.4: UPDATE directo de relacionados de un vivo'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000009';
    raise exception 'FAIL F6.4: DELETE directo de relacionados de un vivo'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'apply:d0000000-0000-4000-8000-000000000009', true);
  select ctid into v_ctid from guide.articles where id = 'd0000000-0000-4000-8000-000000000009';
  update guide.article_items set sort_order = 2 where article_id = 'd0000000-0000-4000-8000-000000000009';
  if (select ctid from guide.articles where id = 'd0000000-0000-4000-8000-000000000009') = v_ctid then
    raise exception 'FAIL D23 O3: UPDATE en article_items no toca el artículo'; end if;
  select ctid into v_ctid from guide.articles where id = 'd0000000-0000-4000-8000-000000000009';
  delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000009';
  if (select ctid from guide.articles where id = 'd0000000-0000-4000-8000-000000000009') = v_ctid then
    raise exception 'FAIL D23 O3: DELETE en article_items no toca el artículo'; end if;
  perform set_config('guide.draft_op', '', true);

  perform set_config('guide.draft_op', 'apply:f0000000-0000-4000-8000-00000000000b', true);
  select ctid into v_ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b';
  delete from guide.author_reviews where id = '40000000-0000-4000-8000-000000000003';
  if (select ctid from guide.items where id = 'f0000000-0000-4000-8000-00000000000b') = v_ctid then
    raise exception 'FAIL D23 O3: borrar la reseña no toca la ficha'; end if;
  perform set_config('guide.draft_op', '', true);

  -- Sin ruido: los toques solo cambian updated_at y log_activity no los registra
  if exists (select 1 from guide.activity_log
             where action = 'update' and entity_table in ('items', 'articles', 'author_reviews')
               and entity_id in ('f0000000-0000-4000-8000-000000000009', 'f0000000-0000-4000-8000-00000000000a',
                                 'f0000000-0000-4000-8000-00000000000b', 'd0000000-0000-4000-8000-000000000008',
                                 'd0000000-0000-4000-8000-000000000009', '40000000-0000-4000-8000-000000000002',
                                 '40000000-0000-4000-8000-000000000003')) then
    raise exception 'FAIL D23 O3: el toque del padre genera entradas update en activity_log';
  end if;
end $$;

reset role;

-- Al borrar la entidad, su borrador cae en cascada sin dejar un "descartado" falso
do $$
begin
  insert into guide.content_drafts (entity, page_id, payload, base_updated_at)
  values ('page', 'e0000000-0000-4000-8000-000000000001', '{"page":{"title_es":"x"}}', now());
  -- F6.13: una página solo se borra en mantenimiento explícito (postgres).
  perform set_config('guide.draft_op', 'maintenance', true);
  delete from guide.pages where id = 'e0000000-0000-4000-8000-000000000001';
  perform set_config('guide.draft_op', '', true);
  if exists (select 1 from guide.content_drafts where page_id = 'e0000000-0000-4000-8000-000000000001')
     or exists (select 1 from guide.activity_log where action = 'draft_discard' and entity_id = 'e0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D23: cascada de borrador al borrar la entidad';
  end if;
  -- O3: borrar padres con galería, reseña+notas o relacionados (cascadas que disparan el toque
  -- sobre una fila ya borrada) no falla.
  -- F6.7: una ficha publicada no se borra (tampoco como postgres sin mantenimiento); se oculta antes.
  begin delete from guide.items where id = 'f0000000-0000-4000-8000-000000000009';
    raise exception 'FAIL F6.7: borra una ficha publicada'; exception when sqlstate 'PT423' then null; end;
  -- F6.8: f…09/f…0a y d…08 conservan su borrador (el 409 de O3): despublicar en directo con borrador → PT423;
  -- aquí se despublica con mantenimiento explícito (el panel usa unpublish_item / unpublish_article).
  begin update guide.items set published = false where id = 'f0000000-0000-4000-8000-000000000009';
    raise exception 'FAIL F6.8: oculta en directo con borrador pendiente'; exception when sqlstate 'PT423' then null; end;
  begin update guide.articles set status = 'draft' where id = 'd0000000-0000-4000-8000-000000000008';
    raise exception 'FAIL F6.8: despublica en directo con borrador pendiente'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'maintenance', true);
  update guide.items set published = false where id in ('f0000000-0000-4000-8000-000000000009', 'f0000000-0000-4000-8000-00000000000a');
  perform set_config('guide.draft_op', '', true);
  delete from guide.items where id in ('f0000000-0000-4000-8000-000000000009', 'f0000000-0000-4000-8000-00000000000a');
  -- F6.4: un artículo vivo no se borra (tampoco como postgres sin mantenimiento); se despublica antes.
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-000000000008';
    raise exception 'FAIL F6.4: borra un artículo vivo'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'maintenance', true);
  update guide.articles set status = 'draft' where id = 'd0000000-0000-4000-8000-000000000008';
  perform set_config('guide.draft_op', '', true);
  delete from guide.articles where id = 'd0000000-0000-4000-8000-000000000008';
  if exists (select 1 from guide.item_media where item_id = 'f0000000-0000-4000-8000-00000000000a')
     or exists (select 1 from guide.author_reviews where id = '40000000-0000-4000-8000-000000000002')
     or exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000008') then
    raise exception 'FAIL D23 O3: cascada incompleta';
  end if;
end $$;

-- Append-only incluso para el propietario
do $$
begin
  begin update guide.subscriber_consent_events set source = 'hack';
    if exists (select 1 from guide.subscriber_consent_events) then raise exception 'LEAK H2: el propietario modifica el historial'; end if;
  exception when insufficient_privilege then null; end;
end $$;

-- Storage DELETE: storage.protect_delete() impide borrar por SQL a cualquier rol (solo vía Storage API),
-- así que se verifica en catálogo que la única policy DELETE sobre media exige is_admin().
do $$
begin
  if exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd in ('DELETE', 'ALL')
      and coalesce(qual, '') like '%media%' and coalesce(qual, '') not like '%is_admin()%'
  ) then
    raise exception 'LEAK storage: policy DELETE sobre media sin is_admin()';
  end if;
end $$;

-- ═════════════ D24: última visita a Opiniones, redirecciones de slugs, fichas con opiniones, O5 ═════════════
-- Fixtures (como postgres, sin claims de usuario)
select set_config('request.jwt.claims', '{}', true);
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000009', 'authenticated', 'authenticated', 'rls-d24@chalkguide.test', '{"full_name":"D24"}', now(), now());
-- F6.15b: se publican sin mantenimiento → cumplen items_z_publish_ready (portada con alt y detalle con city). Se crean
-- ocultas con su guide.gyms (con la ficha viva, el detalle daría PT423) y luego se publican.
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f0000000-0000-4000-8000-00000000000c', 'gym', 'Gym D24 con opinión', 'rls-d24-opinion', false, 'b0000000-0000-4000-8000-000000000001'),
  ('f0000000-0000-4000-8000-00000000000d', 'gym', 'Gym D24 slug', 'rls-d24-gym', false, 'b0000000-0000-4000-8000-000000000001'),
  ('f0000000-0000-4000-8000-00000000000e', 'gym', 'Gym D24 oculto', 'rls-d24-oculto', false, null);
insert into guide.gyms (item_id, city) values
  ('f0000000-0000-4000-8000-00000000000c', 'Barcelona'), ('f0000000-0000-4000-8000-00000000000d', 'Barcelona');
update guide.items set published = true
where id in ('f0000000-0000-4000-8000-00000000000c', 'f0000000-0000-4000-8000-00000000000d');
insert into guide.user_reviews (id, item_id, category, user_id, overall_score, body, status) values
  ('20000000-0000-4000-8000-0000000000d1', 'f0000000-0000-4000-8000-00000000000c', 'gym', 'a0000000-0000-4000-8000-000000000009', 4, 'oculta d24', 'hidden');
-- d…0c: título y slug en, sin cuerpo en → has_en = false
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, title_en, slug_en, body_json_en, body_html_en) values
  ('d0000000-0000-4000-8000-00000000000a', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '1 day',
   'D24 pub', 'rls-d24-a', 'D24 pub en', 'rls-d24-a-en', '{"type":"doc","content":[]}', '<p>en</p>'),
  ('d0000000-0000-4000-8000-00000000000b', 'c0000000-0000-4000-8000-000000000002', 'draft', null, 'D24 draft', 'rls-d24-draft', null, null, null, null),
  ('d0000000-0000-4000-8000-00000000000c', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '1 day',
   'D24 solo es', 'rls-d24-soloes', 'D24 solo es en', 'rls-d24-soloes-en', null, null);
-- F6.13: clave cerrada (legal publicada → noindex obligatorio).
insert into guide.pages (id, key, title_es, slug_es, published, noindex) values
  ('e0000000-0000-4000-8000-000000000002', 'legal_notice', 'Página D24', 'rls-d24-pagina', true, true);
-- O5: borrador de a…09 (updated_by) que luego deja de validar
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
insert into guide.content_drafts (entity, page_id, payload, base_updated_at)
values ('page', 'e0000000-0000-4000-8000-000000000002', '{"page":{"title_es":"x"}}', now());
select set_config('request.jwt.claims', '{}', true);

-- anon
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v text;
begin
  begin perform 1 from guide.admins; raise exception 'LEAK D24: anon lee admins';
  exception when insufficient_privilege then null; end;
  begin perform guide.mark_reviews_seen(); raise exception 'LEAK D24: anon marca visita';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.slug_redirects; raise exception 'LEAK D24: anon lee slug_redirects';
  exception when insufficient_privilege then null; end;
  begin insert into guide.slug_redirects (kind, locale, old_slug, article_id)
        values ('article', 'es', 'rls-hack', 'd0000000-0000-4000-8000-00000000000a');
        raise exception 'LEAK D24: anon inserta redirección';
  exception when insufficient_privilege then null; end;
  begin perform guide.resolve_redirect('nope', 'es', 'x'); raise exception 'FAIL D24: kind inválido aceptado';
  exception when invalid_parameter_value then null; end;
  begin perform guide.resolve_redirect('article', 'fr', 'x'); raise exception 'FAIL D24: locale inválido aceptado';
  exception when invalid_parameter_value then null; end;
  if guide.resolve_redirect('article', 'es', 'rls-d24-a') is not null then
    raise exception 'FAIL D24: slug vivo devuelve redirección'; end if;
end $$;
reset role;

-- authenticated no admin (user1)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v integer;
begin
  select count(*) into v from guide.admins;
  if v <> 0 then raise exception 'LEAK D24: no admin ve admins'; end if;
  begin perform guide.mark_reviews_seen(); raise exception 'LEAK D24: no admin marca visita';
  exception when insufficient_privilege then null; end;
  begin update guide.admins set reviews_seen_at = now(); raise exception 'LEAK D24: UPDATE directo en admins';
  exception when insufficient_privilege then null; end;
  select count(*) into v from guide.slug_redirects;
  if v <> 0 then raise exception 'LEAK D24: no admin ve slug_redirects'; end if;
  begin delete from guide.items where id = 'f0000000-0000-4000-8000-00000000000d';
  exception when insufficient_privilege then null; end;
  if not exists (select 1 from guide.items where id = 'f0000000-0000-4000-8000-00000000000d') then
    raise exception 'LEAK D24: no admin borra una ficha'; end if;
end $$;
reset role;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_prev timestamptz;
  v      integer;
  v_s    text;
begin
  -- 1. Última visita
  v_prev := guide.mark_reviews_seen();
  if v_prev is not null then raise exception 'FAIL D24: primera visita no devuelve null'; end if;
  v_prev := guide.mark_reviews_seen();
  if v_prev is null then raise exception 'FAIL D24: segunda visita no devuelve la marca anterior'; end if;
  if (select reviews_seen_at from guide.admins where user_id = 'a0000000-0000-4000-8000-000000000001') is null then
    raise exception 'FAIL D24: el admin no lee su reviews_seen_at'; end if;
  if exists (select 1 from guide.activity_log where entity_table = 'admins' and action = 'update') then
    raise exception 'FAIL D24: marcar la visita ensucia activity_log'; end if;

  -- 2. Redirecciones · artículo publicado (es y en). F6.4: lo vivo cambia de slug vía borrador de cambios.
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000a', '{"article":{"slug_es":"rls-d24-b","slug_en":"rls-d24-b-en"}}',
                           guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000a'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000a');
  if guide.resolve_redirect('article', 'es', 'rls-d24-a') is distinct from 'rls-d24-b'
     or guide.resolve_redirect('article', 'en', 'rls-d24-a-en') is distinct from 'rls-d24-b-en' then
    raise exception 'FAIL D24: no redirige el slug antiguo del artículo'; end if;
  if guide.resolve_redirect('article', 'en', 'rls-d24-a') is not null then
    raise exception 'FAIL D24: redirección cruzada entre locales'; end if;
  -- Sin cadenas: A→B→C resuelve A y B a C
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000a', '{"article":{"slug_es":"rls-d24-c"}}',
                           guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000a'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000a');
  if guide.resolve_redirect('article', 'es', 'rls-d24-a') is distinct from 'rls-d24-c'
     or guide.resolve_redirect('article', 'es', 'rls-d24-b') is distinct from 'rls-d24-c' then
    raise exception 'FAIL D24: cadena de redirecciones'; end if;
  -- Sin bucles: vuelta a A → A deja de ser redirección, C redirige a A
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000a', '{"article":{"slug_es":"rls-d24-a"}}',
                           guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000a'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000a');
  if exists (select 1 from guide.slug_redirects where kind = 'article' and locale = 'es' and old_slug = 'rls-d24-a') then
    raise exception 'FAIL D24: el slug vivo conserva su redirección (bucle)'; end if;
  if guide.resolve_redirect('article', 'es', 'rls-d24-a') is not null
     or guide.resolve_redirect('article', 'es', 'rls-d24-c') is distinct from 'rls-d24-a' then
    raise exception 'FAIL D24: bucle A→B→A'; end if;
  -- Reutilizar un slug (aunque sea un borrador) borra la redirección; no expone el borrador
  update guide.articles set slug_es = 'rls-d24-b' where id = 'd0000000-0000-4000-8000-00000000000b';
  if exists (select 1 from guide.slug_redirects where kind = 'article' and locale = 'es' and old_slug = 'rls-d24-b')
     or guide.resolve_redirect('article', 'es', 'rls-d24-b') is not null then
    raise exception 'FAIL D24: slug reutilizado sigue redirigiendo'; end if;
  -- Borrador: cambiar su slug no crea redirección
  update guide.articles set slug_es = 'rls-d24-draft-2' where id = 'd0000000-0000-4000-8000-00000000000b';
  if exists (select 1 from guide.slug_redirects where article_id = 'd0000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL D24: un borrador genera redirección'; end if;
  -- en sin versión inglesa publicada (has_en = false): no se registra ni se resuelve
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000c', '{"article":{"slug_en":"rls-d24-soloes-en-2"}}',
                           guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000c'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000c');
  if exists (select 1 from guide.slug_redirects where article_id = 'd0000000-0000-4000-8000-00000000000c') then
    raise exception 'FAIL D24: redirección en para artículo sin inglés'; end if;
  -- Despublicar el destino: deja de resolver (no filtra el slug de algo no público)
  update guide.articles set status = 'draft' where id = 'd0000000-0000-4000-8000-00000000000a';
  if guide.resolve_redirect('article', 'es', 'rls-d24-c') is not null then
    raise exception 'LEAK D24: resuelve hacia un artículo despublicado'; end if;

  -- Ítems: por categoría, sin locale; oculto no redirige ni resuelve
  -- F6.7: el slug de una publicada cambia vía publish_draft (su GUC); en directo es PT423.
  begin update guide.items set slug = 'rls-d24-gym-2' where id = 'f0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.7: slug de una ficha publicada en directo'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'apply:f0000000-0000-4000-8000-00000000000d', true);
  update guide.items set slug = 'rls-d24-gym-2' where id = 'f0000000-0000-4000-8000-00000000000d';
  perform set_config('guide.draft_op', '', true);
  if guide.resolve_redirect('gym', 'es', 'rls-d24-gym') is distinct from 'rls-d24-gym-2'
     or guide.resolve_redirect('gym', 'en', 'rls-d24-gym') is distinct from 'rls-d24-gym-2'
     or guide.resolve_redirect('shoe', 'es', 'rls-d24-gym') is not null then
    raise exception 'FAIL D24: redirección de ítem'; end if;
  update guide.items set slug = 'rls-d24-oculto-2' where id = 'f0000000-0000-4000-8000-00000000000e';
  if exists (select 1 from guide.slug_redirects where item_id = 'f0000000-0000-4000-8000-00000000000e') then
    raise exception 'FAIL D24: ítem oculto genera redirección'; end if;
  update guide.items set published = false where id = 'f0000000-0000-4000-8000-00000000000d';
  if guide.resolve_redirect('gym', 'es', 'rls-d24-gym') is not null then
    raise exception 'LEAK D24: resuelve hacia un ítem oculto'; end if;

  -- Página publicada y categoría (siempre pública). F6.13 (D34): los slugs de páginas son fijos (rutas en código):
  -- el cambio se rechaza y no hay redirección.
  begin update guide.pages set slug_es = 'rls-d24-pagina-2' where id = 'e0000000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.13: cambia el slug de una página'; exception when sqlstate '22023' or sqlstate '42501' then null; end;
  update guide.article_categories set slug_es = 'rls-cat-b-2' where id = 'c0000000-0000-4000-8000-000000000002';
  if guide.resolve_redirect('page', 'es', 'rls-d24-pagina') is not null
     or guide.resolve_redirect('article_category', 'es', 'rls-cat-b') is distinct from 'rls-cat-b-2' then
    raise exception 'FAIL D24: redirección de página o categoría'; end if;

  -- El admin ve y borra; no inserta a mano
  select count(*) into v from guide.slug_redirects where old_slug like 'rls-%';
  if v = 0 then raise exception 'FAIL D24: el admin no ve slug_redirects'; end if;
  begin insert into guide.slug_redirects (kind, locale, old_slug, article_id)
        values ('article', 'es', 'rls-hack', 'd0000000-0000-4000-8000-00000000000a');
        raise exception 'FAIL D24: el admin inserta redirecciones a mano';
  exception when insufficient_privilege then null; end;

  -- Borrar la entidad borra sus redirecciones
  delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000a';
  if exists (select 1 from guide.slug_redirects where old_slug in ('rls-d24-b-en', 'rls-d24-c')) then
    raise exception 'FAIL D24: redirecciones huérfanas tras borrar'; end if;
  delete from guide.items where id = 'f0000000-0000-4000-8000-00000000000d';
  if exists (select 1 from guide.slug_redirects where old_slug = 'rls-d24-gym') then
    raise exception 'FAIL D24: redirección de ítem huérfana'; end if;

  -- 3. Ficha con opiniones (oculta incluida): no se borra, error estable
  begin
    delete from guide.items where id = 'f0000000-0000-4000-8000-00000000000c';
    raise exception 'FAIL D24: se borra una ficha con opiniones';
  exception when foreign_key_violation then
    get stacked diagnostics v_s = message_text;
    if v_s <> 'item has user reviews' then raise exception 'FAIL D24: mensaje inesperado: %', v_s; end if;
  end;
  -- Despublicar sí se puede
  update guide.items set published = false where id = 'f0000000-0000-4000-8000-00000000000c';

  -- O5: un admin por PostgREST no puede usar el atajo (pasa por la validación completa)
  update guide.content_drafts set updated_by = null where page_id = 'e0000000-0000-4000-8000-000000000002';
  if (select updated_by from guide.content_drafts where page_id = 'e0000000-0000-4000-8000-000000000002')
     is distinct from 'a0000000-0000-4000-8000-000000000001'::uuid then
    raise exception 'FAIL D23 O5: un admin anula updated_by sin pasar por la auditoría forzada'; end if;
end $$;
reset role;

-- 3 (como postgres, orden del purge): borrar antes las opiniones permite borrar la ficha
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'user_reviews_item_fk' and confdeltype <> 'r') then
    raise exception 'FAIL D24: user_reviews_item_fk sigue en cascada'; end if;
  delete from guide.user_reviews where item_id = 'f0000000-0000-4000-8000-00000000000c';
  delete from guide.items where id = 'f0000000-0000-4000-8000-00000000000c';
end $$;

-- O5: el borrador deja de validar; borrar su autor de auth no falla ni toca payload/updated_at
alter table guide.content_drafts disable trigger content_drafts_before_write;
update guide.content_drafts set payload = '{"bogus":{}}', updated_by = 'a0000000-0000-4000-8000-000000000009'
where page_id = 'e0000000-0000-4000-8000-000000000002';
alter table guide.content_drafts enable trigger content_drafts_before_write;
do $$
declare v_at timestamptz; v_d guide.content_drafts;
begin
  select updated_at into v_at from guide.content_drafts where page_id = 'e0000000-0000-4000-8000-000000000002';
  delete from auth.users where id = 'a0000000-0000-4000-8000-000000000009';
  select * into v_d from guide.content_drafts where page_id = 'e0000000-0000-4000-8000-000000000002';
  if v_d.updated_by is not null or v_d.updated_at <> v_at or v_d.payload <> '{"bogus":{}}'::jsonb then
    raise exception 'FAIL D23 O5: la cascada de updated_by revalida o toca el borrador'; end if;
end $$;

-- ═════════════ F6.4 (hallazgo 4): lo vivo no se edita en directo, según el reloj del servidor ═════════════
-- Fixtures (como postgres). d…0e es un programado ya vencido que aún no ha pasado publish_due_articles:
-- se crea en futuro, recibe sus relacionados y solo después se mueve al pasado sin trigger (el trigger no deja
-- programar en el pasado). El orden importa: el toque O3 de un INSERT en article_items sobre un programado ya
-- vencido lo pasaría a published y el caso dejaría de probar un programado vencido.
select set_config('request.jwt.claims', '{}', true);
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d0000000-0000-4000-8000-00000000000d', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '1 day', 'Vivo', 'rls-f64-vivo'),
  ('d0000000-0000-4000-8000-00000000000e', 'c0000000-0000-4000-8000-000000000002', 'scheduled', now() + interval '1 day', 'Vencido', 'rls-f64-vencido'),
  ('d0000000-0000-4000-8000-00000000000f', 'c0000000-0000-4000-8000-000000000002', 'scheduled', now() + interval '1 day', 'Futuro', 'rls-f64-futuro');
-- F6.15b: se publica sin mantenimiento → portada con alt y city (items_z_publish_ready). Oculta con su guide.gyms
-- (con la ficha viva, el detalle daría PT423) y luego publicada.
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f0000000-0000-4000-8000-00000000000f', 'gym', 'Gym F6.4', 'rls-f64-gym', false, 'b0000000-0000-4000-8000-000000000001');
insert into guide.gyms (item_id, city) values ('f0000000-0000-4000-8000-00000000000f', 'Barcelona');
update guide.items set published = true where id = 'f0000000-0000-4000-8000-00000000000f';
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_items (article_id, item_id, sort_order) values
  ('d0000000-0000-4000-8000-00000000000d', 'f0000000-0000-4000-8000-00000000000f', 1),
  ('d0000000-0000-4000-8000-00000000000e', 'f0000000-0000-4000-8000-00000000000f', 1);
select set_config('guide.draft_op', '', true);
alter table guide.articles disable trigger articles_before_write;
update guide.articles set published_at = now() - interval '1 minute' where id = 'd0000000-0000-4000-8000-00000000000e';
alter table guide.articles enable trigger articles_before_write;
do $$
begin
  -- Precondición: d…0e es un programado vencido (scheduled, fecha pasada) con relacionados
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e'
                 and status = 'scheduled' and published_at <= now())
     or not exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000e') then
    raise exception 'FAIL F6.4: el fixture d…0e no es un programado vencido con relacionados'; end if;
end $$;
do $$
begin
  -- Sin exención por rol: ni postgres (ni una SECURITY DEFINER suya) edita contenido de lo vivo (D23 O6)
  begin update guide.articles set title_es = 'pg' where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: postgres edita un artículo vivo'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: postgres borra un artículo vivo sin mantenimiento'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: postgres borra relacionados de un vivo sin mantenimiento'; exception when sqlstate 'PT423' then null; end;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_bad   text;
  v_msg   text;
  v_det   text;
begin
  -- 1. Publicado: ninguna columna del borrador de cambios se escribe en directo (PT423 'article is live')
  foreach v_bad in array array[
    'title_es = ''x''', 'slug_es = ''rls-f64-x''', 'excerpt_en = ''x''', 'body_html_es = ''<p>x</p>''',
    'body_json_es = ''{"type":"doc","content":[{"type":"paragraph"}]}''', 'seo_title_es = ''x''', 'cover_media_id = ''b0000000-0000-4000-8000-000000000001''',
    'og_media_id = ''b0000000-0000-4000-8000-000000000001''', 'canonical_url = ''https://x.test/a''', 'noindex = true',
    'is_featured = true', 'category_id = ''c0000000-0000-4000-8000-000000000003''',
    -- cambiar fecha/estado dejándolo vivo no abre la puerta al contenido
    'status = ''published'', published_at = now() - interval ''2 days'', title_es = ''x''']::text[] loop
    begin
      execute format('update guide.articles set %s where id = %L', v_bad, 'd0000000-0000-4000-8000-00000000000d');
      raise exception 'FAIL F6.4: edita en directo un publicado: %', v_bad;
    exception when sqlstate 'PT423' then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'article is live' or v_det not like 'changed: %' then
        raise exception 'FAIL F6.4: error no estable (% / %)', v_msg, v_det; end if;
    end;
  end loop;

  -- 2. Programado vencido en el servidor (el caso del reloj atrasado): mismo bloqueo, y no pasa a published
  begin update guide.articles set title_es = 'reloj atrasado' where id = 'd0000000-0000-4000-8000-00000000000e';
    raise exception 'FAIL F6.4: edita un programado vencido'; exception when sqlstate 'PT423' then null; end;
  if (select status::text || title_es from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e') <> 'scheduledVencido' then
    raise exception 'FAIL F6.4: el programado vencido cambió'; end if;

  -- 3. El GUC solo exime al artículo que publish_draft está aplicando, y la reasignación solo category_id
  perform set_config('guide.draft_op', 'apply:d0000000-0000-4000-8000-00000000000e', true);
  begin update guide.articles set title_es = 'x' where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: el GUC de otro artículo exime'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'reassign_category', true);
  begin update guide.articles set category_id = 'c0000000-0000-4000-8000-000000000003', title_es = 'x'
        where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: reassign_category exime contenido'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', '', true);

  -- 4. Permitido sobre lo vivo: sort_order, fecha/estado sin contenido
  update guide.articles set sort_order = 42 where id = 'd0000000-0000-4000-8000-00000000000d';
  update guide.articles set published_at = now() - interval '3 days' where id = 'd0000000-0000-4000-8000-00000000000d';

  -- 4a. Sin "publicado invisible" (O1): 'published' con fecha futura se publica ya (published_at := now()),
  -- así que sigue vivo y mover la fecha al futuro no abre el contenido en directo
  begin update guide.articles set published_at = now() + interval '1 day', title_es = 'x'
        where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4 O1: fecha futura en un publicado abre el contenido'; exception when sqlstate 'PT423' then null; end;
  update guide.articles set published_at = now() + interval '1 day' where id = 'd0000000-0000-4000-8000-00000000000d';
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d'
                 and status = 'published' and published_at = now()) then
    raise exception 'FAIL F6.4 O1: publicado con fecha futura (UPDATE)'; end if;
  insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
    ('d0000000-0000-4000-8000-000000000010', 'c0000000-0000-4000-8000-000000000002', 'published', now() + interval '1 day',
     'Invisible', 'rls-f64-invisible');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000010'
                 and status = 'published' and published_at = now()) then
    raise exception 'FAIL F6.4 O1: publicado con fecha futura (INSERT)'; end if;

  -- 4b. Relacionados de un vivo (publicado o programado vencido): ni INSERT, ni UPDATE, ni DELETE en directo
  begin insert into guide.article_items (article_id, item_id, sort_order)
        values ('d0000000-0000-4000-8000-00000000000d', 'f0000000-0000-4000-8000-000000000001', 2);
    raise exception 'FAIL F6.4: añade relacionado a un vivo'; exception when sqlstate 'PT423' then null; end;
  begin update guide.article_items set sort_order = 5 where article_id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: reordena relacionados de un vivo'; exception when sqlstate 'PT423' then null; end;
  if (select status from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e') <> 'scheduled' then
    raise exception 'FAIL F6.4: d…0e ya no es scheduled antes de quitar relacionados'; end if;
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000e';
    raise exception 'FAIL F6.4: quita relacionados de un programado vencido'; exception when sqlstate 'PT423' then null; end;
  if not exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000e') then
    raise exception 'FAIL F6.4: el programado vencido perdió sus relacionados'; end if;
  -- mover un relacionado de un borrador a un vivo tampoco (UPDATE comprueba ambos artículos)
  begin update guide.article_items set article_id = 'd0000000-0000-4000-8000-00000000000f'
        where article_id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: saca un relacionado de un vivo por UPDATE'; exception when sqlstate 'PT423' then null; end;
  -- el GUC de otro artículo y 'maintenance' sin bypassrls (admin) no eximen
  perform set_config('guide.draft_op', 'apply:d0000000-0000-4000-8000-00000000000e', true);
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: el GUC de otro artículo exime relacionados'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'maintenance', true);
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: maintenance exime al admin (relacionados)'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: maintenance exime al admin (borrar)'; exception when sqlstate 'PT423' then null; end;
  begin update guide.articles set title_es = 'x' where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: maintenance exime al admin (contenido)'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', '', true);
  -- relacionados de un programado futuro: en directo
  insert into guide.article_items (article_id, item_id, sort_order)
  values ('d0000000-0000-4000-8000-00000000000f', 'f0000000-0000-4000-8000-000000000001', 1);
  update guide.article_items set sort_order = 2 where article_id = 'd0000000-0000-4000-8000-00000000000f';

  -- 4c. Borrar un vivo (publicado o programado vencido): PT423 'article is live', detail 'delete'
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: borra un publicado';
  exception when sqlstate 'PT423' then
    get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
    if v_msg <> 'article is live' or v_det <> 'delete' then
      raise exception 'FAIL F6.4: error de borrado no estable (% / %)', v_msg, v_det; end if;
  end;
  if (select status from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e') <> 'scheduled' then
    raise exception 'FAIL F6.4: d…0e ya no es scheduled antes de borrarlo'; end if;
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e';
    raise exception 'FAIL F6.4: borra un programado vencido';
  exception when sqlstate 'PT423' then
    get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
    if v_msg <> 'article is live' or v_det <> 'delete' then
      raise exception 'FAIL F6.4: error de borrado no estable en programado vencido (% / %)', v_msg, v_det; end if;
  end;
  -- programado aún no vencido: se edita en directo
  update guide.articles set title_es = 'Futuro editado' where id = 'd0000000-0000-4000-8000-00000000000f';

  -- 5. publish_draft sigue aplicando contenido (y relacionados) sobre lo vivo; no deja el GUC abierto
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000d',
    '{"article":{"title_es":"Vía borrador","body_html_es":"<p>uno dos</p>","category_id":"c0000000-0000-4000-8000-000000000003"},
      "item_ids":["f0000000-0000-4000-8000-000000000001"]}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000d'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000d');
  if not exists (select 1 from guide.articles a where a.id = 'd0000000-0000-4000-8000-00000000000d' and a.title_es = 'Vía borrador'
                 and a.reading_minutes_es = 1 and a.category_id = 'c0000000-0000-4000-8000-000000000003' and a.status = 'published')
     or not exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000d') then
    raise exception 'FAIL F6.4: publish_draft no aplicó sobre el artículo vivo'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.4: publish_draft deja guide.draft_op = %', current_setting('guide.draft_op', true); end if;
  begin update guide.articles set title_es = 'tras publicar' where id = 'd0000000-0000-4000-8000-00000000000d';
    raise exception 'FAIL F6.4: tras publish_draft se edita en directo'; exception when sqlstate 'PT423' then null; end;
  -- publish_draft sobre el programado vencido también aplica (y el trigger lo pasa a published)
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-00000000000e', '{"article":{"excerpt_es":"Desde borrador"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-00000000000e'));
  if (select status from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e') <> 'scheduled' then
    raise exception 'FAIL F6.4: d…0e ya no es scheduled antes de publish_draft'; end if;
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-00000000000e');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-00000000000e'
                 and excerpt_es = 'Desde borrador' and status = 'published') then
    raise exception 'FAIL F6.4: publish_draft sobre programado vencido'; end if;
  -- borrar una ficha mencionada por artículos vivos sí se puede (cascada): dejan de mencionarla
  -- (F6.7: publicada no se borra; se oculta antes)
  update guide.items set published = false where id = 'f0000000-0000-4000-8000-00000000000f';
  delete from guide.items where id = 'f0000000-0000-4000-8000-00000000000f';
  if exists (select 1 from guide.article_items where item_id = 'f0000000-0000-4000-8000-00000000000f') then
    raise exception 'FAIL F6.4: la cascada de la ficha no quitó los relacionados'; end if;

  -- 6. Despublicar (con o sin contenido en el mismo UPDATE) y después editar en directo
  update guide.articles set status = 'draft', title_es = 'Despublicado' where id = 'd0000000-0000-4000-8000-00000000000d';
  update guide.articles set excerpt_es = 'ya es borrador' where id = 'd0000000-0000-4000-8000-00000000000d';
  -- volver a publicar desde borrador (no vivo antes) admite contenido
  update guide.articles set status = 'published', published_at = null, title_es = 'Republicado'
  where id = 'd0000000-0000-4000-8000-00000000000d';
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d' and title_es = 'Republicado'
                 and status = 'published' and excerpt_es = 'ya es borrador') then
    raise exception 'FAIL F6.4: despublicar/republicar'; end if;
  -- despublicar y después borrar (con sus relacionados en cascada)
  update guide.articles set status = 'draft' where id = 'd0000000-0000-4000-8000-00000000000d';
  delete from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d';
  if exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-00000000000d')
     or exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-00000000000d') then
    raise exception 'FAIL F6.4: despublicar y borrar'; end if;

  -- 7. Reprogramar a futuro (lo saca de la web) admite contenido; luego ya es editable
  update guide.articles set status = 'scheduled', published_at = now() + interval '2 days', title_es = 'Reprogramado'
  where id = 'd0000000-0000-4000-8000-00000000000e';
  update guide.articles set excerpt_es = 'editable' where id = 'd0000000-0000-4000-8000-00000000000e';
  -- reprogramar al pasado sigue siendo 23514
  begin update guide.articles set published_at = now() - interval '1 hour' where id = 'd0000000-0000-4000-8000-00000000000e';
    raise exception 'FAIL F6.4: reprograma al pasado'; exception when check_violation then null; end;

  -- 8. Borrar una categoría reasigna también artículos vivos (category_id con 'reassign_category')
  perform guide.delete_article_category('c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000002');
  if exists (select 1 from guide.articles where category_id = 'c0000000-0000-4000-8000-000000000003') then
    raise exception 'FAIL F6.4: delete_article_category no reasignó lo vivo'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.4: delete_article_category deja el GUC abierto'; end if;
end $$;
reset role;

-- ═════════════ F6.4 parte 2b: despublicar con guide.unpublish_article ═════════════
-- Fixtures (como postgres): d…11 publicado sin borrador (con relacionado), d…12 publicado con borrador de cambios
-- (contenido, slug y relacionados), d…13 programado vencido con borrador, d…14 borrador, d…15 programado futuro.
select set_config('request.jwt.claims', '{}', true);
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d0000000-0000-4000-8000-000000000011', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '2 days', 'Unpub sin', 'rls-unpub-sin'),
  ('d0000000-0000-4000-8000-000000000012', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '2 days', 'Unpub con', 'rls-unpub-con'),
  ('d0000000-0000-4000-8000-000000000013', 'c0000000-0000-4000-8000-000000000002', 'scheduled', now() + interval '1 day', 'Unpub vencido', 'rls-unpub-vencido'),
  ('d0000000-0000-4000-8000-000000000014', 'c0000000-0000-4000-8000-000000000002', 'draft', null, 'Unpub borrador', 'rls-unpub-borrador'),
  ('d0000000-0000-4000-8000-000000000015', 'c0000000-0000-4000-8000-000000000002', 'scheduled', now() + interval '1 day', 'Unpub futuro', 'rls-unpub-futuro');
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_items (article_id, item_id, sort_order) values
  ('d0000000-0000-4000-8000-000000000011', 'f0000000-0000-4000-8000-000000000001', 1),
  ('d0000000-0000-4000-8000-000000000012', 'f0000000-0000-4000-8000-000000000001', 1);
select set_config('guide.draft_op', '', true);
alter table guide.articles disable trigger articles_before_write;
update guide.articles set published_at = now() - interval '1 minute' where id = 'd0000000-0000-4000-8000-000000000013';
alter table guide.articles enable trigger articles_before_write;

-- Firma, DEFINER con search_path vacío y EXECUTE solo para authenticated (ni PUBLIC ni anon ni service_role)
do $$
declare
  v_fn regprocedure := 'guide.unpublish_article(uuid)'::regprocedure;
begin
  if not exists (select 1 from pg_proc p where p.oid = v_fn and p.prosecdef and p.prorettype = 'void'::regtype
                 and p.proconfig @> array['search_path=""']) then
    raise exception 'FAIL F6.4 unpublish: no es SECURITY DEFINER void con search_path vacío'; end if;
  if has_function_privilege('anon', v_fn, 'execute') or has_function_privilege('service_role', v_fn, 'execute')
     or not has_function_privilege('authenticated', v_fn, 'execute')
     or exists (select 1 from aclexplode((select proacl from pg_proc where oid = v_fn)) a where a.grantee = 0) then
    raise exception 'FAIL F6.4 unpublish: EXECUTE mal concedido'; end if;
  -- no depende de nada de public
  if exists (select 1 from pg_depend d join pg_proc p on p.oid = d.refobjid and d.refclassid = 'pg_proc'::regclass
             join pg_namespace n on n.oid = p.pronamespace where d.objid = v_fn and n.nspname = 'public')
     or pg_get_functiondef(v_fn) ~* '\mpublic\.' then
    raise exception 'FAIL F6.4 unpublish: referencia a public'; end if;
end $$;

-- Foto de public (filas y hash por tabla) para comprobar que despublicar no lo toca
create temp table _unpub_public_snap on commit drop as
select c.relname::text as tbl, null::bigint as n, null::text as h
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p');
do $$
declare r record; v_n bigint; v_h text;
begin
  for r in select tbl from _unpub_public_snap loop
    execute format('select count(*), coalesce(md5(string_agg(t::text, %L order by t::text)), %L) from public.%I t', ',', '', r.tbl)
      into v_n, v_h;
    update _unpub_public_snap set n = v_n, h = v_h where tbl = r.tbl;
  end loop;
end $$;

-- El admin deja un borrador de cambios en d…12 (contenido, slug y relacionados) y en d…13
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000012',
    '{"article":{"title_es":"Unpub editado","body_html_es":"<p>uno dos tres</p>","slug_es":"rls-unpub-con-nuevo"},"item_ids":[]}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000012'));
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000013', '{"article":{"excerpt_es":"Vencido editado"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000013'));
end $$;
reset role;

-- anon y no admin (también con JWT forjado): rechazados, nada cambia
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000012');
    raise exception 'LEAK anon F6.4: unpublish_article (con borrador)'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$
declare
  v_claims text;
begin
  foreach v_claims in array array[
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}',
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"service_role","app_metadata":{"role":"admin"},"user_metadata":{"is_admin":true}}'] loop
    perform set_config('request.jwt.claims', v_claims, true);
    set local role authenticated;
    begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000011');
      raise exception 'LEAK user F6.4: unpublish_article (%)', v_claims; exception when insufficient_privilege then null; end;
    begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000012');
      raise exception 'LEAK user F6.4: unpublish_article con borrador (%)', v_claims; exception when insufficient_privilege then null; end;
    -- ni siquiera filtra si el artículo existe o está vivo (42501 antes que P0002/22023)
    begin perform guide.unpublish_article('d0000000-0000-4000-8000-0000000000ff');
      raise exception 'LEAK user F6.4: unpublish_article inexistente'; exception when insufficient_privilege then null; end;
    reset role;
  end loop;
end $$;
select set_config('request.jwt.claims', '{}', true);
do $$
begin
  if (select count(*) from guide.articles where id in ('d0000000-0000-4000-8000-000000000011', 'd0000000-0000-4000-8000-000000000012')
      and status = 'published') <> 2
     or (select count(*) from guide.content_drafts where article_id in ('d0000000-0000-4000-8000-000000000012',
         'd0000000-0000-4000-8000-000000000013')) <> 2
     or exists (select 1 from guide.activity_log where action = 'unpublish' and occurred_at = now()) then
    raise exception 'LEAK F6.4: un no admin despublicó o tocó el borrador'; end if;
end $$;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_msg text;
begin
  -- 1. No vivo: borrador o programado futuro → 22023 'article not live'; inexistente → P0002. Sin efectos.
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000014');
    raise exception 'FAIL F6.4 unpublish: despublica un borrador';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'article not live' then raise exception 'FAIL F6.4 unpublish: error no estable (%)', v_msg; end if;
  end;
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000015');
    raise exception 'FAIL F6.4 unpublish: despublica un programado futuro'; exception when sqlstate '22023' then null; end;
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-0000000000ff');
    raise exception 'FAIL F6.4 unpublish: inexistente'; exception when sqlstate 'P0002' then null; end;
  begin perform guide.unpublish_article(null);
    raise exception 'FAIL F6.4 unpublish: null'; exception when sqlstate 'P0002' then null; end;
  if (select status::text from guide.articles where id = 'd0000000-0000-4000-8000-000000000015') <> 'scheduled' then
    raise exception 'FAIL F6.4 unpublish: el programado futuro cambió'; end if;

  -- 2. Publicado sin borrador: draft, published_at null, contenido, slug y relacionados intactos, sin redirecciones
  perform guide.unpublish_article('d0000000-0000-4000-8000-000000000011');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000011'
                 and status = 'draft' and published_at is null and title_es = 'Unpub sin' and slug_es = 'rls-unpub-sin')
     or not exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000011') then
    raise exception 'FAIL F6.4 unpublish: publicado sin borrador'; end if;
  if exists (select 1 from guide.slug_redirects where article_id = 'd0000000-0000-4000-8000-000000000011') then
    raise exception 'FAIL F6.4 unpublish: crea redirección sin cambio de slug'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish' and entity_table = 'articles'
                 and entity_id = 'd0000000-0000-4000-8000-000000000011' and actor_id = 'a0000000-0000-4000-8000-000000000001'
                 and details = '{"draft_applied": false, "previous_status": "published"}'::jsonb) then
    raise exception 'FAIL F6.4 unpublish: no registra la despublicación'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL F6.4 unpublish: deja GUC abiertos'; end if;
  -- ya no está vivo: segunda llamada → 22023; y se edita en directo
  begin perform guide.unpublish_article('d0000000-0000-4000-8000-000000000011');
    raise exception 'FAIL F6.4 unpublish: dos veces'; exception when sqlstate '22023' then null; end;
  update guide.articles set title_es = 'Unpub sin editado' where id = 'd0000000-0000-4000-8000-000000000011';

  -- 3. Publicado con borrador: el borrador se aplica (contenido, slug, relacionados) y desaparece
  perform guide.unpublish_article('d0000000-0000-4000-8000-000000000012');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000012'
                 and status = 'draft' and published_at is null and title_es = 'Unpub editado'
                 and body_html_es = '<p>uno dos tres</p>' and reading_minutes_es = 1 and slug_es = 'rls-unpub-con-nuevo') then
    raise exception 'FAIL F6.4 unpublish: no aplicó el borrador'; end if;
  if exists (select 1 from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000012') then
    raise exception 'FAIL F6.4 unpublish: no aplicó item_ids del borrador'; end if;
  if exists (select 1 from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000012') then
    raise exception 'FAIL F6.4 unpublish: el borrador sigue ahí'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish'
                 and entity_id = 'd0000000-0000-4000-8000-000000000012' and entity_label = 'Unpub editado'
                 and details = '{"draft_applied": true, "previous_status": "published"}'::jsonb)
     or exists (select 1 from guide.activity_log where action in ('draft_publish', 'draft_discard')
                and entity_id = 'd0000000-0000-4000-8000-000000000012') then
    raise exception 'FAIL F6.4 unpublish: registro con borrador'; end if;
  -- el slug cambió por el borrador: redirección old → artículo como en publish_draft, sin resolver mientras no esté vivo
  if not exists (select 1 from guide.slug_redirects where article_id = 'd0000000-0000-4000-8000-000000000012'
                 and old_slug = 'rls-unpub-con') then
    raise exception 'FAIL F6.4 unpublish: falta la redirección del slug cambiado por el borrador'; end if;
  if guide.resolve_redirect('article', 'es', 'rls-unpub-con') is not null then
    raise exception 'FAIL F6.4 unpublish: la redirección resuelve a un borrador'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL F6.4 unpublish: deja GUC abiertos (con borrador)'; end if;

  -- 4. Programado vencido con borrador: también (no pasa por published al final)
  if (select status::text from guide.articles where id = 'd0000000-0000-4000-8000-000000000013') <> 'scheduled' then
    raise exception 'FAIL F6.4 unpublish: d…13 no es un programado vencido'; end if;
  perform guide.unpublish_article('d0000000-0000-4000-8000-000000000013');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000013'
                 and status = 'draft' and published_at is null and excerpt_es = 'Vencido editado')
     or exists (select 1 from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000013') then
    raise exception 'FAIL F6.4 unpublish: programado vencido con borrador'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish'
                 and entity_id = 'd0000000-0000-4000-8000-000000000013'
                 and details = '{"draft_applied": true, "previous_status": "scheduled"}'::jsonb) then
    raise exception 'FAIL F6.4 unpublish: registro del programado vencido'; end if;

  -- 5. Republicar tras despublicar: el trigger fija la fecha de la nueva publicación
  update guide.articles set status = 'published', published_at = null where id = 'd0000000-0000-4000-8000-000000000012';
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000012'
                 and status = 'published' and published_at = now()) then
    raise exception 'FAIL F6.4 unpublish: republicar'; end if;
  if guide.resolve_redirect('article', 'es', 'rls-unpub-con') is distinct from 'rls-unpub-con-nuevo' then
    raise exception 'FAIL F6.4 unpublish: la redirección no resuelve al republicar'; end if;

  -- 6. publish_draft normal sigue registrando 'draft_publish' (el GUC de unpublish no se queda abierto)
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000012', '{"article":{"excerpt_es":"tras unpublish"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000012'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000012');
  if not exists (select 1 from guide.activity_log where action = 'draft_publish'
                 and entity_id = 'd0000000-0000-4000-8000-000000000012' and changed_columns = array['article.excerpt_es']) then
    raise exception 'FAIL F6.4 unpublish: publish_draft dejó de registrarse'; end if;
end $$;
reset role;

-- X1/X3 (revisión leona-lia 2b). Fixtures como postgres: d…16 publicado con relacionado (GUC falsificado),
-- d…17 publicado con updated_at en el pasado (para que un cambio posterior deje obsoleta la base del borrador).
select set_config('request.jwt.claims', '{}', true);
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, updated_at) values
  ('d0000000-0000-4000-8000-000000000016', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '2 days', 'Unpub X1', 'rls-unpub-x1', now() - interval '1 hour'),
  ('d0000000-0000-4000-8000-000000000017', 'c0000000-0000-4000-8000-000000000002', 'published', now() - interval '2 days', 'Unpub X3', 'rls-unpub-x3', now() - interval '1 hour');
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_items (article_id, item_id, sort_order)
values ('d0000000-0000-4000-8000-000000000016', 'f0000000-0000-4000-8000-000000000001', 1);
select set_config('guide.draft_op', '', true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  -- X1. Admin con guide.unpublish_op falsificado (id del vivo): no exime ninguna guarda de lo vivo → PT423
  perform set_config('guide.unpublish_op', 'd0000000-0000-4000-8000-000000000016', true);
  begin update guide.articles set title_es = 'x' where id = 'd0000000-0000-4000-8000-000000000016';
    raise exception 'FAIL F6.4 X1: unpublish_op falsificado exime el contenido'; exception when sqlstate 'PT423' then null; end;
  begin insert into guide.article_items (article_id, item_id, sort_order)
        values ('d0000000-0000-4000-8000-000000000016', 'f0000000-0000-4000-8000-000000000003', 2);
    raise exception 'FAIL F6.4 X1: unpublish_op falsificado exime añadir relacionados'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000016';
    raise exception 'FAIL F6.4 X1: unpublish_op falsificado exime quitar relacionados'; exception when sqlstate 'PT423' then null; end;
  begin delete from guide.articles where id = 'd0000000-0000-4000-8000-000000000016';
    raise exception 'FAIL F6.4 X1: unpublish_op falsificado exime borrar lo vivo'; exception when sqlstate 'PT423' then null; end;
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000016'
                 and status = 'published' and title_es = 'Unpub X1')
     or (select count(*) from guide.article_items where article_id = 'd0000000-0000-4000-8000-000000000016') <> 1 then
    raise exception 'FAIL F6.4 X1: el vivo cambió con unpublish_op falsificado'; end if;

  -- X1c. F6.7 O3: con el GUC falsificado, publish_draft ya NO omite la línea 'draft_publish' (la exención exige
  -- bypassrls, solo dentro de unpublish_article); la línea 'update' de articles_log_activity también queda.
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000016', '{"article":{"excerpt_es":"X1c"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000016'));
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000016');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000016'
                 and excerpt_es = 'X1c' and status = 'published') then
    raise exception 'FAIL F6.4 X1c: publish_draft no aplicó'; end if;
  if not exists (select 1 from guide.activity_log where action = 'draft_publish'
                 and entity_id = 'd0000000-0000-4000-8000-000000000016' and changed_columns = array['article.excerpt_es']) then
    raise exception 'FAIL F6.7 O3: el GUC falsificado omite la línea draft_publish'; end if;
  -- O3: el escritor del registro no se llama por RPC
  begin perform guide.content_drafts_log_write('article', 'd0000000-0000-4000-8000-000000000016', '{"article":{"x":1}}');
    raise exception 'LEAK F6.7 O3: content_drafts_log_write por RPC'; exception when insufficient_privilege then null; end;
  -- O2: articles_set_updated_at toma las generadas del catálogo; ordenar sigue sin cambiar la versión
  declare v_ts timestamptz := (select updated_at from guide.articles where id = 'd0000000-0000-4000-8000-000000000017');
  begin
    update guide.articles set sort_order = sort_order + 7 where id = 'd0000000-0000-4000-8000-000000000017';
    if (select updated_at from guide.articles where id = 'd0000000-0000-4000-8000-000000000017') <> v_ts then
      raise exception 'FAIL F6.7 O2: ordenar cambia la versión del artículo'; end if;
    update guide.articles set sort_order = sort_order - 7 where id = 'd0000000-0000-4000-8000-000000000017';
  end;
  if not exists (select 1 from guide.activity_log where action = 'update' and entity_table = 'articles'
                 and entity_id = 'd0000000-0000-4000-8000-000000000016'
                 and actor_id = 'a0000000-0000-4000-8000-000000000001' and changed_columns @> array['excerpt_es']) then
    raise exception 'FAIL F6.4 X1c: falta la línea update del cambio aplicado'; end if;
  perform set_config('guide.unpublish_op', '', true);

  -- X3 (preparación). Borrador de cambios sobre d…17 con la base actual (updated_at de hace una hora).
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-000000000017', '{"article":{"title_es":"X3 borrador"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-000000000017'));
end $$;
reset role;

-- X3. Mantenimiento (postgres) cambia en vivo una columna fuera del payload → la base del borrador queda obsoleta
select set_config('request.jwt.claims', '{}', true);
select set_config('guide.draft_op', 'maintenance', true);
update guide.articles set excerpt_en = 'X3 mantenimiento' where id = 'd0000000-0000-4000-8000-000000000017';
select set_config('guide.draft_op', '', true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  -- publish_draft sin force: conflicto PT409 y nada cambia
  begin perform guide.publish_draft('article', 'd0000000-0000-4000-8000-000000000017');
    raise exception 'FAIL F6.4 X3: publish_draft con base obsoleta no da PT409'; exception when sqlstate 'PT409' then null; end;
  if not exists (select 1 from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000017')
     or (select title_es from guide.articles where id = 'd0000000-0000-4000-8000-000000000017') <> 'Unpub X3' then
    raise exception 'FAIL F6.4 X3: el PT409 dejó efectos'; end if;
  -- unpublish_article aplica igualmente el borrador (force) y conserva lo que no está en el payload
  perform guide.unpublish_article('d0000000-0000-4000-8000-000000000017');
  if not exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000017'
                 and status = 'draft' and published_at is null and title_es = 'X3 borrador'
                 and excerpt_en = 'X3 mantenimiento' and slug_es = 'rls-unpub-x3') then
    raise exception 'FAIL F6.4 X3: unpublish con base obsoleta no aplicó o pisó columnas fuera del payload'; end if;
  if exists (select 1 from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-000000000017') then
    raise exception 'FAIL F6.4 X3: el borrador sigue ahí'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish'
                 and entity_id = 'd0000000-0000-4000-8000-000000000017'
                 and details = '{"draft_applied": true, "previous_status": "published"}'::jsonb) then
    raise exception 'FAIL F6.4 X3: registro de la despublicación'; end if;
  -- F6.7 O3: dentro de unpublish_article la exención (GUC + bypassrls) sigue omitiendo draft_publish
  if exists (select 1 from guide.activity_log where action in ('draft_publish', 'draft_discard')
             and entity_id = 'd0000000-0000-4000-8000-000000000017') then
    raise exception 'FAIL F6.7 O3: unpublish_article registra draft_publish duplicado'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL F6.4 X3: deja GUC abiertos'; end if;
end $$;
reset role;

-- ═════════════ F6.5: categorías del panel (crear/editar, ordenar, borrar con reasignación) ═════════════
-- Fixtures (como postgres). Categorías a1 (es+en, 3 artículos), a2 (1 borrador), a3 (vacía), a4 (vacía pero elegida
-- por un borrador de cambios). Artículos con updated_at de hace una hora para detectar cualquier subida de versión.
-- a1: d…a1 publicado (con borrador de contenido), d…a2 borrador, d…a3 publicado (con borrador que lo mueve a a4).
select set_config('request.jwt.claims', '{}', true);
insert into guide.article_categories (id, name_es, slug_es, name_en, slug_en, sort_order) values
  ('c0000000-0000-4000-8000-0000000000a1', 'F65 A', 'rls-f65-a', 'F65 A en', 'rls-f65-a-en', 101),
  ('c0000000-0000-4000-8000-0000000000a2', 'F65 B', 'rls-f65-b', null, null, 102),
  ('c0000000-0000-4000-8000-0000000000a3', 'F65 vacía', 'rls-f65-vacia', null, null, 103),
  ('c0000000-0000-4000-8000-0000000000a4', 'F65 destino', 'rls-f65-destino', null, null, 104);
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, sort_order, created_at, updated_at) values
  ('d0000000-0000-4000-8000-0000000000a1', 'c0000000-0000-4000-8000-0000000000a1', 'published', now() - interval '2 days', 'F65 uno', 'rls-f65-uno', 1, now() - interval '2 days', now() - interval '1 hour'),
  ('d0000000-0000-4000-8000-0000000000a2', 'c0000000-0000-4000-8000-0000000000a1', 'draft', null, 'F65 dos', 'rls-f65-dos', 2, now() - interval '2 days', now() - interval '1 hour'),
  ('d0000000-0000-4000-8000-0000000000a3', 'c0000000-0000-4000-8000-0000000000a1', 'published', now() - interval '2 days', 'F65 tres', 'rls-f65-tres', 3, now() - interval '2 days', now() - interval '1 hour'),
  ('d0000000-0000-4000-8000-0000000000a4', 'c0000000-0000-4000-8000-0000000000a2', 'draft', null, 'F65 cuatro', 'rls-f65-cuatro', 1, now() - interval '2 days', now() - interval '1 hour');

-- Firmas, seguridad y grants
do $$
begin
  if not exists (select 1 from pg_proc where oid = 'guide.delete_article_category(uuid, uuid)'::regprocedure
                 and prosecdef and proconfig @> array['search_path=""']) then
    raise exception 'FAIL F6.5: delete_article_category no es DEFINER con search_path vacío'; end if;
  if exists (select 1 from pg_proc where oid in ('guide.reorder_articles(uuid, uuid[])'::regprocedure,
                                                 'guide.reorder_article_categories(uuid[])'::regprocedure)
             and (prosecdef or not proconfig @> array['search_path=""'])) then
    raise exception 'FAIL F6.5: reorder_* deben ser INVOKER con search_path vacío'; end if;
  if has_function_privilege('anon', 'guide.delete_article_category(uuid, uuid)', 'execute')
     or has_function_privilege('anon', 'guide.reorder_articles(uuid, uuid[])', 'execute')
     or has_function_privilege('anon', 'guide.reorder_article_categories(uuid[])', 'execute')
     or not has_function_privilege('authenticated', 'guide.delete_article_category(uuid, uuid)', 'execute')
     or exists (select 1 from pg_proc p, aclexplode(p.proacl) a
                where p.oid in ('guide.delete_article_category(uuid, uuid)'::regprocedure, 'guide.reorder_articles(uuid, uuid[])'::regprocedure,
                                'guide.reorder_article_categories(uuid[])'::regprocedure) and a.grantee = 0) then
    raise exception 'FAIL F6.5: EXECUTE mal concedido'; end if;
  if has_table_privilege('authenticated', 'guide.article_categories', 'delete')
     or has_table_privilege('anon', 'guide.article_categories', 'delete')
     or exists (select 1 from pg_policies where schemaname = 'guide' and tablename = 'article_categories' and cmd = 'DELETE') then
    raise exception 'FAIL F6.5: DELETE directo de categorías sigue abierto'; end if;
  if has_function_privilege('authenticated', 'guide.articles_set_updated_at()', 'execute') then
    raise exception 'FAIL F6.5: la función de trigger es ejecutable por clientes'; end if;
end $$;

-- El admin deja dos borradores de cambios: d…a1 (contenido) y d…a3 (lo mueve a la categoría a4)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-0000000000a1', '{"article":{"title_es":"F65 uno editado"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-0000000000a1'));
  perform guide.save_draft('article', 'd0000000-0000-4000-8000-0000000000a3',
    '{"article":{"category_id":"c0000000-0000-4000-8000-0000000000a4"}}',
    guide.draft_entity_version('article', 'd0000000-0000-4000-8000-0000000000a3'));
end $$;
reset role;

-- anon y no admin (también con JWT forjado): ni crean, ni editan, ni ordenan, ni borran
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.reorder_article_categories(array['c0000000-0000-4000-8000-0000000000a1']::uuid[]);
    raise exception 'LEAK anon F6.5: reorder_article_categories'; exception when insufficient_privilege then null; end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1', array['d0000000-0000-4000-8000-0000000000a1']::uuid[]);
    raise exception 'LEAK anon F6.5: reorder_articles'; exception when insufficient_privilege then null; end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a3', null);
    raise exception 'LEAK anon F6.5: delete_article_category'; exception when insufficient_privilege then null; end;
  begin delete from guide.article_categories where id = 'c0000000-0000-4000-8000-0000000000a3';
    raise exception 'LEAK anon F6.5: DELETE directo'; exception when insufficient_privilege then null; end;
  begin insert into guide.article_categories (name_es, slug_es) values ('hack', 'rls-f65-hack');
    raise exception 'LEAK anon F6.5: INSERT'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$
declare
  v_claims text;
  v_n integer;
begin
  foreach v_claims in array array[
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}',
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"service_role","app_metadata":{"role":"admin"},"user_metadata":{"is_admin":true}}'] loop
    perform set_config('request.jwt.claims', v_claims, true);
    set local role authenticated;
    begin perform guide.reorder_article_categories(array['c0000000-0000-4000-8000-0000000000a1']::uuid[]);
      raise exception 'LEAK user F6.5: reorder_article_categories (%)', v_claims; exception when insufficient_privilege then null; end;
    begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
        array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-0000000000a1']::uuid[]);
      raise exception 'LEAK user F6.5: reorder_articles (%)', v_claims; exception when insufficient_privilege then null; end;
    -- 42501 antes que P0002: no filtra si la categoría existe
    begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000ff', null);
      raise exception 'LEAK user F6.5: delete_article_category inexistente'; exception when insufficient_privilege then null; end;
    begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a3', null);
      raise exception 'LEAK user F6.5: delete_article_category'; exception when insufficient_privilege then null; end;
    begin delete from guide.article_categories where id = 'c0000000-0000-4000-8000-0000000000a3';
      raise exception 'LEAK user F6.5: DELETE directo'; exception when insufficient_privilege then null; end;
    begin insert into guide.article_categories (name_es, slug_es) values ('hack', 'rls-f65-hack');
      raise exception 'LEAK user F6.5: INSERT'; exception when insufficient_privilege then null; end;
    update guide.article_categories set slug_es = 'rls-f65-hack' where id = 'c0000000-0000-4000-8000-0000000000a1';
    get diagnostics v_n = row_count;
    if v_n <> 0 then raise exception 'LEAK user F6.5: UPDATE de categoría'; end if;
    reset role;
  end loop;
end $$;
select set_config('request.jwt.claims', '{}', true);
do $$
begin
  if (select count(*) from guide.article_categories where id::text like 'c0000000-0000-4000-8000-0000000000a%') <> 4
     or exists (select 1 from guide.article_categories where slug_es = 'rls-f65-hack')
     or (select array_agg(sort_order order by sort_order) from guide.articles where category_id = 'c0000000-0000-4000-8000-0000000000a1') <> array[1, 2, 3] then
    raise exception 'LEAK F6.5: un no admin cambió categorías u orden'; end if;
end $$;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_msg  text;
  v_ids  uuid[];
  v_logs integer;
  v_new  uuid;
  v_draft guide.content_drafts%rowtype;
begin
  -- 1. Crear (como PostgREST): slug único por idioma (23505), color #rrggbb (23514), actividad 'insert'
  insert into guide.article_categories (name_es, slug_es, color, sort_order) values ('F65 nueva', 'rls-f65-nueva', '#A1b2C3', 105)
  returning id into v_new;
  if not exists (select 1 from guide.activity_log where action = 'insert' and entity_table = 'article_categories'
                 and entity_id = v_new::text and entity_label = 'F65 nueva' and actor_id = 'a0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL F6.5: crear categoría sin actividad'; end if;
  begin insert into guide.article_categories (name_es, slug_es) values ('dup', 'rls-f65-a');
    raise exception 'FAIL F6.5: slug_es duplicado'; exception when unique_violation then null; end;
  begin insert into guide.article_categories (name_es, slug_es, name_en, slug_en) values ('dup', 'rls-f65-dup', 'dup', 'rls-f65-a-en');
    raise exception 'FAIL F6.5: slug_en duplicado'; exception when unique_violation then null; end;
  begin insert into guide.article_categories (name_es, slug_es, color) values ('c', 'rls-f65-color', '#12345');
    raise exception 'FAIL F6.5: color corto'; exception when check_violation then null; end;
  begin update guide.article_categories set color = 'red' where id = v_new;
    raise exception 'FAIL F6.5: color con nombre'; exception when check_violation then null; end;
  begin update guide.article_categories set color = '#12345g' where id = v_new;
    raise exception 'FAIL F6.5: color no hexadecimal'; exception when check_violation then null; end;

  -- 2. Editar slug es/en (UPDATE como PostgREST) → 301 desde los antiguos (D24) y actividad 'update'
  update guide.article_categories set slug_es = 'rls-f65-a2', slug_en = 'rls-f65-a2-en', description_es = 'Desc'
  where id = 'c0000000-0000-4000-8000-0000000000a1';
  if guide.resolve_redirect('article_category', 'es', 'rls-f65-a') is distinct from 'rls-f65-a2'
     or guide.resolve_redirect('article_category', 'en', 'rls-f65-a-en') is distinct from 'rls-f65-a2-en' then
    raise exception 'FAIL F6.5: el cambio de slug de categoría no crea la 301'; end if;
  if not exists (select 1 from guide.activity_log where action = 'update' and entity_table = 'article_categories'
                 and entity_id = 'c0000000-0000-4000-8000-0000000000a1' and changed_columns @> array['slug_es', 'slug_en', 'description_es']) then
    raise exception 'FAIL F6.5: editar categoría sin actividad'; end if;

  -- 3. reorder_articles: validación de la lista (22023/P0002) sin efectos
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
      array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2']::uuid[]);
    raise exception 'FAIL F6.5: reorder_articles con lista incompleta';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'list must include every article of the category' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
      array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a1']::uuid[]);
    raise exception 'FAIL F6.5: reorder_articles con duplicados';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'duplicate ids' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
      array['d0000000-0000-4000-8000-0000000000a3', null, 'd0000000-0000-4000-8000-0000000000a1']::uuid[]);
    raise exception 'FAIL F6.5: reorder_articles con nulo'; exception when sqlstate '22023' then null; end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1', null);
    raise exception 'FAIL F6.5: reorder_articles con null'; exception when sqlstate '22023' then null; end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
      array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-0000000000a4']::uuid[]);
    raise exception 'FAIL F6.5: reorder_articles con artículo ajeno';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'articles must belong to the category' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000ff', '{}'::uuid[]);
    raise exception 'FAIL F6.5: reorder_articles con categoría inexistente'; exception when sqlstate 'P0002' then null; end;
  if (select array_agg(sort_order order by id) from guide.articles where category_id = 'c0000000-0000-4000-8000-0000000000a1') <> array[1, 2, 3] then
    raise exception 'FAIL F6.5: un reorder rechazado dejó efectos'; end if;

  -- 3b. Reordenar con publicados (uno con borrador pendiente): sin PT423, sin borradores nuevos, sin tocar updated_at
  perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
    array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-0000000000a1']::uuid[]);
  if (select array_agg(id order by sort_order) from guide.articles where category_id = 'c0000000-0000-4000-8000-0000000000a1')
     <> array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-0000000000a1']::uuid[] then
    raise exception 'FAIL F6.5: reorder_articles no ordenó'; end if;
  if exists (select 1 from guide.articles where id::text like 'd0000000-0000-4000-8000-0000000000a%'
             and updated_at <> now() - interval '1 hour') then
    raise exception 'FAIL F6.5: reordenar subió updated_at'; end if;
  if (select count(*) from guide.content_drafts where article_id::text like 'd0000000-0000-4000-8000-0000000000a%') <> 2
     or (select payload from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-0000000000a1')
        <> '{"article":{"title_es":"F65 uno editado"}}'::jsonb then
    raise exception 'FAIL F6.5: reordenar creó o tocó borradores'; end if;
  if (select array_agg(changed_columns) from guide.activity_log where action = 'update' and entity_table = 'articles'
      and entity_id = 'd0000000-0000-4000-8000-0000000000a3') <> array[array['sort_order']] then
    raise exception 'FAIL F6.5: actividad del reorden de artículos'; end if;
  -- mismo orden otra vez: no escribe nada (sin actividad de más)
  select count(*) into v_logs from guide.activity_log where entity_id like 'd0000000-0000-4000-8000-0000000000a%';
  perform guide.reorder_articles('c0000000-0000-4000-8000-0000000000a1',
    array['d0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2', 'd0000000-0000-4000-8000-0000000000a1']::uuid[]);
  if (select count(*) from guide.activity_log where entity_id like 'd0000000-0000-4000-8000-0000000000a%') <> v_logs then
    raise exception 'FAIL F6.5: reorden sin cambios registra actividad'; end if;
  -- el contenido de lo vivo sigue bloqueado en directo
  begin update guide.articles set title_es = 'hack' where id = 'd0000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL F6.5: lo vivo se edita en directo'; exception when sqlstate 'PT423' then null; end;

  -- 4. reorder_article_categories: lista completa (todas las categorías) sin duplicados
  select array_agg(id order by sort_order desc, id) into v_ids from guide.article_categories;
  begin perform guide.reorder_article_categories(v_ids[2:]);
    raise exception 'FAIL F6.5: reorder_article_categories incompleta';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'list must include every category' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_article_categories(v_ids[2:] || v_ids[2]);
    raise exception 'FAIL F6.5: reorder_article_categories duplicados'; exception when sqlstate '22023' then null; end;
  begin perform guide.reorder_article_categories(v_ids[2:] || 'c0000000-0000-4000-8000-0000000000ff'::uuid);
    raise exception 'FAIL F6.5: reorder_article_categories desconocida';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'unknown category' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_article_categories(null);
    raise exception 'FAIL F6.5: reorder_article_categories null'; exception when sqlstate '22023' then null; end;
  perform guide.reorder_article_categories(v_ids);
  if (select array_agg(id order by sort_order) from guide.article_categories) <> v_ids
     or (select array_agg(sort_order order by sort_order) from guide.article_categories)
        <> (select array_agg(g) from generate_series(1, cardinality(v_ids)) g) then
    raise exception 'FAIL F6.5: reorder_article_categories no ordenó 1..n'; end if;
  if not exists (select 1 from guide.activity_log where action = 'update' and entity_table = 'article_categories'
                 and entity_id = 'c0000000-0000-4000-8000-0000000000a3' and changed_columns = array['sort_order']) then
    raise exception 'FAIL F6.5: actividad del reorden de categorías'; end if;

  -- 5. delete_article_category: errores estables y sin efectos
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a1', 'c0000000-0000-4000-8000-0000000000a1');
    raise exception 'FAIL F6.5: reasigna a sí misma';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'target must differ' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000ff', null);
    raise exception 'FAIL F6.5: borra inexistente'; exception when sqlstate 'P0002' then null; end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a1', null);
    raise exception 'FAIL F6.5: borra con artículos sin destino';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'target required' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a4', null);
    raise exception 'FAIL F6.5: borra sin destino la categoría elegida por un borrador'; exception when sqlstate '22023' then null; end;
  begin perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a1', 'c0000000-0000-4000-8000-0000000000ff');
    raise exception 'FAIL F6.5: destino inexistente';
  exception when sqlstate '22023' then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'target category not found' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
  end;
  if (select count(*) from guide.article_categories where id::text like 'c0000000-0000-4000-8000-0000000000a%') <> 4 then
    raise exception 'FAIL F6.5: un borrado rechazado dejó efectos'; end if;

  -- 5b. Vacía sin destino: se borra (actividad 'delete' con foto) y sus 301 caen con ella
  update guide.article_categories set slug_es = 'rls-f65-vacia-2' where id = 'c0000000-0000-4000-8000-0000000000a3';
  perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a3', null);
  if exists (select 1 from guide.article_categories where id = 'c0000000-0000-4000-8000-0000000000a3')
     or guide.resolve_redirect('article_category', 'es', 'rls-f65-vacia') is not null then
    raise exception 'FAIL F6.5: borrar vacía sin destino'; end if;
  if not exists (select 1 from guide.activity_log where action = 'delete' and entity_table = 'article_categories'
                 and entity_id = 'c0000000-0000-4000-8000-0000000000a3' and old_row ->> 'slug_es' = 'rls-f65-vacia-2') then
    raise exception 'FAIL F6.5: borrar categoría sin actividad'; end if;

  -- 5c. a1 → a2 con publicados y borradores pendientes: al final de a2 en su orden, sin subir updated_at,
  --     borradores intactos y 301 de a1 (antiguas y actual) hacia a2. En: a2 no tiene versión en → sin destino.
  perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a1', 'c0000000-0000-4000-8000-0000000000a2');
  if (select array_agg(id order by sort_order) from guide.articles where category_id = 'c0000000-0000-4000-8000-0000000000a2')
     <> array['d0000000-0000-4000-8000-0000000000a4', 'd0000000-0000-4000-8000-0000000000a3', 'd0000000-0000-4000-8000-0000000000a2',
              'd0000000-0000-4000-8000-0000000000a1']::uuid[]
     or (select array_agg(sort_order order by sort_order) from guide.articles where category_id = 'c0000000-0000-4000-8000-0000000000a2') <> array[1, 2, 3, 4] then
    raise exception 'FAIL F6.5: reasignación (orden en el destino)'; end if;
  if exists (select 1 from guide.articles where id::text like 'd0000000-0000-4000-8000-0000000000a%'
             and updated_at <> now() - interval '1 hour')
     or (select count(*) from guide.articles where id in ('d0000000-0000-4000-8000-0000000000a1', 'd0000000-0000-4000-8000-0000000000a3')
         and status = 'published') <> 2 then
    raise exception 'FAIL F6.5: reasignar subió updated_at o despublicó'; end if;
  if guide.resolve_redirect('article_category', 'es', 'rls-f65-a') is distinct from 'rls-f65-b'
     or guide.resolve_redirect('article_category', 'es', 'rls-f65-a2') is distinct from 'rls-f65-b'
     or guide.resolve_redirect('article_category', 'en', 'rls-f65-a2-en') is not null then
    raise exception 'FAIL F6.5: 301 de la categoría borrada'; end if;
  if (select count(*) from guide.slug_redirects where kind = 'article_category' and article_category_id = 'c0000000-0000-4000-8000-0000000000a2'
      and old_slug in ('rls-f65-a', 'rls-f65-a2', 'rls-f65-a-en', 'rls-f65-a2-en')) <> 4 then
    raise exception 'FAIL F6.5: redirecciones no movidas al destino'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.5: delete_article_category deja el GUC abierto'; end if;
  -- el borrador pendiente se publica sin conflicto (la base no cambió)
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-0000000000a1');
  if (select title_es from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a1') <> 'F65 uno editado' then
    raise exception 'FAIL F6.5: publish_draft tras reordenar/reasignar'; end if;

  -- 5d. Borrar la categoría destino de un borrador pendiente: el borrador pasa a la de reasignación y publica
  select * into v_draft from guide.content_drafts where article_id = 'd0000000-0000-4000-8000-0000000000a3';
  perform guide.delete_article_category('c0000000-0000-4000-8000-0000000000a4', v_new);
  if (select payload #>> '{article,category_id}' from guide.content_drafts
      where article_id = 'd0000000-0000-4000-8000-0000000000a3') is distinct from v_new::text then
    raise exception 'FAIL F6.5: el borrador sigue apuntando a la categoría borrada'; end if;
  -- Excepción O6 (obs. 1): la reescritura DEFINER solo toca payload.category_id. base_updated_at intacto (si
  -- cambiara, publish_draft daría o taparía un PT409). updated_by no lo escribe la función: lo fuerza
  -- content_drafts_before_write a auth.uid() del admin que borra (aquí el mismo autor); nunca null ni ajeno.
  if not exists (select 1 from guide.content_drafts d where d.article_id = 'd0000000-0000-4000-8000-0000000000a3'
                 and d.base_updated_at = v_draft.base_updated_at
                 and d.updated_by = 'a0000000-0000-4000-8000-000000000001'
                 and d.updated_by = v_draft.updated_by
                 and d.created_at = v_draft.created_at
                 and d.payload = jsonb_set(v_draft.payload, '{article,category_id}', to_jsonb(v_new))) then
    raise exception 'FAIL F6.5 O6: la reescritura del borrador tocó algo más que payload.category_id'; end if;
  perform guide.publish_draft('article', 'd0000000-0000-4000-8000-0000000000a3');
  if (select category_id from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a3') is distinct from v_new then
    raise exception 'FAIL F6.5: publicar el borrador reescrito'; end if;
  if guide.resolve_redirect('article_category', 'es', 'rls-f65-destino') is distinct from 'rls-f65-nueva' then
    raise exception 'FAIL F6.5: 301 de la categoría destino borrada'; end if;
  -- crear una categoría con un slug redirigido lo libera (la 301 desaparece)
  insert into guide.article_categories (name_es, slug_es) values ('F65 reusa', 'rls-f65-destino');
  if guide.resolve_redirect('article_category', 'es', 'rls-f65-destino') is not null then
    raise exception 'FAIL F6.5: el slug reutilizado sigue redirigiendo'; end if;

  -- B7c (obs. 2). GUC de reasignación atada a la categoría: 'reassign_category:<p_id>' solo exime a artículos
  -- con old.category_id = p_id. Aquí d…a1 (vivo) y los borradores d…a2 y d…a4 (updated_at = now() - 1 h) están en a2.
  perform set_config('guide.draft_op', 'reassign_category', true);  -- sin id (valor antiguo)
  begin update guide.articles set category_id = v_new where id = 'd0000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL F6.5 B7c: reassign_category sin id mueve un vivo'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.draft_op', 'reassign_category:' || v_new::text, true);  -- otra categoría
  begin update guide.articles set category_id = v_new where id = 'd0000000-0000-4000-8000-0000000000a1';
    raise exception 'FAIL F6.5 B7c: reassign_category de otra categoría mueve un vivo'; exception when sqlstate 'PT423' then null; end;
  -- no vivo con la GUC de otra categoría: se mueve, pero updated_at sí sube (es una edición)
  update guide.articles set category_id = v_new where id = 'd0000000-0000-4000-8000-0000000000a2';
  if (select updated_at from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a2') <> now() then
    raise exception 'FAIL F6.5 B7c: GUC de otra categoría no sube updated_at'; end if;
  -- control: con la categoría correcta sí exime (no vivo sin subir updated_at; vivo sin PT423)
  perform set_config('guide.draft_op', 'reassign_category:c0000000-0000-4000-8000-0000000000a2', true);
  update guide.articles set category_id = v_new where id = 'd0000000-0000-4000-8000-0000000000a4';
  if (select updated_at from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a4') <> now() - interval '1 hour' then
    raise exception 'FAIL F6.5 B7c: la GUC atada correcta dejó de eximir updated_at'; end if;
  update guide.articles set category_id = v_new where id = 'd0000000-0000-4000-8000-0000000000a1';
  if (select category_id from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a1') is distinct from v_new then
    raise exception 'FAIL F6.5 B7c: la GUC atada correcta dejó de eximir el PT423'; end if;
  -- sin id, sobre el mismo no vivo (ahora en v_new, aún a -1 h): updated_at sube
  perform set_config('guide.draft_op', 'reassign_category', true);
  update guide.articles set category_id = 'c0000000-0000-4000-8000-0000000000a2' where id = 'd0000000-0000-4000-8000-0000000000a4';
  if (select updated_at from guide.articles where id = 'd0000000-0000-4000-8000-0000000000a4') <> now() then
    raise exception 'FAIL F6.5 B7c: GUC sin id no sube updated_at'; end if;
  perform set_config('guide.draft_op', '', true);
end $$;
reset role;

-- 6. Última categoría (P1): nunca se borra. Subtransacción: como postgres (mantenimiento) se deja una sola
--    categoría y el admin intenta borrarla; después se deshace todo.
do $$
declare
  v_last uuid := 'c0000000-0000-4000-8000-0000000000a2';
  v_msg  text;
begin
  begin
    perform set_config('guide.draft_op', 'maintenance', true);
    delete from guide.articles where category_id <> v_last;
    delete from guide.article_categories where id <> v_last;
    perform set_config('guide.draft_op', '', true);
    perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
    set local role authenticated;
    begin perform guide.delete_article_category(v_last, null);
      raise exception 'FAIL F6.5: borra la última categoría';
    exception when sqlstate '22023' then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'cannot delete the last category' then raise exception 'FAIL F6.5: mensaje (%)', v_msg; end if;
    end;
    reset role;
    raise exception 'F65_UNDO';
  exception when raise_exception then
    get stacked diagnostics v_msg = message_text;
    if v_msg <> 'F65_UNDO' then raise exception '%', v_msg; end if;
  end;
  if (select count(*) from guide.article_categories where id::text like 'c0000000-0000-4000-8000-0000000000a%') <> 1 then
    raise exception 'FAIL F6.5: la subtransacción de la última categoría no se deshizo'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
select set_config('guide.draft_op', '', true);

-- ═════════════ F6.6: biblioteca de medios (subir, reemplazar, borrar con usos, buscador) ═════════════
-- Fixtures (como postgres). Objetos con metadatos como los deja la API de Storage.
--   b6…01 sin usar · b6…02 portada de una ficha oculta · b6…03 solo pegado (URL, sin data-media-id) en el
--   HTML de un artículo borrador · b6…13 objeto huérfano antiguo (sin fila).
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata, created_at) values
  ('media', 'b6000000-0000-4000-8000-000000000001/1-libre.jpg', '{"mimetype":"image/jpeg","size":1200}', now()),
  ('media', 'b6000000-0000-4000-8000-000000000002/1-oculta.png', '{"mimetype":"image/png","size":1300}', now()),
  ('media', 'b6000000-0000-4000-8000-000000000003/1-pegada.webp', '{"mimetype":"image/webp","size":1400}', now()),
  ('media', 'b6000000-0000-4000-8000-000000000013/1-huerfano.jpg', '{"mimetype":"image/jpeg","size":1500}', now() - interval '2 hours');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es) values
  ('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000001/1-libre.jpg', 'libre.jpg', 'image/jpeg', 1, 10, 10, 'Pared libre'),
  ('b6000000-0000-4000-8000-000000000002', 'b6000000-0000-4000-8000-000000000002/1-oculta.png', 'oculta.png', 'image/png', 1, 10, 10, null),
  ('b6000000-0000-4000-8000-000000000003', 'b6000000-0000-4000-8000-000000000003/1-pegada.webp', 'pegada.webp', 'image/webp', 1, 10, 10, null);
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f6000000-0000-4000-8000-000000000001', 'gym', 'Gym F66 oculto', 'rls-f66-oculto', false, 'b6000000-0000-4000-8000-000000000002');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, body_html_es) values
  ('d6000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'draft', null, 'F66 borrador', 'rls-f66-borrador',
   '<p>x</p><img src="https://eqtjlafxtrzbjazhhyin.supabase.co/storage/v1/object/public/media/b6000000-0000-4000-8000-000000000003/1-pegada.webp" alt="">');
select set_config('guide.draft_op', '', true);

do $$
begin
  -- El trigger toma mime/size del objeto (la fila declaraba 1 byte)
  if (select size_bytes from guide.media where id = 'b6000000-0000-4000-8000-000000000001') <> 1200 then
    raise exception 'FAIL F6.6: size_bytes no sale de los metadatos del objeto'; end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'avatar upload') then
    raise exception 'FAIL F6.6: se tocaron las policies de avatars'; end if;
  if exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'guide media admin update') then
    raise exception 'FAIL F6.6: sigue existiendo UPDATE en Storage (sobrescritura)'; end if;
  if exists (select 1 from information_schema.routine_privileges
             where routine_schema = 'guide' and grantee in ('anon', 'PUBLIC')
               and routine_name in ('create_media', 'replace_media', 'delete_media', 'media_usages', 'search_media',
                                    'media_stats', 'media_storage_orphans', 'media_object_insertable', 'media_object_deletable')) then
    raise exception 'LEAK F6.6: RPC de medios ejecutable por anon/PUBLIC'; end if;
end $$;

-- anon: solo filas de medios usados por contenido visible; nada de RPC ni Storage
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if exists (select 1 from guide.media where id::text like 'b6000000-%') then
    raise exception 'LEAK anon F6.6: ve medios sin uso público (sin usar, ficha oculta, borrador)'; end if;
  if not exists (select 1 from guide.media where id = 'b0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL anon F6.6: no ve la portada del artículo publicado'; end if;
  begin perform guide.search_media('libre'); raise exception 'LEAK anon F6.6: search_media'; exception when insufficient_privilege then null; end;
  begin perform guide.media_usages('b6000000-0000-4000-8000-000000000002'); raise exception 'LEAK anon F6.6: media_usages'; exception when insufficient_privilege then null; end;
  begin perform guide.media_stats(); raise exception 'LEAK anon F6.6: media_stats'; exception when insufficient_privilege then null; end;
  begin perform guide.media_storage_orphans(5); raise exception 'LEAK anon F6.6: media_storage_orphans'; exception when insufficient_privilege then null; end;
  begin perform guide.delete_media('b6000000-0000-4000-8000-000000000001', 1); raise exception 'LEAK anon F6.6: delete_media'; exception when insufficient_privilege then null; end;
  begin perform guide.create_media('b6000000-0000-4000-8000-000000000020', 'b6000000-0000-4000-8000-000000000020/1-x.jpg', 'x.jpg', 1, 1);
    raise exception 'LEAK anon F6.6: create_media'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata)
      values ('media', 'b6000000-0000-4000-8000-000000000020/1-x.jpg', '{"mimetype":"image/jpeg","size":1}');
    raise exception 'LEAK anon F6.6: sube a una ruta válida'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- no admin y JWT forjado
do $$
declare
  v_claims text;
  v_n integer;
begin
  foreach v_claims in array array[
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}',
    '{"sub":"a0000000-0000-4000-8000-000000000002","role":"service_role","app_metadata":{"role":"admin"},"user_metadata":{"is_admin":true}}'] loop
    perform set_config('request.jwt.claims', v_claims, true);
    set local role authenticated;
    if exists (select 1 from guide.media where id::text like 'b6000000-%') then
      raise exception 'LEAK user F6.6: ve medios sin uso público (%)', v_claims; end if;
    begin perform guide.search_media(null); raise exception 'LEAK user F6.6: search_media'; exception when insufficient_privilege then null; end;
    begin perform guide.media_usages('b6000000-0000-4000-8000-000000000002'); raise exception 'LEAK user F6.6: media_usages'; exception when insufficient_privilege then null; end;
    begin perform guide.media_stats(); raise exception 'LEAK user F6.6: media_stats'; exception when insufficient_privilege then null; end;
    begin perform guide.media_storage_orphans(5); raise exception 'LEAK user F6.6: orphans'; exception when insufficient_privilege then null; end;
    -- 42501 antes que P0002: no filtra si el medio existe
    begin perform guide.delete_media('b6000000-0000-4000-8000-0000000000ff', 1); raise exception 'LEAK user F6.6: delete_media inexistente'; exception when insufficient_privilege then null; end;
    begin perform guide.delete_media('b6000000-0000-4000-8000-000000000001', 1); raise exception 'LEAK user F6.6: delete_media'; exception when insufficient_privilege then null; end;
    begin perform guide.replace_media('b6000000-0000-4000-8000-000000000001', 1, 'b6000000-0000-4000-8000-000000000001/2-x.jpg', 'x.jpg', 1, 1);
      raise exception 'LEAK user F6.6: replace_media'; exception when insufficient_privilege then null; end;
    begin perform guide.create_media('b6000000-0000-4000-8000-000000000001', 'b6000000-0000-4000-8000-000000000001/1-libre.jpg', 'x.jpg', 1, 1);
      raise exception 'LEAK user F6.6: create_media'; exception when insufficient_privilege then null; end;
    -- Insert directo sobre un objeto existente: el trigger corta con 42501 (no revela si el objeto existe)
    begin insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes)
        values ('b6000000-0000-4000-8000-000000000013', 'b6000000-0000-4000-8000-000000000013/1-huerfano.jpg', 'h.jpg', 'image/jpeg', 1);
      raise exception 'LEAK user F6.6: INSERT directo en media'; exception when insufficient_privilege then null; end;
    update guide.media set alt_es = 'hack' where id::text like 'b%';
    get diagnostics v_n = row_count;
    if v_n <> 0 then raise exception 'LEAK user F6.6: UPDATE de media'; end if;
    begin insert into storage.objects (bucket_id, name, metadata)
        values ('media', 'b6000000-0000-4000-8000-000000000021/1-x.jpg', '{"mimetype":"image/jpeg","size":1}');
      raise exception 'LEAK user F6.6: sube a media'; exception when insufficient_privilege then null; end;
    perform set_config('storage.allow_delete_query', 'true', true);
    delete from storage.objects where bucket_id = 'media';
    get diagnostics v_n = row_count;
    perform set_config('storage.allow_delete_query', 'false', true);
    if v_n <> 0 then raise exception 'LEAK user F6.6: borra objetos de media'; end if;
    reset role;
  end loop;
end $$;
select set_config('request.jwt.claims', '{}', true);

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_row  guide.media%rowtype;
  v_n    integer;
  v_old  text;
  v_path text;
  v_cnt  bigint;
begin
  -- 1. Storage INSERT: solo rutas de la convención, versión 1 para id nuevo o version + 1 para uno existente
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', '../b6000000-0000-4000-8000-000000000010/1-x.jpg', '{}');
    raise exception 'FAIL admin F6.6: ruta con ../'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000010/../1-x.jpg', '{}');
    raise exception 'FAIL admin F6.6: ruta con /../'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'B6000000-0000-4000-8000-000000000010/1-X.jpg', '{}');
    raise exception 'FAIL admin F6.6: ruta en mayúsculas'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000010/1-x.svg', '{}');
    raise exception 'FAIL admin F6.6: extensión svg'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000010/2-x.jpg', '{}');
    raise exception 'FAIL admin F6.6: versión 2 de un id nuevo'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000001/1-otra.jpg', '{}');
    raise exception 'FAIL admin F6.6: versión vigente de un id existente'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000001/3-salto.jpg', '{}');
    raise exception 'FAIL admin F6.6: salto de versión'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', '2026/b6000000-0000-4000-8000-000000000010.jpg', '{}');
    raise exception 'FAIL admin F6.6: ruta fuera de convención'; exception when insufficient_privilege then null; end;
  -- Sin UPDATE en Storage: nada se sobrescribe ni se mueve
  update storage.objects set name = name || '-x' where bucket_id = 'media';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'FAIL admin F6.6: modifica objetos (sobrescritura)'; end if;

  -- 2. Subida: objeto (como la API) y alta con create_media
  insert into storage.objects (bucket_id, name, metadata)
  values ('media', 'b6000000-0000-4000-8000-000000000010/1-nueva-foto.webp', '{"mimetype":"image/webp","size":2048}');
  select * into v_row from guide.create_media('b6000000-0000-4000-8000-000000000010',
    'b6000000-0000-4000-8000-000000000010/1-nueva-foto.webp', E' Nueva\tFoto.webp ', 800, 600, '#AABBCC', '  Escaladora  ', '', null, null, 'Xavi');
  if v_row.mime_type <> 'image/webp' or v_row.size_bytes <> 2048 or v_row.version <> 1 or v_row.dominant_color <> '#aabbcc'
     or v_row.alt_es <> 'Escaladora' or v_row.alt_en is not null or v_row.original_filename <> 'Nueva Foto.webp' then
    raise exception 'FAIL admin F6.6: create_media no normaliza (%)', row_to_json(v_row); end if;
  if not exists (select 1 from guide.activity_log where entity_table = 'media' and entity_id = 'b6000000-0000-4000-8000-000000000010' and action = 'insert') then
    raise exception 'FAIL admin F6.6: alta sin registro de actividad'; end if;
  -- Reintento del alta ya hecha → 23505
  begin perform guide.create_media('b6000000-0000-4000-8000-000000000010', 'b6000000-0000-4000-8000-000000000010/1-nueva-foto.webp', 'x', 1, 1);
    raise exception 'FAIL admin F6.6: alta duplicada'; exception when unique_violation then null; end;
  -- Sin objeto → 22023; ruta de otro id → 22023; mime del objeto ≠ extensión → 23514
  begin perform guide.create_media('b6000000-0000-4000-8000-000000000011', 'b6000000-0000-4000-8000-000000000011/1-x.jpg', 'x.jpg', 1, 1);
    raise exception 'FAIL admin F6.6: alta sin objeto'; exception when invalid_parameter_value then null; end;
  begin perform guide.create_media('b6000000-0000-4000-8000-000000000011', 'b6000000-0000-4000-8000-000000000001/1-libre.jpg', 'x.jpg', 1, 1);
    raise exception 'FAIL admin F6.6: alta con la ruta de otro medio'; exception when invalid_parameter_value then null; end;
  insert into storage.objects (bucket_id, name, metadata)
  values ('media', 'b6000000-0000-4000-8000-000000000011/1-disfraz.jpg', '{"mimetype":"image/png","size":10}');
  begin perform guide.create_media('b6000000-0000-4000-8000-000000000011', 'b6000000-0000-4000-8000-000000000011/1-disfraz.jpg', 'x.jpg', 1, 1);
    raise exception 'FAIL admin F6.6: mime del objeto distinto de la extensión'; exception when check_violation then null; end;
  -- Insert directo: mime/size declarados se ignoran (salen del objeto)
  insert into storage.objects (bucket_id, name, metadata)
  values ('media', 'b6000000-0000-4000-8000-000000000012/1-directo.jpg', '{"mimetype":"image/jpeg","size":3333}');
  insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes)
  values ('b6000000-0000-4000-8000-000000000012', 'b6000000-0000-4000-8000-000000000012/1-directo.jpg', 'directo.jpg', 'image/gif', 9);
  if not exists (select 1 from guide.media where id = 'b6000000-0000-4000-8000-000000000012' and mime_type = 'image/jpeg' and size_bytes = 3333) then
    raise exception 'FAIL admin F6.6: el insert directo se fía del mime/size del cliente'; end if;

  -- 3. Metadatos editables; archivo solo con objeto nuevo
  update guide.media set alt_en = 'Climber', credit = 'X' where id = 'b6000000-0000-4000-8000-000000000010';
  begin update guide.media set version = 2 where id = 'b6000000-0000-4000-8000-000000000010';
    raise exception 'FAIL admin F6.6: sube versión sin objeto'; exception when invalid_parameter_value then null; end;
  begin update guide.media set size_bytes = 1 where id = 'b6000000-0000-4000-8000-000000000010';
    raise exception 'FAIL admin F6.6: cambia size_bytes a mano'; exception when invalid_parameter_value then null; end;
  begin update guide.media set id = 'b6000000-0000-4000-8000-0000000000ee' where id = 'b6000000-0000-4000-8000-000000000010';
    raise exception 'FAIL admin F6.6: cambia el id'; exception when invalid_parameter_value then null; end;

  -- 4. Reemplazo: objeto nuevo v2 → replace_media (conflicto de versión, ruta inválida, ok)
  insert into storage.objects (bucket_id, name, metadata)
  values ('media', 'b6000000-0000-4000-8000-000000000010/2-otra.jpg', '{"mimetype":"image/jpeg","size":3000}');
  begin perform guide.replace_media('b6000000-0000-4000-8000-000000000010', 2, 'b6000000-0000-4000-8000-000000000010/2-otra.jpg', 'otra.jpg', 1024, 768);
    raise exception 'FAIL admin F6.6: replace con versión vieja'; exception when sqlstate 'PT409' then null; end;
  begin perform guide.replace_media('b6000000-0000-4000-8000-000000000010', 1, 'b6000000-0000-4000-8000-000000000010/3-otra.jpg', 'otra.jpg', 1024, 768);
    raise exception 'FAIL admin F6.6: replace con versión saltada'; exception when invalid_parameter_value then null; end;
  begin perform guide.replace_media('b6000000-0000-4000-8000-0000000000ff', 1, 'b6000000-0000-4000-8000-0000000000ff/2-x.jpg', 'x.jpg', 1, 1);
    raise exception 'FAIL admin F6.6: replace de inexistente'; exception when no_data_found then null; end;
  select r.previous_storage_path into v_old
  from guide.replace_media('b6000000-0000-4000-8000-000000000010', 1, 'b6000000-0000-4000-8000-000000000010/2-otra.jpg', 'otra.jpg', 1024, 768, null) r;
  if v_old <> 'b6000000-0000-4000-8000-000000000010/1-nueva-foto.webp' then
    raise exception 'FAIL admin F6.6: replace no devuelve la ruta anterior'; end if;
  if not exists (select 1 from guide.media where id = 'b6000000-0000-4000-8000-000000000010' and version = 2
                 and mime_type = 'image/jpeg' and size_bytes = 3000 and width = 1024 and alt_es = 'Escaladora' and dominant_color is null) then
    raise exception 'FAIL admin F6.6: replace no deja la fila coherente con el objeto nuevo'; end if;
  if not exists (select 1 from guide.activity_log where entity_table = 'media' and entity_id = 'b6000000-0000-4000-8000-000000000010'
                 and action = 'update' and changed_columns @> array['storage_path', 'version']) then
    raise exception 'FAIL admin F6.6: reemplazo sin registro de actividad'; end if;
  -- La v2 ya es vigente: no se vuelve a subir encima; el objeto viejo sí se borra, el vigente no
  begin insert into storage.objects (bucket_id, name, metadata) values ('media', 'b6000000-0000-4000-8000-000000000010/2-dup.jpg', '{}');
    raise exception 'FAIL admin F6.6: sube otra v2'; exception when insufficient_privilege then null; end;
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'media' and name = 'b6000000-0000-4000-8000-000000000010/2-otra.jpg';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'FAIL admin F6.6: borra el objeto vigente de una fila'; end if;
  delete from storage.objects where bucket_id = 'media' and name = v_old;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL admin F6.6: no borra el objeto de la versión anterior'; end if;
  perform set_config('storage.allow_delete_query', 'false', true);

  -- 5. Usos
  if not exists (select 1 from guide.media_usages('b0000000-0000-4000-8000-000000000001')
                 where owner_table = 'articles' and owner_id = 'd0000000-0000-4000-8000-000000000001' and role = 'cover') then
    raise exception 'FAIL admin F6.6: media_usages no ve la portada'; end if;
  if not exists (select 1 from guide.media_usages('b6000000-0000-4000-8000-000000000002')
                 where owner_table = 'items' and item_category = 'gym' and role = 'cover') then
    raise exception 'FAIL admin F6.6: media_usages no ve la portada de la ficha'; end if;
  if not exists (select 1 from guide.media_usages('b6000000-0000-4000-8000-000000000003')
                 where owner_table = 'articles' and owner_id = 'd6000000-0000-4000-8000-000000000001' and role = 'body_es') then
    raise exception 'FAIL admin F6.6: media_usages no ve la imagen pegada sin data-media-id'; end if;
  if exists (select 1 from guide.media_usages('b6000000-0000-4000-8000-000000000001')) then
    raise exception 'FAIL admin F6.6: usos inventados'; end if;

  -- 6. Borrado: en uso → 23503 (RPC y directo); versión vieja → PT409; inexistente → P0002; libre → ok + actividad
  begin perform guide.delete_media('b0000000-0000-4000-8000-000000000001', 1);
    raise exception 'FAIL admin F6.6: borra una portada'; exception when foreign_key_violation then null; end;
  begin perform guide.delete_media('b6000000-0000-4000-8000-000000000003', 1);
    raise exception 'FAIL admin F6.6: borra una imagen pegada en un cuerpo'; exception when foreign_key_violation then null; end;
  begin delete from guide.media where id = 'b6000000-0000-4000-8000-000000000003';
    raise exception 'FAIL admin F6.6: DELETE directo de una imagen pegada'; exception when foreign_key_violation then null; end;
  begin perform guide.delete_media('b6000000-0000-4000-8000-000000000001', 2);
    raise exception 'FAIL admin F6.6: borra con versión vieja'; exception when sqlstate 'PT409' then null; end;
  begin perform guide.delete_media('b6000000-0000-4000-8000-0000000000ff', 1);
    raise exception 'FAIL admin F6.6: borra inexistente'; exception when no_data_found then null; end;
  v_path := guide.delete_media('b6000000-0000-4000-8000-000000000001', 1);
  if v_path <> 'b6000000-0000-4000-8000-000000000001/1-libre.jpg'
     or exists (select 1 from guide.media where id = 'b6000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL admin F6.6: delete_media'; end if;
  if not exists (select 1 from guide.activity_log where entity_table = 'media' and entity_id = 'b6000000-0000-4000-8000-000000000001'
                 and action = 'delete' and old_row ->> 'storage_path' = v_path) then
    raise exception 'FAIL admin F6.6: borrado sin registro (con foto de la fila)'; end if;
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'media' and name = v_path;
  get diagnostics v_n = row_count;
  perform set_config('storage.allow_delete_query', 'false', true);
  if v_n <> 1 then raise exception 'FAIL admin F6.6: no borra el objeto tras borrar la fila'; end if;

  -- 7. Buscador: nombre, alt, crédito; sin acentos; comodines literales; filtros; paginación
  if not exists (select 1 from guide.search_media('OTRA') where id = 'b6000000-0000-4000-8000-000000000010') then
    raise exception 'FAIL admin F6.6: no busca por nombre de archivo'; end if;
  if not exists (select 1 from guide.search_media('escaladóra climber') where id = 'b6000000-0000-4000-8000-000000000010') then
    raise exception 'FAIL admin F6.6: no busca por alt es+en sin acentos'; end if;
  -- '_' y '%' son literales (con comodines, 'otr_' y 'o%a' casarían con 'otra.jpg')
  if exists (select 1 from guide.search_media('otr_') where id = 'b6000000-0000-4000-8000-000000000010')
     or exists (select 1 from guide.search_media('o%a') where id = 'b6000000-0000-4000-8000-000000000010')
     or exists (select 1 from guide.search_media('a,or(id.eq.b6000000-0000-4000-8000-000000000010)')) then
    raise exception 'FAIL admin F6.6: comodines o filtros PostgREST interpretados en la búsqueda'; end if;
  if exists (select 1 from guide.search_media(null, 'unused') where id = 'b0000000-0000-4000-8000-000000000001')
     or not exists (select 1 from guide.search_media(null, 'unused') where id = 'b6000000-0000-4000-8000-000000000010')
     or not exists (select 1 from guide.search_media(null, 'in_use') where id = 'b6000000-0000-4000-8000-000000000003' and usage_count = 1)
     or not exists (select 1 from guide.search_media(null, 'missing_alt') where id = 'b6000000-0000-4000-8000-000000000002') then
    raise exception 'FAIL admin F6.6: filtros del buscador'; end if;
  begin perform guide.search_media(null, 'todo'); raise exception 'FAIL admin F6.6: filtro desconocido'; exception when invalid_parameter_value then null; end;
  begin perform guide.search_media(repeat('a', 201)); raise exception 'FAIL admin F6.6: consulta larga'; exception when invalid_parameter_value then null; end;
  select count(*), max(total_count) into v_n, v_cnt from guide.search_media(null, 'all', 1, 0);
  if v_n <> 1 or v_cnt < 4 then raise exception 'FAIL admin F6.6: paginación/total (% / %)', v_n, v_cnt; end if;
  if (select count(*) from guide.search_media(null, 'all', 100000, 0)) > 100 then raise exception 'FAIL admin F6.6: límite sin tope'; end if;

  -- 8. Estadísticas y huérfanos
  if (select total_count from guide.media_stats()) <> (select count(*) from guide.media)
     or (select storage_bytes from guide.media_stats()) <= 0 then
    raise exception 'FAIL admin F6.6: media_stats'; end if;
  if not exists (select 1 from guide.media_storage_orphans(60)
                 where kind = 'object_without_row' and storage_path = 'b6000000-0000-4000-8000-000000000013/1-huerfano.jpg') then
    raise exception 'FAIL admin F6.6: no lista el objeto huérfano'; end if;
  if exists (select 1 from guide.media_storage_orphans(60) where storage_path like 'b6000000-0000-4000-8000-000000000011/%') then
    raise exception 'FAIL admin F6.6: lista como huérfana una subida reciente'; end if;
  if exists (select 1 from guide.media_storage_orphans(60) where kind = 'row_without_object') then
    raise exception 'FAIL admin F6.6: filas sin objeto'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
select set_config('storage.allow_delete_query', '', true);

-- ═════════════ D27: texto alternativo obligatorio para publicar ═════════════
-- Fixtures (como postgres, mantenimiento explícito). Medios b27…: 01 y 09 con alt; el resto sin alt_es.
--   02 portada · 03 cuerpo JSON · 04 cuerpo HTML (data-media-id) · 05 galería · 06 OG de página
--   07 cuerpo de reseña · 08 pegado por URL · 10 cuerpo EN
-- d27…05 publicado conforme (portada 09, con versión EN: has_en es generada) · d27…07 y f27…04 publicados "heredados" sin alt (portada 02).
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b2700000-0000-4000-8000-0000000000%s/1-d27.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','02','03','04','05','06','07','08','09','10']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es, alt_en)
select format('b2700000-0000-4000-8000-0000000000%s', n)::uuid, format('b2700000-0000-4000-8000-0000000000%s/1-d27.jpg', n),
       'd27.jpg', 'image/jpeg', 1, 10, 10,
       case n when '01' then 'Pared con presas' when '09' then 'Escaladora en el techo' end,
       case n when '01' then 'Wall with holds' end
from unnest(array['01','02','03','04','05','06','07','08','09','10']) n;
insert into guide.article_categories (id, name_es, slug_es) values ('c2700000-0000-4000-8000-000000000001', 'Cat D27', 'rls-d27-cat');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, cover_media_id, title_en, slug_en,
                            body_json_es, body_html_es, body_json_en, body_html_en) values
  ('d2700000-0000-4000-8000-000000000001', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D27 portada', 'rls-d27-1',
   'b2700000-0000-4000-8000-000000000002', null, null, '{"type":"doc","content":[]}', '', null, null),
  ('d2700000-0000-4000-8000-000000000002', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D27 json', 'rls-d27-2', null, null, null,
   '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2700000-0000-4000-8000-000000000003"}}]}', '<p>x</p>', null, null),
  ('d2700000-0000-4000-8000-000000000003', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D27 html', 'rls-d27-3', null, null, null,
   '{"type":"doc","content":[]}', '<p>x</p><img src="x.jpg" DATA-MEDIA-ID=''B2700000-0000-4000-8000-000000000004'' alt="">', null, null),
  ('d2700000-0000-4000-8000-000000000004', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D27 en', 'rls-d27-4', null, null, null,
   '{"type":"doc","content":[]}', '<p>x</p>', '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2700000-0000-4000-8000-000000000010"}}]}', '<p>x</p>'),
  ('d2700000-0000-4000-8000-000000000005', 'c2700000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'D27 vivo', 'rls-d27-5',
   'b2700000-0000-4000-8000-000000000009', 'D27 live', 'rls-d27-5-en', '{"type":"doc","content":[]}', '<p>x</p>', '{"type":"doc","content":[]}', '<p>x</p>'),
  ('d2700000-0000-4000-8000-000000000006', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D27 pegada', 'rls-d27-6', null, null, null,
   '{"type":"doc","content":[]}', '<img src="https://eqtjlafxtrzbjazhhyin.supabase.co/storage/v1/object/public/media/b2700000-0000-4000-8000-000000000008/1-d27.jpg" alt="">', null, null),
  ('d2700000-0000-4000-8000-000000000007', 'c2700000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'D27 heredado', 'rls-d27-7',
   'b2700000-0000-4000-8000-000000000002', null, null, '{"type":"doc","content":[]}', '<p>x</p>', null, null);
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f2700000-0000-4000-8000-000000000001', 'gym', 'D27 galería', 'rls-d27-galeria', false, 'b2700000-0000-4000-8000-000000000001'),
  ('f2700000-0000-4000-8000-000000000002', 'gym', 'D27 publicada', 'rls-d27-publicada', true, 'b2700000-0000-4000-8000-000000000001'),
  ('f2700000-0000-4000-8000-000000000003', 'gym', 'D27 reseña', 'rls-d27-resena', false, 'b2700000-0000-4000-8000-000000000001'),
  ('f2700000-0000-4000-8000-000000000004', 'gym', 'D27 heredada', 'rls-d27-heredada', true, 'b2700000-0000-4000-8000-000000000002');
-- F6.15b: f27…01 y …03 se publican en el paso 9 sin mantenimiento → portada con alt (01) y city (items_z_publish_ready).
insert into guide.gyms (item_id, city)
select i, 'Barcelona' from unnest(array['f2700000-0000-4000-8000-000000000001', 'f2700000-0000-4000-8000-000000000002',
                                        'f2700000-0000-4000-8000-000000000003', 'f2700000-0000-4000-8000-000000000004']::uuid[]) i;
insert into guide.item_media (item_id, media_id, sort_order) values
  ('f2700000-0000-4000-8000-000000000001', 'b2700000-0000-4000-8000-000000000005', 1);
insert into guide.author_reviews (item_id, category, body_json_es, body_html_es) values
  ('f2700000-0000-4000-8000-000000000003', 'gym',
   '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2700000-0000-4000-8000-000000000007"}}]}', '<p>x</p>');
insert into guide.pages (id, key, title_es, slug_es, published, og_media_id) values
  ('e2700000-0000-4000-8000-000000000001', 'transparency', 'Página D27', 'rls-d27-pagina', false, 'b2700000-0000-4000-8000-000000000006');
select set_config('guide.draft_op', '', true);

-- Espera PT422 con el contrato estable: message, detail JSON {entity, entity_id, media_ids} y hint.
create or replace function pg_temp.d27_expect(p_sql text, p_entity text, p_entity_id uuid, p_ids uuid[], p_case text)
returns jsonb
language plpgsql
as $$
declare
  v_msg text; v_det text; v_hint text; v_j jsonb;
begin
  begin
    execute p_sql;
  exception when sqlstate 'PT422' then
    get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail, v_hint = pg_exception_hint;
    v_j := v_det::jsonb;
    if v_msg <> 'missing alt text' or v_hint not like '%alt_es%'
       or v_j ->> 'entity' is distinct from p_entity or (v_j ->> 'entity_id')::uuid is distinct from p_entity_id
       or (select array_agg(x::uuid order by x::uuid) from jsonb_array_elements_text(v_j -> 'media_ids') x)
          is distinct from (select array_agg(x order by x) from unnest(p_ids) x) then
      raise exception 'FAIL D27 %: error no estable (% / %)', p_case, v_msg, v_det;
    end if;
    return v_j;
  end;
  raise exception 'FAIL D27 %: no exige alt_es', p_case;
end;
$$;

-- anon y no admin: ni el chequeo del panel ni los helpers
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.content_alt_check('article', 'd2700000-0000-4000-8000-000000000001');
    raise exception 'LEAK anon D27: content_alt_check'; exception when insufficient_privilege then null; end;
  begin perform guide.media_committed_owners('b2700000-0000-4000-8000-000000000009');
    raise exception 'LEAK anon D27: media_committed_owners'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  begin perform guide.content_alt_check('article', 'd2700000-0000-4000-8000-000000000001');
    raise exception 'LEAK user D27: content_alt_check sin ser admin'; exception when insufficient_privilege then null; end;
  -- No admin: ni vacía alts ni publica (RLS: 0 filas o sin privilegio)
  begin update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000009';
  exception when insufficient_privilege then null; end;
  begin update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000001';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$
begin
  if (select alt_es from guide.media where id = 'b2700000-0000-4000-8000-000000000009') is null
     or (select status::text from guide.articles where id = 'd2700000-0000-4000-8000-000000000001') <> 'draft' then
    raise exception 'LEAK user D27: un no admin cambió medios o artículos'; end if;
  if exists (select 1 from information_schema.routine_privileges
             where routine_schema = 'guide' and grantee in ('anon', 'PUBLIC')
               and routine_name in ('content_alt_check', 'entity_missing_alt', 'media_committed_owners', 'body_media_ids',
                                    'content_alt_media_ids', 'item_alt_media_ids', 'media_missing_alt', 'raise_missing_alt',
                                    'alt_guard_bypassed', 'articles_require_alt', 'media_require_alt')) then
    raise exception 'LEAK D27: funciones ejecutables por anon/PUBLIC'; end if;
end $$;


-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_j jsonb;
begin
  -- 1. Artículos: publicar o programar con portada / OG / cuerpo JSON / data-media-id / URL pegada sin alt → PT422
  perform pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000001'$q$,
    'article', 'd2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000002']::uuid[], '1a portada');
  perform pg_temp.d27_expect($q$update guide.articles set status = 'scheduled', published_at = now() + interval '1 day'
                                where id = 'd2700000-0000-4000-8000-000000000001'$q$,
    'article', 'd2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000002']::uuid[], '1b programar');
  perform pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000002'$q$,
    'article', 'd2700000-0000-4000-8000-000000000002', array['b2700000-0000-4000-8000-000000000003']::uuid[], '1c cuerpo JSON');
  perform pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000003'$q$,
    'article', 'd2700000-0000-4000-8000-000000000003', array['b2700000-0000-4000-8000-000000000004']::uuid[], '1d data-media-id');
  perform pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000006'$q$,
    'article', 'd2700000-0000-4000-8000-000000000006', array['b2700000-0000-4000-8000-000000000008']::uuid[], '1e URL pegada');
  perform pg_temp.d27_expect($q$insert into guide.articles (id, category_id, status, title_es, slug_es, og_media_id, cover_media_id)
                                values ('d2700000-0000-4000-8000-000000000008', 'c2700000-0000-4000-8000-000000000001', 'published',
                                        'D27 alta', 'rls-d27-alta', 'b2700000-0000-4000-8000-000000000005',
                                        'b2700000-0000-4000-8000-000000000002')$q$,
    'article', 'd2700000-0000-4000-8000-000000000008',
    array['b2700000-0000-4000-8000-000000000002', 'b2700000-0000-4000-8000-000000000005']::uuid[], '1f alta publicada (lista completa)');
  if (select status::text from guide.articles where id = 'd2700000-0000-4000-8000-000000000001') <> 'draft'
     or exists (select 1 from guide.articles where id = 'd2700000-0000-4000-8000-000000000008') then
    raise exception 'FAIL D27 1: el rechazo dejó efectos'; end if;

  -- 2. Cuerpo EN: no cuenta sin has_en; con has_en sí (programado futuro se edita en directo)
  update guide.articles set status = 'scheduled', published_at = now() + interval '1 day'
  where id = 'd2700000-0000-4000-8000-000000000004';
  v_j := pg_temp.d27_expect($q$update guide.articles set title_en = 'D27 en', slug_en = 'rls-d27-4-en' where id = 'd2700000-0000-4000-8000-000000000004'$q$,
    'article', 'd2700000-0000-4000-8000-000000000004', array['b2700000-0000-4000-8000-000000000010']::uuid[], '2 has_en');
  -- D27 (2): el cuerpo EN exige alt_es y alt_en; 'missing' detalla ambos
  if v_j -> 'missing' <> '[{"lang":"en","media_id":"b2700000-0000-4000-8000-000000000010"},{"lang":"es","media_id":"b2700000-0000-4000-8000-000000000010"}]'::jsonb then
    raise exception 'FAIL D27 2: missing es+en (%)', v_j; end if;
  -- Seguir programado sin tocar imágenes no falla por D27
  update guide.articles set title_es = 'D27 en editado' where id = 'd2700000-0000-4000-8000-000000000004';

  -- 3. Checklist del panel: alt_es pendiente bloquea; alt_en solo avisa y solo con has_en
  if not exists (select 1 from guide.content_alt_check('article', 'd2700000-0000-4000-8000-000000000001')
                 where media_id = 'b2700000-0000-4000-8000-000000000002' and missing_alt_es and not missing_alt_en)
     or not exists (select 1 from guide.content_alt_check('article', 'd2700000-0000-4000-8000-000000000005')
                    where media_id = 'b2700000-0000-4000-8000-000000000009' and not missing_alt_es and missing_alt_en)
     or exists (select 1 from guide.content_alt_check('item', 'f2700000-0000-4000-8000-000000000002'))
     or (select count(*) from guide.content_alt_check('item', 'f2700000-0000-4000-8000-000000000003')) <> 1 then
    raise exception 'FAIL D27 3: content_alt_check'; end if;
  begin perform guide.content_alt_check('article', 'd2700000-0000-4000-8000-0000000000ff');
    raise exception 'FAIL D27 3: inexistente'; exception when sqlstate 'P0002' then null; end;
  begin perform guide.content_alt_check('event', 'd2700000-0000-4000-8000-000000000001');
    raise exception 'FAIL D27 3: entidad desconocida'; exception when sqlstate '22023' then null; end;

  -- 4. Medios: no se vacía el alt de lo usado por contenido publicado o programado; sí el de lo demás
  v_j := pg_temp.d27_expect($q$update guide.media set alt_es = '   ' where id = 'b2700000-0000-4000-8000-000000000009'$q$,
    'media', 'b2700000-0000-4000-8000-000000000009', array['b2700000-0000-4000-8000-000000000009']::uuid[], '4a vaciar alt usado');
  if not (v_j -> 'used_by') @> '[{"entity":"article","entity_id":"d2700000-0000-4000-8000-000000000005"}]'::jsonb then
    raise exception 'FAIL D27 4a: used_by no indica el artículo (%)', v_j; end if;
  perform pg_temp.d27_expect($q$update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000001'$q$,
    'media', 'b2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000001']::uuid[], '4b portada de ficha');
  update guide.media set alt_es = 'Escaladora (editado)' where id = 'b2700000-0000-4000-8000-000000000009';
  update guide.media set alt_es = 'Presa' where id = 'b2700000-0000-4000-8000-000000000003';
  update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000003';  -- solo en un borrador
  update guide.media set alt_es = 'Presa' where id = 'b2700000-0000-4000-8000-000000000003';
  update guide.articles set status = 'scheduled', published_at = now() + interval '2 days'
  where id = 'd2700000-0000-4000-8000-000000000002';
  perform pg_temp.d27_expect($q$update guide.media set alt_es = '' where id = 'b2700000-0000-4000-8000-000000000003'$q$,
    'media', 'b2700000-0000-4000-8000-000000000003', array['b2700000-0000-4000-8000-000000000003']::uuid[], '4c usado por programado');
  -- alt_en sí se puede vaciar (D27 solo exige alt_es)
  update guide.media set alt_en = null where id = 'b2700000-0000-4000-8000-000000000001';

  -- 5. Fichas: publicar con galería / reseña sin alt; cambios nuevos sobre una publicada
  perform pg_temp.d27_expect($q$update guide.items set published = true where id = 'f2700000-0000-4000-8000-000000000001'$q$,
    'item', 'f2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000005']::uuid[], '5a galería');
  perform pg_temp.d27_expect($q$update guide.items set published = true where id = 'f2700000-0000-4000-8000-000000000003'$q$,
    'item', 'f2700000-0000-4000-8000-000000000003', array['b2700000-0000-4000-8000-000000000007']::uuid[], '5b reseña');
  -- F6.7: una ficha publicada solo cambia vía publish_draft; se simula con su GUC (D27 sigue aplicando).
  perform set_config('guide.draft_op', 'apply:f2700000-0000-4000-8000-000000000002', true);
  perform pg_temp.d27_expect($q$insert into guide.item_media (item_id, media_id, sort_order)
                                values ('f2700000-0000-4000-8000-000000000002', 'b2700000-0000-4000-8000-000000000005', 2)$q$,
    'item', 'f2700000-0000-4000-8000-000000000002', array['b2700000-0000-4000-8000-000000000005']::uuid[], '5c galería de publicada');
  perform pg_temp.d27_expect($q$update guide.items set og_media_id = 'b2700000-0000-4000-8000-000000000005'
                                where id = 'f2700000-0000-4000-8000-000000000002'$q$,
    'item', 'f2700000-0000-4000-8000-000000000002', array['b2700000-0000-4000-8000-000000000005']::uuid[], '5d OG de publicada');
  perform pg_temp.d27_expect($q$insert into guide.author_reviews (item_id, category, body_json_es, body_html_es)
                                values ('f2700000-0000-4000-8000-000000000002', 'gym', '{"type":"doc","content":[]}',
                                        '<img data-media-id="b2700000-0000-4000-8000-000000000007" src="x.jpg">')$q$,
    'item', 'f2700000-0000-4000-8000-000000000002', array['b2700000-0000-4000-8000-000000000007']::uuid[], '5e reseña de publicada');
  perform set_config('guide.draft_op', '', true);
  insert into guide.item_media (item_id, media_id, sort_order)  -- ficha oculta: libre
  values ('f2700000-0000-4000-8000-000000000003', 'b2700000-0000-4000-8000-000000000005', 1);
  perform guide.reorder_item_media('f2700000-0000-4000-8000-000000000002', array['b2700000-0000-4000-8000-000000000001']::uuid[]);

  -- 6. Lo heredado (publicado antes de D27) no se rompe; solo se rechaza lo nuevo
  perform set_config('guide.draft_op', 'apply:f2700000-0000-4000-8000-000000000004', true);
  update guide.items set summary_es = 'Editada sin tocar imágenes' where id = 'f2700000-0000-4000-8000-000000000004';
  perform pg_temp.d27_expect($q$update guide.items set og_media_id = 'b2700000-0000-4000-8000-000000000006'
                                where id = 'f2700000-0000-4000-8000-000000000004'$q$,
    'item', 'f2700000-0000-4000-8000-000000000004', array['b2700000-0000-4000-8000-000000000006']::uuid[], '6a solo lo nuevo');
  perform set_config('guide.draft_op', '', true);
  -- "Publicar cambios" sí exige el resultado completo (también lo heredado)
  perform guide.save_draft('article', 'd2700000-0000-4000-8000-000000000007', '{"article":{"title_es":"D27 heredado v2"}}',
                           guide.draft_entity_version('article', 'd2700000-0000-4000-8000-000000000007'));
  perform pg_temp.d27_expect($q$select guide.publish_draft('article', 'd2700000-0000-4000-8000-000000000007')$q$,
    'article', 'd2700000-0000-4000-8000-000000000007', array['b2700000-0000-4000-8000-000000000002']::uuid[], '6b publish_draft heredado');
  if not exists (select 1 from guide.content_drafts where entity = 'article' and entity_id = 'd2700000-0000-4000-8000-000000000007')
     or (select title_es from guide.articles where id = 'd2700000-0000-4000-8000-000000000007') <> 'D27 heredado' then
    raise exception 'FAIL D27 6b: el rechazo aplicó o perdió el borrador'; end if;

  -- V1 (leona-lia): un admin no se salta D27 falsificando guide.unpublish_op (solo vale dentro de unpublish_article)
  perform set_config('guide.unpublish_op', 'd2700000-0000-4000-8000-000000000001', true);
  perform pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'd2700000-0000-4000-8000-000000000001'$q$,
    'article', 'd2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000002']::uuid[], 'X1 GUC falsificado');
  perform set_config('guide.unpublish_op', 'd2700000-0000-4000-8000-000000000005', true);
  perform guide.save_draft('article', 'd2700000-0000-4000-8000-000000000005',
    '{"article":{"cover_media_id":"b2700000-0000-4000-8000-000000000002"}}',
    guide.draft_entity_version('article', 'd2700000-0000-4000-8000-000000000005'));
  perform pg_temp.d27_expect($q$select guide.publish_draft('article', 'd2700000-0000-4000-8000-000000000005')$q$,
    'article', 'd2700000-0000-4000-8000-000000000005', array['b2700000-0000-4000-8000-000000000002']::uuid[], 'X8b GUC falsificado');
  perform set_config('guide.unpublish_op', '', true);
  perform guide.discard_draft('article', 'd2700000-0000-4000-8000-000000000005');
  if (select cover_media_id from guide.articles where id = 'd2700000-0000-4000-8000-000000000005')
     <> 'b2700000-0000-4000-8000-000000000009' then
    raise exception 'FAIL D27 X8b: cambió la portada'; end if;
  -- O1: un alt solo con invisibles cuenta como vacío
  perform pg_temp.d27_expect(format('update guide.media set alt_es = %L where id = %L', chr(8203) || ' ' || chr(65279),
                                    'b2700000-0000-4000-8000-000000000009'),
    'media', 'b2700000-0000-4000-8000-000000000009', array['b2700000-0000-4000-8000-000000000009']::uuid[], 'O1 alt invisible');
  if not guide.alt_is_missing(chr(8203)) or not guide.alt_is_missing(chr(8204) || chr(8205) || chr(8288))
     or guide.alt_is_missing('Presa ' || chr(8203)) then
    raise exception 'FAIL D27 O1: alt_is_missing'; end if;

  -- 7. publish_draft con una imagen nueva sin alt → PT422 (el borrador se queda); despublicar sí deja
  perform guide.save_draft('article', 'd2700000-0000-4000-8000-000000000005',
    '{"article":{"body_json_es":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2700000-0000-4000-8000-000000000004"}}]},
                 "body_html_es":"<img data-media-id=\"b2700000-0000-4000-8000-000000000004\" src=\"x.jpg\">"}}',
    guide.draft_entity_version('article', 'd2700000-0000-4000-8000-000000000005'));
  perform pg_temp.d27_expect($q$select guide.publish_draft('article', 'd2700000-0000-4000-8000-000000000005')$q$,
    'article', 'd2700000-0000-4000-8000-000000000005', array['b2700000-0000-4000-8000-000000000004']::uuid[], '7a publish_draft');
  perform guide.unpublish_article('d2700000-0000-4000-8000-000000000005');
  if not exists (select 1 from guide.articles where id = 'd2700000-0000-4000-8000-000000000005'
                 and status = 'draft' and strpos(body_html_es, 'b2700000-0000-4000-8000-000000000004') > 0)
     or exists (select 1 from guide.content_drafts where entity_id = 'd2700000-0000-4000-8000-000000000005') then
    raise exception 'FAIL D27 7b: despublicar con borrador sin alt'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL D27 7: deja GUC abiertos'; end if;
  -- ya despublicado, el alt de 09 se puede vaciar
  update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000009';

  -- 8. Páginas
  perform pg_temp.d27_expect($q$update guide.pages set published = true where id = 'e2700000-0000-4000-8000-000000000001'$q$,
    'page', 'e2700000-0000-4000-8000-000000000001', array['b2700000-0000-4000-8000-000000000006']::uuid[], '8 página');

  -- 9. Con el alt rellenado, todo se publica
  update guide.media set alt_es = 'Bloque desplomado' where id::text like 'b2700000-%' and alt_es is null;
  update guide.articles set status = 'published' where id in ('d2700000-0000-4000-8000-000000000001', 'd2700000-0000-4000-8000-000000000003',
                                                               'd2700000-0000-4000-8000-000000000006');
  update guide.items set published = true where id in ('f2700000-0000-4000-8000-000000000001', 'f2700000-0000-4000-8000-000000000003');
  update guide.pages set published = true where id = 'e2700000-0000-4000-8000-000000000001';
  perform guide.publish_draft('article', 'd2700000-0000-4000-8000-000000000007');
  if (select count(*) from guide.articles where id::text like 'd2700000-%' and status = 'published') <> 4
     or (select count(*) from guide.items where id::text like 'f2700000-%' and published) <> 4
     or not (select published from guide.pages where id = 'e2700000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D27 9: no publica con alt completo'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- publish_due_articles (cron, como postgres) no falla por D27 aunque haya programados con imágenes
do $$ begin perform guide.publish_due_articles(); end $$;

-- Mantenimiento explícito como postgres: escape documentado (igual que F6.4); como admin no vale
select set_config('guide.draft_op', 'maintenance', true);
update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  perform pg_temp.d27_expect($q$update guide.media set alt_es = null where id = 'b2700000-0000-4000-8000-000000000005'$q$,
    'media', 'b2700000-0000-4000-8000-000000000005', array['b2700000-0000-4000-8000-000000000005']::uuid[], '10 maintenance como admin');
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
select set_config('guide.draft_op', '', true);
-- D27 (2): alt_en en cuerpos EN (decisión de Xavi) y OG por defecto. Medios b28…: 01, 03, 04, 05 con alt_es y sin
-- alt_en; 06 con los dos. a28…01 borrador EN con portada 01 y cuerpo EN con 01; a28…02 cuerpo EN sin has_en;
-- a28…03 EN con portada 03 (solo aviso); f28…01 ficha EN con reseña EN (03); f28…02 igual sin resumen EN;
-- e28…01 página EN con cuerpo EN (04).
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b2800000-0000-4000-8000-0000000000%s/1-d28.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','03','04','05','06']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es, alt_en)
select format('b2800000-0000-4000-8000-0000000000%s', n)::uuid, format('b2800000-0000-4000-8000-0000000000%s/1-d28.jpg', n),
       'd28.jpg', 'image/jpeg', 1, 10, 10, 'Imagen ' || n, case n when '06' then 'Image 06' end
from unnest(array['01','03','04','05','06']) n;
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es, cover_media_id, title_en, slug_en,
                            body_json_es, body_html_es, body_json_en, body_html_en) values
  ('a2800000-0000-4000-8000-000000000001', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D28 en', 'rls-d28-1',
   'b2800000-0000-4000-8000-000000000001', 'D28 en', 'rls-d28-1-en', '{"type":"doc","content":[]}', '<p>x</p>',
   '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2800000-0000-4000-8000-000000000001"}}]}', '<p>x</p>'),
  ('a2800000-0000-4000-8000-000000000002', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D28 sin en', 'rls-d28-2',
   null, null, null, '{"type":"doc","content":[]}', '<p>x</p>',
   '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2800000-0000-4000-8000-000000000001"}}]}', '<p>x</p>'),
  ('a2800000-0000-4000-8000-000000000003', 'c2700000-0000-4000-8000-000000000001', 'draft', null, 'D28 portada', 'rls-d28-3',
   'b2800000-0000-4000-8000-000000000003', 'D28 cover', 'rls-d28-3-en', '{"type":"doc","content":[]}', '<p>x</p>',
   '{"type":"doc","content":[]}', '<p>x</p>');
-- F6.15b: se publican sin mantenimiento → portada 06 (alt_es y alt_en: no altera los "missing" EN) y city.
insert into guide.items (id, category, name, slug, published, summary_en, cover_media_id) values
  ('f2800000-0000-4000-8000-000000000001', 'gym', 'D28 ficha en', 'rls-d28-ficha-en', false, 'English summary', 'b2800000-0000-4000-8000-000000000006'),
  ('f2800000-0000-4000-8000-000000000002', 'gym', 'D28 ficha es', 'rls-d28-ficha-es', false, null, 'b2800000-0000-4000-8000-000000000006');
insert into guide.gyms (item_id, city) values
  ('f2800000-0000-4000-8000-000000000001', 'Barcelona'), ('f2800000-0000-4000-8000-000000000002', 'Barcelona');
insert into guide.author_reviews (item_id, category, body_json_es, body_html_es, body_json_en, body_html_en)
select i, 'gym', '{"type":"doc","content":[]}', '<p>x</p>',
       '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2800000-0000-4000-8000-000000000003"}}]}', '<p>x</p>'
from unnest(array['f2800000-0000-4000-8000-000000000001', 'f2800000-0000-4000-8000-000000000002']::uuid[]) i;
insert into guide.pages (id, key, title_es, slug_es, title_en, slug_en, published, body_json_en, body_html_en) values
  ('e2800000-0000-4000-8000-000000000001', 'about', 'Página D28', 'rls-d28-pagina', 'Page D28', 'rls-d28-page', false,
   '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2800000-0000-4000-8000-000000000004"}}]}', '<p>x</p>');
select set_config('guide.draft_op', '', true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_j  jsonb;
  v_s  smallint := (select min(id) from guide.site_settings);
  v_og uuid := (select default_og_media_id from guide.site_settings where id = (select min(id) from guide.site_settings));
begin
  -- 1. Cuerpo EN: alt_en obligatorio; 'missing' dice el idioma (media_ids se mantiene)
  if not exists (select 1 from guide.content_alt_check('article', 'a2800000-0000-4000-8000-000000000001')
                 where media_id = 'b2800000-0000-4000-8000-000000000001'
                   and not missing_alt_es and missing_alt_en and alt_en_required) then
    raise exception 'FAIL D28 1: content_alt_check alt_en_required'; end if;
  v_j := pg_temp.d27_expect($q$update guide.articles set status = 'published' where id = 'a2800000-0000-4000-8000-000000000001'$q$,
    'article', 'a2800000-0000-4000-8000-000000000001', array['b2800000-0000-4000-8000-000000000001']::uuid[], 'D28 1 cuerpo EN');
  if v_j -> 'missing' <> '[{"lang":"en","media_id":"b2800000-0000-4000-8000-000000000001"}]'::jsonb then
    raise exception 'FAIL D28 1: missing (%)', v_j; end if;
  -- sin has_en el cuerpo EN no cuenta; portada sin alt_en solo avisa
  update guide.articles set status = 'published' where id = 'a2800000-0000-4000-8000-000000000002';
  if not exists (select 1 from guide.content_alt_check('article', 'a2800000-0000-4000-8000-000000000003')
                 where media_id = 'b2800000-0000-4000-8000-000000000003' and missing_alt_en and not alt_en_required) then
    raise exception 'FAIL D28 1: portada sin alt_en no es aviso'; end if;
  update guide.articles set status = 'published' where id = 'a2800000-0000-4000-8000-000000000003';
  -- con alt_en se publica; después no se vacía
  update guide.media set alt_en = 'Image 01' where id = 'b2800000-0000-4000-8000-000000000001';
  update guide.articles set status = 'published' where id = 'a2800000-0000-4000-8000-000000000001';
  v_j := pg_temp.d27_expect($q$update guide.media set alt_en = ' ' where id = 'b2800000-0000-4000-8000-000000000001'$q$,
    'media', 'b2800000-0000-4000-8000-000000000001', array['b2800000-0000-4000-8000-000000000001']::uuid[], 'D28 1 vaciar alt_en');
  if not (v_j -> 'used_by') @> '[{"entity":"article","entity_id":"a2800000-0000-4000-8000-000000000001"}]'::jsonb
     or v_j -> 'missing' <> '[{"lang":"en","media_id":"b2800000-0000-4000-8000-000000000001"}]'::jsonb then
    raise exception 'FAIL D28 1: vaciar alt_en (%)', v_j; end if;
  -- alt_en de la portada (solo aviso) sí se puede vaciar
  update guide.media set alt_en = 'Cover 03' where id = 'b2800000-0000-4000-8000-000000000003';
  update guide.media set alt_en = null where id = 'b2800000-0000-4000-8000-000000000003';

  -- 2. publish_draft: imagen nueva sin alt_en en el cuerpo EN de un publicado
  perform guide.save_draft('article', 'a2800000-0000-4000-8000-000000000001',
    '{"article":{"body_json_en":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b2800000-0000-4000-8000-000000000004"}}]},"body_html_en":"<p>y</p>"}}',
    guide.draft_entity_version('article', 'a2800000-0000-4000-8000-000000000001'));
  v_j := pg_temp.d27_expect($q$select guide.publish_draft('article', 'a2800000-0000-4000-8000-000000000001')$q$,
    'article', 'a2800000-0000-4000-8000-000000000001', array['b2800000-0000-4000-8000-000000000004']::uuid[], 'D28 2 publish_draft');
  if v_j -> 'missing' <> '[{"lang":"en","media_id":"b2800000-0000-4000-8000-000000000004"}]'::jsonb then
    raise exception 'FAIL D28 2: missing (%)', v_j; end if;
  perform guide.discard_draft('article', 'a2800000-0000-4000-8000-000000000001');

  -- 3. Ficha: la reseña EN exige alt_en solo si la ficha está lista en EN
  v_j := pg_temp.d27_expect($q$update guide.items set published = true where id = 'f2800000-0000-4000-8000-000000000001'$q$,
    'item', 'f2800000-0000-4000-8000-000000000001', array['b2800000-0000-4000-8000-000000000003']::uuid[], 'D28 3 reseña EN');
  if v_j -> 'missing' <> '[{"lang":"en","media_id":"b2800000-0000-4000-8000-000000000003"}]'::jsonb then
    raise exception 'FAIL D28 3: missing (%)', v_j; end if;
  update guide.items set published = true where id = 'f2800000-0000-4000-8000-000000000002';
  -- y pasa a exigirse al dejar la ficha lista en EN (cambio nuevo sobre una publicada, vía publish_draft)
  perform guide.save_draft('item', 'f2800000-0000-4000-8000-000000000002', '{"item":{"summary_en":"Now in English"}}',
                           guide.draft_entity_version('item', 'f2800000-0000-4000-8000-000000000002'));
  perform pg_temp.d27_expect($q$select guide.publish_draft('item', 'f2800000-0000-4000-8000-000000000002')$q$,
    'item', 'f2800000-0000-4000-8000-000000000002', array['b2800000-0000-4000-8000-000000000003']::uuid[], 'D28 3 ficha pasa a EN');
  perform guide.discard_draft('item', 'f2800000-0000-4000-8000-000000000002');

  -- 4. Página EN
  perform pg_temp.d27_expect($q$update guide.pages set published = true where id = 'e2800000-0000-4000-8000-000000000001'$q$,
    'page', 'e2800000-0000-4000-8000-000000000001', array['b2800000-0000-4000-8000-000000000004']::uuid[], 'D28 4 página EN');

  -- 5. OG por defecto: alt_es y alt_en; no se vacían mientras lo sea
  begin update guide.site_settings set default_og_media_id = 'b2800000-0000-4000-8000-000000000005' where id = v_s;
    raise exception 'FAIL D28 5a: OG por defecto sin alt_en'; exception when sqlstate 'PT422' then
      get stacked diagnostics v_j = pg_exception_detail;
      if v_j ->> 'entity' <> 'site_settings' or (v_j ->> 'setting_id')::smallint <> v_s
         or v_j -> 'missing' <> '[{"lang":"en","media_id":"b2800000-0000-4000-8000-000000000005"}]'::jsonb then
        raise exception 'FAIL D28 5a: details (%)', v_j; end if;
  end;
  update guide.site_settings set default_og_media_id = 'b2800000-0000-4000-8000-000000000006' where id = v_s;
  v_j := pg_temp.d27_expect($q$update guide.media set alt_es = null where id = 'b2800000-0000-4000-8000-000000000006'$q$,
    'media', 'b2800000-0000-4000-8000-000000000006', array['b2800000-0000-4000-8000-000000000006']::uuid[], 'D28 5b vaciar alt_es OG');
  if not (v_j -> 'used_by') @> jsonb_build_array(jsonb_build_object('entity', 'site_settings', 'entity_id', v_s)) then
    raise exception 'FAIL D28 5b: used_by (%)', v_j; end if;
  perform pg_temp.d27_expect($q$update guide.media set alt_en = '' where id = 'b2800000-0000-4000-8000-000000000006'$q$,
    'media', 'b2800000-0000-4000-8000-000000000006', array['b2800000-0000-4000-8000-000000000006']::uuid[], 'D28 5c vaciar alt_en OG');
  update guide.site_settings set default_og_media_id = v_og where id = v_s;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
drop function pg_temp.d27_expect(text, text, uuid, uuid[], text);

-- ═════════════ F6.7: editor de fichas (alta atómica, ocultar, índices de no publicadas, borradores) ═════════════
-- Fixtures (como postgres, mantenimiento explícito). Medios: m1 con alt, m2 sin alt.
--   f67…03 gym publicado con precios y nota "beginner_friendly" (coherencia con gym_indices)
--   f67…04 gym publicado (ocultar con borrador) · f67…05 gym publicado (D27 vía publish_draft)
--   f67…06 gym no publicado con portada sin alt (D27 al publicar)
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata) values
  ('media', 'b6700000-0000-4000-8000-000000000001/1-f67.jpg', '{"mimetype":"image/jpeg","size":700}'),
  ('media', 'b6700000-0000-4000-8000-000000000002/1-f67.jpg', '{"mimetype":"image/jpeg","size":700}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es) values
  ('b6700000-0000-4000-8000-000000000001', 'b6700000-0000-4000-8000-000000000001/1-f67.jpg', 'f67.jpg', 'image/jpeg', 1, 10, 10, 'Muro de bloque'),
  ('b6700000-0000-4000-8000-000000000002', 'b6700000-0000-4000-8000-000000000002/1-f67.jpg', 'f67.jpg', 'image/jpeg', 1, 10, 10, null);
insert into guide.criteria (id, category, key, name_es, name_en) values
  ('c6700000-0000-4000-8000-000000000001', 'shoe', 'rls_editor_shoe', 'Shoe F67', 'Shoe F67');
insert into guide.criteria (id, category, key, name_es, name_en)
select 'c6700000-0000-4000-8000-000000000002', 'gym', 'beginner_friendly', 'Principiantes', 'Beginners'
where not exists (select 1 from guide.criteria where category = 'gym' and key = 'beginner_friendly');
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f6700000-0000-4000-8000-000000000003', 'gym', 'F67 indices', 'rls-f67-indices', true, null),
  ('f6700000-0000-4000-8000-000000000004', 'gym', 'F67 ocultar', 'rls-f67-ocultar', true, null),
  ('f6700000-0000-4000-8000-000000000005', 'gym', 'F67 d27', 'rls-f67-d27', true, null),
  ('f6700000-0000-4000-8000-000000000006', 'gym', 'F67 portada', 'rls-f67-portada', false, 'b6700000-0000-4000-8000-000000000002');
insert into guide.gyms (item_id, price_monthly_eur, price_registration_eur, price_day_eur, price_10_pass_eur,
                        has_beginner_courses, gear_rental, belay_test_required, has_boulder, has_kids_area, kids_min_age, has_cafe)
values ('f6700000-0000-4000-8000-000000000003', 61.37, 24, 13.5, 117, true, true, false, true, true, 4, false);
insert into guide.gyms (item_id) values
  ('f6700000-0000-4000-8000-000000000004'), ('f6700000-0000-4000-8000-000000000005'), ('f6700000-0000-4000-8000-000000000006');
insert into guide.author_reviews (id, item_id, category) values
  ('a6700000-0000-4000-8000-000000000003', 'f6700000-0000-4000-8000-000000000003', 'gym');
insert into guide.author_review_scores (review_id, criterion_id, category, score)
select 'a6700000-0000-4000-8000-000000000003', c.id, 'gym', 4 from guide.criteria c
where c.category = 'gym' and c.key = 'beginner_friendly';
select set_config('guide.draft_op', '', true);

-- anon y no admin: sin acceso a las RPC nuevas
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.create_item('gym', 'x', 'rls-f67-anon');
    raise exception 'LEAK anon F6.7: create_item'; exception when insufficient_privilege then null; end;
  begin perform guide.unpublish_item('f6700000-0000-4000-8000-000000000004');
    raise exception 'LEAK anon F6.7: unpublish_item'; exception when insufficient_privilege then null; end;
  begin perform guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006');
    raise exception 'LEAK anon F6.7: gym_indices_preview'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  begin perform guide.create_item('gym', 'x', 'rls-f67-user');
    raise exception 'LEAK user F6.7: create_item'; exception when insufficient_privilege then null; end;
  begin perform guide.unpublish_item('f6700000-0000-4000-8000-000000000004');
    raise exception 'LEAK user F6.7: unpublish_item'; exception when insufficient_privilege then null; end;
  begin perform guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006');
    raise exception 'LEAK user F6.7: gym_indices_preview'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$
begin
  if exists (select 1 from guide.items where slug in ('rls-f67-anon', 'rls-f67-user'))
     or not (select published from guide.items where id = 'f6700000-0000-4000-8000-000000000004') then
    raise exception 'LEAK F6.7: un no admin creó u ocultó fichas'; end if;
  if exists (select 1 from information_schema.routine_privileges
             where routine_schema = 'guide' and grantee in ('anon', 'PUBLIC')
               and routine_name in ('create_item', 'unpublish_item', 'gym_indices_preview')) then
    raise exception 'LEAK F6.7: RPC ejecutables por anon/PUBLIC'; end if;
end $$;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_row  record;
  v_id   uuid;
  v_msg  text;
  v_det  text;
  v_prev record;
  v_view record;
  v_beg  uuid := (select id from guide.criteria where category = 'gym' and key = 'beginner_friendly');
begin
  -- 1. create_item: ficha + detalle en una transacción; slug libre; validaciones
  select * into v_row from guide.create_item('gym', 'F67 nuevo', 'rls-f67-nuevo');
  if v_row.slug <> 'rls-f67-nuevo'
     or not exists (select 1 from guide.items where id = v_row.id and category = 'gym' and not published and name = 'F67 nuevo')
     or not exists (select 1 from guide.gyms where item_id = v_row.id) then
    raise exception 'FAIL F6.7 1a: create_item'; end if;
  if (select slug from guide.create_item('gym', 'F67 nuevo', 'rls-f67-nuevo')) <> 'rls-f67-nuevo-2' then
    raise exception 'FAIL F6.7 1b: slug ocupado'; end if;
  -- F6.9: brand/model son opcionales mientras no se publica → el alta sin detalle crea ficha + fila de shoes vacía.
  select * into v_row from guide.create_item('shoe', 'F67 zapa', 'rls-f67-zapa-vacia');
  if not exists (select 1 from guide.shoes where item_id = v_row.id and brand is null and model is null) then
    raise exception 'FAIL F6.7 1c: alta de shoe sin brand/model (ficha sin detalle)'; end if;
  select * into v_row from guide.create_item('shoe', 'F67 zapa', 'rls-f67-zapa', '{"brand":"Marca","model":"Modelo"}');
  if not exists (select 1 from guide.shoes where item_id = v_row.id and brand = 'Marca' and model = 'Modelo') then
    raise exception 'FAIL F6.7 1d: create_item con detalle'; end if;
  begin perform guide.create_item('event', 'x', 'rls-f67-x');
    raise exception 'FAIL F6.7 1e: categoría'; exception when invalid_parameter_value then null; end;
  begin perform guide.create_item('gym', 'x', 'Con Espacios');
    raise exception 'FAIL F6.7 1f: slug'; exception when invalid_parameter_value then null; end;
  begin perform guide.create_item('gym', 'x', 'rls-f67-x', '{"item_id":"f6700000-0000-4000-8000-000000000003"}');
    raise exception 'FAIL F6.7 1g: detalle fuera de lista blanca'; exception when invalid_parameter_value then null; end;
  begin perform guide.create_item('gym', 'x', 'rls-f67-x', '{"category":"shoe"}');
    raise exception 'FAIL F6.7 1h: categoría en el detalle'; exception when invalid_parameter_value then null; end;

  -- 2. gym_indices_preview: igual que la vista en una publicada; funciona en no publicadas y con valores del editor
  select * into v_prev from guide.gym_indices_preview('f6700000-0000-4000-8000-000000000003');
  select * into v_view from guide.gym_indices where item_id = 'f6700000-0000-4000-8000-000000000003';
  if v_prev.monthly_cost_2pw_eur is distinct from v_view.monthly_cost_2pw_eur
     or v_prev.price_index is distinct from v_view.price_index
     or v_prev.beginner_index is distinct from v_view.beginner_index
     or v_prev.beginner_index_complete is distinct from v_view.beginner_index_complete
     or v_prev.family_index is distinct from v_view.family_index then
    raise exception 'FAIL F6.7 2a: preview ≠ gym_indices (% / %)', row_to_json(v_prev), row_to_json(v_view); end if;
  if exists (select 1 from guide.gym_indices where item_id = 'f6700000-0000-4000-8000-000000000006') then
    raise exception 'FAIL F6.7 2b: gym_indices expone no publicadas'; end if;
  select * into v_prev from guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006');
  if v_prev.beginner_index <> 1.0 or v_prev.beginner_index_complete or v_prev.price_index is not null then
    raise exception 'FAIL F6.7 2c: preview de no publicada vacía (%)', row_to_json(v_prev); end if;
  select * into v_prev from guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006',
    '{"has_beginner_courses":true,"gear_rental":true,"belay_test_required":false,"has_boulder":true,"price_monthly_eur":50}',
    jsonb_build_object(v_beg::text, 5));
  if v_prev.beginner_index <> 5.0 or not v_prev.beginner_index_complete or v_prev.price_index is null
     or v_prev.monthly_cost_2pw_eur <> 50.00 then
    raise exception 'FAIL F6.7 2d: preview con valores del editor (%)', row_to_json(v_prev); end if;
  if (select has_beginner_courses from guide.gyms where item_id = 'f6700000-0000-4000-8000-000000000006') is not null then
    raise exception 'FAIL F6.7 2d: preview escribió en gyms'; end if;
  begin perform guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006', '{"item_id":"f6700000-0000-4000-8000-000000000003"}');
    raise exception 'FAIL F6.7 2e: columna fuera de lista blanca'; exception when invalid_parameter_value then null; end;
  begin perform guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006', null, '{"c6700000-0000-4000-8000-000000000001":3}');
    raise exception 'FAIL F6.7 2f: criterio de otra categoría'; exception when invalid_parameter_value then null; end;
  begin perform guide.gym_indices_preview(v_row.id);  -- la zapatilla no es un rocódromo
    raise exception 'FAIL F6.7 2g: preview de una no-gym'; exception when sqlstate 'P0002' then null; end;

  -- 3. Borradores de ficha: notas solo de criterios de su categoría
  begin perform guide.save_draft('item', 'f6700000-0000-4000-8000-000000000004', '{"scores":{"c6700000-0000-4000-8000-000000000001":3}}',
                                 guide.draft_entity_version('item', 'f6700000-0000-4000-8000-000000000004'));
    raise exception 'FAIL F6.7 3: scores de otra categoría'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'invalid section: scores' then raise exception 'FAIL F6.7 3: mensaje (%)', v_msg; end if;
  end;

  -- 4. D27 en fichas: publish_draft y published=true devuelven PT422 con details.media_ids
  perform guide.save_draft('item', 'f6700000-0000-4000-8000-000000000005', '{"gallery":["b6700000-0000-4000-8000-000000000002"]}',
                           guide.draft_entity_version('item', 'f6700000-0000-4000-8000-000000000005'));
  begin perform guide.publish_draft('item', 'f6700000-0000-4000-8000-000000000005');
    raise exception 'FAIL F6.7 4a: publish_draft con galería sin alt'; exception when sqlstate 'PT422' then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det::jsonb <> jsonb_build_object('entity', 'item', 'entity_id', 'f6700000-0000-4000-8000-000000000005',
                                            'media_ids', jsonb_build_array('b6700000-0000-4000-8000-000000000002'),
                                            'missing', jsonb_build_array(jsonb_build_object(
                                              'media_id', 'b6700000-0000-4000-8000-000000000002', 'lang', 'es'))) then
        raise exception 'FAIL F6.7 4a: details (%)', v_det; end if;
  end;
  begin update guide.items set published = true where id = 'f6700000-0000-4000-8000-000000000006';
    raise exception 'FAIL F6.7 4b: publicar con portada sin alt'; exception when sqlstate 'PT422' then
      get stacked diagnostics v_det = pg_exception_detail;
      if (v_det::jsonb -> 'media_ids') <> '["b6700000-0000-4000-8000-000000000002"]'::jsonb then
        raise exception 'FAIL F6.7 4b: details (%)', v_det; end if;
  end;
  -- GUC falsificado: no exime (V1 de D27 también en fichas)
  perform set_config('guide.unpublish_op', 'f6700000-0000-4000-8000-000000000005', true);
  begin perform guide.publish_draft('item', 'f6700000-0000-4000-8000-000000000005');
    raise exception 'FAIL F6.7 4c: GUC falsificado exime D27'; exception when sqlstate 'PT422' then null; end;
  perform set_config('guide.unpublish_op', '', true);
  perform guide.discard_draft('item', 'f6700000-0000-4000-8000-000000000005');

  -- 5. unpublish_item: oculta, aplica el borrador (aunque traiga imágenes sin alt) y lo borra; un solo registro
  perform guide.save_draft('item', 'f6700000-0000-4000-8000-000000000004',
    '{"item":{"name":"F67 ocultada"},"gallery":["b6700000-0000-4000-8000-000000000002"]}',
    guide.draft_entity_version('item', 'f6700000-0000-4000-8000-000000000004'));
  perform guide.unpublish_item('f6700000-0000-4000-8000-000000000004');
  if not exists (select 1 from guide.items where id = 'f6700000-0000-4000-8000-000000000004' and not published and name = 'F67 ocultada')
     or not exists (select 1 from guide.item_media where item_id = 'f6700000-0000-4000-8000-000000000004'
                    and media_id = 'b6700000-0000-4000-8000-000000000002')
     or exists (select 1 from guide.content_drafts where entity = 'item' and entity_id = 'f6700000-0000-4000-8000-000000000004') then
    raise exception 'FAIL F6.7 5a: unpublish_item con borrador'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish' and entity_table = 'items'
                 and entity_id = 'f6700000-0000-4000-8000-000000000004' and actor_id = 'a0000000-0000-4000-8000-000000000001'
                 and details = '{"draft_applied": true}'::jsonb)
     or exists (select 1 from guide.activity_log where action in ('draft_publish', 'draft_discard')
                and entity_id = 'f6700000-0000-4000-8000-000000000004') then
    raise exception 'FAIL F6.7 5b: registro de actividad'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL F6.7 5c: deja GUC abiertos'; end if;
  begin perform guide.unpublish_item('f6700000-0000-4000-8000-000000000004');
    raise exception 'FAIL F6.7 5d: dos veces'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'item not live' then raise exception 'FAIL F6.7 5d: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.unpublish_item('f6700000-0000-4000-8000-0000000000ff');
    raise exception 'FAIL F6.7 5e: inexistente'; exception when sqlstate 'P0002' then null; end;
  -- sin borrador
  perform guide.unpublish_item('f6700000-0000-4000-8000-000000000005');
  if (select published from guide.items where id = 'f6700000-0000-4000-8000-000000000005')
     or not exists (select 1 from guide.activity_log where action = 'unpublish' and entity_id = 'f6700000-0000-4000-8000-000000000005'
                    and details = '{"draft_applied": false}'::jsonb) then
    raise exception 'FAIL F6.7 5f: unpublish_item sin borrador'; end if;

  -- 6. Guarda de lo publicado (D23 en la BD): f67…03 publicada
  declare
    v_rid uuid := 'a6700000-0000-4000-8000-000000000003';
    v_f3  uuid := 'f6700000-0000-4000-8000-000000000003';
    v_ts  timestamptz;
  begin
    begin update guide.items set name = 'hack' where id = v_f3;
      raise exception 'FAIL F6.7 6a: items en directo'; exception when sqlstate 'PT423' then
        get stacked diagnostics v_det = pg_exception_detail, v_msg = message_text;
        if v_msg <> 'item is live' or v_det <> 'changed: name' then raise exception 'FAIL F6.7 6a: error (% / %)', v_msg, v_det; end if;
    end;
    begin update guide.items set name = 'hack', verified_at = current_date where id = v_f3;
      raise exception 'FAIL F6.7 6b: verified_at no abre otras columnas'; exception when sqlstate 'PT423' then null; end;
    -- O1: created_at ya no está excluida
    begin update guide.items set created_at = now() - interval '9 days' where id = v_f3;
      raise exception 'FAIL F6.7 O1: created_at de una publicada en directo'; exception when sqlstate 'PT423' then
        get stacked diagnostics v_det = pg_exception_detail;
        if v_det <> 'changed: created_at' then raise exception 'FAIL F6.7 O1: detail (%)', v_det; end if;
    end;
    begin update guide.gyms set created_at = now() - interval '9 days' where item_id = v_f3;
      raise exception 'FAIL F6.7 O1: created_at del detalle en directo'; exception when sqlstate 'PT423' then null; end;
    -- O2: generadas desde el catálogo (has_en de items, is_affiliate de shoes), no por nombre
    if guide.changed_columns('guide.items', '{"has_en":false,"updated_at":"a","created_at":"x"}',
                                            '{"has_en":true,"updated_at":"b","created_at":"x"}') is not null
       or guide.changed_columns('guide.shoes', '{"is_affiliate":false}', '{"is_affiliate":true}') is not null
       or guide.changed_columns('guide.items', '{"created_at":"x"}', '{"created_at":"y"}') <> array['created_at']
       or guide.changed_columns('guide.gyms', '{"has_en":false}', '{"has_en":true}') <> array['has_en'] then
      raise exception 'FAIL F6.7 O2: changed_columns'; end if;
    begin update guide.gyms set price_monthly_eur = 1 where item_id = v_f3;
      raise exception 'FAIL F6.7 6c: detalle en directo'; exception when sqlstate 'PT423' then null; end;
    begin update guide.author_reviews set headline_es = 'hack' where id = v_rid;
      raise exception 'FAIL F6.7 6d: reseña en directo'; exception when sqlstate 'PT423' then null; end;
    begin update guide.author_review_scores set score = 1 where review_id = v_rid;
      raise exception 'FAIL F6.7 6e: notas en directo'; exception when sqlstate 'PT423' then null; end;
    begin insert into guide.item_media (item_id, media_id, sort_order) values (v_f3, 'b6700000-0000-4000-8000-000000000001', 1);
      raise exception 'FAIL F6.7 6f: galería en directo'; exception when sqlstate 'PT423' then null; end;
    begin delete from guide.items where id = v_f3;
      raise exception 'FAIL F6.7 6g: borrar publicada'; exception when sqlstate 'PT423' then
        get stacked diagnostics v_det = pg_exception_detail;
        if v_det <> 'delete' then raise exception 'FAIL F6.7 6g: detail (%)', v_det; end if;
    end;
    -- GUC de OTRA ficha no exime; 'maintenance' sin bypassrls tampoco
    perform set_config('guide.draft_op', 'apply:f6700000-0000-4000-8000-000000000006', true);
    begin update guide.gyms set price_monthly_eur = 1 where item_id = v_f3;
      raise exception 'FAIL F6.7 6h: GUC de otra ficha exime'; exception when sqlstate 'PT423' then null; end;
    perform set_config('guide.draft_op', 'maintenance', true);
    begin update guide.items set name = 'hack' where id = v_f3;
      raise exception 'FAIL F6.7 6i: maintenance como admin exime'; exception when sqlstate 'PT423' then null; end;
    perform set_config('guide.draft_op', '', true);
    -- Permitido: sellos de verificación solos, ocultar/publicar, y todo en no publicadas
    update guide.items set verified_at = current_date where id = v_f3;
    update guide.gyms set prices_verified_at = current_date where item_id = v_f3;
    update guide.items set name = 'Libre' where id = 'f6700000-0000-4000-8000-000000000006';
    update guide.gyms set price_monthly_eur = 40 where item_id = 'f6700000-0000-4000-8000-000000000006';
    if (select verified_at from guide.items where id = v_f3) <> current_date
       or (select prices_verified_at from guide.gyms where item_id = v_f3) <> current_date then
      raise exception 'FAIL F6.7 6j: sellos de verificación'; end if;
    -- publish_draft sí aplica (detalle, reseña, notas y galería)
    v_ts := guide.draft_entity_version('item', v_f3);
    perform guide.save_draft('item', v_f3,
      jsonb_build_object('item', jsonb_build_object('name', 'F67 vía borrador'),
                         'detail', jsonb_build_object('price_monthly_eur', 59),
                         'author_review', jsonb_build_object('headline_es', 'Titular'),
                         'scores', jsonb_build_object(v_beg::text, 5),
                         'gallery', jsonb_build_array('b6700000-0000-4000-8000-000000000001')), v_ts);
    -- O3: con guide.unpublish_op falsificado, publish_draft sí registra 'draft_publish'
    perform set_config('guide.unpublish_op', v_f3::text, true);
    perform guide.publish_draft('item', v_f3);
    perform set_config('guide.unpublish_op', '', true);
    if not exists (select 1 from guide.activity_log where action = 'draft_publish' and entity_table = 'items'
                   and entity_id = v_f3::text) then
      raise exception 'FAIL F6.7 O3: el GUC falsificado omite draft_publish de la ficha'; end if;
    if not exists (select 1 from guide.items i join guide.gyms g on g.item_id = i.id
                   join guide.author_reviews r on r.item_id = i.id
                   where i.id = v_f3 and i.published and i.name = 'F67 vía borrador' and g.price_monthly_eur = 59
                     and r.headline_es = 'Titular')
       or (select score from guide.author_review_scores where review_id = v_rid and criterion_id = v_beg) <> 5
       or not exists (select 1 from guide.item_media where item_id = v_f3 and media_id = 'b6700000-0000-4000-8000-000000000001') then
      raise exception 'FAIL F6.7 6k: publish_draft de ficha publicada'; end if;
    if coalesce(current_setting('guide.draft_op', true), '') <> '' then
      raise exception 'FAIL F6.7 6k: deja el GUC abierto'; end if;
  end;
end $$;
reset role;
-- 6l. Mantenimiento explícito como postgres sí escribe en directo
select set_config('guide.draft_op', 'maintenance', true);
update guide.gyms set price_monthly_eur = 60 where item_id = 'f6700000-0000-4000-8000-000000000003';
select set_config('guide.draft_op', '', true);
do $$
begin
  if (select price_monthly_eur from guide.gyms where item_id = 'f6700000-0000-4000-8000-000000000003') <> 60 then
    raise exception 'FAIL F6.7 6l: maintenance como postgres'; end if;
  -- como postgres SIN maintenance: también PT423
  begin update guide.items set name = 'hack' where id = 'f6700000-0000-4000-8000-000000000003';
    raise exception 'FAIL F6.7 6m: postgres sin maintenance'; exception when sqlstate 'PT423' then null; end;
end $$;

-- 7. Índice de precio: tramos fijos de 7,50 € con < 10 rocódromos publicados con precio; quintiles con ≥ 10
do $$
begin
  if guide.gym_price_tier(49.99) <> 5 or guide.gym_price_tier(50) <> 4 or guide.gym_price_tier(57.49) <> 4
     or guide.gym_price_tier(57.50) <> 3 or guide.gym_price_tier(64.99) <> 3 or guide.gym_price_tier(65) <> 2
     or guide.gym_price_tier(72.49) <> 2 or guide.gym_price_tier(72.50) <> 1 or guide.gym_price_tier(null) is not null
     or guide.gym_price_quintile_min() <> 10 then
    raise exception 'FAIL F6.7 7a: tramos'; end if;
  if (select count(*) from guide.gym_indices where monthly_cost_2pw_eur is not null) < 10
     and exists (select 1 from guide.gym_indices
                 where price_index is distinct from guide.gym_price_tier(monthly_cost_2pw_eur)) then
    raise exception 'FAIL F6.7 7b: con < 10 no usa tramos'; end if;
end $$;
-- anon lee la vista (security_invoker: necesita EXECUTE en las funciones de tramos)
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin perform price_index from guide.gym_indices; end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
-- 7e. En el umbral (leona-lia, D28): con 9 publicados con precio la vista va por tramos, pero el preview de una
-- ficha NO publicada cuenta 10 (ella incluida) y va por quintiles; la ficha pública se ajusta al publicarla.
-- Precios controlados: se ocultan (mantenimiento, en esta transacción) los rocódromos publicados y se crean 9.
select set_config('guide.draft_op', 'maintenance', true);
update guide.items set published = false where category = 'gym' and published;
insert into guide.items (id, category, name, slug, published)
select ('f6700000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'gym', 'F67 umbral ' || n, 'rls-f67-umbral-' || n, true
from generate_series(1, 9) n;
insert into guide.gyms (item_id, price_monthly_eur)
select ('f6700000-0000-4000-8000-0000000002' || lpad(n::text, 2, '0'))::uuid, (array[40, 50, 62, 64, 66, 68, 70, 72, 74])[n]
from generate_series(1, 9) n;
select set_config('guide.draft_op', '', true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_prev record;
begin
  if (select count(*) from guide.gym_indices where monthly_cost_2pw_eur is not null) <> 9
     or exists (select 1 from guide.gym_indices where price_index is distinct from guide.gym_price_tier(monthly_cost_2pw_eur)) then
    raise exception 'FAIL F6.7 7e: con 9 la vista no va por tramos'; end if;
  -- 60 queda 3.º de 10 → ntile 2 → quintil 4; por tramos sería 3
  select * into v_prev from guide.gym_indices_preview('f6700000-0000-4000-8000-000000000006', '{"price_monthly_eur":60}');
  if v_prev.monthly_cost_2pw_eur <> 60 or v_prev.price_index <> 4 or guide.gym_price_tier(60) <> 3 then
    raise exception 'FAIL F6.7 7e: preview en el umbral (%)', row_to_json(v_prev); end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
-- ≥ 10 con precio: se añaden rocódromos publicados (mantenimiento) hasta pasar el umbral
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.items (id, category, name, slug, published)
select ('f6700000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'gym', 'F67 precio ' || n, 'rls-f67-precio-' || n, true
from generate_series(1, 10) n;
insert into guide.gyms (item_id, price_monthly_eur)
select ('f6700000-0000-4000-8000-0000000001' || lpad(n::text, 2, '0'))::uuid, 40 + n * 3.1
from generate_series(1, 10) n;
select set_config('guide.draft_op', '', true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_prev record;
begin
  if exists (
    select 1
    from guide.gym_indices v
    join (select item_id, (6 - ntile(5) over (order by c))::smallint as q
          from (select g.item_id,
                       least(g.price_monthly_eur + coalesce(g.price_registration_eur, 0) / 12,
                             g.price_day_eur * (104.0 / 12), g.price_10_pass_eur / 10 * (104.0 / 12)) as c
                from guide.gyms g join guide.items i on i.id = g.item_id and i.published) x
          where c is not null) q on q.item_id = v.item_id
    where v.price_index is distinct from q.q) then
    raise exception 'FAIL F6.7 7c: con ≥ 10 no vuelve a quintiles'; end if;
  if not exists (select 1 from guide.gym_indices where price_index = 5)
     or not exists (select 1 from guide.gym_indices where price_index = 1) then
    raise exception 'FAIL F6.7 7c: quintiles incompletos'; end if;
  -- 7d compara un rocódromo publicado en este punto (f67…03 lo oculta 7e y ya no está en la vista)
  select * into v_prev from guide.gym_indices_preview('f6700000-0000-4000-8000-000000000105');
  if v_prev.price_index is null
     or v_prev.price_index is distinct from (select price_index from guide.gym_indices
                                             where item_id = 'f6700000-0000-4000-8000-000000000105') then
    raise exception 'FAIL F6.7 7d: preview ≠ vista en quintiles (%)', row_to_json(v_prev); end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
reset role;
select set_config('request.jwt.claims', '{}', true);

-- ═════════════ F6.8: resoladores (editor genérico de fichas: servicios D18, CHECK en el borrador, guardas) ═════════════
-- Fixtures (como postgres, mantenimiento). r68…01 publicado (servicios, plazos 2–5, reseña); r68…02 no publicado con
-- galería sin alt; g68…01 rocódromo publicado (regresión del CHECK en borradores). Medios b68…01 con alt, …02 sin alt.
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata) values
  ('media', 'b6800000-0000-4000-8000-000000000001/1-f68.jpg', '{"mimetype":"image/jpeg","size":700}'),
  ('media', 'b6800000-0000-4000-8000-000000000002/1-f68.jpg', '{"mimetype":"image/jpeg","size":700}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es) values
  ('b6800000-0000-4000-8000-000000000001', 'b6800000-0000-4000-8000-000000000001/1-f68.jpg', 'f68.jpg', 'image/jpeg', 1, 10, 10, 'Zapatilla resolada'),
  ('b6800000-0000-4000-8000-000000000002', 'b6800000-0000-4000-8000-000000000002/1-f68.jpg', 'f68.jpg', 'image/jpeg', 1, 10, 10, null);
insert into guide.criteria (id, category, key, name_es, name_en) values
  ('c6800000-0000-4000-8000-000000000001', 'resoler', 'rls_editor_quality', 'Calidad', 'Quality'),
  ('c6800000-0000-4000-8000-000000000002', 'gym', 'rls_editor_gymcrit', 'Criterio gym', 'Gym criterion');
-- F6.15b: r68…02 con portada con alt para que el paso 5 solo lo bloquee la galería sin alt (no items_z_publish_ready).
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f6800000-0000-4000-8000-000000000001', 'resoler', 'F68 resolador', 'rls-f68-resolador', true, null),
  ('f6800000-0000-4000-8000-000000000002', 'resoler', 'F68 oculto', 'rls-f68-oculto', false, 'b6800000-0000-4000-8000-000000000001'),
  ('f6800000-0000-4000-8000-000000000003', 'gym', 'F68 gym', 'rls-f68-gym', true, null);
insert into guide.resolers (item_id, services, turnaround_days_min, turnaround_days_max, price_per_pair_eur) values
  ('f6800000-0000-4000-8000-000000000001', '{half_sole}', 2, 5, 45),
  ('f6800000-0000-4000-8000-000000000002', '{}', null, null, null);
insert into guide.gyms (item_id) values ('f6800000-0000-4000-8000-000000000003');
insert into guide.author_reviews (id, item_id, category) values
  ('a6800000-0000-4000-8000-000000000001', 'f6800000-0000-4000-8000-000000000001', 'resoler');
insert into guide.item_media (item_id, media_id, sort_order) values
  ('f6800000-0000-4000-8000-000000000002', 'b6800000-0000-4000-8000-000000000002', 1);
select set_config('guide.draft_op', '', true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_row record;
  v_msg text;
  v_det text;
  v_r1  uuid := 'f6800000-0000-4000-8000-000000000001';
begin
  -- 1. Alta atómica con servicios; servicio inválido → 23514 y nada a medias
  select * into v_row from guide.create_item('resoler', 'F68 taller', 'rls-f68-taller',
    '{"services":["half_sole","rand"],"turnaround_days_min":2,"turnaround_days_max":5}');
  if not exists (select 1 from guide.resolers where item_id = v_row.id and services = '{half_sole,rand}'
                 and turnaround_days_max = 5) then
    raise exception 'FAIL F6.8 1a: create_item resoler'; end if;
  begin perform guide.create_item('resoler', 'F68 malo', 'rls-f68-malo', '{"services":["laser"]}');
    raise exception 'FAIL F6.8 1b: servicio inválido'; exception when check_violation then null; end;
  if exists (select 1 from guide.items where slug = 'rls-f68-malo') then
    raise exception 'FAIL F6.8 1b: alta a medias'; end if;

  -- 2. Publicado: servicios y demás en directo → PT423; sello de precios solo → permitido
  begin update guide.resolers set services = '{half_sole,rand}' where item_id = v_r1;
    raise exception 'FAIL F6.8 2a: servicios en directo'; exception when sqlstate 'PT423' then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det <> 'resolers: services' then raise exception 'FAIL F6.8 2a: detail (%)', v_det; end if;
  end;
  update guide.resolers set prices_verified_at = current_date where item_id = v_r1;
  begin update guide.resolers set prices_verified_at = current_date - 1, phone = '600000000' where item_id = v_r1;
    raise exception 'FAIL F6.8 2b: el sello no abre otras columnas'; exception when sqlstate 'PT423' then null; end;

  -- 3. Borrador: los CHECK se validan al guardar (fila guardada + parche)
  begin perform guide.save_draft('item', v_r1, '{"detail":{"services":["laser"]}}', guide.draft_entity_version('item', v_r1));
    raise exception 'FAIL F6.8 3a: servicio inválido en borrador'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: resolers_services_allowed' then raise exception 'FAIL F6.8 3a: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_r1, '{"detail":{"turnaround_days_min":9}}', guide.draft_entity_version('item', v_r1));
    raise exception 'FAIL F6.8 3b: plazo mínimo > máximo guardado'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: resolers_turnaround_range' then raise exception 'FAIL F6.8 3b: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_r1, '{"scores":{"c6800000-0000-4000-8000-000000000002":4}}', guide.draft_entity_version('item', v_r1));
    raise exception 'FAIL F6.8 3c: nota de criterio de rocódromo'; exception when invalid_parameter_value then null; end;
  begin insert into guide.content_drafts (entity, item_id, payload, base_updated_at)
        values ('item', v_r1, '{"detail":{"services":["laser"]}}', now());
    raise exception 'FAIL F6.8 3d: INSERT directo sin validar CHECK'; exception when check_violation then null; end;
  begin perform guide.save_draft('item', 'f6800000-0000-4000-8000-000000000003', '{"detail":{"grading_difficulty":6}}',
                                 guide.draft_entity_version('item', 'f6800000-0000-4000-8000-000000000003'));
    raise exception 'FAIL F6.8 3e: CHECK de gyms en borrador'; exception when check_violation then null; end;

  -- 4. Borrador completo de resolador → publish_draft aplica detalle, reseña, notas y galería
  perform guide.save_draft('item', v_r1,
    '{"item":{"summary_es":"Resolado en 48 h"},
      "detail":{"services":["half_sole","full_sole","stitching"],"turnaround_days_min":1,"turnaround_days_max":3,"price_per_pair_eur":42},
      "author_review":{"headline_es":"Rápidos y finos"},
      "scores":{"c6800000-0000-4000-8000-000000000001":4},
      "gallery":["b6800000-0000-4000-8000-000000000001"]}',
    guide.draft_entity_version('item', v_r1));
  perform guide.publish_draft('item', v_r1);
  if not exists (select 1 from guide.items i join guide.resolers r on r.item_id = i.id
                 join guide.author_reviews ar on ar.item_id = i.id
                 where i.id = v_r1 and i.published and i.summary_es = 'Resolado en 48 h'
                   and r.services = '{half_sole,full_sole,stitching}' and r.turnaround_days_max = 3 and r.price_per_pair_eur = 42
                   and ar.headline_es = 'Rápidos y finos')
     or (select score from guide.author_review_scores where review_id = 'a6800000-0000-4000-8000-000000000001'
         and criterion_id = 'c6800000-0000-4000-8000-000000000001') <> 4
     or not exists (select 1 from guide.item_media where item_id = v_r1 and media_id = 'b6800000-0000-4000-8000-000000000001') then
    raise exception 'FAIL F6.8 4: publish_draft de resolador'; end if;

  -- 5. D27 en resoladores: publicar con galería sin alt → PT422
  begin update guide.items set published = true where id = 'f6800000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.8 5: publica con galería sin alt'; exception when sqlstate 'PT422' then
      get stacked diagnostics v_det = pg_exception_detail;
      if (v_det::jsonb -> 'media_ids') <> '["b6800000-0000-4000-8000-000000000002"]'::jsonb then
        raise exception 'FAIL F6.8 5: details (%)', v_det; end if;
  end;

  -- 6. Ocultar con borrador pendiente
  perform guide.save_draft('item', v_r1, '{"detail":{"services":["half_sole"]}}', guide.draft_entity_version('item', v_r1));
  perform guide.unpublish_item(v_r1);
  if not exists (select 1 from guide.items i join guide.resolers r on r.item_id = i.id
                 where i.id = v_r1 and not i.published and r.services = '{half_sole}')
     or exists (select 1 from guide.content_drafts where item_id = v_r1) then
    raise exception 'FAIL F6.8 6: unpublish_item de resolador'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- 7. O5 (leona-lia): no admin (user1)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare
  v_n integer;
begin
  update guide.resolers set prices_verified_at = current_date where item_id = 'f6800000-0000-4000-8000-000000000002';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK F6.8 7a: un no admin sella precios'; end if;
  -- ficha no publicada (invisible por RLS) = inexistente: P0002, sin revelar que existe
  begin perform guide.draft_check_payload('item', 'f6800000-0000-4000-8000-000000000002', '{"item":{"name":"x"}}');
    raise exception 'LEAK F6.8 7b: valida sobre una ficha oculta'; exception when sqlstate 'P0002' then null; end;
  begin perform guide.draft_check_payload('item', 'f6800000-0000-4000-8000-0000000000ff', '{"item":{"name":"x"}}');
    raise exception 'FAIL F6.8 7b: uuid inexistente'; exception when sqlstate 'P0002' then null; end;
  begin perform guide.draft_check_payload('item', 'f6800000-0000-4000-8000-000000000003',
                                          '{"detail":{"x); drop table guide.items; --":1}}');
    raise exception 'LEAK F6.8 7c: clave de columna maliciosa'; exception when invalid_parameter_value then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- 8. Despublicar en directo con borrador pendiente → PT423 'pending draft' (el borrador no queda huérfano);
--    sin borrador sí; unpublish_item / unpublish_article siguen aplicándolo.
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_categories (id, name_es, slug_es) values ('c6800000-0000-4000-8000-0000000000a1', 'Cat F68', 'rls-f68-cat');
-- F6.15b: el paso 8 la republica sin mantenimiento → portada con alt (b68…01) y city.
insert into guide.items (id, category, name, slug, published, cover_media_id) values
  ('f6800000-0000-4000-8000-000000000004', 'resoler', 'F68 con borrador', 'rls-f68-con-borrador', true, 'b6800000-0000-4000-8000-000000000001');
insert into guide.resolers (item_id, city) values ('f6800000-0000-4000-8000-000000000004', 'Barcelona');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d6800000-0000-4000-8000-000000000001', 'c6800000-0000-4000-8000-0000000000a1', 'published', now() - interval '1 day', 'F68 vivo', 'rls-f68-vivo');
select set_config('guide.draft_op', '', true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_i   uuid := 'f6800000-0000-4000-8000-000000000004';
  v_a   uuid := 'd6800000-0000-4000-8000-000000000001';
  v_msg text;
  v_det text;
begin
  perform guide.save_draft('item', v_i, '{"item":{"summary_es":"pendiente"}}', guide.draft_entity_version('item', v_i));
  begin update guide.items set published = false where id = v_i;
    raise exception 'FAIL F6.8 8a: oculta en directo con borrador pendiente'; exception when sqlstate 'PT423' then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'pending draft' or v_det <> 'use unpublish_item' then raise exception 'FAIL F6.8 8a: error (% / %)', v_msg, v_det; end if;
  end;
  -- el GUC falsificado no exime (exige rolbypassrls)
  perform set_config('guide.unpublish_op', v_i::text, true);
  begin update guide.items set published = false where id = v_i;
    raise exception 'FAIL F6.8 8b: GUC falsificado exime'; exception when sqlstate 'PT423' then null; end;
  perform set_config('guide.unpublish_op', '', true);
  perform guide.unpublish_item(v_i);
  if not exists (select 1 from guide.items where id = v_i and not published and summary_es = 'pendiente')
     or exists (select 1 from guide.content_drafts where item_id = v_i) then
    raise exception 'FAIL F6.8 8c: unpublish_item con borrador'; end if;
  if (select count(*) from guide.activity_log where action = 'unpublish' and entity_id = v_i::text) <> 1
     or exists (select 1 from guide.activity_log where action = 'draft_publish' and entity_id = v_i::text) then
    raise exception 'FAIL F6.8 8c: registro'; end if;

  perform guide.save_draft('article', v_a, '{"article":{"excerpt_es":"pendiente"}}', guide.draft_entity_version('article', v_a));
  begin update guide.articles set status = 'draft', published_at = null where id = v_a;
    raise exception 'FAIL F6.8 8d: despublica en directo con borrador pendiente'; exception when sqlstate 'PT423' then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'pending draft' or v_det <> 'use unpublish_article' then raise exception 'FAIL F6.8 8d: error (% / %)', v_msg, v_det; end if;
  end;
  perform guide.unpublish_article(v_a);
  if not exists (select 1 from guide.articles where id = v_a and status = 'draft' and excerpt_es = 'pendiente')
     or exists (select 1 from guide.content_drafts where article_id = v_a)
     or (select count(*) from guide.activity_log where action = 'unpublish' and entity_id = v_a::text) <> 1 then
    raise exception 'FAIL F6.8 8e: unpublish_article con borrador'; end if;
  -- sin borrador, despublicar en directo sigue permitido
  update guide.articles set status = 'published' where id = v_a;
  update guide.articles set status = 'draft', published_at = null where id = v_a;
  update guide.items set published = true where id = v_i;
  update guide.items set published = false where id = v_i;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);


-- ═════════════ F6.9: pies de gato (create_item('shoe'), afiliado derivado y validado, precio con fecha, "Lo que aprendí") ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING: en la suite
-- completa ya existen (fixtures globales) y no se reinsertan (public intacto); solo, se crean y caen con el ROLLBACK.
-- Fixtures (como postgres, mantenimiento): s69…01 publicado con afiliado, precio fechado, autor con talla y "Lo que aprendí";
-- s69…02 no publicado con afiliado. Medios b69…01 con alt, …02 sin alt. Criterios propios (shoe y gym).
select set_config('guide.draft_op', 'maintenance', true);
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
do $$ begin
  if exists (select 1 from guide.admins where user_id = 'a0000000-0000-4000-8000-000000000002') then
    raise exception 'FAIL F6.9 fixtures: user1 es admin'; end if;
end $$;
insert into storage.objects (bucket_id, name, metadata) values
  ('media', 'b6900000-0000-4000-8000-000000000001/1-f69.jpg', '{"mimetype":"image/jpeg","size":700}'),
  ('media', 'b6900000-0000-4000-8000-000000000002/1-f69.jpg', '{"mimetype":"image/jpeg","size":700}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es) values
  ('b6900000-0000-4000-8000-000000000001', 'b6900000-0000-4000-8000-000000000001/1-f69.jpg', 'f69.jpg', 'image/jpeg', 1, 10, 10, 'Pie de gato en la presa'),
  ('b6900000-0000-4000-8000-000000000002', 'b6900000-0000-4000-8000-000000000002/1-f69.jpg', 'f69.jpg', 'image/jpeg', 1, 10, 10, null);
insert into guide.criteria (id, category, key, name_es, name_en) values
  ('c6900000-0000-4000-8000-000000000001', 'shoe', 'rls_shoe_editor_fit', 'Ajuste F69', 'Fit F69'),
  ('c6900000-0000-4000-8000-000000000002', 'gym', 'rls_shoe_editor_gym', 'Criterio gym F69', 'Gym criterion F69');
set constraints guide.items_shoe_require_brand_model deferred;  -- O1: ficha publicada antes que su detalle (FK)
insert into guide.items (id, category, name, slug, published) values
  ('f6900000-0000-4000-8000-000000000001', 'shoe', 'RLS F69 Publicado', 'rls-f69-publicado', true),
  ('f6900000-0000-4000-8000-000000000002', 'shoe', 'RLS F69 Oculto', 'rls-f69-oculto', false);
insert into guide.shoes (item_id, brand, model, price_min_eur, price_max_eur, price_checked_at, affiliate_url, affiliate_program,
                         owned_by_author, author_size_eu, author_street_size_eu) values
  ('f6900000-0000-4000-8000-000000000001', 'RLS F69', 'Publicado', 100, 120, '2026-09-01', 'https://www.example.com/aff?p=f69', 'Tienda F69',
   true, 41, 43),
  ('f6900000-0000-4000-8000-000000000002', 'RLS F69', 'Oculto', null, null, null, 'https://www.example.com/aff?p=oculto', null,
   false, null, null);
insert into guide.author_reviews (id, item_id, category, headline_es) values
  ('a6900000-0000-4000-8000-000000000001', 'f6900000-0000-4000-8000-000000000001', 'shoe', 'Lo que aprendí F69');
set constraints guide.items_shoe_require_brand_model immediate;
select set_config('guide.draft_op', '', true);

-- anon: lee lo publicado con su marca derivada; nada de lo oculto; no escribe ni llama a las RPC del panel
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_n integer;
begin
  if not exists (select 1 from guide.shoes where item_id = 'f6900000-0000-4000-8000-000000000001' and is_affiliate) then
    raise exception 'FAIL anon F6.9: no ve el pie de gato publicado con is_affiliate'; end if;
  if exists (select 1 from guide.shoes where item_id = 'f6900000-0000-4000-8000-000000000002') then
    raise exception 'LEAK anon F6.9: lee el detalle de un pie de gato oculto'; end if;
  begin update guide.shoes set affiliate_url = null where item_id = 'f6900000-0000-4000-8000-000000000001';
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'LEAK anon F6.9: quita el enlace de afiliado'; end if;
  exception when insufficient_privilege then null; end;
  begin perform guide.create_item('shoe', 'x', 'rls-f69-anon', '{"brand":"A","model":"B"}');
    raise exception 'LEAK anon F6.9: create_item'; exception when insufficient_privilege then null; end;
  begin perform guide.save_draft('item', 'f6900000-0000-4000-8000-000000000001', '{"detail":{"affiliate_url":null}}', now());
    raise exception 'LEAK anon F6.9: save_draft'; exception when insufficient_privilege then null; end;
  begin perform guide.shoe_model_taken('RLS F69', 'Oculto');
    raise exception 'LEAK anon F6.9: shoe_model_taken'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- no admin (user1): igual que anon; RLS deja 0 filas en UPDATE y rechaza el INSERT
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if exists (select 1 from guide.shoes where item_id = 'f6900000-0000-4000-8000-000000000002') then
    raise exception 'LEAK user F6.9: lee el detalle de un pie de gato oculto'; end if;
  update guide.shoes set affiliate_url = null, affiliate_program = null where item_id in
    ('f6900000-0000-4000-8000-000000000001', 'f6900000-0000-4000-8000-000000000002');
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user F6.9: edita el afiliado'; end if;
  update guide.shoes set price_checked_at = current_date where item_id = 'f6900000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user F6.9: sella el precio'; end if;
  begin perform guide.create_item('shoe', 'x', 'rls-f69-user', '{"brand":"A","model":"B"}');
    raise exception 'LEAK user F6.9: create_item'; exception when insufficient_privilege then null; end;
  begin perform guide.save_draft('item', 'f6900000-0000-4000-8000-000000000001', '{"detail":{"affiliate_url":null}}',
                                 guide.draft_entity_version('item', 'f6900000-0000-4000-8000-000000000001'));
    raise exception 'LEAK user F6.9: save_draft'; exception when insufficient_privilege then null; end;
  begin perform guide.unpublish_item('f6900000-0000-4000-8000-000000000001');
    raise exception 'LEAK user F6.9: unpublish_item'; exception when insufficient_privilege then null; end;
  -- revelaría que existe un modelo oculto
  begin perform guide.shoe_model_taken('RLS F69', 'Oculto');
    raise exception 'LEAK user F6.9: shoe_model_taken'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_row record;
  v_msg text;
  v_det text;
  v_p   uuid := 'f6900000-0000-4000-8000-000000000001';
  v_new uuid;
begin
  -- 1. create_item('shoe'): brand/model opcionales sin publicar; obligatorios al publicar (23514 shoes_brand_model_required);
  --    recortados y únicos sin distinguir mayúsculas; nada a medias
  select * into v_row from guide.create_item('shoe', 'RLS F69 Vacio', 'rls-f69-vacio');
  if not exists (select 1 from guide.shoes where item_id = v_row.id and brand is null and model is null) then
    raise exception 'FAIL F6.9 1a: alta sin marca/modelo'; end if;
  -- F6.15b: con portada (alt) para que solo bloquee marca/modelo (items_z_publish_ready exige cover)
  update guide.items set cover_media_id = 'b6900000-0000-4000-8000-000000000001' where id = v_row.id;
  begin update guide.items set published = true where id = v_row.id;
    raise exception 'FAIL F6.9 1a: publica sin marca/modelo'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_brand_model_required' then raise exception 'FAIL F6.9 1a: constraint (%)', v_msg; end if;
  end;
  update guide.shoes set brand = 'RLS F69' where item_id = v_row.id;
  begin update guide.items set published = true where id = v_row.id;
    raise exception 'FAIL F6.9 1a: publica sin modelo'; exception when check_violation then null; end;
  update guide.shoes set model = 'Vacio' where item_id = v_row.id;
  update guide.items set published = true where id = v_row.id;
  -- publicada: quitar la marca (como lo haría publish_draft, con su GUC) → 23514
  perform set_config('guide.draft_op', 'apply:' || v_row.id::text, true);
  begin update guide.shoes set brand = null where item_id = v_row.id;
    raise exception 'FAIL F6.9 1a: publicada sin marca'; exception when check_violation then null; end;
  perform set_config('guide.draft_op', '', true);
  perform guide.unpublish_item(v_row.id);
  update guide.shoes set brand = null, model = null where item_id = v_row.id;
  -- O1 (leona-lia): sin fila de detalle también es incompleta → 23514 (ficha publicada sin shoes; detalle borrado y publicar)
  begin insert into guide.items (id, category, name, slug, published, cover_media_id)
        values ('f6900000-0000-4000-8000-0000000000a1', 'shoe', 'RLS F69 Sin detalle', 'rls-f69-sin-detalle', true,
                'b6900000-0000-4000-8000-000000000001');
    raise exception 'FAIL F6.9 O1a: ficha shoe publicada sin detalle'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_brand_model_required' then raise exception 'FAIL F6.9 O1a: constraint (%)', v_msg; end if;
  end;
  delete from guide.shoes where item_id = v_row.id;
  begin update guide.items set published = true where id = v_row.id;
    raise exception 'FAIL F6.9 O1b: publica tras borrar el detalle'; exception when check_violation then null; end;
  if exists (select 1 from guide.items where id in (v_row.id, 'f6900000-0000-4000-8000-0000000000a1') and published) then
    raise exception 'FAIL F6.9 O1: quedó publicada'; end if;
  -- O2 (leona-lia): espacios e invisibles Unicode en los extremos (NBSP, ZWSP, BOM), también en el borrador
  begin perform guide.create_item('shoe', 'F69 nbsp', 'rls-f69-sin-modelo', jsonb_build_object('brand', 'RLS F69' || chr(160), 'model', 'M'));
    raise exception 'FAIL F6.9 O2a: marca con NBSP final'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_brand_trimmed' then raise exception 'FAIL F6.9 O2a: constraint (%)', v_msg; end if;
  end;
  begin perform guide.create_item('shoe', 'F69 zwsp', 'rls-f69-sin-modelo', jsonb_build_object('brand', 'RLS F69', 'model', chr(8203) || 'M'));
    raise exception 'FAIL F6.9 O2b: modelo con ZWSP inicial'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_model_trimmed' then raise exception 'FAIL F6.9 O2b: constraint (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_p, jsonb_build_object('detail', jsonb_build_object('model', 'Publicado' || chr(65279))),
                                 guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 O2c: BOM final en borrador'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: shoes_model_trimmed' then raise exception 'FAIL F6.9 O2c: mensaje (%)', v_msg; end if;
  end;
  -- aviso de duplicado (mismo criterio que shoes_brand_model_key)
  if not guide.shoe_model_taken(' rls f69 ', 'PUBLICADO')
     or guide.shoe_model_taken('RLS F69', 'Publicado', v_p)
     or guide.shoe_model_taken('RLS F69', 'Inexistente')
     or guide.shoe_model_taken(null, 'Publicado') then
    raise exception 'FAIL F6.9 1a: shoe_model_taken'; end if;
  begin perform guide.create_item('shoe', 'F69 vacio', 'rls-f69-sin-modelo', '{"brand":"","model":"X"}');
    raise exception 'FAIL F6.9 1b: brand vacío'; exception when check_violation then null; end;
  begin perform guide.create_item('shoe', 'F69 espacios', 'rls-f69-sin-modelo', '{"brand":" RLS F69","model":"Nuevo"}');
    raise exception 'FAIL F6.9 1b: brand sin recortar'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_brand_trimmed' then raise exception 'FAIL F6.9 1b: constraint (%)', v_msg; end if;
  end;
  begin perform guide.create_item('shoe', 'F69 duplicado', 'rls-f69-sin-modelo', '{"brand":"rls f69","model":"PUBLICADO"}');
    raise exception 'FAIL F6.9 1c: marca+modelo duplicados'; exception when unique_violation then null; end;
  begin perform guide.create_item('shoe', 'F69 marca', 'rls-f69-sin-modelo', '{"brand":"RLS F69","model":"M","is_affiliate":false}');
    raise exception 'FAIL F6.9 1d: is_affiliate en p_detail'; exception when invalid_parameter_value then null; end;
  begin perform guide.create_item('shoe', 'F69 enum', 'rls-f69-sin-modelo', '{"brand":"RLS F69","model":"M","closure":"zip"}');
    raise exception 'FAIL F6.9 1e: cierre inválido'; exception when check_violation then null; end;
  begin perform guide.create_item('shoe', 'F69 uso', 'rls-f69-sin-modelo', '{"brand":"RLS F69","model":"M","recommended_use":["ice"]}');
    raise exception 'FAIL F6.9 1e: uso inválido'; exception when check_violation then null; end;
  begin perform guide.create_item('shoe', 'F69 talla', 'rls-f69-sin-modelo', '{"brand":"RLS F69","model":"M","owned_by_author":true,"author_size_eu":41.3}');
    raise exception 'FAIL F6.9 1e: talla fuera de paso 0,5'; exception when check_violation then null; end;
  begin perform guide.create_item('shoe', 'F69 talla', 'rls-f69-sin-modelo', '{"brand":"RLS F69","model":"M","author_size_eu":41}');
    raise exception 'FAIL F6.9 1e: talla sin tenerlo el autor'; exception when check_violation then null; end;
  if exists (select 1 from guide.items where slug like 'rls-f69-sin-modelo%') then
    raise exception 'FAIL F6.9 1: alta a medias'; end if;

  -- alta completa con toda la lista blanca de shoes
  select * into v_row from guide.create_item('shoe', 'RLS F69 Nuevo', 'rls-f69-nuevo',
    '{"brand":"RLS F69","model":"Nuevo","fit":"women","profile":"moderate","asymmetry":"slight","closure":"lace",
      "rubber":"Vibram XS Edge","rubber_thickness_mm":4,"stiffness":4,"recommended_use":["gym","sport"],"levels":["beginner"],
      "price_min_eur":90,"price_max_eur":110,"price_checked_at":"2026-10-01",
      "affiliate_url":"https://www.example.com/aff?p=nuevo&utm_source=chalkguide","affiliate_program":"Tienda",
      "owned_by_author":true,"author_size_eu":41.5,"author_street_size_eu":43,"author_size_note_es":"Justos","author_size_note_en":"Snug"}');
  v_new := v_row.id;
  if not exists (select 1 from guide.items i join guide.shoes s on s.item_id = i.id
                 where i.id = v_new and not i.published and s.is_affiliate and s.fit = 'women' and s.author_size_eu = 41.5) then
    raise exception 'FAIL F6.9 1f: create_item shoe completo'; end if;

  -- 2. Afiliado: la marca es derivada (no editable) y la URL se valida (borrador no publicado: edición directa)
  begin update guide.shoes set is_affiliate = false where item_id = v_new;
    raise exception 'FAIL F6.9 2a: is_affiliate editable'; exception when sqlstate '428C9' then null; end;
  begin update guide.shoes set affiliate_url = 'javascript:alert(1)' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: javascript:'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = 'http://www.example.com/aff' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: http'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = 'https://www.example.com@evil.example/aff' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: userinfo'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = 'https://www.example.com/"><script>' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: comillas y <>'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = E'https://www.example.com/\u202Egnp' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: Unicode invisible'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = 'https://' where item_id = v_new;
    raise exception 'FAIL F6.9 2b: sin host'; exception when check_violation then null; end;
  begin update guide.shoes set affiliate_url = null where item_id = v_new;
    raise exception 'FAIL F6.9 2c: programa sin enlace'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_affiliate_program_needs_url' then raise exception 'FAIL F6.9 2c: constraint (%)', v_msg; end if;
  end;
  update guide.shoes set affiliate_url = null, affiliate_program = null where item_id = v_new;
  if (select is_affiliate from guide.shoes where item_id = v_new) then
    raise exception 'FAIL F6.9 2d: sin enlace sigue marcado'; end if;
  update guide.shoes set affiliate_url = 'https://www.example.com/aff?p=nuevo' where item_id = v_new;
  if not (select is_affiliate from guide.shoes where item_id = v_new) then
    raise exception 'FAIL F6.9 2d: con enlace no queda marcado'; end if;
  begin update guide.shoes set price_checked_at = null where item_id = v_new;
    raise exception 'FAIL F6.9 2e: precio sin fecha'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_price_dated' then raise exception 'FAIL F6.9 2e: constraint (%)', v_msg; end if;
  end;

  -- 3. Publicado: en directo PT423 salvo el sello de precio solo
  begin update guide.shoes set affiliate_url = 'https://www.example.com/otra' where item_id = v_p;
    raise exception 'FAIL F6.9 3a: afiliado en directo'; exception when sqlstate 'PT423' then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det <> 'shoes: affiliate_url' then raise exception 'FAIL F6.9 3a: detail (%)', v_det; end if;
  end;
  update guide.shoes set price_checked_at = current_date where item_id = v_p;
  begin update guide.shoes set price_checked_at = current_date, price_min_eur = 95 where item_id = v_p;
    raise exception 'FAIL F6.9 3b: el sello no abre el precio'; exception when sqlstate 'PT423' then null; end;
  begin update guide.shoes set price_checked_at = null where item_id = v_p;
    raise exception 'FAIL F6.9 3b: el sello deja el precio sin fecha'; exception when check_violation then null; end;
  begin update guide.author_reviews set headline_es = 'en directo' where item_id = v_p;
    raise exception 'FAIL F6.9 3c: "Lo que aprendí" en directo'; exception when sqlstate 'PT423' then null; end;

  -- 4. Borrador: lista blanca y CHECK del detalle al guardar
  begin perform guide.save_draft('item', v_p, '{"detail":{"is_affiliate":false}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4a: is_affiliate en borrador'; exception when invalid_parameter_value then null; end;
  begin perform guide.save_draft('item', v_p, '{"detail":{"affiliate_url":"javascript:alert(1)"}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4b: javascript: en borrador'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: shoes_affiliate_url_check' then raise exception 'FAIL F6.9 4b: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_p, '{"detail":{"affiliate_url":null}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4c: quita el enlace dejando el programa'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: shoes_affiliate_program_needs_url' then raise exception 'FAIL F6.9 4c: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_p, '{"detail":{"price_max_eur":130,"price_checked_at":null}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4d: precio sin fecha en borrador'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: shoes_price_dated' then raise exception 'FAIL F6.9 4d: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_p, '{"detail":{"owned_by_author":false}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4e: deja de tenerlo con tallas'; exception when check_violation then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'check violation: shoes_author_sizes_owned' then raise exception 'FAIL F6.9 4e: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.save_draft('item', v_p, '{"scores":{"c6900000-0000-4000-8000-000000000002":4}}', guide.draft_entity_version('item', v_p));
    raise exception 'FAIL F6.9 4f: nota de criterio de rocódromo'; exception when invalid_parameter_value then null; end;
  -- vaciar la marca de una publicada: el borrador se guarda (columna nullable), publicar → 23514 y nada a medias
  perform guide.save_draft('item', v_p, '{"item":{"summary_es":"sin marca"},"detail":{"brand":null}}', guide.draft_entity_version('item', v_p));
  begin perform guide.publish_draft('item', v_p);
    raise exception 'FAIL F6.9 4g: publica sin marca'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'shoes_brand_model_required' then raise exception 'FAIL F6.9 4g: constraint (%)', v_msg; end if;
  end;
  if (select summary_es from guide.items where id = v_p) is not null or (select brand from guide.shoes where item_id = v_p) <> 'RLS F69' then
    raise exception 'FAIL F6.9 4g: publicación a medias'; end if;
  perform guide.discard_draft('item', v_p);

  -- 5. "Lo que aprendí" (author_reviews) en el borrador: D27 al publicar (imagen sin alt → PT422, todo se revierte)
  perform guide.save_draft('item', v_p,
    '{"author_review":{"headline_es":"Aprendí F69","body_json_es":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b6900000-0000-4000-8000-000000000002"}}]},"body_html_es":"<p>x</p>"}}',
    guide.draft_entity_version('item', v_p));
  begin perform guide.publish_draft('item', v_p);
    raise exception 'FAIL F6.9 5a: publica "Lo que aprendí" con imagen sin alt'; exception when sqlstate 'PT422' then null; end;
  if (select headline_es from guide.author_reviews where item_id = v_p) <> 'Lo que aprendí F69' then
    raise exception 'FAIL F6.9 5a: publicación a medias'; end if;

  -- 6. Borrador completo: detalle (afiliado, precio), "Lo que aprendí", notas y galería → publish_draft
  perform guide.save_draft('item', v_p,
    '{"detail":{"affiliate_url":"https://www.example.com/aff?p=f69-v2","affiliate_program":"Tienda F69 v2",
                "price_min_eur":95,"price_max_eur":115,"price_checked_at":"2026-10-20","author_size_note_es":"Medio número menos"},
      "author_review":{"headline_es":"Aprendí F69","body_json_es":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b6900000-0000-4000-8000-000000000001"}}]},"body_html_es":"<p>x</p>"},
      "scores":{"c6900000-0000-4000-8000-000000000001":5},
      "gallery":["b6900000-0000-4000-8000-000000000001"]}',
    guide.draft_entity_version('item', v_p));
  perform guide.publish_draft('item', v_p);
  if not exists (select 1 from guide.items i join guide.shoes s on s.item_id = i.id join guide.author_reviews r on r.item_id = i.id
                 where i.id = v_p and i.published and s.is_affiliate and s.affiliate_program = 'Tienda F69 v2'
                   and s.price_min_eur = 95 and s.price_checked_at = '2026-10-20' and r.headline_es = 'Aprendí F69')
     or (select score from guide.author_review_scores where review_id = 'a6900000-0000-4000-8000-000000000001'
         and criterion_id = 'c6900000-0000-4000-8000-000000000001') <> 5
     or not exists (select 1 from guide.item_media where item_id = v_p and media_id = 'b6900000-0000-4000-8000-000000000001') then
    raise exception 'FAIL F6.9 6: publish_draft de pie de gato'; end if;

  -- 7. Quitar el afiliado vía borrador (enlace y programa juntos) → la marca cae sola
  perform guide.save_draft('item', v_p, '{"detail":{"affiliate_url":null,"affiliate_program":null}}', guide.draft_entity_version('item', v_p));
  perform guide.publish_draft('item', v_p);
  if (select is_affiliate from guide.shoes where item_id = v_p) then
    raise exception 'FAIL F6.9 7: sin enlace sigue marcado tras publicar'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);


-- ═════════════ F6.10: criterios de nota (crear/editar ES-EN, activar, ordenar, borrar sin notas, fórmulas) ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING.
-- Fixtures (como postgres, mantenimiento): ficha gym publicada f610…01 con reseña del autor y notas en c610…01 (4),
-- c610…08 (2) y c610…03 (2, criterio inactivo); opinión visible de user1 con nota en c610…05. c610…02 y c610…06 sin
-- notas; la opinión de user1 puntúa también c610…08 (3); c610…07 inactivo sin notas; c610…04 de shoe. family_friendly/beginner_friendly (gym) si no existen.
-- f610…02 gym no publicada con reseña a610…02 y nota guardada (3) en el inactivo c610…03 (mantenimiento).
select set_config('guide.draft_op', 'maintenance', true);
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
do $$ begin
  if exists (select 1 from guide.admins where user_id = 'a0000000-0000-4000-8000-000000000002') then
    raise exception 'FAIL F6.10 fixtures: user1 es admin'; end if;
end $$;
insert into guide.criteria (id, category, key, name_es, name_en)
select 'c6100000-0000-4000-8000-00000000000f', 'gym', 'family_friendly', 'Para familias', 'Family friendly'
where not exists (select 1 from guide.criteria where category = 'gym' and key = 'family_friendly');
insert into guide.criteria (id, category, key, name_es, name_en)
select 'c6100000-0000-4000-8000-00000000000e', 'gym', 'beginner_friendly', 'Para principiantes', 'Beginner friendly'
where not exists (select 1 from guide.criteria where category = 'gym' and key = 'beginner_friendly');
insert into guide.criteria (id, category, key, name_es, name_en, is_active) values
  ('c6100000-0000-4000-8000-000000000001', 'gym', 'rls_f610_a', 'Con nota del autor', 'Author scored', true),
  ('c6100000-0000-4000-8000-000000000002', 'gym', 'rls_f610_b', 'Sin notas', 'No scores', true),
  ('c6100000-0000-4000-8000-000000000003', 'gym', 'rls_f610_c', 'Inactivo con nota', 'Inactive scored', false),
  ('c6100000-0000-4000-8000-000000000004', 'shoe', 'rls_f610_shoe', 'De pies de gato', 'Shoe one', true),
  ('c6100000-0000-4000-8000-000000000005', 'gym', 'rls_f610_user', 'Con nota de usuario', 'User scored', true),
  ('c6100000-0000-4000-8000-000000000006', 'gym', 'rls_f610_draft', 'En borrador', 'In draft', true),
  ('c6100000-0000-4000-8000-000000000007', 'gym', 'rls_f610_off', 'Inactivo sin notas', 'Inactive unscored', false),
  ('c6100000-0000-4000-8000-000000000008', 'gym', 'rls_f610_d', 'Segunda nota', 'Second score', true);
insert into guide.items (id, category, name, slug, published) values
  ('f6100000-0000-4000-8000-000000000001', 'gym', 'RLS F610 Gym', 'rls-f610-gym', true),
  ('f6100000-0000-4000-8000-000000000002', 'gym', 'RLS F610 Oculta', 'rls-f610-oculta', false);
insert into guide.gyms (item_id) values ('f6100000-0000-4000-8000-000000000001'), ('f6100000-0000-4000-8000-000000000002');
insert into guide.author_reviews (id, item_id, category) values
  ('a6100000-0000-4000-8000-000000000001', 'f6100000-0000-4000-8000-000000000001', 'gym'),
  ('a6100000-0000-4000-8000-000000000002', 'f6100000-0000-4000-8000-000000000002', 'gym');
insert into guide.author_review_scores (review_id, criterion_id, category, score) values
  ('a6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000001', 'gym', 4),
  ('a6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000008', 'gym', 2),
  ('a6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000003', 'gym', 2),
  ('a6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000003', 'gym', 3);
insert into guide.user_reviews (id, item_id, category, user_id, overall_score, status) values
  ('e6100000-0000-4000-8000-000000000001', 'f6100000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000002', 4, 'visible');
insert into guide.user_review_scores (review_id, criterion_id, category, score) values
  ('e6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000005', 'gym', 5),
  ('e6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000008', 'gym', 3);
select set_config('guide.draft_op', '', true);

-- anon: lee activos (no inactivos) y su marca de fórmula; no escribe ni reordena; la media pública ignora inactivos
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_n integer;
begin
  if not exists (select 1 from guide.criteria where id = 'c6100000-0000-4000-8000-000000000001') then
    raise exception 'FAIL anon F6.10: no ve un criterio activo'; end if;
  if exists (select 1 from guide.criteria where id in ('c6100000-0000-4000-8000-000000000003', 'c6100000-0000-4000-8000-000000000007')) then
    raise exception 'LEAK anon F6.10: ve criterios inactivos'; end if;
  if not exists (select 1 from guide.criteria where category = 'gym' and key = 'family_friendly' and used_in_formula) then
    raise exception 'FAIL anon F6.10: used_in_formula'; end if;
  if (select count(*) from guide.item_author_scores where item_id = 'f6100000-0000-4000-8000-000000000001') <> 2
     or (select max(avg_overall) from guide.item_author_scores where item_id = 'f6100000-0000-4000-8000-000000000001') <> 3.00 then
    raise exception 'FAIL anon F6.10: item_author_scores con inactivos'; end if;
  -- O2: tampoco en la tabla base (ficha publicada; la nota del activo sí se ve)
  if exists (select 1 from guide.author_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000003')
     or not exists (select 1 from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
                    and criterion_id = 'c6100000-0000-4000-8000-000000000001') then
    raise exception 'LEAK anon F6.10 O2: notas de criterio inactivo en author_review_scores'; end if;
  if not exists (select 1 from guide.user_review_scores where review_id = 'e6100000-0000-4000-8000-000000000001'
                 and criterion_id = 'c6100000-0000-4000-8000-000000000005') then
    raise exception 'FAIL anon F6.10 O2: no ve la nota de usuario de un criterio activo'; end if;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_anon', 'x', 'x');
    raise exception 'LEAK anon F6.10: crea criterio'; exception when insufficient_privilege then null; end;
  begin update guide.criteria set is_active = false where id = 'c6100000-0000-4000-8000-000000000001';
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'LEAK anon F6.10: desactiva criterio'; end if;
  exception when insufficient_privilege then null; end;
  begin delete from guide.criteria where id = 'c6100000-0000-4000-8000-000000000002';
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'LEAK anon F6.10: borra criterio'; end if;
  exception when insufficient_privilege then null; end;
  begin perform guide.reorder_criteria('gym', array['c6100000-0000-4000-8000-000000000001']::uuid[]);
    raise exception 'LEAK anon F6.10: reorder_criteria'; exception when insufficient_privilege then null; end;
  begin perform guide.criteria_usage('gym');
    raise exception 'LEAK anon F6.10: criteria_usage'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- no admin (user1): igual que anon; RLS deja 0 filas en UPDATE/DELETE y rechaza el INSERT
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if exists (select 1 from guide.criteria where id in ('c6100000-0000-4000-8000-000000000003', 'c6100000-0000-4000-8000-000000000007')) then
    raise exception 'LEAK user F6.10: ve criterios inactivos'; end if;
  if exists (select 1 from guide.author_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000003') then
    raise exception 'LEAK user F6.10 O2: notas de criterio inactivo en author_review_scores'; end if;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_user1', 'x', 'x');
    raise exception 'LEAK user F6.10: crea criterio'; exception when insufficient_privilege then null; end;
  update guide.criteria set name_es = 'hackeado', is_active = false
  where id in ('c6100000-0000-4000-8000-000000000001', 'c6100000-0000-4000-8000-000000000003');
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user F6.10: edita criterios'; end if;
  delete from guide.criteria where id in ('c6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000007');
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user F6.10: borra criterios'; end if;
  begin perform guide.reorder_criteria('gym', array['c6100000-0000-4000-8000-000000000001']::uuid[]);
    raise exception 'LEAK user F6.10: reorder_criteria'; exception when insufficient_privilege then null; end;
  begin perform guide.criteria_usage('gym');
    raise exception 'LEAK user F6.10: criteria_usage'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_msg  text;
  v_det  text;
  v_id   uuid;
  v_fam  uuid := (select id from guide.criteria where category = 'gym' and key = 'family_friendly');
  v_beg  uuid := (select id from guide.criteria where category = 'gym' and key = 'beginner_friendly');
  v_item uuid := 'f6100000-0000-4000-8000-000000000001';
  v_ids  uuid[];
  v_log  bigint;
  v_srt  bigint;
  v_chg  bigint;
begin
  -- 1. RLS: el admin ve también los inactivos
  if (select count(*) from guide.criteria where id in ('c6100000-0000-4000-8000-000000000003', 'c6100000-0000-4000-8000-000000000007')) <> 2 then
    raise exception 'FAIL F6.10 1: admin no ve inactivos'; end if;
  if (select count(*) from guide.author_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000003') <> 2 then
    raise exception 'FAIL F6.10 1 O2: admin no ve las notas de un inactivo'; end if;

  -- 2. Crear: al final de su categoría; validación de key, nombres, descripciones y categoría
  insert into guide.criteria (category, key, name_es, name_en, description_es)
  values ('gym', 'rls_f610_new2', 'Nuevo', 'New', 'Descripción') returning id into v_id;
  if (select sort_order from guide.criteria where id = v_id)
     <> (select max(sort_order) from guide.criteria where category = 'gym')
     or (select count(*) from guide.criteria where category = 'gym'
         and sort_order = (select sort_order from guide.criteria where id = v_id)) <> 1
     or (select used_in_formula from guide.criteria where id = v_id) then
    raise exception 'FAIL F6.10 2a: alta al final de la categoría'; end if;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'Rls_f610', 'x', 'x');
    raise exception 'FAIL F6.10 2b: key con mayúsculas'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'criteria_key_check' then raise exception 'FAIL F6.10 2b: constraint (%)', v_msg; end if;
  end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls__f610', 'x', 'x');
    raise exception 'FAIL F6.10 2b: key con __'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_', 'x', 'x');
    raise exception 'FAIL F6.10 2b: key acabada en _'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', '9rls', 'x', 'x');
    raise exception 'FAIL F6.10 2b: key empieza por dígito'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'r', 'x', 'x');
    raise exception 'FAIL F6.10 2b: key de 1 carácter'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_' || repeat('a', 37), 'x', 'x');
    raise exception 'FAIL F6.10 2b: key de 41'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', 'x', null);
    raise exception 'FAIL F6.10 2c: sin name_en'; exception when not_null_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', '', 'x');
    raise exception 'FAIL F6.10 2c: name_es vacío'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', repeat('a', 81), 'x');
    raise exception 'FAIL F6.10 2c: name_es de 81'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', 'Nombre' || chr(160), 'x');
    raise exception 'FAIL F6.10 2c: name_es con NBSP final'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'criteria_name_es_trimmed' then raise exception 'FAIL F6.10 2c: constraint (%)', v_msg; end if;
  end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', 'x', chr(8203) || 'Name');
    raise exception 'FAIL F6.10 2c: name_en con ZWSP inicial'; exception when check_violation then
      get stacked diagnostics v_msg = constraint_name;
      if v_msg <> 'criteria_name_en_trimmed' then raise exception 'FAIL F6.10 2c: constraint (%)', v_msg; end if;
  end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_x', E'Dos\nlíneas', 'x');
    raise exception 'FAIL F6.10 2c: name_es con salto de línea'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en, description_en) values ('gym', 'rls_f610_x', 'x', 'x', '');
    raise exception 'FAIL F6.10 2d: descripción vacía'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en, description_es) values ('gym', 'rls_f610_x', 'x', 'x', repeat('a', 301));
    raise exception 'FAIL F6.10 2d: descripción de 301'; exception when check_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('rope', 'rls_f610_x', 'x', 'x');
    raise exception 'FAIL F6.10 2e: categoría inexistente'; exception when foreign_key_violation then null; end;
  begin insert into guide.criteria (category, key, name_es, name_en) values ('gym', 'rls_f610_a', 'x', 'x');
    raise exception 'FAIL F6.10 2f: key repetida en la categoría'; exception when unique_violation then null; end;
  insert into guide.criteria (category, key, name_es, name_en) values ('shoe', 'rls_f610_a', 'Misma key', 'Same key');
  begin insert into guide.criteria (category, key, name_es, name_en, used_in_formula) values ('gym', 'rls_f610_x', 'x', 'x', true);
    raise exception 'FAIL F6.10 2g: used_in_formula escribible'; exception when sqlstate '428C9' then null; end;

  -- 3. Editar: nombres y descripciones sí; id, categoría y key inmutables (22023)
  update guide.criteria set name_es = 'Renombrado', name_en = 'Renamed', description_es = 'Otra', description_en = 'Other'
  where id = 'c6100000-0000-4000-8000-000000000001';
  if not exists (select 1 from guide.item_author_scores where criterion_id = 'c6100000-0000-4000-8000-000000000001' and name_en = 'Renamed') then
    raise exception 'FAIL F6.10 3a: renombrar'; end if;
  begin update guide.criteria set key = 'rls_f610_z' where id = 'c6100000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.10 3b: cambia la key'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'criterion key is immutable' then raise exception 'FAIL F6.10 3b: mensaje (%)', v_msg; end if;
  end;
  begin update guide.criteria set category = 'resoler' where id = 'c6100000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.10 3c: cambia la categoría'; exception when invalid_parameter_value then null; end;
  begin update guide.criteria set id = gen_random_uuid() where id = 'c6100000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.10 3d: cambia el id'; exception when invalid_parameter_value then null; end;
  begin update guide.criteria set used_in_formula = true where id = 'c6100000-0000-4000-8000-000000000002';
    raise exception 'FAIL F6.10 3e: used_in_formula escribible'; exception when sqlstate '428C9' then null; end;

  -- 4. Fórmulas: family_friendly y beginner_friendly marcados; no se desactivan, no se borran, key fija;
  --    el GUC de mantenimiento no exime a un cliente (sin bypassrls)
  if v_fam is null or v_beg is null
     or not (select bool_and(used_in_formula) from guide.criteria where id in (v_fam, v_beg))
     or exists (select 1 from guide.criteria where used_in_formula and not (category = 'gym' and key in ('family_friendly', 'beginner_friendly'))) then
    raise exception 'FAIL F6.10 4a: used_in_formula'; end if;
  begin update guide.criteria set is_active = false where id = v_fam;
    raise exception 'FAIL F6.10 4b: desactiva family_friendly'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'criterion used by an index formula' or v_det <> 'gym.family_friendly' then
        raise exception 'FAIL F6.10 4b: mensaje (%, %)', v_msg, v_det; end if;
  end;
  begin update guide.criteria set is_active = false where id = v_beg;
    raise exception 'FAIL F6.10 4b: desactiva beginner_friendly'; exception when invalid_parameter_value then null; end;
  begin update guide.criteria set key = 'family' where id = v_fam;
    raise exception 'FAIL F6.10 4c: cambia la key de una fórmula'; exception when invalid_parameter_value then null; end;
  begin delete from guide.criteria where id = v_fam;
    raise exception 'FAIL F6.10 4d: borra family_friendly'; exception when invalid_parameter_value then null; end;
  perform set_config('guide.draft_op', 'maintenance', true);
  begin update guide.criteria set is_active = false where id = v_beg;
    raise exception 'FAIL F6.10 4e: mantenimiento sin bypassrls'; exception when invalid_parameter_value then null; end;
  perform set_config('guide.draft_op', '', true);
  if not (select bool_and(is_active) from guide.criteria where id in (v_fam, v_beg)) then
    raise exception 'FAIL F6.10 4: fórmula desactivada'; end if;

  -- 5. Borrar: con notas (autor, usuarios o borradores) → 23503 con detalle; sin notas se borra (con actividad)
  begin delete from guide.criteria where id = 'c6100000-0000-4000-8000-000000000001';
    raise exception 'FAIL F6.10 5a: borra con nota del autor'; exception when foreign_key_violation then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'criterion has scores' or v_det <> 'author_review_scores: 1, user_review_scores: 0, content_drafts: 0' then
        raise exception 'FAIL F6.10 5a: mensaje (%, %)', v_msg, v_det; end if;
  end;
  begin delete from guide.criteria where id = 'c6100000-0000-4000-8000-000000000003';
    raise exception 'FAIL F6.10 5a: borra inactivo con nota'; exception when foreign_key_violation then null; end;
  begin delete from guide.criteria where id = 'c6100000-0000-4000-8000-000000000005';
    raise exception 'FAIL F6.10 5b: borra con nota de usuario'; exception when foreign_key_violation then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det <> 'author_review_scores: 0, user_review_scores: 1, content_drafts: 0' then
        raise exception 'FAIL F6.10 5b: detail (%)', v_det; end if;
  end;
  -- borrador de la ficha publicada con nota nueva en c610…06 (y las guardadas, incluida la del inactivo c610…03)
  perform guide.save_draft('item', v_item,
    '{"scores":{"c6100000-0000-4000-8000-000000000001":4,"c6100000-0000-4000-8000-000000000008":2,
                "c6100000-0000-4000-8000-000000000003":2,"c6100000-0000-4000-8000-000000000006":3}}',
    guide.draft_entity_version('item', v_item));
  begin delete from guide.criteria where id = 'c6100000-0000-4000-8000-000000000006';
    raise exception 'FAIL F6.10 5c: borra criterio citado en un borrador'; exception when foreign_key_violation then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det <> 'author_review_scores: 0, user_review_scores: 0, content_drafts: 1' then
        raise exception 'FAIL F6.10 5c: detail (%)', v_det; end if;
  end;
  select count(*) into v_log from guide.activity_log where entity_table = 'criteria' and action = 'delete'
    and entity_id = 'c6100000-0000-4000-8000-000000000002';
  delete from guide.criteria where id in ('c6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000007');
  if exists (select 1 from guide.criteria where id in ('c6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000007'))
     or (select count(*) from guide.activity_log where entity_table = 'criteria' and action = 'delete'
         and entity_id = 'c6100000-0000-4000-8000-000000000002' and old_row ->> 'key' = 'rls_f610_b') <> v_log + 1 then
    raise exception 'FAIL F6.10 5d: borrar sin notas (o su actividad)'; end if;

  -- 6. Borrador: un criterio inactivo conserva la nota guardada (5c ya lo guardó) pero no admite una nueva;
  --    otra categoría → 22023 con su detalle. Publicar conserva la nota del inactivo.
  update guide.criteria set is_active = false where id = 'c6100000-0000-4000-8000-000000000005';  -- con nota de usuario: se desactiva
  if not exists (select 1 from guide.user_review_scores where review_id = 'e6100000-0000-4000-8000-000000000001'
                 and criterion_id = 'c6100000-0000-4000-8000-000000000005') then
    raise exception 'FAIL F6.10 6 O2: admin no ve la nota de usuario de un inactivo'; end if;
  insert into guide.criteria (id, category, key, name_es, name_en, is_active)
  values ('c6100000-0000-4000-8000-000000000009', 'gym', 'rls_f610_off2', 'Inactivo nuevo', 'Inactive new', false);
  begin perform guide.save_draft('item', v_item,
      '{"scores":{"c6100000-0000-4000-8000-000000000001":4,"c6100000-0000-4000-8000-000000000009":3}}',
      guide.draft_entity_version('item', v_item));
    raise exception 'FAIL F6.10 6a: nota nueva en criterio inactivo'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'invalid section: scores' or v_det <> 'inactive criterion' then
        raise exception 'FAIL F6.10 6a: mensaje (%, %)', v_msg, v_det; end if;
  end;
  begin perform guide.save_draft('item', v_item, '{"scores":{"c6100000-0000-4000-8000-000000000004":3}}',
      guide.draft_entity_version('item', v_item));
    raise exception 'FAIL F6.10 6b: nota de criterio de otra categoría'; exception when invalid_parameter_value then
      get stacked diagnostics v_det = pg_exception_detail;
      if v_det <> 'criterion not in category' then raise exception 'FAIL F6.10 6b: detail (%)', v_det; end if;
  end;
  perform guide.publish_draft('item', v_item);
  if (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
      and criterion_id = 'c6100000-0000-4000-8000-000000000003') <> 2
     or (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
         and criterion_id = 'c6100000-0000-4000-8000-000000000006') <> 3 then
    raise exception 'FAIL F6.10 6c: publicar con nota de inactivo guardada'; end if;

  -- 7. Desactivar con notas en una ficha publicada: sale de la media pública (igual para admin y anon); reactivar la restaura
  if (select max(avg_overall) from guide.item_author_scores where item_id = v_item) <> 3.00 then  -- 4, 2, 3 (c610…03 inactivo)
    raise exception 'FAIL F6.10 7a: media inicial (%)', (select max(avg_overall) from guide.item_author_scores where item_id = v_item); end if;
  update guide.criteria set is_active = false where id = 'c6100000-0000-4000-8000-000000000008';
  if (select max(avg_overall) from guide.item_author_scores where item_id = v_item) <> 3.50
     or exists (select 1 from guide.item_author_scores where item_id = v_item
                and criterion_id in ('c6100000-0000-4000-8000-000000000008', 'c6100000-0000-4000-8000-000000000003')) then
    raise exception 'FAIL F6.10 7b: la media incluye inactivos'; end if;
  if (select count(*) from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001') <> 4 then
    raise exception 'FAIL F6.10 7c: desactivar borró notas'; end if;
  update guide.criteria set is_active = true where id = 'c6100000-0000-4000-8000-000000000008';
  if (select max(avg_overall) from guide.item_author_scores where item_id = v_item) <> 3.00 then
    raise exception 'FAIL F6.10 7d: reactivar no restaura la media'; end if;

  -- 8. reorder_criteria: categoría, lista completa sin nulos ni duplicados; solo escribe (y registra) lo que cambia
  select array_agg(id order by sort_order desc, id) into v_ids from guide.criteria where category = 'gym';
  begin perform guide.reorder_criteria('rope', v_ids);
    raise exception 'FAIL F6.10 8a: categoría inexistente'; exception when no_data_found then null; end;
  begin perform guide.reorder_criteria('gym', null);
    raise exception 'FAIL F6.10 8b: lista nula'; exception when invalid_parameter_value then null; end;
  begin perform guide.reorder_criteria('gym', v_ids || null::uuid);
    raise exception 'FAIL F6.10 8b: lista con nulo'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'ids required' then raise exception 'FAIL F6.10 8b: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_criteria('gym', v_ids || v_ids[1]);
    raise exception 'FAIL F6.10 8c: duplicados'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'duplicate ids' then raise exception 'FAIL F6.10 8c: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_criteria('gym', v_ids || 'c6100000-0000-4000-8000-000000000004'::uuid);
    raise exception 'FAIL F6.10 8d: criterio de otra categoría'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'criteria must belong to the category' then raise exception 'FAIL F6.10 8d: mensaje (%)', v_msg; end if;
  end;
  begin perform guide.reorder_criteria('gym', v_ids[2:]);
    raise exception 'FAIL F6.10 8e: lista incompleta'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'list must include every criterion of the category' then raise exception 'FAIL F6.10 8e: mensaje (%)', v_msg; end if;
  end;
  select count(*) into v_chg from guide.criteria c join unnest(v_ids) with ordinality x(id, ord) on x.id = c.id
  where c.sort_order is distinct from x.ord::integer;
  select count(*) into v_log from guide.activity_log where entity_table = 'criteria' and action = 'update';
  select count(*) into v_srt from guide.activity_log where entity_table = 'criteria' and action = 'update'
    and changed_columns = array['sort_order'] and actor_id = 'a0000000-0000-4000-8000-000000000001';
  perform guide.reorder_criteria('gym', v_ids);
  if v_chg = 0 or exists (select 1 from guide.criteria c join unnest(v_ids) with ordinality x(id, ord) on x.id = c.id
                          where c.sort_order <> x.ord) then
    raise exception 'FAIL F6.10 8f: orden aplicado'; end if;
  -- una entrada 'update' {sort_order} del admin por fila movida, ninguna más
  if (select count(*) from guide.activity_log where entity_table = 'criteria' and action = 'update') <> v_log + v_chg
     or (select count(*) from guide.activity_log where entity_table = 'criteria' and action = 'update'
         and changed_columns = array['sort_order'] and actor_id = 'a0000000-0000-4000-8000-000000000001') <> v_srt + v_chg then
    raise exception 'FAIL F6.10 8g: actividad del reorden'; end if;
  select count(*) into v_log from guide.activity_log where entity_table = 'criteria';
  perform guide.reorder_criteria('gym', v_ids);
  if (select count(*) from guide.activity_log where entity_table = 'criteria') <> v_log then
    raise exception 'FAIL F6.10 8h: reorden sin cambios deja actividad'; end if;

  -- 9. criteria_usage: recuentos por criterio (fichas con nota del autor, opiniones, borradores), fórmula y borrable
  begin perform guide.criteria_usage('rope');
    raise exception 'FAIL F6.10 9a: categoría inexistente'; exception when no_data_found then null; end;
  if not exists (select 1 from guide.criteria_usage('gym') u where u.criterion_id = 'c6100000-0000-4000-8000-000000000003'
                 and u.author_items = 2 and u.user_reviews = 0 and u.draft_items = 0 and not u.used_by_index and not u.can_delete)
     or not exists (select 1 from guide.criteria_usage('gym') u where u.criterion_id = 'c6100000-0000-4000-8000-000000000005'
                    and u.author_items = 0 and u.user_reviews = 1 and not u.can_delete)
     or not exists (select 1 from guide.criteria_usage('gym') u where u.criterion_id = v_fam and u.used_by_index and not u.can_delete)
     or not exists (select 1 from guide.criteria_usage('gym') u where u.criterion_id = v_id
                    and u.author_items = 0 and u.user_reviews = 0 and u.draft_items = 0 and u.can_delete)
     or (select count(*) from guide.criteria_usage('gym')) <> (select count(*) from guide.criteria where category = 'gym')
     or exists (select 1 from guide.criteria_usage('gym') u where u.criterion_id = 'c6100000-0000-4000-8000-000000000004') then
    raise exception 'FAIL F6.10 9b: criteria_usage'; end if;

  -- 10. Las notas de criterios inactivos no se tocan al publicar ni en la edición directa
  --  a) borrador sin la nota del inactivo c610…03 → publicar la conserva
  perform guide.save_draft('item', v_item, '{"scores":{"c6100000-0000-4000-8000-000000000001":5}}', guide.draft_entity_version('item', v_item));
  perform guide.publish_draft('item', v_item);
  if (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
      and criterion_id = 'c6100000-0000-4000-8000-000000000003') is distinct from 2::smallint
     or (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
         and criterion_id = 'c6100000-0000-4000-8000-000000000001') <> 5
     or exists (select 1 from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
                and criterion_id = 'c6100000-0000-4000-8000-000000000008') then
    raise exception 'FAIL F6.10 10a: publicar sin la nota del inactivo'; end if;
  --  b) O1 (leona-lia): un borrador que cambia la nota guardada de un inactivo → 22023; con el mismo valor pasa y
  --     publicar la deja igual
  begin perform guide.save_draft('item', v_item, '{"scores":{"c6100000-0000-4000-8000-000000000001":5,"c6100000-0000-4000-8000-000000000003":5}}',
                                 guide.draft_entity_version('item', v_item));
    raise exception 'FAIL F6.10 10b: borrador cambia la nota de un inactivo'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text, v_det = pg_exception_detail;
      if v_msg <> 'invalid section: scores' or v_det <> 'inactive criterion' then
        raise exception 'FAIL F6.10 10b: mensaje (%, %)', v_msg, v_det; end if;
  end;
  perform guide.save_draft('item', v_item, '{"scores":{"c6100000-0000-4000-8000-000000000001":5,"c6100000-0000-4000-8000-000000000003":2}}',
                           guide.draft_entity_version('item', v_item));
  perform guide.publish_draft('item', v_item);
  if (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000001'
      and criterion_id = 'c6100000-0000-4000-8000-000000000003') <> 2 then
    raise exception 'FAIL F6.10 10b: publicar cambió la nota del inactivo'; end if;
  --  c) ficha no publicada (edición directa, como saveScores): borrar o cambiar la del inactivo no la toca; crear una nueva → 22023
  delete from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000002';
  update guide.author_review_scores set score = 1 where review_id = 'a6100000-0000-4000-8000-000000000002';
  insert into guide.author_review_scores (review_id, criterion_id, category, score)
  values ('a6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000003', 'gym', 4)
  on conflict (review_id, criterion_id) do update set score = excluded.score;
  if (select score from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000002'
      and criterion_id = 'c6100000-0000-4000-8000-000000000003') is distinct from 3::smallint then
    raise exception 'FAIL F6.10 10c: edición directa tocó la nota del inactivo'; end if;
  begin insert into guide.author_review_scores (review_id, criterion_id, category, score)
        values ('a6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000009', 'gym', 4);
    raise exception 'FAIL F6.10 10c: nota nueva en inactivo'; exception when invalid_parameter_value then
      get stacked diagnostics v_msg = message_text;
      if v_msg <> 'inactive criterion' then raise exception 'FAIL F6.10 10c: mensaje (%)', v_msg; end if;
  end;
  insert into guide.author_review_scores (review_id, criterion_id, category, score)
  values ('a6100000-0000-4000-8000-000000000002', 'c6100000-0000-4000-8000-000000000001', 'gym', 4);
  --  d) borrar la reseña (cascada) sí se lleva sus notas, también las del inactivo
  delete from guide.author_reviews where id = 'a6100000-0000-4000-8000-000000000002';
  if exists (select 1 from guide.author_review_scores where review_id = 'a6100000-0000-4000-8000-000000000002') then
    raise exception 'FAIL F6.10 10d: la cascada no borra las notas del inactivo'; end if;
  -- categoría sin criterios: lista vacía válida
  if exists (select 1 from guide.item_categories where key = 'resoler')
     and not exists (select 1 from guide.criteria where category = 'resoler') then
    perform guide.reorder_criteria('resoler', '{}'::uuid[]);
  end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- anon tras los cambios del admin: misma media que el admin (solo c610…01 = 5 activo; el inactivo c610…03 no cuenta)
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  if (select max(avg_overall) from guide.item_author_scores where item_id = 'f6100000-0000-4000-8000-000000000001') <> 5.00
     or exists (select 1 from guide.criteria where id = 'c6100000-0000-4000-8000-000000000005') then
    raise exception 'FAIL anon F6.10: media o criterio desactivado tras el panel'; end if;
  -- O2: notas de inactivos ocultas en las tablas base (autor: c610…03; usuario: c610…05, desactivado en el paso 6)
  if exists (select 1 from guide.author_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000003')
     or exists (select 1 from guide.user_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000005') then
    raise exception 'LEAK anon F6.10 O2: notas de criterio inactivo'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- no admin (user1, dueño de la opinión): tampoco ve en su opinión la nota del criterio desactivado; la opinión sí.
-- O2a: get_my_review solo devuelve las keys activas y reenviar la opinión con lo recibido funciona.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_mine record;
begin
  if not exists (select 1 from guide.user_reviews where id = 'e6100000-0000-4000-8000-000000000001')
     or exists (select 1 from guide.user_review_scores where review_id = 'e6100000-0000-4000-8000-000000000001'
                and criterion_id = 'c6100000-0000-4000-8000-000000000005')
     or not exists (select 1 from guide.user_review_scores where review_id = 'e6100000-0000-4000-8000-000000000001'
                    and criterion_id = 'c6100000-0000-4000-8000-000000000008')
     or exists (select 1 from guide.author_review_scores where criterion_id = 'c6100000-0000-4000-8000-000000000003') then
    raise exception 'LEAK user F6.10 O2: notas de criterio inactivo'; end if;
  select * into v_mine from guide.get_my_review('f6100000-0000-4000-8000-000000000001');
  if v_mine.scores is distinct from '{"c6100000-0000-4000-8000-000000000008": 3}'::jsonb then
    raise exception 'FAIL user F6.10 O2a: get_my_review con inactivos (%)', v_mine.scores; end if;
  if guide.submit_user_review('f6100000-0000-4000-8000-000000000001', v_mine.overall_score, v_mine.scores, v_mine.body, v_mine.locale)
     <> 'e6100000-0000-4000-8000-000000000001' then
    raise exception 'FAIL user F6.10 O2a: reenviar la opinión'; end if;
  if (select scores from guide.get_my_review('f6100000-0000-4000-8000-000000000001'))
     is distinct from '{"c6100000-0000-4000-8000-000000000008": 3}'::jsonb then
    raise exception 'FAIL user F6.10 O2a: notas tras reenviar'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);


-- ═════════════ F6.11: opiniones del panel (bandeja, moderar, contadores D24, borrado con motivo, ayuda de criterios D29) ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING.
-- Fixtures (como postgres): fichas f611…01 (gym publicada), …02 (shoe publicada), …03 (gym oculta); todas con «RLS F611»
-- en el nombre (las búsquedas «rls f611» acotan a estos datos). Criterios c611…01 (activo, con ayuda) y …02 (inactivo,
-- con ayuda y una nota guardada). Opiniones (u1 = a…02, u2 = a…03, u3 = a…04):
--   e01 u1 f01 visible 5 «100%_ok» −2 d sin revisar · e02 u2 f01 visible 1 «Marta G.» −1 d sin revisar
--   e03 u2 f02 hidden 2 −5 d revisada · e04 u1 f03 (ficha oculta) visible 4 −10 d
--   e05 u3 f01 visible 3 −3 d, revisada −1 h y editada −30 min (vuelve a pedir revisión) · e06 u1 f02 pending 4 −2 h
-- Última visita del admin: −36 h. Premoderación off y mínimo 3 para la media (se restauran con el ROLLBACK).
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'rls-user2@chalkguide.test', '{"full_name":"User Dos"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'rls-user3@chalkguide.test', '{"full_name":"User Tres"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
do $$ begin
  if exists (select 1 from guide.admins where user_id in ('a0000000-0000-4000-8000-000000000002',
             'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000004')) then
    raise exception 'FAIL F6.11 fixtures: un usuario de prueba es admin'; end if;
end $$;
select set_config('guide.draft_op', 'maintenance', true);
update guide.site_settings set user_reviews_premoderation = false, min_user_reviews_for_average = 3 where id = 1;
update guide.admins set reviews_seen_at = now() - interval '36 hours' where user_id = 'a0000000-0000-4000-8000-000000000001';
insert into guide.criteria (id, category, key, name_es, name_en, description_es, description_en, is_active) values
  ('c6110000-0000-4000-8000-000000000001', 'gym', 'rls_f611_a', 'F611 activo', 'F611 active', 'Ayuda F611', 'Help F611', true),
  ('c6110000-0000-4000-8000-000000000002', 'gym', 'rls_f611_off', 'F611 inactivo', 'F611 inactive', 'Ayuda oculta F611', 'Hidden help F611', true);
set constraints guide.items_shoe_require_brand_model deferred;
insert into guide.items (id, category, name, slug, published) values
  ('f6110000-0000-4000-8000-000000000001', 'gym', 'RLS F611 Rocódromo', 'rls-f611-gym', true),
  ('f6110000-0000-4000-8000-000000000002', 'shoe', 'RLS F611 Pie', 'rls-f611-shoe', true),
  ('f6110000-0000-4000-8000-000000000003', 'gym', 'RLS F611 Oculta', 'rls-f611-oculta', false);
insert into guide.gyms (item_id) values ('f6110000-0000-4000-8000-000000000001'), ('f6110000-0000-4000-8000-000000000003');
insert into guide.shoes (item_id, brand, model) values ('f6110000-0000-4000-8000-000000000002', 'RLS', 'F611');
set constraints guide.items_shoe_require_brand_model immediate;
insert into guide.user_reviews (id, item_id, category, user_id, author_name, overall_score, body, status, created_at, moderated_at, edited_at) values
  ('e6110000-0000-4000-8000-000000000001', 'f6110000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000002',
   'User U.', 5, 'Muy buen ambiente 100%_ok', 'visible', now() - interval '2 days', null, null),
  ('e6110000-0000-4000-8000-000000000002', 'f6110000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000003',
   'Marta G.', 1, 'Personal borde', 'visible', now() - interval '1 day', null, null),
  ('e6110000-0000-4000-8000-000000000003', 'f6110000-0000-4000-8000-000000000002', 'shoe', 'a0000000-0000-4000-8000-000000000003',
   'Marta G.', 2, 'spam enlace', 'hidden', now() - interval '5 days', now() - interval '4 days', null),
  ('e6110000-0000-4000-8000-000000000004', 'f6110000-0000-4000-8000-000000000003', 'gym', 'a0000000-0000-4000-8000-000000000002',
   'User U.', 4, null, 'visible', now() - interval '10 days', null, null),
  ('e6110000-0000-4000-8000-000000000005', 'f6110000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000004',
   'Pepe T.', 3, 'Correcto', 'visible', now() - interval '3 days', now() - interval '1 hour', now() - interval '30 minutes'),
  ('e6110000-0000-4000-8000-000000000006', 'f6110000-0000-4000-8000-000000000002', 'shoe', 'a0000000-0000-4000-8000-000000000002',
   'User U.', 4, 'Pendiente', 'pending', now() - interval '2 hours', null, null);
insert into guide.user_review_scores (review_id, criterion_id, category, score) values
  ('e6110000-0000-4000-8000-000000000001', 'c6110000-0000-4000-8000-000000000001', 'gym', 4),
  ('e6110000-0000-4000-8000-000000000001', 'c6110000-0000-4000-8000-000000000002', 'gym', 2);
update guide.criteria set is_active = false where id = 'c6110000-0000-4000-8000-000000000002';
-- Opiniones totales de u1 (en la suite completa otros bloques también le crean opiniones)
select set_config('rls.f611_u1_n', (select count(*) from guide.user_reviews
                                    where user_id = 'a0000000-0000-4000-8000-000000000002')::text, true);
select set_config('guide.draft_op', '', true);

-- anon: ayuda de criterios activos (D29) sí, inactivos no; solo opiniones visibles de fichas publicadas; media pública;
-- ninguna RPC del panel; no borra
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_n integer;
begin
  if not exists (select 1 from guide.criteria where id = 'c6110000-0000-4000-8000-000000000001'
                 and description_es = 'Ayuda F611' and description_en = 'Help F611') then
    raise exception 'FAIL anon F6.11 (D29): no lee la ayuda de un criterio activo'; end if;
  if exists (select 1 from guide.criteria where id = 'c6110000-0000-4000-8000-000000000002') then
    raise exception 'LEAK anon F6.11: ve la ayuda de un criterio inactivo'; end if;
  if (select array_agg(id order by id) from guide.user_reviews_public where item_id in
      ('f6110000-0000-4000-8000-000000000001', 'f6110000-0000-4000-8000-000000000002', 'f6110000-0000-4000-8000-000000000003'))
     is distinct from array['e6110000-0000-4000-8000-000000000001', 'e6110000-0000-4000-8000-000000000002',
                            'e6110000-0000-4000-8000-000000000005']::uuid[] then
    raise exception 'LEAK anon F6.11: ve opiniones ocultas, pendientes o de fichas ocultas'; end if;
  if not exists (select 1 from guide.item_user_ratings where item_id = 'f6110000-0000-4000-8000-000000000001'
                 and review_count = 3 and avg_overall = 3.00) then
    raise exception 'FAIL anon F6.11: media pública inicial'; end if;
  begin perform guide.admin_list_user_reviews(); raise exception 'LEAK anon F6.11: admin_list_user_reviews';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_reviews_summary(); raise exception 'LEAK anon F6.11: admin_reviews_summary';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_review_items(); raise exception 'LEAK anon F6.11: admin_review_items';
  exception when insufficient_privilege then null; end;
  begin perform guide.user_review_item_stats('f6110000-0000-4000-8000-000000000001'); raise exception 'LEAK anon F6.11: item_stats';
  exception when insufficient_privilege then null; end;
  begin perform guide.moderate_user_review('e6110000-0000-4000-8000-000000000002', 'hidden'); raise exception 'LEAK anon F6.11: modera';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_delete_user_review('e6110000-0000-4000-8000-000000000002', 'illegal_content'); raise exception 'LEAK anon F6.11: borra por RPC';
  exception when insufficient_privilege then null; end;
  begin delete from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000002';
    get diagnostics v_n = row_count;
    if v_n > 0 then raise exception 'LEAK anon F6.11: borra opinión'; end if;
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- otro usuario (u2, a…03): no ve lo no público de u1; no borra lo ajeno ni su opinión oculta (H1); nada del panel
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if exists (select 1 from guide.user_reviews where id in ('e6110000-0000-4000-8000-000000000004', 'e6110000-0000-4000-8000-000000000006')) then
    raise exception 'LEAK user2 F6.11: ve opiniones no públicas de otro'; end if;
  if not exists (select 1 from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000003') then
    raise exception 'FAIL user2 F6.11: no ve su propia opinión oculta'; end if;
  delete from guide.user_reviews where id in ('e6110000-0000-4000-8000-000000000001', 'e6110000-0000-4000-8000-000000000003');
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user2 F6.11: borra opinión ajena o su opinión oculta'; end if;
  update guide.user_reviews set status = 'visible' where id = 'e6110000-0000-4000-8000-000000000003';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user2 F6.11: reabre su opinión oculta'; end if;
  begin perform guide.moderate_user_review('e6110000-0000-4000-8000-000000000003', 'visible'); raise exception 'LEAK user2 F6.11: modera';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_delete_user_review('e6110000-0000-4000-8000-000000000001', 'erasure_request'); raise exception 'LEAK user2 F6.11: borra por RPC';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_list_user_reviews(p_query => 'rls f611'); raise exception 'LEAK user2 F6.11: lista del panel';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_reviews_summary(); raise exception 'LEAK user2 F6.11: contadores';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_review_items(); raise exception 'LEAK user2 F6.11: fichas con opiniones';
  exception when insufficient_privilege then null; end;
  begin delete from guide.user_review_scores where review_id = 'e6110000-0000-4000-8000-000000000001';
    raise exception 'LEAK user2 F6.11: borra notas'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.activity_log where entity_table = 'user_reviews') then
    raise exception 'LEAK user2 F6.11: lee activity_log'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- dueño (u1, a…02): ve sus opiniones en cualquier estado; no las modera, ni aprueba la pendiente, ni borra sus notas sueltas
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if (select count(*) from guide.user_reviews where id in ('e6110000-0000-4000-8000-000000000001',
      'e6110000-0000-4000-8000-000000000004', 'e6110000-0000-4000-8000-000000000006')) <> 3 then
    raise exception 'FAIL owner F6.11: no ve sus opiniones (pendiente / ficha oculta)'; end if;
  if exists (select 1 from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000003') then
    raise exception 'LEAK owner F6.11: ve la opinión oculta de otro'; end if;
  update guide.user_reviews set status = 'visible', moderated_at = now() where id = 'e6110000-0000-4000-8000-000000000006';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK owner F6.11: aprueba su opinión pendiente'; end if;
  begin perform guide.moderate_user_review('e6110000-0000-4000-8000-000000000006', 'visible'); raise exception 'LEAK owner F6.11: modera';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_delete_user_review('e6110000-0000-4000-8000-000000000001', 'erasure_request'); raise exception 'LEAK owner F6.11: RPC de borrado';
  exception when insufficient_privilege then null; end;
  begin delete from guide.user_review_scores where review_id = 'e6110000-0000-4000-8000-000000000001';
    raise exception 'LEAK owner F6.11: borra sus notas sueltas'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_list_user_reviews(); raise exception 'LEAK owner F6.11: lista del panel';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_r     record;
  v_ids   uuid[];
  v_n     integer;
  v_s0    jsonb;
  v_s     jsonb;
  v_j     jsonb;
  v_log   record;
  v_prev  timestamptz;
  v_res   text;
begin
  -- Contrato: nunca user_id ni email en lo que devuelve el panel
  select pg_get_function_result(p.oid) into v_res from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'guide' and p.proname = 'admin_list_user_reviews';
  if v_res ~* '(user_id|email)' then raise exception 'LEAK admin F6.11: la bandeja devuelve user_id/email'; end if;

  -- Listado, orden y paginación (acotado a los fixtures con la búsqueda «rls f611»)
  select array_agg(x.id order by x.ord) into v_ids
  from (select l.id, row_number() over () as ord from guide.admin_list_user_reviews(p_query => 'rls f611') l) x;
  if v_ids is distinct from array['e6110000-0000-4000-8000-000000000005', 'e6110000-0000-4000-8000-000000000006',
      'e6110000-0000-4000-8000-000000000002', 'e6110000-0000-4000-8000-000000000001',
      'e6110000-0000-4000-8000-000000000003', 'e6110000-0000-4000-8000-000000000004']::uuid[] then
    raise exception 'FAIL admin F6.11: orden por última actividad (%)', v_ids; end if;
  select array_agg(l.id), max(l.total_count) into v_ids, v_n
  from guide.admin_list_user_reviews(p_query => 'rls f611', p_limit => 2, p_offset => 4) l;
  if v_n <> 6 or v_ids is distinct from array['e6110000-0000-4000-8000-000000000003', 'e6110000-0000-4000-8000-000000000004']::uuid[] then
    raise exception 'FAIL admin F6.11: paginación (% / %)', v_ids, v_n; end if;

  -- Filtros (las fechas se miden sobre la última actividad: e05 cuenta por su edición de hace 30 min)
  if (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_status => 'hidden')) <> 1
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_status => 'pending')) <> 1
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_category => 'shoe')) <> 2
     or (select count(*) from guide.admin_list_user_reviews(p_item_id => 'f6110000-0000-4000-8000-000000000001')) <> 3
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_max_overall => 2)) <> 2
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_since => now() - interval '36 hours')) <> 3
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_from => now() - interval '4 days',
                                                           p_to => now() - interval '1 day')) <> 1
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611', p_needs_review => true)) <> 5
     or (select array_agg(id) from guide.admin_list_user_reviews(p_query => 'rls f611', p_needs_review => false))
        is distinct from array['e6110000-0000-4000-8000-000000000003']::uuid[] then
    raise exception 'FAIL admin F6.11: filtros'; end if;

  -- Búsqueda: varias palabras (AND), sin tildes, comodines literales, nombre público y entrada hostil
  if (select array_agg(id) from guide.admin_list_user_reviews(p_query => 'rls f611 PERSONAL bórde'))
       is distinct from array['e6110000-0000-4000-8000-000000000002']::uuid[]
     or (select array_agg(id) from guide.admin_list_user_reviews(p_query => 'rls f611 ambiénte'))
       is distinct from array['e6110000-0000-4000-8000-000000000001']::uuid[]
     or (select array_agg(id) from guide.admin_list_user_reviews(p_item_id => 'f6110000-0000-4000-8000-000000000001', p_query => '%'))
       is distinct from array['e6110000-0000-4000-8000-000000000001']::uuid[]
     or (select array_agg(id) from guide.admin_list_user_reviews(p_item_id => 'f6110000-0000-4000-8000-000000000001', p_query => '_'))
       is distinct from array['e6110000-0000-4000-8000-000000000001']::uuid[]
     or (select count(*) from guide.admin_list_user_reviews(p_query => 'rls f611 marta g.')) <> 2 then
    raise exception 'FAIL admin F6.11: búsqueda'; end if;
  if exists (select 1 from guide.admin_list_user_reviews(p_query => E'\'); delete from guide.user_reviews; --'))
     or (select count(*) from guide.user_reviews where item_id = 'f6110000-0000-4000-8000-000000000001') <> 3 then
    raise exception 'LEAK admin F6.11: la búsqueda interpreta la entrada'; end if;
  begin perform guide.admin_list_user_reviews(p_query => repeat('x', 201)); raise exception 'FAIL admin F6.11: consulta larga';
  exception when invalid_parameter_value then null; end;
  begin perform guide.admin_list_user_reviews(p_max_overall => 6); raise exception 'FAIL admin F6.11: nota máxima 6';
  exception when invalid_parameter_value then null; end;

  -- Fila: autor mínimo, notas (incluida la del criterio inactivo, marcada), medias y «si la ocultas»
  select * into v_r from guide.admin_list_user_reviews(p_item_id => 'f6110000-0000-4000-8000-000000000001',
                                                       p_query => 'ambiente');
  if v_r.author_name <> 'User U.' or v_r.item_name <> 'RLS F611 Rocódromo' or not v_r.item_published
     or v_r.author_review_count <> current_setting('rls.f611_u1_n')::integer
     or jsonb_array_length(v_r.scores) <> 2
     or not (v_r.scores @> '[{"key":"rls_f611_off","is_active":false,"score":2}]'::jsonb)
     or v_r.item_visible_count <> 3 or v_r.item_avg_overall <> 3.00
     or v_r.item_count_if_toggled <> 2 or v_r.item_avg_if_toggled <> 2.00 or not v_r.needs_review then
    raise exception 'FAIL admin F6.11: datos de la fila (%)', row_to_json(v_r); end if;
  select * into v_r from guide.admin_list_user_reviews(p_query => 'rls f611 personal');
  if v_r.item_avg_if_toggled <> 4.00 then raise exception 'FAIL admin F6.11: media si se oculta'; end if;
  select * into v_r from guide.admin_list_user_reviews(p_query => 'rls f611 pendiente');
  if v_r.item_count_if_toggled <> 1 or v_r.item_avg_if_toggled <> 4.00 then
    raise exception 'FAIL admin F6.11: media si se aprueba'; end if;

  -- Fichas con opiniones (filtro «Ficha»)
  if not exists (select 1 from guide.admin_review_items() where item_id = 'f6110000-0000-4000-8000-000000000001'
                 and review_count = 3 and visible_count = 3)
     or not exists (select 1 from guide.admin_review_items() where item_id = 'f6110000-0000-4000-8000-000000000002'
                    and review_count = 2 and pending_count = 1 and hidden_count = 1)
     or not exists (select 1 from guide.admin_review_items() where item_id = 'f6110000-0000-4000-8000-000000000003'
                    and not published) then
    raise exception 'FAIL admin F6.11: admin_review_items'; end if;

  -- Contadores (D24)
  v_s0 := guide.admin_reviews_summary();
  if (v_s0 ->> 'seen_at')::timestamptz <> now() - interval '36 hours' or (v_s0 ->> 'premoderation')::boolean
     or (v_s0 ->> 'min_for_average')::integer <> 3 then
    raise exception 'FAIL admin F6.11: summary (%)', v_s0; end if;

  -- 1. «Está bien» sobre una visible: revisada, sin entrada en activity_log; baja «nuevas» y el badge
  v_j := guide.moderate_user_review('e6110000-0000-4000-8000-000000000002', 'visible');
  if v_j ->> 'status' <> 'visible' or (v_j ->> 'item_visible_count')::integer <> 3 then
    raise exception 'FAIL admin F6.11: revisar (%)', v_j; end if;
  if exists (select 1 from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000002') then
    raise exception 'FAIL admin F6.11: revisar sin cambio de estado deja registro'; end if;
  v_s := guide.admin_reviews_summary();
  if (v_s ->> 'new_since_seen')::integer <> (v_s0 ->> 'new_since_seen')::integer - 1
     or (v_s ->> 'badge')::integer <> (v_s0 ->> 'badge')::integer - 1
     or (v_s ->> 'needs_review')::integer <> (v_s0 ->> 'needs_review')::integer - 1 then
    raise exception 'FAIL admin F6.11: contadores tras revisar (% → %)', v_s0, v_s; end if;

  -- 2. Aprobar la pendiente (premoderación)
  v_j := guide.moderate_user_review('e6110000-0000-4000-8000-000000000006', 'visible');
  v_s0 := v_s;
  v_s := guide.admin_reviews_summary();
  if (v_s ->> 'pending')::integer <> (v_s0 ->> 'pending')::integer - 1
     or (v_s ->> 'visible')::integer <> (v_s0 ->> 'visible')::integer + 1
     or (v_s ->> 'badge')::integer <> (v_s0 ->> 'badge')::integer - 1
     or (v_j ->> 'item_visible_count')::integer <> 1 then
    raise exception 'FAIL admin F6.11: aprobar (% → %)', v_s0, v_s; end if;
  select * into v_log from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000006';
  if v_log.details ->> 'from' <> 'pending' or v_log.details ->> 'to' <> 'visible' or v_log.details ->> 'by' <> 'admin' then
    raise exception 'FAIL admin F6.11: registro de aprobar'; end if;

  -- 3. Ocultar: la media pública cae por debajo del mínimo; registro sin datos personales
  v_j := guide.moderate_user_review('e6110000-0000-4000-8000-000000000002', 'hidden');
  if (v_j ->> 'item_visible_count')::integer <> 2 or (v_j ->> 'item_avg_overall')::numeric <> 4.00
     or v_j -> 'item_public_avg_overall' <> 'null'::jsonb then
    raise exception 'FAIL admin F6.11: medias al ocultar (%)', v_j; end if;
  if not exists (select 1 from guide.item_user_ratings where item_id = 'f6110000-0000-4000-8000-000000000001'
                 and review_count = 2 and avg_overall is null) then
    raise exception 'FAIL admin F6.11: item_user_ratings tras ocultar'; end if;
  select * into v_log from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000002';
  if v_log.action <> 'update' or v_log.actor_id <> 'a0000000-0000-4000-8000-000000000001'
     or v_log.entity_label <> 'RLS F611 Rocódromo' or v_log.changed_columns <> array['status']
     or v_log.old_row is not null or v_log.details ->> 'to' <> 'hidden'
     or v_log.details ?| array['body', 'author_name', 'user_id', 'email'] then
    raise exception 'LEAK/FAIL admin F6.11: registro de ocultar (%)', row_to_json(v_log); end if;
  if exists (select 1 from guide.activity_log where entity_table = 'user_reviews'
             and (old_row is not null or details::text ~ '(Personal borde|Marta G\.|a0000000-0000-4000-8000-00000000000[234])')) then
    raise exception 'LEAK admin F6.11: datos personales en activity_log'; end if;

  -- 4. Mostrar de nuevo
  perform guide.moderate_user_review('e6110000-0000-4000-8000-000000000002', 'visible');
  if not exists (select 1 from guide.item_user_ratings where item_id = 'f6110000-0000-4000-8000-000000000001'
                 and review_count = 3 and avg_overall = 3.00) then
    raise exception 'FAIL admin F6.11: item_user_ratings tras mostrar'; end if;

  -- 5. Entradas inválidas
  begin perform guide.moderate_user_review('e6110000-0000-4000-8000-000000000001', 'pending');
    raise exception 'FAIL admin F6.11: devuelve a pendiente'; exception when invalid_parameter_value then null; end;
  begin perform guide.moderate_user_review('e6110000-0000-4000-8000-0000000000ff', 'hidden');
    raise exception 'FAIL admin F6.11: modera una inexistente'; exception when no_data_found then null; end;

  -- 6. Sin escritura directa: ni borrar opiniones (solo por RPC con motivo) ni notas sueltas, ni editar texto/nota
  delete from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000004';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'FAIL admin F6.11: borra por PostgREST sin motivo'; end if;
  begin delete from guide.user_review_scores where review_id = 'e6110000-0000-4000-8000-000000000001';
    raise exception 'LEAK admin F6.11: borra notas sueltas'; exception when insufficient_privilege then null; end;
  begin update guide.user_reviews set body = 'x' where id = 'e6110000-0000-4000-8000-000000000001';
    raise exception 'LEAK admin F6.11: edita el texto'; exception when insufficient_privilege then null; end;

  -- 7. Borrado excepcional con motivo (la oculta de u2, que su autor no puede borrar: supresión RGPD)
  begin perform guide.admin_delete_user_review('e6110000-0000-4000-8000-000000000003', 'spam');
    raise exception 'FAIL admin F6.11: motivo libre'; exception when invalid_parameter_value then null; end;
  begin perform guide.admin_delete_user_review('e6110000-0000-4000-8000-0000000000ff', 'erasure_request');
    raise exception 'FAIL admin F6.11: borra una inexistente'; exception when no_data_found then null; end;
  v_j := guide.admin_delete_user_review('e6110000-0000-4000-8000-000000000003', 'erasure_request');
  if not (v_j ->> 'deleted')::boolean or (v_j ->> 'item_visible_count')::integer <> 1
     or exists (select 1 from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000003') then
    raise exception 'FAIL admin F6.11: borrado con motivo (%)', v_j; end if;
  select * into v_log from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000003';
  if v_log.action <> 'delete' or v_log.actor_id <> 'a0000000-0000-4000-8000-000000000001' or v_log.old_row is not null
     or v_log.details ->> 'reason' <> 'erasure_request' or v_log.details ->> 'by' <> 'admin'
     or v_log.details ->> 'status' <> 'hidden' or v_log.details::text ~ '(spam enlace|Marta)' then
    raise exception 'LEAK/FAIL admin F6.11: registro del borrado (%)', row_to_json(v_log); end if;
  if coalesce(current_setting('guide.review_delete', true), '') <> '' then
    raise exception 'FAIL admin F6.11: la marca de borrado queda puesta'; end if;

  -- 8. Marcar visita (D24): devuelve la anterior; nada nuevo desde ahora
  v_prev := guide.mark_reviews_seen();
  if v_prev <> now() - interval '36 hours' then raise exception 'FAIL admin F6.11: mark_reviews_seen'; end if;
  v_s := guide.admin_reviews_summary();
  if (v_s ->> 'seen_at')::timestamptz <> now() or (v_s ->> 'new_since_seen')::integer <> 0
     or (v_s ->> 'badge')::integer <> (v_s ->> 'pending')::integer then
    raise exception 'FAIL admin F6.11: contadores tras marcar visita (%)', v_s; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- dueño (u1): borra su opinión visible; aunque falsee la marca de borrado del admin, queda como «author», sin actor ni motivo
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  perform set_config('guide.review_delete', 'e6110000-0000-4000-8000-000000000001:illegal_content', true);
  delete from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL owner F6.11: no borra su opinión visible'; end if;
  perform set_config('guide.review_delete', '', true);
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
do $$
declare v_log record;
begin
  select * into v_log from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000001';
  if v_log.action <> 'delete' or v_log.actor_id is not null or v_log.details ->> 'by' <> 'author'
     or v_log.details ? 'reason' or v_log.old_row is not null then
    raise exception 'LEAK/FAIL F6.11: registro del borrado propio (%)', row_to_json(v_log); end if;
  if exists (select 1 from guide.user_review_scores where review_id = 'e6110000-0000-4000-8000-000000000001') then
    raise exception 'FAIL F6.11: las notas no caen en cascada'; end if;
end $$;

-- O3 (leona-lia): borrar una cuenta de auth arrastra su opinión y sus notas; el registro queda «system», sin PII.
-- Usuario propio del bloque, creado y borrado aquí (su public.profiles de Chalk app nace y cae con él: public intacto).
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000611', 'authenticated', 'authenticated', 'rls-f611-gone@chalkguide.test',
   '{"full_name":"Borrada Cuenta"}', now(), now());
insert into guide.user_reviews (id, item_id, category, user_id, author_name, overall_score, body, status) values
  ('e6110000-0000-4000-8000-000000000007', 'f6110000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000611',
   'Borrada C.', 2, 'Texto de la cuenta borrada', 'visible');
insert into guide.user_review_scores (review_id, criterion_id, category, score) values
  ('e6110000-0000-4000-8000-000000000007', 'c6110000-0000-4000-8000-000000000001', 'gym', 2);
delete from auth.users where id = 'a0000000-0000-4000-8000-000000000611';
do $$
declare v_log record;
begin
  if exists (select 1 from guide.user_reviews where id = 'e6110000-0000-4000-8000-000000000007')
     or exists (select 1 from guide.user_review_scores where review_id = 'e6110000-0000-4000-8000-000000000007') then
    raise exception 'FAIL F6.11 O3: la opinión o sus notas no caen al borrar la cuenta'; end if;
  select * into v_log from guide.activity_log where entity_id = 'e6110000-0000-4000-8000-000000000007';
  if v_log is null or v_log.action <> 'delete' or v_log.actor_id is not null or v_log.details ->> 'by' <> 'system'
     or v_log.details ? 'reason' or v_log.old_row is not null
     or concat_ws(' ', v_log.entity_label, v_log.details::text)
        ~ '(Borrada|rls-f611-gone|Texto de la cuenta|a0000000-0000-4000-8000-000000000611)' then
    raise exception 'LEAK/FAIL F6.11 O3: registro del borrado por cuenta (%)', row_to_json(v_log); end if;
  if exists (select 1 from public.profiles where id = 'a0000000-0000-4000-8000-000000000611') then
    raise exception 'FAIL F6.11 O3: queda el perfil de public'; end if;
end $$;

-- ═════════════ F6.11b: fotos en opiniones (buckets, subida del dueño, consentimiento, moderación con motivo, limpieza) ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING.
-- Fixtures (como postgres): fichas f6b1…01 (gym publicada), …02 (gym oculta), …03 (gym publicada).
-- Opiniones: e6b1…01 u1 f01 visible · …02 u2 f01 visible · …03 u1 f02 (ficha oculta) · …04 u2 f03 hidden.
-- Fotos de u1 en e01: a6b1…01/02/03 (webp); copia pública 76b1…01.webp. Objetos con metadatos como los deja Storage.
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'rls-user2@chalkguide.test', '{"full_name":"User Dos"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
do $$ begin
  if exists (select 1 from guide.admins where user_id in ('a0000000-0000-4000-8000-000000000002',
             'a0000000-0000-4000-8000-000000000003')) then
    raise exception 'FAIL F6.11b fixtures: un usuario de prueba es admin'; end if;
end $$;
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.items (id, category, name, slug, published) values
  ('f6b10000-0000-4000-8000-000000000001', 'gym', 'RLS F611b Rocódromo', 'rls-f611b-gym', true),
  ('f6b10000-0000-4000-8000-000000000002', 'gym', 'RLS F611b Oculta', 'rls-f611b-oculta', false),
  ('f6b10000-0000-4000-8000-000000000003', 'gym', 'RLS F611b Otra', 'rls-f611b-otra', true);
insert into guide.gyms (item_id) values ('f6b10000-0000-4000-8000-000000000001'),
  ('f6b10000-0000-4000-8000-000000000002'), ('f6b10000-0000-4000-8000-000000000003');
insert into guide.user_reviews (id, item_id, category, user_id, author_name, overall_score, body, status) values
  ('e6b10000-0000-4000-8000-000000000001', 'f6b10000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000002', 'User U.', 4, 'Fotos', 'visible'),
  ('e6b10000-0000-4000-8000-000000000002', 'f6b10000-0000-4000-8000-000000000001', 'gym', 'a0000000-0000-4000-8000-000000000003', 'User D.', 3, 'Otra', 'visible'),
  ('e6b10000-0000-4000-8000-000000000003', 'f6b10000-0000-4000-8000-000000000002', 'gym', 'a0000000-0000-4000-8000-000000000002', 'User U.', 3, 'Oculta', 'visible'),
  ('e6b10000-0000-4000-8000-000000000004', 'f6b10000-0000-4000-8000-000000000003', 'gym', 'a0000000-0000-4000-8000-000000000003', 'User D.', 1, 'Spam', 'hidden');
select set_config('guide.draft_op', '', true);

-- Estructura: buckets, límites, sin UPDATE en Storage, policies de media/avatars intactas
do $$
begin
  if not exists (select 1 from storage.buckets where id = 'review-photo-uploads' and not public
                 and file_size_limit = 2097152 and allowed_mime_types = array['image/jpeg', 'image/webp']) then
    raise exception 'FAIL F6.11b: bucket privado mal configurado'; end if;
  if not exists (select 1 from storage.buckets where id = 'review-photos' and public
                 and file_size_limit = 2097152 and allowed_mime_types = array['image/jpeg', 'image/webp']) then
    raise exception 'FAIL F6.11b: bucket público mal configurado'; end if;
  if exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and cmd = 'UPDATE'
             and (coalesce(qual, '') || coalesce(with_check, '')) like '%review-photo%') then
    raise exception 'FAIL F6.11b: hay UPDATE en Storage (sobrescritura)'; end if;
  if exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
             and (coalesce(qual, '') || coalesce(with_check, '')) like '%review-photo%' and 'anon' = any(roles)) then
    raise exception 'LEAK F6.11b: policy de Storage para anon'; end if;
  if (select count(*) from pg_policies where schemaname = 'storage' and policyname like 'avatar%') <> 3 then
    raise exception 'FAIL F6.11b: se tocaron las policies de avatars'; end if;
  if not (select relrowsecurity from pg_class where oid = 'guide.user_review_photos'::regclass)
     or not (select relrowsecurity from pg_class where oid = 'guide.user_review_photo_quota'::regclass) then
    raise exception 'FAIL F6.11b: RLS desactivada'; end if;
  if has_table_privilege('authenticated', 'guide.user_review_photo_quota', 'SELECT')
     or has_table_privilege('anon', 'guide.user_review_photo_quota', 'SELECT') then
    raise exception 'LEAK F6.11b: cupo legible por clientes'; end if;
  if has_column_privilege('anon', 'guide.user_review_photos', 'reject_reason', 'SELECT')
     or has_column_privilege('anon', 'guide.user_review_photos', 'storage_path', 'SELECT')
     or has_column_privilege('anon', 'guide.user_review_photos', 'rights_accepted_at', 'SELECT') then
    raise exception 'LEAK F6.11b: anon puede leer columnas internas'; end if;
  if has_function_privilege('anon', 'guide.register_review_photo(uuid, uuid, text, integer, integer, boolean, text)', 'EXECUTE')
     or has_function_privilege('anon', 'guide.moderate_review_photo(uuid, guide.review_photo_status, text, integer, integer, text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'guide.review_photos_cleanup_collect(integer)', 'EXECUTE')
     or has_function_privilege('anon', 'guide.review_photos_cleanup_collect(integer)', 'EXECUTE')
     or has_function_privilege('authenticated', 'guide.user_review_photos_before_write()', 'EXECUTE')
     or has_function_privilege('anon', 'guide.user_review_is_mine(uuid)', 'EXECUTE') then
    raise exception 'LEAK F6.11b: RPC ejecutable por quien no toca'; end if;
end $$;

-- ───── u1 (dueño de e01): sube y registra ─────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v jsonb; v_n integer;
begin
  insert into storage.objects (bucket_id, name, owner_id, metadata) values
    ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp',
     'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/webp","size":1000}');
  -- Rutas o destinos no permitidos
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000002/a6b10000-0000-4000-8000-000000000050.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'LEAK u1 F6.11b: sube a la opinión de otro'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000003/a6b10000-0000-4000-8000-000000000051.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: sube a una opinión de ficha oculta'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000052.png', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: extensión png'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'E6B10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000053.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: uuid en mayúsculas'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000001/../a6b10000-0000-4000-8000-000000000054.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: ruta con ..'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'a0000000-0000-4000-8000-000000000002/e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000055.webp',
      'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: ruta con user_id'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000056.webp', 'a0000000-0000-4000-8000-000000000003', '{}');
    raise exception 'LEAK u1 F6.11b: sube con owner_id ajeno'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photos',
      '76b10000-0000-4000-8000-000000000050.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'LEAK u1 F6.11b: sube al bucket público'; exception when insufficient_privilege then null; end;

  -- Consentimiento de derechos de imagen (D31)
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000001',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp', 1200, 900, false, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra sin aceptar derechos'; exception when sqlstate 'PT412' then null; end;
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000001',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp', 1200, 900, true, '2000-01-01');
    raise exception 'FAIL u1 F6.11b: registra con versión de derechos antigua'; exception when sqlstate 'PT412' then null; end;
  begin insert into guide.user_review_photos (id, review_id, storage_path, width, height, rights_version) values
      ('a6b10000-0000-4000-8000-000000000001', 'e6b10000-0000-4000-8000-000000000001',
       'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp', 1, 1, '2000-01-01');
    raise exception 'FAIL u1 F6.11b: INSERT directo sin la versión vigente'; exception when sqlstate 'PT412' then null; end;

  v := guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000001',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp', 1200, 900, true, guide.review_photo_rights_version());
  if v ->> 'status' <> 'pending' or (v ->> 'sort_order')::int <> 1 or v ->> 'mime_type' <> 'image/webp'
     or (v ->> 'size_bytes')::int <> 1000 or v ->> 'rights_accepted_at' is null
     or v ->> 'rights_version' <> guide.review_photo_rights_version() then
    raise exception 'FAIL u1 F6.11b: registro (%)', v; end if;

  -- Objeto inexistente, id ajeno a la ruta, tipo y tamaño desde los metadatos
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000009',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000009.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra sin objeto'; exception when invalid_parameter_value then null; end;
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000008',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra con id que no es el de la ruta'; exception when invalid_parameter_value then null; end;
  insert into storage.objects (bucket_id, name, owner_id, metadata) values
    ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp',
     'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/png","size":10}');
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000002',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra un png con extensión webp'; exception when invalid_parameter_value then null; end;
  -- El dueño borra su objeto sin fila
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'review-photo-uploads'
    and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp';
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL u1 F6.11b: no borra su objeto sin fila'; end if;
  -- …pero no el de una foto registrada
  delete from storage.objects where bucket_id = 'review-photo-uploads'
    and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp';
  get diagnostics v_n = row_count;
  perform set_config('storage.allow_delete_query', 'false', true);
  if v_n <> 0 then raise exception 'FAIL u1 F6.11b: borra el objeto de una foto registrada'; end if;
  insert into storage.objects (bucket_id, name, owner_id, metadata) values
    ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp',
     'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/webp","size":3000000}');
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000002',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra > 2 MB'; exception when invalid_parameter_value then null; end;
end $$;
reset role;
-- (el objeto de 3 MB lo sustituye postgres por uno válido; Storage no lo permitiría por el límite del bucket)
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'review-photo-uploads'
  and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp';
select set_config('storage.allow_delete_query', 'false', true);
set local role authenticated;
do $$
declare v jsonb; v_n integer;
begin
  insert into storage.objects (bucket_id, name, owner_id, metadata) values
    ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp',
     'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/webp","size":2000}'),
    ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000003.jpg',
     'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/jpeg","size":3000}');
  perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000002',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp', 800, 600, true, guide.review_photo_rights_version());
  perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000003',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000003.jpg', 800, 600, true, guide.review_photo_rights_version());
  if (select array_agg(sort_order order by id) from guide.user_review_photos
      where review_id = 'e6b10000-0000-4000-8000-000000000001') <> array[1, 2, 3]::smallint[] then
    raise exception 'FAIL u1 F6.11b: huecos 1..3'; end if;
  -- Cuarta subida: la policy de Storage la rechaza (3 en uso)
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000004.webp', 'a0000000-0000-4000-8000-000000000002',
      '{"mimetype":"image/webp","size":10}');
    raise exception 'FAIL u1 F6.11b: cuarta subida a la misma opinión'; exception when insufficient_privilege then null; end;
  -- Moderación y columnas internas: no
  begin update guide.user_review_photos set status = 'approved' where id = 'a6b10000-0000-4000-8000-000000000001';
    raise exception 'LEAK u1 F6.11b: aprueba su foto'; exception when insufficient_privilege then null; end;
  begin update guide.user_review_photos set public_path = '76b10000-0000-4000-8000-000000000051.webp'
      where id = 'a6b10000-0000-4000-8000-000000000001';
    raise exception 'LEAK u1 F6.11b: cambia la ruta pública'; exception when insufficient_privilege then null; end;
  begin update guide.user_review_photos set storage_path = 'x' where id = 'a6b10000-0000-4000-8000-000000000001';
    raise exception 'LEAK u1 F6.11b: cambia la ruta privada'; exception when insufficient_privilege then null; end;
  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'rejected', null, null, null, 'low_quality');
    raise exception 'LEAK u1 F6.11b: moderate_review_photo'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_list_review_photos(); raise exception 'LEAK u1 F6.11b: admin_list_review_photos';
    exception when insufficient_privilege then null; end;
  begin perform guide.review_photos_storage_orphans(5); raise exception 'LEAK u1 F6.11b: orphans';
    exception when insufficient_privilege then null; end;
  begin perform guide.review_photos_cleanup_collect(10); raise exception 'LEAK u1 F6.11b: cleanup_collect';
    exception when insufficient_privilege then null; end;
  -- Reordenar
  perform guide.reorder_review_photos('e6b10000-0000-4000-8000-000000000001',
    array['a6b10000-0000-4000-8000-000000000003', 'a6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000002']::uuid[]);
  if (select sort_order from guide.user_review_photos where id = 'a6b10000-0000-4000-8000-000000000003') <> 1 then
    raise exception 'FAIL u1 F6.11b: reordenar'; end if;
  begin perform guide.reorder_review_photos('e6b10000-0000-4000-8000-000000000001',
      array['a6b10000-0000-4000-8000-000000000003', 'a6b10000-0000-4000-8000-000000000001']::uuid[]);
    raise exception 'FAIL u1 F6.11b: reordenar sin todas'; exception when invalid_parameter_value then null; end;
  -- Ve las suyas en cualquier estado y solo sus objetos
  select count(*) into v_n from guide.user_review_photos where review_id = 'e6b10000-0000-4000-8000-000000000001';
  if v_n <> 3 then raise exception 'FAIL u1 F6.11b: no ve sus pendientes'; end if;
  if exists (select 1 from storage.objects where bucket_id in ('review-photo-uploads', 'review-photos')
             and owner_id is distinct from 'a0000000-0000-4000-8000-000000000002') then
    raise exception 'LEAK u1 F6.11b: ve objetos ajenos'; end if;
end $$;
reset role;
-- Límite de 3 en BD aunque el objeto exista (subido por postgres)
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000004.webp',
   'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/webp","size":10}');
set local role authenticated;
do $$ begin
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000004',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000004.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: cuarta foto en BD'; exception when sqlstate 'PT409' then null; end;
end $$;

-- ───── u2: nada de lo de u1; su opinión oculta no admite fotos ─────
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if exists (select 1 from guide.user_review_photos where review_id = 'e6b10000-0000-4000-8000-000000000001') then
    raise exception 'LEAK u2 F6.11b: ve fotos pendientes ajenas'; end if;
  if exists (select 1 from storage.objects where bucket_id = 'review-photo-uploads') then
    raise exception 'LEAK u2 F6.11b: ve objetos privados ajenos'; end if;
  update guide.user_review_photos set sort_order = 3 where id = 'a6b10000-0000-4000-8000-000000000003';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK u2 F6.11b: reordena fotos ajenas'; end if;
  delete from guide.user_review_photos where review_id = 'e6b10000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK u2 F6.11b: borra fotos ajenas'; end if;
  begin perform guide.delete_review_photo('a6b10000-0000-4000-8000-000000000001');
    raise exception 'LEAK u2 F6.11b: delete_review_photo ajena'; exception when no_data_found then null; end;
  begin perform guide.reorder_review_photos('e6b10000-0000-4000-8000-000000000001',
      array['a6b10000-0000-4000-8000-000000000001']::uuid[]);
    raise exception 'LEAK u2 F6.11b: reorder ajeno'; exception when insufficient_privilege then null; end;
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000004',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000004.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'LEAK u2 F6.11b: registra en opinión ajena'; exception when insufficient_privilege then null; end;
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'review-photo-uploads';
  get diagnostics v_n = row_count;
  perform set_config('storage.allow_delete_query', 'false', true);
  if v_n <> 0 then raise exception 'LEAK u2 F6.11b: borra objetos ajenos'; end if;
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000004/a6b10000-0000-4000-8000-000000000060.webp', 'a0000000-0000-4000-8000-000000000003', '{}');
    raise exception 'FAIL u2 F6.11b: sube a su opinión oculta'; exception when insufficient_privilege then null; end;
end $$;
reset role;
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000004/a6b10000-0000-4000-8000-000000000060.webp',
   'a0000000-0000-4000-8000-000000000003', '{"mimetype":"image/webp","size":10}');
set local role authenticated;
do $$ begin
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000004', 'a6b10000-0000-4000-8000-000000000060',
      'e6b10000-0000-4000-8000-000000000004/a6b10000-0000-4000-8000-000000000060.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u2 F6.11b: registra en su opinión oculta'; exception when invalid_parameter_value then null; end;
end $$;

-- ───── admin: bandeja, aprobar con copia pública, rechazar con motivo ─────
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v jsonb; v_n integer; r record;
begin
  select count(*) into v_n from guide.admin_list_review_photos('pending', 'e6b10000-0000-4000-8000-000000000001');
  if v_n <> 3 then raise exception 'FAIL admin F6.11b: lista de pendientes (%)', v_n; end if;
  v := guide.admin_reviews_summary();
  if (v ->> 'photos_pending')::int < 3 or (v ->> 'reviews_with_pending_photos')::int < 1 then
    raise exception 'FAIL admin F6.11b: contadores (%)', v; end if;
  select * into r from guide.admin_list_user_reviews(p_item_id => 'f6b10000-0000-4000-8000-000000000001',
                                                     p_has_pending_photos => true);
  if r.id is distinct from 'e6b10000-0000-4000-8000-000000000001'::uuid or r.pending_photo_count <> 3
     or r.photo_count <> 3 or jsonb_array_length(r.photos) <> 3 then
    raise exception 'FAIL admin F6.11b: bandeja con fotos'; end if;
  if r.photos::text like '%a0000000-0000-4000-8000-000000000002%' or r.photos::text like '%user_id%' then
    raise exception 'LEAK admin F6.11b: la bandeja expone user_id'; end if;
  select count(*) into v_n from guide.admin_list_user_reviews(p_item_id => 'f6b10000-0000-4000-8000-000000000001',
                                                              p_has_pending_photos => false);
  if v_n <> 1 then raise exception 'FAIL admin F6.11b: filtro sin fotos pendientes (%)', v_n; end if;

  -- Copia pública: ruta bien formada
  begin insert into storage.objects (bucket_id, name, metadata) values ('review-photos',
      'e6b10000-0000-4000-8000-000000000001/76b10000-0000-4000-8000-000000000001.webp', '{}');
    raise exception 'FAIL admin F6.11b: copia pública con carpeta'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects (bucket_id, name, metadata) values ('review-photos', 'foto-de-marta.webp', '{}');
    raise exception 'FAIL admin F6.11b: copia pública con nombre'; exception when insufficient_privilege then null; end;
  insert into storage.objects (bucket_id, name, metadata) values ('review-photos',
    '76b10000-0000-4000-8000-000000000001.webp', '{"mimetype":"image/webp","size":800}');

  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'approved');
    raise exception 'FAIL admin F6.11b: aprueba sin copia pública'; exception when invalid_parameter_value then null; end;
  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'approved',
      '76b10000-0000-4000-8000-000000000099.webp', 1000, 750);
    raise exception 'FAIL admin F6.11b: aprueba con copia inexistente'; exception when invalid_parameter_value then null; end;
  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'approved',
      '76b10000-0000-4000-8000-000000000001.webp', 1000, 750, 'low_quality');
    raise exception 'FAIL admin F6.11b: aprueba con motivo'; exception when invalid_parameter_value then null; end;
  v := guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'approved',
      '76b10000-0000-4000-8000-000000000001.webp', 1000, 750);
  if v ->> 'status' <> 'approved' or v ->> 'public_path' <> '76b10000-0000-4000-8000-000000000001.webp'
     or (v ->> 'width')::int <> 1000 or v ->> 'moderated_at' is null then
    raise exception 'FAIL admin F6.11b: aprobar (%)', v; end if;
  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000001', 'approved',
      '76b10000-0000-4000-8000-000000000001.webp', 1000, 750);
    raise exception 'FAIL admin F6.11b: aprobar dos veces'; exception when invalid_parameter_value then null; end;
  begin update guide.user_review_photos set status = 'pending' where id = 'a6b10000-0000-4000-8000-000000000001';
    raise exception 'FAIL admin F6.11b: vuelve a pendiente'; exception when invalid_parameter_value or check_violation then null; end;
  begin update guide.user_review_photos set public_path = '76b10000-0000-4000-8000-000000000002.webp'
      where id = 'a6b10000-0000-4000-8000-000000000001';
    raise exception 'FAIL admin F6.11b: cambia la copia de una aprobada'; exception when invalid_parameter_value then null; end;

  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000002', 'rejected');
    raise exception 'FAIL admin F6.11b: rechaza sin motivo'; exception when invalid_parameter_value then null; end;
  begin perform guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000002', 'rejected', null, null, null, 'spam');
    raise exception 'FAIL admin F6.11b: motivo fuera de la lista'; exception when invalid_parameter_value then null; end;
  v := guide.moderate_review_photo('a6b10000-0000-4000-8000-000000000002', 'rejected', null, null, null, 'identifiable_people');
  if v ->> 'status' <> 'rejected' or v ->> 'reject_reason' <> 'identifiable_people' then
    raise exception 'FAIL admin F6.11b: rechazar (%)', v; end if;

  -- Registro sin datos personales
  for r in select * from guide.activity_log where entity_table = 'user_review_photos'
           and entity_id in ('a6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000002') loop
    if r.old_row is not null or r.details::text like '%a0000000-0000-4000-8000-000000000002%'
       or r.details::text like '%storage_path%' or r.details::text like '%e6b10000-0000-4000-8000-000000000001/%'
       or r.actor_id is distinct from 'a0000000-0000-4000-8000-000000000001'::uuid or r.details ->> 'by' <> 'admin' then
      raise exception 'LEAK/FAIL admin F6.11b: registro (%)', row_to_json(r); end if;
  end loop;
  if not exists (select 1 from guide.activity_log where entity_table = 'user_review_photos'
                 and entity_id = 'a6b10000-0000-4000-8000-000000000002' and details ->> 'reason' = 'identifiable_people'
                 and details ->> 'to' = 'rejected') then
    raise exception 'FAIL admin F6.11b: el rechazo no se registra con motivo'; end if;

  -- Storage del admin: copia en uso no se borra; original de aprobada sí; original de pendiente no
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'review-photos' and name = '76b10000-0000-4000-8000-000000000001.webp';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'FAIL admin F6.11b: borra una copia pública en uso'; end if;
  delete from storage.objects where bucket_id = 'review-photo-uploads'
    and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000003.jpg';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'FAIL admin F6.11b: borra el original de una pendiente'; end if;
  delete from storage.objects where bucket_id = 'review-photo-uploads'
    and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp';
  get diagnostics v_n = row_count;
  perform set_config('storage.allow_delete_query', 'false', true);
  if v_n <> 1 then raise exception 'FAIL admin F6.11b: no borra el original de una aprobada'; end if;
end $$;

-- ───── anon: solo aprobadas de opiniones visibles de fichas publicadas ─────
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_n integer;
begin
  select count(*) into v_n from guide.user_review_photos_public where review_id = 'e6b10000-0000-4000-8000-000000000001';
  if v_n <> 1 then raise exception 'FAIL anon F6.11b: no ve la aprobada (%)', v_n; end if;
  if exists (select 1 from guide.user_review_photos where status <> 'approved') then
    raise exception 'LEAK anon F6.11b: ve pendientes o rechazadas'; end if;
  begin perform reject_reason from guide.user_review_photos limit 1;
    raise exception 'LEAK anon F6.11b: lee reject_reason'; exception when insufficient_privilege then null; end;
  begin perform storage_path from guide.user_review_photos limit 1;
    raise exception 'LEAK anon F6.11b: lee storage_path'; exception when insufficient_privilege then null; end;
  if exists (select 1 from storage.objects where bucket_id in ('review-photo-uploads', 'review-photos')) then
    raise exception 'LEAK anon F6.11b: lista los buckets'; end if;
  begin insert into storage.objects (bucket_id, name, metadata) values ('review-photos', '76b10000-0000-4000-8000-000000000070.webp', '{}');
    raise exception 'LEAK anon F6.11b: sube al bucket público'; exception when insufficient_privilege then null; end;
  begin perform guide.register_review_photo(null, null, null, null, null, true, null);
    raise exception 'LEAK anon F6.11b: register'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_list_review_photos(); raise exception 'LEAK anon F6.11b: admin_list_review_photos';
    exception when insufficient_privilege then null; end;
  begin perform guide.review_photos_cleanup_collect(10); raise exception 'LEAK anon F6.11b: cleanup_collect';
    exception when insufficient_privilege then null; end;
end $$;
reset role;
-- Opinión oculta o ficha despublicada → sus fotos aprobadas dejan de verse
update guide.user_reviews set status = 'hidden' where id = 'e6b10000-0000-4000-8000-000000000001';
set local role anon;
do $$ begin
  if exists (select 1 from guide.user_review_photos_public where review_id = 'e6b10000-0000-4000-8000-000000000001') then
    raise exception 'LEAK anon F6.11b: ve fotos de una opinión oculta'; end if;
end $$;
reset role;
update guide.user_reviews set status = 'visible' where id = 'e6b10000-0000-4000-8000-000000000001';

-- ───── u1 ve el motivo del rechazo; u2 no; u1 borra su rechazada ─────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
do $$ begin
  if exists (select 1 from guide.user_review_photos where id = 'a6b10000-0000-4000-8000-000000000002') then
    raise exception 'LEAK u2 F6.11b: ve la rechazada ajena'; end if;
  if not exists (select 1 from guide.user_review_photos_public where id = 'a6b10000-0000-4000-8000-000000000001') then
    raise exception 'FAIL u2 F6.11b: no ve la aprobada'; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v jsonb; v_n integer;
begin
  if (select reject_reason from guide.user_review_photos where id = 'a6b10000-0000-4000-8000-000000000002')
     is distinct from 'identifiable_people' then
    raise exception 'FAIL u1 F6.11b: no ve el motivo del rechazo'; end if;
  v := guide.delete_review_photo('a6b10000-0000-4000-8000-000000000002');
  if v ->> 'storage_path' <> 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000002.webp' then
    raise exception 'FAIL u1 F6.11b: delete_review_photo (%)', v; end if;
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'review-photo-uploads' and name = v ->> 'storage_path';
  get diagnostics v_n = row_count;
  perform set_config('storage.allow_delete_query', 'false', true);
  if v_n <> 1 then raise exception 'FAIL u1 F6.11b: no borra el objeto tras borrar la foto'; end if;
end $$;
reset role;
-- (activity_log solo lo lee el admin: se comprueba como postgres)
do $$ begin
  if not exists (select 1 from guide.activity_log where entity_table = 'user_review_photos'
                 and entity_id = 'a6b10000-0000-4000-8000-000000000002' and action = 'delete'
                 and details ->> 'by' = 'author' and actor_id is null) then
    raise exception 'FAIL u1 F6.11b: registro del borrado propio'; end if;
end $$;

-- ───── Cupo diario (15) ─────
update guide.user_review_photo_quota set uploads = guide.review_photo_daily_limit(), window_started_at = now()
where user_id = 'a0000000-0000-4000-8000-000000000002';
select set_config('storage.allow_delete_query', 'true', true);
delete from storage.objects where bucket_id = 'review-photo-uploads'
  and name = 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000004.webp';
select set_config('storage.allow_delete_query', 'false', true);
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000005.webp',
   'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/webp","size":10}');
set local role authenticated;
do $$ begin
  begin insert into storage.objects (bucket_id, name, owner_id, metadata) values ('review-photo-uploads',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000006.webp', 'a0000000-0000-4000-8000-000000000002', '{}');
    raise exception 'FAIL u1 F6.11b: sube con el cupo agotado'; exception when insufficient_privilege then null; end;
  begin perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000005',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000005.webp', 10, 10, true, guide.review_photo_rights_version());
    raise exception 'FAIL u1 F6.11b: registra con el cupo agotado'; exception when sqlstate 'PT429' then null; end;
end $$;
reset role;
update guide.user_review_photo_quota set window_started_at = now() - interval '25 hours'
where user_id = 'a0000000-0000-4000-8000-000000000002';
set local role authenticated;
do $$ begin
  perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000005',
      'e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000005.webp', 10, 10, true, guide.review_photo_rights_version());
end $$;
reset role;
do $$ begin
  if (select uploads from guide.user_review_photo_quota where user_id = 'a0000000-0000-4000-8000-000000000002') <> 1 then
    raise exception 'FAIL F6.11b: el cupo no se reinicia a las 24 h'; end if;
end $$;

-- ───── Limpieza: huérfanos (admin) y pasada diaria (service_role) ─────
insert into storage.objects (bucket_id, name, owner_id, metadata, created_at) values
  ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000002/a6b10000-0000-4000-8000-000000000080.webp',
   'a0000000-0000-4000-8000-000000000003', '{"mimetype":"image/webp","size":10}', now() - interval '2 hours'),
  ('review-photos', '76b10000-0000-4000-8000-000000000080.webp', null, '{"mimetype":"image/webp","size":10}', now() - interval '2 hours');
-- Rechazada hace 31 días (fecha forzada sin el trigger; DDL dentro de la transacción, se deshace)
alter table guide.user_review_photos disable trigger user_review_photos_before_write;
update guide.user_review_photos set status = 'rejected', reject_reason = 'off_topic', moderated_at = now() - interval '31 days'
where id = 'a6b10000-0000-4000-8000-000000000005';
alter table guide.user_review_photos enable trigger user_review_photos_before_write;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v_kinds text[];
begin
  select array_agg(kind || ':' || storage_path order by kind, storage_path) into v_kinds
  from guide.review_photos_storage_orphans(5)
  where storage_path like '%a6b10000-0000-4000-8000-0000000000%' or storage_path like '76b10000%';
  if not ('upload_without_row:e6b10000-0000-4000-8000-000000000002/a6b10000-0000-4000-8000-000000000080.webp' = any(v_kinds))
     or not ('public_without_row:76b10000-0000-4000-8000-000000000080.webp' = any(v_kinds))
     or not ('rejected_expired:e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000005.webp' = any(v_kinds))
     or ('approved_original:e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000001.webp' = any(v_kinds))
     or exists (select 1 from unnest(v_kinds) k where k like 'row_without_object:%') then
    raise exception 'FAIL admin F6.11b: huérfanos (%)', v_kinds; end if;
  -- El admin borra el huérfano público
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects where bucket_id = 'review-photos' and name = '76b10000-0000-4000-8000-000000000080.webp';
  perform set_config('storage.allow_delete_query', 'false', true);
  if exists (select 1 from storage.objects where bucket_id = 'review-photos' and name = '76b10000-0000-4000-8000-000000000080.webp') then
    raise exception 'FAIL admin F6.11b: no borra la copia pública huérfana'; end if;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$
declare v_paths text[];
begin
  select array_agg(bucket_id || '/' || storage_path) into v_paths from guide.review_photos_cleanup_collect(1000);
  if not ('review-photo-uploads/e6b10000-0000-4000-8000-000000000001/a6b10000-0000-4000-8000-000000000005.webp' = any(v_paths))
     or not ('review-photo-uploads/e6b10000-0000-4000-8000-000000000002/a6b10000-0000-4000-8000-000000000080.webp' = any(v_paths)) then
    raise exception 'FAIL service F6.11b: cleanup_collect (%)', v_paths; end if;
  if exists (select 1 from unnest(v_paths) p where p like '%a0000000-0000-4000-8000-00000000000%') then
    raise exception 'LEAK service F6.11b: cleanup devuelve user_id'; end if;
end $$;
reset role;
do $$ begin
  if exists (select 1 from guide.user_review_photos where id = 'a6b10000-0000-4000-8000-000000000005') then
    raise exception 'FAIL F6.11b: no purga la rechazada caducada'; end if;
end $$;

-- ───── Cascadas: borrar la opinión (autor) y borrar la cuenta ─────
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  delete from guide.user_reviews where id = 'e6b10000-0000-4000-8000-000000000001';
end $$;
reset role;
do $$ begin
  if exists (select 1 from guide.user_review_photos where review_id = 'e6b10000-0000-4000-8000-000000000001') then
    raise exception 'FAIL F6.11b: las fotos no caen con la opinión'; end if;
  if exists (select 1 from guide.activity_log where entity_table = 'user_review_photos' and action = 'delete'
             and entity_id in ('a6b10000-0000-4000-8000-000000000001', 'a6b10000-0000-4000-8000-000000000003')) then
    raise exception 'FAIL F6.11b: la cascada registra cada foto'; end if;
end $$;
-- Cuenta borrada: usuario propio del bloque, creado y borrado aquí (su public.profiles nace y cae con él: public intacto)
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-0000000006b1', 'authenticated', 'authenticated', 'rls-f611b-gone@chalkguide.test', '{}', now(), now());
insert into guide.user_reviews (id, item_id, category, user_id, author_name, overall_score, body, status) values
  ('e6b10000-0000-4000-8000-000000000005', 'f6b10000-0000-4000-8000-000000000003', 'gym', 'a0000000-0000-4000-8000-0000000006b1',
   'Borrada C.', 2, 'Cuenta', 'visible');
insert into storage.objects (bucket_id, name, owner_id, metadata) values
  ('review-photo-uploads', 'e6b10000-0000-4000-8000-000000000005/a6b10000-0000-4000-8000-000000000090.webp',
   'a0000000-0000-4000-8000-0000000006b1', '{"mimetype":"image/webp","size":10}');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-0000000006b1","role":"authenticated"}', true);
do $$ begin
  perform guide.register_review_photo('e6b10000-0000-4000-8000-000000000005', 'a6b10000-0000-4000-8000-000000000090',
      'e6b10000-0000-4000-8000-000000000005/a6b10000-0000-4000-8000-000000000090.webp', 10, 10, true, guide.review_photo_rights_version());
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
delete from auth.users where id = 'a0000000-0000-4000-8000-0000000006b1';
do $$ begin
  if exists (select 1 from guide.user_review_photos where id = 'a6b10000-0000-4000-8000-000000000090')
     or exists (select 1 from guide.user_review_photo_quota where user_id = 'a0000000-0000-4000-8000-0000000006b1') then
    raise exception 'FAIL F6.11b: fotos o cupo no caen al borrar la cuenta'; end if;
  if exists (select 1 from public.profiles where id = 'a0000000-0000-4000-8000-0000000006b1') then
    raise exception 'FAIL F6.11b: queda el perfil de public'; end if;
end $$;
-- (su objeto privado queda huérfano; lo recoge la limpieza diaria pasados 60 min: upload_without_row)
select set_config('storage.allow_delete_query', '', true);
-- Fin F6.11b: deja el rol y los claims como estaban
reset role;
select set_config('request.jwt.claims', '{}', true);

-- ═════════════ F6.12: agenda del panel (estados, transiciones, agente solo borradores, procedencia oculta, contadores) ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING.
-- Fixtures (como postgres, mantenimiento): fichas f612…01 (gym publicada), …02 (gym oculta), …03 (shoe publicada),
-- …04 (resolador publicado).
-- Eventos (todos «RLS F612» en el título; agent_meta con la forma de F8):
--   e01 draft manual +5 d en f01 · e02 approved +6 d en f01 · e03 draft agent +7 d (dedupe y agent_meta)
--   e04 approved −10 d (pasado) · e05 draft +8 d sin lugar · e06 cancelled +9 d · e07 rejected agent +4 d · e08 draft agent −3 d
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
do $$ begin
  if exists (select 1 from guide.admins where user_id = 'a0000000-0000-4000-8000-000000000002') then
    raise exception 'FAIL F6.12 fixtures: un usuario de prueba es admin'; end if;
end $$;
select set_config('guide.draft_op', 'maintenance', true);
set constraints guide.items_shoe_require_brand_model deferred;
insert into guide.items (id, category, name, slug, published) values
  ('f6120000-0000-4000-8000-000000000001', 'gym', 'RLS F612 Rocódromo', 'rls-f612-gym', true),
  ('f6120000-0000-4000-8000-000000000002', 'gym', 'RLS F612 Oculta', 'rls-f612-oculta', false),
  ('f6120000-0000-4000-8000-000000000003', 'shoe', 'RLS F612 Pie', 'rls-f612-shoe', true),
  ('f6120000-0000-4000-8000-000000000004', 'resoler', 'RLS F612 Resolador', 'rls-f612-resoler', true);
insert into guide.gyms (item_id) values ('f6120000-0000-4000-8000-000000000001'), ('f6120000-0000-4000-8000-000000000002');
insert into guide.shoes (item_id, brand, model) values ('f6120000-0000-4000-8000-000000000003', 'RLS', 'F612');
insert into guide.resolers (item_id) values ('f6120000-0000-4000-8000-000000000004');
set constraints guide.items_shoe_require_brand_model immediate;
insert into guide.events (id, title_es, starts_at, status, source, item_id, location_text, dedupe_key, agent_meta, source_url, approved_at) values
  ('e6120000-0000-4000-8000-000000000001', 'RLS F612 borrador', now() + interval '5 days', 'draft', 'manual',
   'f6120000-0000-4000-8000-000000000001', null, null, null, null, null),
  ('e6120000-0000-4000-8000-000000000002', 'RLS F612 publicado', now() + interval '6 days', 'approved', 'manual',
   'f6120000-0000-4000-8000-000000000001', null, null, null, null, now() - interval '1 day'),
  ('e6120000-0000-4000-8000-000000000003', 'RLS F612 del agente', now() + interval '7 days', 'draft', 'agent',
   null, 'Sala RLS', 'rls-f612-a', '{"confidence":0.9,"excerpt":"secreto"}', 'https://fuente.test/a', null),
  ('e6120000-0000-4000-8000-000000000004', 'RLS F612 pasado', now() - interval '10 days', 'approved', 'manual',
   null, 'Sala RLS', null, null, null, now() - interval '20 days'),
  ('e6120000-0000-4000-8000-000000000005', 'RLS F612 sin lugar', now() + interval '8 days', 'draft', 'manual',
   null, null, null, null, null, null),
  ('e6120000-0000-4000-8000-000000000006', 'RLS F612 cancelado', now() + interval '9 days', 'cancelled', 'manual',
   null, 'Sala RLS', null, null, null, now() - interval '2 days'),
  ('e6120000-0000-4000-8000-000000000007', 'RLS F612 descartado', now() + interval '4 days', 'rejected', 'agent',
   null, 'Sala RLS', 'rls-f612-r', '{"confidence":0.4}', 'http://fuente.test/r', null),
  ('e6120000-0000-4000-8000-000000000008', 'RLS F612 borrador viejo', now() - interval '3 days', 'draft', 'agent',
   null, 'Sala RLS', 'rls-f612-v', '{"confidence":0.7,"duplicate_of":"e6120000-0000-4000-8000-000000000002"}', null, null);
select set_config('guide.draft_op', '', true);

-- Devuelve 'ok' o «sqlstate mensaje» (sin capturar los FAIL del propio bloque, que van fuera del helper).
create or replace function pg_temp.f612_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Catálogo: RLS, columnas internas sin grant, firmas de las RPC
do $$
declare v_fn regprocedure;
begin
  if not (select relrowsecurity from pg_class where oid = 'guide.events'::regclass) then
    raise exception 'FAIL F6.12: RLS desactivada en events'; end if;
  if has_column_privilege('anon', 'guide.events', 'agent_meta', 'select')
     or has_column_privilege('authenticated', 'guide.events', 'agent_meta', 'select')
     or has_column_privilege('authenticated', 'guide.events', 'source_url', 'select')
     or has_column_privilege('authenticated', 'guide.events', 'dedupe_key', 'select')
     or has_column_privilege('anon', 'guide.events', 'source', 'select') then
    raise exception 'LEAK F6.12: procedencia del agente legible por clientes'; end if;
  if has_table_privilege('anon', 'guide.events', 'insert') or has_table_privilege('anon', 'guide.export_events', 'select') then
    raise exception 'LEAK F6.12: grants de anon'; end if;
  foreach v_fn in array array['guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz, uuid, text[], text, uuid, text, integer, integer)'::regprocedure,
                              'guide.admin_events_summary()'::regprocedure, 'guide.set_event_status(uuid, guide.event_status, text)'::regprocedure,
                              'guide.set_events_status(uuid[], guide.event_status, text)'::regprocedure, 'guide.reopen_event(uuid)'::regprocedure,
                              'guide.reject_event(uuid, text)'::regprocedure, 'guide.approve_event(uuid)'::regprocedure,
                              'guide.export_events_rows()'::regprocedure] loop
    if has_function_privilege('anon', v_fn, 'execute') then
      raise exception 'LEAK F6.12: anon ejecuta %', v_fn; end if;
  end loop;
  if exists (select 1 from pg_proc where oid in ('guide.admin_list_events'::regproc, 'guide.admin_events_summary'::regproc,
               'guide.export_events_rows'::regproc, 'guide.events_log_activity'::regproc)
             and not (prosecdef and proconfig @> array['search_path=""'])) then
    raise exception 'FAIL F6.12: DEFINER sin search_path vacío'; end if;
  if has_function_privilege('service_role', 'guide.approve_event(uuid)', 'execute')
     or has_function_privilege('service_role', 'guide.set_event_status(uuid, guide.event_status, text)', 'execute') then
    raise exception 'FAIL F6.12 (O3): service_role ejecuta RPC del panel'; end if;
  if has_function_privilege('authenticated', 'guide.events_log_activity()', 'execute')
     or has_function_privilege('authenticated', 'guide.events_before_write()', 'execute') then
    raise exception 'LEAK F6.12: funciones de trigger ejecutables'; end if;
end $$;

-- anon: publicados, cancelados y pasados sí; borradores y descartados no; nada interno; ninguna RPC; no escribe
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v text;
begin
  if (select array_agg(id order by id) from guide.events where title_es like 'RLS F612%') is distinct from
     array['e6120000-0000-4000-8000-000000000002', 'e6120000-0000-4000-8000-000000000004',
           'e6120000-0000-4000-8000-000000000006']::uuid[] then
    raise exception 'LEAK anon F6.12: visibilidad de eventos'; end if;
  v := pg_temp.f612_err($q$select agent_meta from guide.events limit 1$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: lee agent_meta (%)', v; end if;
  v := pg_temp.f612_err($q$select source from guide.events limit 1$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: lee source (%)', v; end if;
  v := pg_temp.f612_err($q$select * from guide.admin_list_events()$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: admin_list_events (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.admin_events_summary()$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: admin_events_summary (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000001', 'approved')$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: set_event_status (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text) values ('RLS F612 anon', now() + interval '1 day', 'x')$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: inserta (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set title_es = 'hack' where id = 'e6120000-0000-4000-8000-000000000002'$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: actualiza (%)', v; end if;
  v := pg_temp.f612_err($q$delete from guide.events where id = 'e6120000-0000-4000-8000-000000000002'$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12: borra (%)', v; end if;
end $$;
reset role;
do $$ begin
  if (select title_es from guide.events where id = 'e6120000-0000-4000-8000-000000000002') <> 'RLS F612 publicado' then
    raise exception 'LEAK anon F6.12: modifica o borra un evento'; end if;
end $$;

-- authenticated no admin: igual que anon; no aprueba, no lista, no inserta; export_events vacío
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v text; v_n integer;
begin
  if exists (select 1 from guide.events where id in ('e6120000-0000-4000-8000-000000000001', 'e6120000-0000-4000-8000-000000000003',
             'e6120000-0000-4000-8000-000000000005', 'e6120000-0000-4000-8000-000000000007', 'e6120000-0000-4000-8000-000000000008')) then
    raise exception 'LEAK u1 F6.12: ve borradores o descartados'; end if;
  v := pg_temp.f612_err($q$select dedupe_key from guide.events limit 1$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: lee dedupe_key (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000001', 'approved')$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: set_event_status (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.approve_event('e6120000-0000-4000-8000-000000000001')$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: approve_event (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_events_status(array['e6120000-0000-4000-8000-000000000001']::uuid[], 'approved')$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: set_events_status (%)', v; end if;
  v := pg_temp.f612_err($q$select * from guide.admin_list_events()$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: admin_list_events (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.admin_events_summary()$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: admin_events_summary (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, status) values ('RLS F612 u1', now() + interval '1 day', 'x', 'draft')$q$);
  if v not like '42501%' then raise exception 'LEAK u1 F6.12: inserta (%)', v; end if;
  update guide.events set status = 'draft' where id = 'e6120000-0000-4000-8000-000000000002';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK u1 F6.12: despublica'; end if;
  delete from guide.events where id = 'e6120000-0000-4000-8000-000000000006';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK u1 F6.12: borra'; end if;
  begin perform 1 from guide.export_events; raise exception 'LEAK u1 F6.12: lee export_events'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_events_rows(); raise exception 'LEAK u1 F6.12: export_events_rows'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Agente (F8) simulado: service_role salta RLS, pero la guarda solo le deja insertar borradores source = 'agent'
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$
declare v text;
begin
  -- O1: id y created_at que manda el agente se ignoran (se renombra luego como postgres para el resto del bloque)
  v := pg_temp.f612_err($q$insert into guide.events (id, created_at, title_es, starts_at, location_text, source, dedupe_key, agent_meta, source_url)
    values ('e6120000-0000-4000-8000-000000000020', now() - interval '1 year', 'RLS F612 agente nuevo', now() + interval '10 days', 'Sala', 'agent',
            'rls-f612-n', '{"confidence":0.62,"note":"Liga","excerpt":"Lliga de bloc","found_at":"2026-10-20T08:00:00Z","inferred":["type","end"],"duplicate_of":null}', 'https://fuente.test/n')$q$);
  if v <> 'ok' then raise exception 'FAIL agente F6.12: no inserta su borrador (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (id, title_es, starts_at, location_text, source, dedupe_key, agent_meta)
    values ('e6120000-0000-4000-8000-000000000002', 'RLS F612 choque', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-c', '{"confidence":0.5}')$q$);
  if v <> 'ok' then raise exception 'FAIL agente F6.12 (O1): un id existente choca (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, status)
    values ('RLS F612 agente publica', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-p', 'approved')$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: inserta publicado (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, approved_at)
    values ('RLS F612 agente fecha', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-q', now())$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: fija approved_at (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text) values ('RLS F612 agente manual', now() + interval '10 days', 'Sala')$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: se hace pasar por manual (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, agent_meta) values ('RLS F612 agente sin clave', now() + interval '10 days', 'Sala', 'agent', '{"confidence":0.5}')$q$);
  if v not like '23514%events_agent_dedupe%' then raise exception 'FAIL agente F6.12: borrador sin dedupe_key (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key) values ('RLS F612 agente sin meta', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m')$q$);
  if v not like '23514%events_agent_meta_only_agent%' then raise exception 'FAIL agente F6.12: borrador sin agent_meta (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 dup', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-r', '{"confidence":0.5}')$q$);
  if v not like '23505%' then raise exception 'FAIL agente F6.12: duplica un descartado (%)', v; end if;
  -- Forma de F8: ON CONFLICT (dedupe_key) DO NOTHING salta claves existentes en cualquier estado (también descartadas)
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta)
    values ('RLS F612 dup', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-r', '{"confidence":0.5}'),
           ('RLS F612 dup2', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-a', '{"confidence":0.5}')
    on conflict (dedupe_key) do nothing$q$);
  if v <> 'ok' then raise exception 'FAIL agente F6.12: on conflict do nothing (%)', v; end if;
  -- agent_meta con forma fija
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m1', '{"confidence":1.5}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: confianza > 1 (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m2', '{"confidence":"alta"}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: confianza no numérica (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m3', '{"confidence":0.5,"publish":true}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: clave extra (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m4', '{"confidence":0.5,"inferred":["type","status"]}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: inferred fuera de lista (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m5', '{"confidence":0.5,"duplicate_of":"x"}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: duplicate_of no uuid (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m6', '{"confidence":0.5,"found_at":"ayer"}')$q$);
  if v not like '23514%events_agent_meta_shape%' then raise exception 'FAIL agente F6.12: found_at no ISO (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, source, dedupe_key, agent_meta, reject_reason) values ('RLS F612 m', now() + interval '10 days', 'Sala', 'agent', 'rls-f612-m7', '{"confidence":0.5}', 'duplicate')$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: fija reject_reason (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set status = 'approved' where id = 'e6120000-0000-4000-8000-000000000003'$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: aprueba (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set title_es = 'RLS F612 pisa' where id = 'e6120000-0000-4000-8000-000000000002'$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: edita lo publicado (%)', v; end if;
  v := pg_temp.f612_err($q$delete from guide.events where id = 'e6120000-0000-4000-8000-000000000003'$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: borra (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000003', 'approved')$q$);
  if v not like '42501%' then raise exception 'LEAK agente F6.12: set_event_status (%)', v; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);
do $$ begin
  if exists (select 1 from guide.events where id = 'e6120000-0000-4000-8000-000000000020')
     or (select created_at from guide.events where dedupe_key = 'rls-f612-n') < now() - interval '1 minute' then
    raise exception 'FAIL agente F6.12 (O1): el agente elige id o created_at'; end if;
  if (select title_es from guide.events where id = 'e6120000-0000-4000-8000-000000000002') <> 'RLS F612 publicado'
     or not exists (select 1 from guide.events where dedupe_key = 'rls-f612-c') then
    raise exception 'FAIL agente F6.12 (O1): el id del agente pisa o choca con otro'; end if;
  if not exists (select 1 from guide.activity_log l join guide.events e on l.entity_id = e.id::text
                 where e.dedupe_key = 'rls-f612-n' and l.entity_table = 'events' and l.action = 'insert'
                   and l.actor_id is null and l.details ->> 'by' = 'agent' and l.details ->> 'status' = 'draft') then
    raise exception 'FAIL agente F6.12: registro del alta del agente'; end if;
end $$;
-- O1 deja dos borradores del agente con id generado: «agente nuevo» pasa a e20 (lo usa el resto del bloque) y el de
-- «choque» se retira para que los filtros por origen/búsqueda solo vean fixtures con id conocido.
select set_config('guide.draft_op', 'maintenance', true);
update guide.events set id = 'e6120000-0000-4000-8000-000000000020' where dedupe_key = 'rls-f612-n';
delete from guide.events where dedupe_key = 'rls-f612-c';
select set_config('guide.draft_op', '', true);
do $$ begin
  if (select status from guide.events where id = 'e6120000-0000-4000-8000-000000000020') <> 'draft' then
    raise exception 'FAIL agente F6.12: su borrador no es draft'; end if;
  if exists (select 1 from guide.events where title_es in ('RLS F612 dup', 'RLS F612 dup2'))
     or (select status from guide.events where id = 'e6120000-0000-4000-8000-000000000007') <> 'rejected' then
    raise exception 'FAIL agente F6.12: vuelve a proponer una clave existente'; end if;
end $$;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v text; v_j jsonb; v_at timestamptz; v_n bigint; r record;
begin
  -- Alta: procedencia forzada a manual; textos recortados; vacíos a null
  insert into guide.events (id, title_es, title_en, description_es, starts_at, location_text, source, dedupe_key, agent_meta, approved_at)
  values ('e6120000-0000-4000-8000-000000000030', '  RLS F612 nuevo  ', '   ', '', now() + interval '12 days', ' Sala ', 'agent', 'rls-f612-x',
          '{"x":1}', now() - interval '1 year');
  select * into r from guide.admin_list_events(p_id => 'e6120000-0000-4000-8000-000000000030');
  if r.source <> 'manual' or r.agent_meta is not null or r.title_es <> 'RLS F612 nuevo' or r.title_en is not null
     or r.description_es is not null or r.location_text <> 'Sala' or r.approved_at is not null or r.status <> 'draft' then
    raise exception 'FAIL admin F6.12: alta no normalizada (%)', to_jsonb(r); end if;

  -- Validación al crear o publicar
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, status) values ('RLS F612 x', now() + interval '3 days', 'approved')$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12: publica sin lugar (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, status, location_text) values ('RLS F612 x', now() - interval '3 days', 'approved', 'Sala')$q$);
  if v <> '23514 event_in_past' then raise exception 'FAIL admin F6.12: publica en pasado (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, status, item_id) values ('RLS F612 x', now() + interval '3 days', 'approved', 'f6120000-0000-4000-8000-000000000002')$q$);
  if v <> '23514 event_item_not_published' then raise exception 'FAIL admin F6.12: publica con ficha oculta (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, item_id) values ('RLS F612 x', now() + interval '3 days', 'f6120000-0000-4000-8000-000000000003')$q$);
  if v <> '23514 event_item_category' then raise exception 'FAIL admin F6.12: ficha que no es un lugar (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, item_id) values ('RLS F612 x', now() + interval '3 days', 'f6120000-0000-4000-8000-000000000004')$q$);
  if v <> '23514 event_item_category' then raise exception 'FAIL admin F6.12: ficha de resolador (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, status) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'rejected')$q$);
  if v not like '55000%' then raise exception 'FAIL admin F6.12: crea descartado (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, status) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'cancelled')$q$);
  if v not like '55000%' then raise exception 'FAIL admin F6.12: crea cancelado (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, url) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'http://inseguro.test')$q$);
  if v not like '23514%events_url_https%' then raise exception 'FAIL admin F6.12: URL http (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, url) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'javascript:alert(1)')$q$);
  if v not like '23514%events_url_https%' then raise exception 'FAIL admin F6.12: URL javascript (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, url) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'https://a.test/"><script>')$q$);
  if v not like '23514%events_url_https%' then raise exception 'FAIL admin F6.12: URL con comillas (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, ends_at, location_text) values ('RLS F612 x', now() + interval '3 days', now() + interval '2 days', 'Sala')$q$);
  if v not like '23514%events_dates%' then raise exception 'FAIL admin F6.12: fin antes del inicio (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, ends_at, location_text) values ('RLS F612 x', now() + interval '3 days', now() + interval '400 days', 'Sala')$q$);
  if v not like '23514%events_duration%' then raise exception 'FAIL admin F6.12: duración > 1 año (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, all_day) values ('RLS F612 x', (date_trunc('day', now() at time zone 'Europe/Madrid') + interval '3 days 10 hours') at time zone 'Europe/Madrid', 'Sala', true)$q$);
  if v not like '23514%events_all_day_midnight%' then raise exception 'FAIL admin F6.12: todo el día a las 10:00 (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, all_day) values ('RLS F612 x', (date_trunc('day', now() at time zone 'Europe/Madrid') + interval '3 days') at time zone 'Europe/Madrid', 'Sala', true)$q$);
  if v <> 'ok' then raise exception 'FAIL admin F6.12: todo el día a medianoche de Madrid (%)', v; end if;
  v := pg_temp.f612_err(format('insert into guide.events (title_es, starts_at, location_text) values (%L, now() + interval %L, %L)',
                               'RLS F612 ' || chr(7), '3 days', 'Sala'));
  if v not like '23514%events_text_no_control%' then raise exception 'FAIL admin F6.12: control en el título (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text) values ('   ', now() + interval '3 days', 'Sala')$q$);
  if v not like '23514%' then raise exception 'FAIL admin F6.12: título vacío (%)', v; end if;
  v := pg_temp.f612_err($q$insert into guide.events (title_es, starts_at, location_text, event_type) values ('RLS F612 x', now() + interval '3 days', 'Sala', 'party')$q$);
  if v not like '23514%events_event_type_check%' then raise exception 'FAIL admin F6.12: tipo inválido (%)', v; end if;

  -- Publicar (aprobar) un borrador manual: approved_at lo fija el servidor; registro con from/to
  v_j := guide.set_event_status('e6120000-0000-4000-8000-000000000001', 'approved');
  if v_j ->> 'status' <> 'approved' or (v_j ->> 'approved_at') is null then
    raise exception 'FAIL admin F6.12: aprobar (%)', v_j; end if;
  if not exists (select 1 from guide.activity_log where entity_table = 'events' and entity_id = 'e6120000-0000-4000-8000-000000000001'
                 and action = 'update' and actor_id = 'a0000000-0000-4000-8000-000000000001'
                 and details @> '{"by":"admin","from":"draft","to":"approved","source":"manual"}' and changed_columns @> array['status']) then
    raise exception 'FAIL admin F6.12: registro de la aprobación'; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000005', 'approved')$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12: aprueba sin lugar (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000008', 'approved')$q$);
  if v <> '23514 event_in_past' then raise exception 'FAIL admin F6.12: aprueba un borrador pasado (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-0000000000ff', 'approved')$q$);
  if v not like 'P0002%' then raise exception 'FAIL admin F6.12: evento inexistente (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status(null, 'approved')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: id nulo (%)', v; end if;

  -- Borrador del agente: el admin lo edita y aprueba; la procedencia no cambia
  update guide.events set title_es = 'RLS F612 del agente revisado' where id = 'e6120000-0000-4000-8000-000000000003';
  perform guide.approve_event('e6120000-0000-4000-8000-000000000003');
  select * into r from guide.admin_list_events(p_id => 'e6120000-0000-4000-8000-000000000003');
  if r.status <> 'approved' or r.source <> 'agent' or r.agent_meta ->> 'excerpt' <> 'secreto' or r.source_url <> 'https://fuente.test/a' then
    raise exception 'FAIL admin F6.12: aprobar borrador del agente (%)', to_jsonb(r); end if;
  v := pg_temp.f612_err($q$update guide.events set source = 'manual' where id = 'e6120000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 event_provenance_immutable' then raise exception 'FAIL admin F6.12: cambia source (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set agent_meta = null where id = 'e6120000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 event_provenance_immutable' then raise exception 'FAIL admin F6.12: cambia agent_meta (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set dedupe_key = 'otra' where id = 'e6120000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 event_provenance_immutable' then raise exception 'FAIL admin F6.12: cambia dedupe_key (%)', v; end if;

  -- Edición directa de lo publicado (sin borrador de cambios), incluido un evento pasado; approved_at no se falsifica
  select approved_at into v_at from guide.events where id = 'e6120000-0000-4000-8000-000000000002';
  update guide.events set title_es = 'RLS F612 publicado editado', approved_at = now() - interval '5 years'
  where id = 'e6120000-0000-4000-8000-000000000002';
  if (select approved_at from guide.events where id = 'e6120000-0000-4000-8000-000000000002') is distinct from v_at then
    raise exception 'FAIL admin F6.12: approved_at editable'; end if;
  update guide.events set price_text = 'Gratis' where id = 'e6120000-0000-4000-8000-000000000004';
  if (select price_text from guide.events where id = 'e6120000-0000-4000-8000-000000000004') is distinct from 'Gratis' then
    raise exception 'FAIL admin F6.12: no edita un publicado pasado'; end if;
  v := pg_temp.f612_err($q$update guide.events set item_id = 'f6120000-0000-4000-8000-000000000002' where id = 'e6120000-0000-4000-8000-000000000002'$q$);
  if v <> '23514 event_item_not_published' then raise exception 'FAIL admin F6.12: publicado con ficha oculta (%)', v; end if;
  -- O2: id inmutable
  v := pg_temp.f612_err($q$update guide.events set id = gen_random_uuid() where id = 'e6120000-0000-4000-8000-000000000005'$q$);
  if v <> '42501 event_id_immutable' then raise exception 'FAIL admin F6.12 (O2): cambia el id (%)', v; end if;
  -- O7: al editar lo publicado (o cancelado) se sigue exigiendo lugar
  v := pg_temp.f612_err($q$update guide.events set location_text = null where id = 'e6120000-0000-4000-8000-000000000004'$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12 (O7): publicado sin lugar (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set location_text = '  ' where id = 'e6120000-0000-4000-8000-000000000006'$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12 (O7): cancelado sin lugar (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set item_id = null where id = 'e6120000-0000-4000-8000-000000000001'$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12 (O7): quita la ficha sin texto (%)', v; end if;

  -- Transiciones: borrar lo publicado PT423; cancelar conserva approved_at; no hay saltos inválidos
  v := pg_temp.f612_err($q$delete from guide.events where id = 'e6120000-0000-4000-8000-000000000002'$q$);
  if v <> 'PT423 event is live' then raise exception 'FAIL admin F6.12: borra un publicado (%)', v; end if;
  v := pg_temp.f612_err($q$delete from guide.events where id = 'e6120000-0000-4000-8000-000000000006'$q$);
  if v <> 'PT423 event is live' then raise exception 'FAIL admin F6.12: borra un cancelado (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000002', 'rejected')$q$);
  if v not like '55000 event_invalid_transition' then raise exception 'FAIL admin F6.12: approved → rejected (%)', v; end if;
  v_j := guide.set_event_status('e6120000-0000-4000-8000-000000000002', 'cancelled');
  if (v_j ->> 'approved_at')::timestamptz is distinct from v_at then raise exception 'FAIL admin F6.12: cancelar cambia approved_at'; end if;
  v_j := guide.set_event_status('e6120000-0000-4000-8000-000000000002', 'approved');
  if (v_j ->> 'approved_at')::timestamptz is distinct from v_at then raise exception 'FAIL admin F6.12: reactivar cambia approved_at'; end if;
  v_j := guide.reopen_event('e6120000-0000-4000-8000-000000000002');
  if v_j ->> 'approved_at' is not null or v_j ->> 'status' <> 'draft' then raise exception 'FAIL admin F6.12: retirar (%)', v_j; end if;
  if not exists (select 1 from guide.activity_log where entity_table = 'events' and entity_id = 'e6120000-0000-4000-8000-000000000002'
                 and action = 'unpublish' and details @> '{"from":"approved","to":"draft"}') then
    raise exception 'FAIL admin F6.12: retirar no queda como unpublish'; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000007', 'approved')$q$);
  if v not like '55000 event_invalid_transition' then raise exception 'FAIL admin F6.12: rejected → approved (%)', v; end if;
  -- Recuperar (reopen) y descartar con motivo; el motivo solo existe en descartados
  v_j := guide.reopen_event('e6120000-0000-4000-8000-000000000007');
  if v_j ->> 'status' <> 'draft' or v_j ->> 'reject_reason' is not null then raise exception 'FAIL admin F6.12: recuperar (%)', v_j; end if;
  v_j := guide.reject_event('e6120000-0000-4000-8000-000000000007', 'members_only');
  if v_j ->> 'reject_reason' <> 'members_only' then raise exception 'FAIL admin F6.12: motivo (%)', v_j; end if;
  v := pg_temp.f612_err($q$select guide.reject_event('e6120000-0000-4000-8000-000000000005', 'me_aburre')$q$);
  if v not like '23514%events_reject_reason_valid%' then raise exception 'FAIL admin F6.12: motivo fuera de lista (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_event_status('e6120000-0000-4000-8000-000000000005', 'approved', 'duplicate')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: motivo sin descartar (%)', v; end if;
  v := pg_temp.f612_err($q$update guide.events set reject_reason = 'duplicate' where id = 'e6120000-0000-4000-8000-000000000005'$q$);
  if v <> 'ok' or (select reject_reason from guide.events where id = 'e6120000-0000-4000-8000-000000000005') is not null then
    raise exception 'FAIL admin F6.12: motivo en un borrador (%)', v; end if;
  -- Lote: cada uno por separado; los fallos no deshacen los aciertos
  v_j := guide.set_events_status(array['e6120000-0000-4000-8000-000000000020', 'e6120000-0000-4000-8000-000000000005',
                                       'e6120000-0000-4000-8000-0000000000ff']::uuid[], 'approved');
  if jsonb_array_length(v_j -> 'ok') <> 1 or v_j -> 'ok' -> 0 ->> 'id' <> 'e6120000-0000-4000-8000-000000000020'
     or (select array_agg(x ->> 'code' order by x ->> 'code') from jsonb_array_elements(v_j -> 'failed') x)
        is distinct from array['23514', 'P0002'] then
    raise exception 'FAIL admin F6.12: lote (%)', v_j; end if;
  if (select status from guide.events where id = 'e6120000-0000-4000-8000-000000000020') <> 'approved'
     or (select status from guide.events where id = 'e6120000-0000-4000-8000-000000000005') <> 'draft' then
    raise exception 'FAIL admin F6.12: lote no atómico por fila'; end if;
  v_j := guide.set_events_status(array['e6120000-0000-4000-8000-000000000020']::uuid[], 'draft');
  v := pg_temp.f612_err($q$select guide.set_events_status(array['e6120000-0000-4000-8000-000000000020', 'e6120000-0000-4000-8000-000000000020']::uuid[], 'approved')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: lote con duplicados (%)', v; end if;
  v := pg_temp.f612_err($q$select guide.set_events_status(array[]::uuid[], 'approved')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: lote vacío (%)', v; end if;
  v := pg_temp.f612_err(format('select guide.set_events_status(%L::uuid[], %L)',
         (select array_agg(gen_random_uuid()) from generate_series(1, 101)), 'approved'));
  if v not like '22023%' then raise exception 'FAIL admin F6.12: lote > 100 (%)', v; end if;

  -- Duplicado resuelto en el listado (antes de borrar e08)
  select * into r from guide.admin_list_events(p_id => 'e6120000-0000-4000-8000-000000000008');
  if r.duplicate_of is distinct from 'e6120000-0000-4000-8000-000000000002'::uuid or r.duplicate_of_status is null then
    raise exception 'FAIL admin F6.12: duplicate_of (%)', to_jsonb(r); end if;

  -- Borrar un borrador: registro sin agent_meta
  delete from guide.events where id = 'e6120000-0000-4000-8000-000000000008';
  if not exists (select 1 from guide.activity_log where entity_table = 'events' and entity_id = 'e6120000-0000-4000-8000-000000000008'
                 and action = 'delete' and old_row is not null and not (old_row ? 'agent_meta')
                 and details @> '{"by":"admin","source":"agent","status":"draft"}') then
    raise exception 'FAIL admin F6.12: registro del borrado'; end if;
  if exists (select 1 from guide.activity_log where entity_table = 'events' and entity_id like 'e6120000-%'
             and (old_row::text like '%secreto%' or details::text like '%secreto%')) then
    raise exception 'LEAK F6.12: agent_meta en el registro'; end if;

  -- Listado: filtros, búsqueda sin comodines inyectados, orden, total
  select count(*) into v_n from guide.admin_list_events(p_query => 'rls f612');
  if v_n < 8 then raise exception 'FAIL admin F6.12: búsqueda (% filas)', v_n; end if;
  if exists (select 1 from guide.admin_list_events(p_query => '%')) or exists (select 1 from guide.admin_list_events(p_query => '_'))
     or exists (select 1 from guide.admin_list_events(p_query => 'rls f612 \')) then
    raise exception 'FAIL admin F6.12: la búsqueda interpreta comodines'; end if;
  if (select count(*) from guide.admin_list_events(p_query => 'RLS F612 ROCÓDROMO')) < 1 then
    raise exception 'FAIL admin F6.12: no busca por nombre de la ficha'; end if;
  if (select array_agg(id order by id) from guide.admin_list_events(p_query => 'rls f612', p_when => 'past'))
     is distinct from array['e6120000-0000-4000-8000-000000000004']::uuid[] then
    raise exception 'FAIL admin F6.12: filtro pasado'; end if;
  if exists (select 1 from guide.admin_list_events(p_query => 'rls f612', p_when => 'upcoming') where is_past) then
    raise exception 'FAIL admin F6.12: filtro próximos'; end if;
  if (select array_agg(id order by id) from guide.admin_list_events(p_query => 'rls f612 del agente') ) is null
     or (select array_agg(id order by id) from guide.admin_list_events(p_query => 'rls f612', p_source => 'agent'))
     is distinct from array['e6120000-0000-4000-8000-000000000003', 'e6120000-0000-4000-8000-000000000007',
                            'e6120000-0000-4000-8000-000000000020']::uuid[] then
    raise exception 'FAIL admin F6.12: filtro por origen'; end if;
  if (select count(*) from guide.admin_list_events(p_query => 'rls f612', p_item_id => 'f6120000-0000-4000-8000-000000000001')) <> 2 then
    raise exception 'FAIL admin F6.12: filtro por ficha'; end if;
  if (select bool_or(prev > starts_at) from (select starts_at, lag(starts_at) over () as prev
        from guide.admin_list_events(p_query => 'rls f612', p_when => 'upcoming')) s) then
    raise exception 'FAIL admin F6.12: próximos no van en orden ascendente'; end if;
  if (select bool_or(prev < starts_at) from (select starts_at, lag(starts_at) over () as prev
        from guide.admin_list_events(p_query => 'rls f612', p_sort => 'desc')) s) then
    raise exception 'FAIL admin F6.12: orden descendente'; end if;
  v := pg_temp.f612_err($q$select * from guide.admin_list_events(p_sort => 'random()')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: p_sort libre (%)', v; end if;
  if (select count(*) from guide.admin_list_events(p_query => 'rls f612', p_limit => 2)) <> 2
     or (select max(total_count) from guide.admin_list_events(p_query => 'rls f612', p_limit => 2)) < 8 then
    raise exception 'FAIL admin F6.12: paginación / total_count'; end if;
  v := pg_temp.f612_err($q$select * from guide.admin_list_events(p_when => 'ayer')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: p_when libre (%)', v; end if;
  v := pg_temp.f612_err($q$select * from guide.admin_list_events(p_event_types => array['x''; drop table guide.events; --'])$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12: p_event_type libre (%)', v; end if;
  v := pg_temp.f612_err(format('select * from guide.admin_list_events(p_query => %L)', repeat('a', 201)));
  if v not like '22023%' then raise exception 'FAIL admin F6.12: búsqueda larga (%)', v; end if;

  -- Contador del menú: borradores no pasados
  v_j := guide.admin_events_summary();
  if (v_j ->> 'badge')::bigint is distinct from (select count(*) from guide.events e
        where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day))
     or (v_j ->> 'pending_agent')::bigint is distinct from (select count(*) from guide.admin_list_events(
        p_status => 'draft', p_source => 'agent', p_when => 'upcoming', p_limit => 200))
     or (v_j ->> 'total')::bigint is distinct from (select count(*) from guide.events)
     or (v_j ->> 'badge')::bigint is distinct from (guide.admin_dashboard_stats() ->> 'events_drafts')::bigint
     or jsonb_typeof(v_j -> 'by_type') <> 'object' then
    raise exception 'FAIL admin F6.12: admin_events_summary (%)', v_j; end if;
  if (select count(*) from guide.admin_list_events(p_query => 'rls f612', p_event_types => array['other', 'course'])) < 1
     or exists (select 1 from guide.admin_list_events(p_query => 'rls f612', p_event_types => array['competition'])) then
    raise exception 'FAIL admin F6.12: filtro por tipos'; end if;
  if exists (select 1 from guide.admin_list_events(p_query => 'rls f612', p_status => 'rejected') where reject_reason is distinct from 'members_only') then
    raise exception 'FAIL admin F6.12: motivo en el listado'; end if;

  -- Exportación con procedencia solo para el admin
  -- O7: despublicar la ficha no se bloquea; los eventos públicos sin texto heredan su nombre (sin enlace en el sitio)
  perform guide.unpublish_item('f6120000-0000-4000-8000-000000000001');
  if (select location_text from guide.events where id = 'e6120000-0000-4000-8000-000000000001') is distinct from 'RLS F612 Rocódromo'
     or (select location_text from guide.events where id = 'e6120000-0000-4000-8000-000000000002') is not null then
    raise exception 'FAIL admin F6.12 (O7): lugar tras despublicar la ficha'; end if;
  update guide.events set price_text = 'Socios' where id = 'e6120000-0000-4000-8000-000000000001';
  v := pg_temp.f612_err($q$update guide.events set location_text = null where id = 'e6120000-0000-4000-8000-000000000001'$q$);
  if v <> '23514 event_place_required' then raise exception 'FAIL admin F6.12 (O7): vacía el texto con la ficha oculta (%)', v; end if;
  if not exists (select 1 from jsonb_array_elements(guide.admin_export('events', 'json', '{"statuses":["draft","approved","cancelled","rejected"]}') -> 'rows') x
                 where x ->> 'id' = 'e6120000-0000-4000-8000-000000000003'
                   and x ->> 'source' = 'agent' and x ->> 'source_url' = 'https://fuente.test/a') then
    raise exception 'FAIL admin F6.12: export_events'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

do $$ begin
  if exists (select 1 from guide.events where dedupe_key = 'rls-f612-x')
     or (select dedupe_key from guide.events where id = 'e6120000-0000-4000-8000-000000000030') is not null then
    raise exception 'FAIL admin F6.12: el admin fija dedupe_key'; end if;
end $$;

-- anon tras los cambios: el cancelado sigue visible; el despublicado (e02) ya no
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  if exists (select 1 from guide.events where id = 'e6120000-0000-4000-8000-000000000002') then
    raise exception 'LEAK anon F6.12: ve un evento despublicado'; end if;
  if not exists (select 1 from guide.events where id = 'e6120000-0000-4000-8000-000000000006' and status = 'cancelled') then
    raise exception 'FAIL anon F6.12: no ve el cancelado'; end if;
  if not exists (select 1 from guide.events where id = 'e6120000-0000-4000-8000-000000000003') then
    raise exception 'FAIL anon F6.12: no ve el borrador del agente aprobado'; end if;
  if exists (select 1 from guide.events where reject_reason is not null) then
    raise exception 'LEAK anon F6.12: ve motivos de descarte'; end if;
end $$;
-- Fin F6.12: deja el rol y los claims como estaban
reset role;
select set_config('request.jwt.claims', '{}', true);

-- ═════════════ F6.12 (D33): descarte automático de borradores caducados ═════════════
-- Autónomo: se puede ejecutar solo (BEGIN … este bloque … ROLLBACK). Usuarios y admin con ON CONFLICT DO NOTHING.
-- Eventos «RLS F612X» (ids e6121000…): x1 draft −2 d (caduca) · x2 draft todo el día hoy en Madrid (no) · x3 draft +3 d
-- (no) · x4 draft en curso (empezó hace 3 h, acaba en 2 h: no) · x5 draft todo el día ayer en Madrid (caduca)
-- · x6 approved −5 d (no se toca) · x7 draft del agente −1 d (caduca; procedencia intacta).
insert into auth.users (id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('a0000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'rls-admin@chalkguide.test', '{"full_name":"Admin Test"}', now(), now()),
  ('a0000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'rls-user1@chalkguide.test', '{"full_name":"User Uno"}', now(), now())
on conflict (id) do nothing;
insert into guide.admins (user_id, email) values ('a0000000-0000-4000-8000-000000000001', 'rls-admin@chalkguide.test')
on conflict (user_id) do nothing;
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.events (id, title_es, starts_at, ends_at, all_day, status, source, location_text, dedupe_key, agent_meta, approved_at) values
  ('e6121000-0000-4000-8000-000000000001', 'RLS F612X caducado', now() - interval '2 days', null, false, 'draft', 'manual',
   'Sala RLS', null, null, null),
  ('e6121000-0000-4000-8000-000000000002', 'RLS F612X hoy todo el día',
   date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid', null, true, 'draft', 'manual',
   'Sala RLS', null, null, null),
  ('e6121000-0000-4000-8000-000000000003', 'RLS F612X futuro', now() + interval '3 days', null, false, 'draft', 'manual',
   'Sala RLS', null, null, null),
  ('e6121000-0000-4000-8000-000000000004', 'RLS F612X en curso', now() - interval '3 hours', now() + interval '2 hours', false,
   'draft', 'manual', 'Sala RLS', null, null, null),
  ('e6121000-0000-4000-8000-000000000005', 'RLS F612X ayer todo el día',
   (date_trunc('day', now() at time zone 'Europe/Madrid') - interval '1 day') at time zone 'Europe/Madrid', null, true,
   'draft', 'manual', 'Sala RLS', null, null, null),
  ('e6121000-0000-4000-8000-000000000006', 'RLS F612X publicado pasado', now() - interval '5 days', null, false, 'approved',
   'manual', 'Sala RLS', null, null, now() - interval '9 days'),
  ('e6121000-0000-4000-8000-000000000007', 'RLS F612X agente caducado', now() - interval '1 day', null, false, 'draft', 'agent',
   'Sala RLS', 'rls-f612x-a', '{"confidence":0.8}', null);
select set_config('guide.draft_op', '', true);

create or replace function pg_temp.f612x_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Catálogo: INVOKER, search_path vacío, sin EXECUTE para clientes ni service_role; job diario en SQL puro
do $$
begin
  if has_function_privilege('anon', 'guide.discard_expired_event_drafts()', 'execute')
     or has_function_privilege('authenticated', 'guide.discard_expired_event_drafts()', 'execute')
     or has_function_privilege('service_role', 'guide.discard_expired_event_drafts()', 'execute') then
    raise exception 'LEAK F6.12 D33: discard_expired_event_drafts ejecutable por clientes'; end if;
  if exists (select 1 from pg_proc where oid = 'guide.discard_expired_event_drafts'::regproc
             and (prosecdef or not proconfig @> array['search_path=""'])) then
    raise exception 'FAIL F6.12 D33: la función no es INVOKER con search_path vacío'; end if;
  if pg_get_functiondef('guide.discard_expired_event_drafts'::regproc) not like '%current_user <> ''postgres''%' then
    raise exception 'FAIL F6.12 D33-1: la guarda no exige postgres'; end if;
  if not exists (select 1 from cron.job where jobname = 'guide-events-discard-expired' and active and username = 'postgres'
                 and schedule = '30 2 * * *' and command = 'select guide.discard_expired_event_drafts()') then
    raise exception 'FAIL F6.12 D33: job diario ausente o distinto'; end if;
end $$;

-- Ningún rol cliente la ejecuta (ni service_role, que salta RLS)
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ declare v text; begin
  v := pg_temp.f612x_err($q$select guide.discard_expired_event_drafts()$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.12 D33: ejecuta el descarte (%)', v; end if;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ declare v text; begin
  v := pg_temp.f612x_err($q$select guide.discard_expired_event_drafts()$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.12 D33: ejecuta el descarte (%)', v; end if;
  -- Antes del descarte: el contador no cuenta caducados y el admin no elige «Caducado»
  if (guide.admin_events_summary() ->> 'badge')::bigint is distinct from (guide.admin_dashboard_stats() ->> 'events_drafts')::bigint
     or (guide.admin_events_summary() ->> 'pending_past')::bigint < 3
     or (guide.admin_events_summary() ->> 'badge')::bigint is distinct from
        (select count(*) from guide.events e where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)) then
    raise exception 'FAIL admin F6.12 D33: contador con caducados'; end if;
  v := pg_temp.f612x_err($q$select guide.set_event_status('e6121000-0000-4000-8000-000000000003', 'rejected', 'expired')$q$);
  if v not like '22023%' then raise exception 'FAIL admin F6.12 D33: set_event_status acepta expired (%)', v; end if;
  v := pg_temp.f612x_err($q$select guide.set_events_status(array['e6121000-0000-4000-8000-000000000003']::uuid[], 'rejected', 'expired')$q$);
  if v <> 'ok' or (select status from guide.events where id = 'e6121000-0000-4000-8000-000000000003') <> 'draft' then
    raise exception 'FAIL admin F6.12 D33: el lote pone expired (%)', v; end if;
  v := pg_temp.f612x_err($q$update guide.events set status = 'rejected', reject_reason = 'expired' where id = 'e6121000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 event_reason_reserved' then raise exception 'FAIL admin F6.12 D33: UPDATE directo pone expired (%)', v; end if;
  v := pg_temp.f612x_err($q$insert into guide.events (title_es, starts_at, status, reject_reason, location_text) values ('RLS F612X x', now() + interval '1 day', 'rejected', 'expired', 'Sala')$q$);
  if v not like '55000%' and v not like '42501%' then raise exception 'FAIL admin F6.12 D33: INSERT con expired (%)', v; end if;
end $$;
reset role;
-- service_role (agente F8) tampoco
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$ declare v text; begin
  v := pg_temp.f612x_err($q$select guide.discard_expired_event_drafts()$q$);
  if v not like '42501%' then raise exception 'LEAK service_role F6.12 D33: ejecuta el descarte (%)', v; end if;
end $$;
reset role;
-- D33-1: aunque se conceda EXECUTE por error a service_role (BYPASSRLS) y no haya claims (SQL directo), no corre.
-- El GRANT vive solo en esta transacción y se retira acto seguido; no se crean roles.
grant execute on function guide.discard_expired_event_drafts() to service_role;
set local role service_role;
select set_config('request.jwt.claims', '', true);
do $$ declare v text; begin
  v := pg_temp.f612x_err($q$select guide.discard_expired_event_drafts()$q$);
  if v <> '42501 maintenance only' then raise exception 'FAIL F6.12 D33-1: corre como service_role sin claims (%)', v; end if;
end $$;
reset role;
revoke execute on function guide.discard_expired_event_drafts() from service_role;
-- D33-2: postgres con un JWT de PostgREST en la sesión (claims fijados aquí): tampoco
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$ declare v text; begin
  v := pg_temp.f612x_err($q$select guide.discard_expired_event_drafts()$q$);
  if v <> '42501 maintenance only' then raise exception 'FAIL F6.12 D33: corre con claims de PostgREST (%)', v; end if;
end $$;
select set_config('request.jwt.claims', '', true);

-- La tarea (como postgres, igual que pg_cron): caducados → rejected/expired; el resto intacto; GUC restaurado; registro
do $$
declare v_n integer; v_log int; r record;
begin
  v_n := guide.discard_expired_event_drafts();
  if v_n < 3 then raise exception 'FAIL F6.12 D33: descarta % (< 3)', v_n; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.12 D33: deja guide.draft_op = %', current_setting('guide.draft_op', true); end if;
  for r in select id, status, reject_reason, approved_at, source, dedupe_key from guide.events where title_es like 'RLS F612X%' loop
    if r.id in ('e6121000-0000-4000-8000-000000000001', 'e6121000-0000-4000-8000-000000000005', 'e6121000-0000-4000-8000-000000000007') then
      if r.status <> 'rejected' or r.reject_reason is distinct from 'expired' or r.approved_at is not null then
        raise exception 'FAIL F6.12 D33: % no queda rejected/expired', r.id; end if;
    elsif r.id = 'e6121000-0000-4000-8000-000000000006' then
      if r.status <> 'approved' or r.reject_reason is not null then raise exception 'FAIL F6.12 D33: toca un publicado pasado'; end if;
    elsif r.status <> 'draft' or r.reject_reason is not null then
      raise exception 'FAIL F6.12 D33: descarta un borrador vigente (%)', r.id;
    end if;
  end loop;
  if (select source::text || '|' || dedupe_key from guide.events where id = 'e6121000-0000-4000-8000-000000000007') <> 'agent|rls-f612x-a' then
    raise exception 'FAIL F6.12 D33: cambia la procedencia'; end if;
  if exists (select 1 from guide.events e where e.status = 'draft' and guide.event_is_past(e.starts_at, e.ends_at, e.all_day)) then
    raise exception 'FAIL F6.12 D33: quedan borradores caducados'; end if;
  select count(*) into v_log from guide.activity_log l
  where l.entity_table = 'events' and l.entity_id in ('e6121000-0000-4000-8000-000000000001', 'e6121000-0000-4000-8000-000000000005',
                                                      'e6121000-0000-4000-8000-000000000007')
    and l.action = 'update' and l.actor_id is null and l.old_row is null
    and l.details = jsonb_build_object('by', 'system', 'source', l.details ->> 'source', 'from', 'draft', 'to', 'rejected', 'reason', 'expired');
  if v_log <> 3 then raise exception 'FAIL F6.12 D33: registro del sistema (% filas)', v_log; end if;
  if exists (select 1 from guide.activity_log l where l.entity_id = 'e6121000-0000-4000-8000-000000000007'
             and (l.details ? 'agent_meta' or l.details::text like '%confidence%')) then
    raise exception 'LEAK F6.12 D33: agent_meta en el registro'; end if;
  -- Idempotente: una segunda pasada no hace nada
  if guide.discard_expired_event_drafts() <> 0 then raise exception 'FAIL F6.12 D33: segunda pasada no vacía'; end if;
end $$;

-- Admin tras el descarte: lo ve como motivo, conserva «Caducado» al editar, lo limpia al recuperar; contador sin caducados
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ declare v text; begin
  if (select reject_reason from guide.admin_list_events(p_id => 'e6121000-0000-4000-8000-000000000005')) is distinct from 'expired' then
    raise exception 'FAIL admin F6.12 D33: el listado no da expired'; end if;
  if (guide.admin_events_summary() ->> 'pending_past')::bigint <> 0
     or (guide.admin_dashboard_stats() ->> 'events_drafts_expired')::bigint <> 0 then
    raise exception 'FAIL admin F6.12 D33: quedan caducados en los contadores'; end if;
  v := pg_temp.f612x_err($q$update guide.events set price_text = 'Gratis' where id = 'e6121000-0000-4000-8000-000000000001'$q$);
  if v <> 'ok' or (select reject_reason from guide.events where id = 'e6121000-0000-4000-8000-000000000001') <> 'expired' then
    raise exception 'FAIL admin F6.12 D33: editar un caducado (%)', v; end if;
  v := pg_temp.f612x_err($q$select guide.set_event_status('e6121000-0000-4000-8000-000000000001', 'rejected', 'duplicate')$q$);
  if v <> 'ok' or (select reject_reason from guide.events where id = 'e6121000-0000-4000-8000-000000000001') <> 'duplicate' then
    raise exception 'FAIL admin F6.12 D33: cambiar el motivo de un caducado (%)', v; end if;
  v := pg_temp.f612x_err($q$update guide.events set reject_reason = 'expired' where id = 'e6121000-0000-4000-8000-000000000001'$q$);
  if v <> '42501 event_reason_reserved' then raise exception 'FAIL admin F6.12 D33: vuelve a poner expired a mano (%)', v; end if;
  perform guide.reopen_event('e6121000-0000-4000-8000-000000000005');
  if (select status::text || '|' || coalesce(reject_reason, '-') from guide.events where id = 'e6121000-0000-4000-8000-000000000005') <> 'draft|-' then
    raise exception 'FAIL admin F6.12 D33: recuperar un caducado'; end if;
  if (guide.admin_events_summary() ->> 'badge')::bigint is distinct from (guide.admin_dashboard_stats() ->> 'events_drafts')::bigint
     or (guide.admin_events_summary() ->> 'pending_past')::bigint <> 1 then
    raise exception 'FAIL admin F6.12 D33: el recuperado cuenta como pendiente'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- anon: los descartados por caducidad siguen ocultos
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  if (select array_agg(id) from guide.events where title_es like 'RLS F612X%') is distinct from
     array['e6121000-0000-4000-8000-000000000006']::uuid[] then
    raise exception 'LEAK anon F6.12 D33: visibilidad de eventos'; end if;
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- Fin F6.12 D33

-- ═════════════ F6.13 (D34): páginas de clave cerrada, PT423, unpublish_page, legales, revised_on, page_versions ═════════════
-- Fixtures (como postgres, mantenimiento explícito). Las filas reales de guide.pages se retiraron al principio; aquí
-- se retiran también las de bloques anteriores y se crean las cinco claves con ids e613…:
--   …01 about publicada con EN · …02 transparency publicada · …03 legal_notice publicada (revised_on hace 30 días)
--   …04 privacy sin publicar · …05 cookies sin publicar. Medio b613…01 sin alt (D27).
select set_config('request.jwt.claims', '{}', true);
select set_config('guide.draft_op', 'maintenance', true);
-- F6.13 V1: solo dentro de la suite completa. SAVEPOINT falla (25P01) fuera de una transacción explícita y el DO exige
-- la marca local guide.rls_suite; el DELETE va dentro del DO para que no corra si la guarda falla.
savepoint pages_guard;
release savepoint pages_guard;
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  delete from guide.pages;
end $$;
insert into storage.objects (bucket_id, name, metadata)
values ('media', 'b6130000-0000-4000-8000-000000000001/1-f613.jpg', '{"mimetype":"image/jpeg","size":900}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height)
values ('b6130000-0000-4000-8000-000000000001', 'b6130000-0000-4000-8000-000000000001/1-f613.jpg', 'f613.jpg', 'image/jpeg', 1, 10, 10);
insert into guide.pages (id, key, title_es, slug_es, title_en, slug_en, body_json_es, body_html_es, body_json_en, body_html_en,
                         published, noindex, revised_on) values
  ('e6130000-0000-4000-8000-000000000001', 'about', 'F613 Sobre', 'rls-f613-sobre', 'F613 About', 'rls-f613-about',
   '{"type":"doc","content":[]}', '<p>es</p>', '{"type":"doc","content":[]}', '<p>en</p>', true, false, null),
  ('e6130000-0000-4000-8000-000000000002', 'transparency', 'F613 Transparencia', 'rls-f613-transparencia', null, null,
   '{"type":"doc","content":[]}', '<p>es</p>', null, null, true, false, null),
  ('e6130000-0000-4000-8000-000000000003', 'legal_notice', 'F613 Aviso', 'rls-f613-aviso', null, null,
   '{"type":"doc","content":[]}', '<p>aviso</p>', null, null, true, true,
   (now() at time zone 'Europe/Madrid')::date - 30),
  ('e6130000-0000-4000-8000-000000000004', 'privacy', 'F613 Privacidad', 'rls-f613-privacidad', null, null,
   '{"type":"doc","content":[]}', '<p>privacidad</p>', null, null, false, true, null),
  ('e6130000-0000-4000-8000-000000000005', 'cookies', 'F613 Cookies', 'rls-f613-cookies', null, null,
   '{"type":"doc","content":[]}', '<p>cookies</p>', null, null, false, true, null);
select set_config('guide.draft_op', '', true);

create or replace function pg_temp.f613_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Catálogo
do $$
begin
  if exists (select 1 from pg_proc where oid = 'guide.unpublish_page'::regproc
             and (not prosecdef or not proconfig @> array['search_path=""'])) then
    raise exception 'FAIL F6.13: unpublish_page no es DEFINER con search_path vacío'; end if;
  if pg_get_functiondef('guide.unpublish_page'::regproc) not like '%begin%perform guide.assert_admin();%' then
    raise exception 'FAIL F6.13: unpublish_page no empieza por assert_admin'; end if;
  if has_function_privilege('anon', 'guide.unpublish_page(uuid)', 'execute')
     or has_function_privilege('anon', 'guide.admin_pages_list()', 'execute')
     or has_function_privilege('anon', 'guide.publish_draft(text, uuid, boolean, text)', 'execute') then
    raise exception 'LEAK F6.13: anon ejecuta RPC de páginas'; end if;
  if has_function_privilege('service_role', 'guide.unpublish_page(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'guide.unpublish_page(uuid)', 'execute')
     or exists (select 1 from aclexplode((select proacl from pg_proc where oid = 'guide.unpublish_page'::regproc)) a where a.grantee = 0)
     or exists (select 1 from aclexplode((select proacl from pg_proc where oid = 'guide.pages_record_version'::regproc)) a
                where a.grantee <> (select oid from pg_roles where rolname = 'postgres')) then
    raise exception 'LEAK F6.13: EXECUTE mal concedido (unpublish_page / pages_record_version)'; end if;
  -- O1: service_role sin INSERT/DELETE/TRUNCATE; guarda de TRUNCATE
  if has_table_privilege('service_role', 'guide.pages', 'insert') or has_table_privilege('service_role', 'guide.pages', 'delete')
     or has_table_privilege('service_role', 'guide.pages', 'truncate')
     or not exists (select 1 from pg_trigger where tgrelid = 'guide.pages'::regclass and tgname = 'pages_before_truncate') then
    raise exception 'LEAK F6.13 O1: service_role escribe filas fijas o falta la guarda de TRUNCATE'; end if;
  -- O3: UPDATE por columnas (editables + published), nada de key, slugs ni revised_on
  if has_table_privilege('authenticated', 'guide.pages', 'update')
     or not has_column_privilege('authenticated', 'guide.pages', 'title_es', 'update')
     or not has_column_privilege('authenticated', 'guide.pages', 'published', 'update')
     or has_column_privilege('authenticated', 'guide.pages', 'key', 'update')
     or has_column_privilege('authenticated', 'guide.pages', 'slug_es', 'update')
     or has_column_privilege('authenticated', 'guide.pages', 'slug_en', 'update')
     or has_column_privilege('authenticated', 'guide.pages', 'revised_on', 'update')
     or has_column_privilege('authenticated', 'guide.pages', 'id', 'update') then
    raise exception 'LEAK F6.13 O3: UPDATE de pages no es por columnas'; end if;
  -- O4: draft_op se limpia justo tras assert_admin()
  if pg_get_functiondef('guide.unpublish_page'::regproc)
     !~ 'perform guide\.assert_admin\(\);\s*(--[^\n]*\n\s*)?perform set_config\(''guide\.draft_op'', '''', true\);' then
    raise exception 'FAIL F6.13 O4: unpublish_page no limpia draft_op tras assert_admin'; end if;
  if to_regprocedure('guide.publish_draft(text, uuid, boolean)') is not null then
    raise exception 'FAIL F6.13: queda la firma de 3 argumentos de publish_draft'; end if;
  if guide.draft_allowed_columns('pages') && array['slug_es', 'slug_en', 'revised_on', 'key', 'published'] then
    raise exception 'FAIL F6.13: slugs/revised_on/key/published en la lista blanca de páginas'; end if;
  if has_table_privilege('authenticated', 'guide.pages', 'insert') or has_table_privilege('authenticated', 'guide.pages', 'delete')
     or exists (select 1 from pg_policies where schemaname = 'guide' and tablename = 'pages' and cmd in ('INSERT', 'DELETE')) then
    raise exception 'LEAK F6.13: INSERT/DELETE de páginas para clientes'; end if;
  if not (select relrowsecurity from pg_class where oid = 'guide.page_versions'::regclass)
     or has_table_privilege('anon', 'guide.page_versions', 'select')
     or has_table_privilege('authenticated', 'guide.page_versions', 'insert')
     or has_table_privilege('authenticated', 'guide.page_versions', 'update')
     or has_table_privilege('authenticated', 'guide.page_versions', 'delete')
     or has_table_privilege('service_role', 'guide.page_versions', 'insert')
     or exists (select 1 from pg_policies where schemaname = 'guide' and tablename = 'page_versions' and cmd <> 'SELECT') then
    raise exception 'LEAK F6.13: page_versions con RLS o privilegios de más'; end if;
  -- La fixture legal publicada en mantenimiento dejó su versión (sin admin)
  if (select count(*) from guide.page_versions where key = 'legal_notice' and title = 'F613 Aviso' and published_by is null) <> 1 then
    raise exception 'FAIL F6.13: la legal publicada no deja versión'; end if;
end $$;

-- Como postgres sin mantenimiento: clave cerrada, sin borrar, clave y slugs inmutables, revised_on futura
do $$ declare v text; begin
  v := pg_temp.f613_err($q$insert into guide.pages (key, title_es, slug_es) values ('rls_f613_x', 'x', 'rls-f613-x')$q$);
  if v not like '23514%' then raise exception 'FAIL F6.13: clave fuera del conjunto (%)', v; end if;
  v := pg_temp.f613_err($q$insert into guide.pages (key, title_es, slug_es) values ('about', 'x', 'rls-f613-x')$q$);
  if v not like '23505%' then raise exception 'FAIL F6.13: segunda fila about (%)', v; end if;
  v := pg_temp.f613_err($q$delete from guide.pages where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v <> '42501 pages are fixed' then raise exception 'FAIL F6.13: postgres sin mantenimiento borra (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set key = 'privacy' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v <> '22023 page key is immutable' then raise exception 'FAIL F6.13: key mutable (%)', v; end if;
  perform set_config('guide.draft_op', 'maintenance', true);
  v := pg_temp.f613_err($q$update guide.pages set key = 'privacy' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v <> '22023 page key is immutable' then raise exception 'FAIL F6.13: key mutable en mantenimiento (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date + 1 where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v <> '23514 revised_on in the future' then raise exception 'FAIL F6.13: revised_on futura en mantenimiento (%)', v; end if;
  perform set_config('guide.draft_op', '', true);
  v := pg_temp.f613_err($q$update guide.pages set slug_es = 'rls-f613-x' where id = 'e6130000-0000-4000-8000-000000000004'$q$);
  if v <> '22023 page slugs are fixed' then raise exception 'FAIL F6.13: slug mutable sin publicar (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set slug_en = 'rls-f613-x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v <> '22023 page slugs are fixed' then raise exception 'FAIL F6.13: slug_en mutable (%)', v; end if;
  -- PT423 también para postgres sin mantenimiento
  v := pg_temp.f613_err($q$update guide.pages set title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v not like 'PT423%' then raise exception 'FAIL F6.13: postgres edita lo publicado sin mantenimiento (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date - 1 where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 revised_on is set on publish' then raise exception 'FAIL F6.13: revised_on a mano como postgres (%)', v; end if;
  -- O1: TRUNCATE se salta los triggers de fila; la guarda de sentencia lo impide (incluso como postgres)
  v := pg_temp.f613_err($q$truncate guide.pages cascade$q$);
  if v <> '42501 pages are fixed' or (select count(*) from guide.pages) <> 5 then
    raise exception 'FAIL F6.13 O1: TRUNCATE de pages (%)', v; end if;
end $$;

-- service_role (BYPASSRLS, no postgres) con 'maintenance': no exime (D33-1)
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
do $$ declare v text; begin
  perform set_config('guide.draft_op', 'maintenance', true);
  v := pg_temp.f613_err($q$update guide.pages set title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  -- PT423 o 42501 (service_role no ejecuta draft_allowed_columns): en ambos casos no escribe
  if (v not like 'PT423%' and v not like '42501%')
     or (select title_es from guide.pages where id = 'e6130000-0000-4000-8000-000000000001') <> 'F613 Sobre' then
    raise exception 'LEAK F6.13: maintenance como service_role exime PT423 (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set published = false where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v not like 'PT423 legal_page_cannot_unpublish%' then raise exception 'LEAK F6.13: service_role despublica una legal (%)', v; end if;
  v := pg_temp.f613_err($q$delete from guide.pages where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  -- O1: sin privilegio DELETE (42501) y, aunque lo tuviera, pages_before_delete (42501 pages are fixed)
  if v not like '42501%' then raise exception 'LEAK F6.13: service_role borra una página (%)', v; end if;
  v := pg_temp.f613_err($q$truncate guide.pages cascade$q$);
  if v not like '42501%' then raise exception 'LEAK F6.13 O1: service_role vacía pages (%)', v; end if;
  perform set_config('guide.draft_op', '', true);
end $$;
reset role;

-- anon: nada de versiones ni RPC; ve solo lo publicado
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ declare v text; begin
  v := pg_temp.f613_err($q$select count(*) from guide.page_versions$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.13: lee page_versions (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.unpublish_page('e6130000-0000-4000-8000-000000000001')$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.13: unpublish_page (%)', v; end if;
  v := pg_temp.f613_err($q$select * from guide.admin_pages_list()$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.13: admin_pages_list (%)', v; end if;
  if (select array_agg(key order by key) from guide.pages) is distinct from array['about', 'legal_notice', 'transparency'] then
    raise exception 'LEAK anon F6.13: visibilidad de páginas'; end if;
  v := pg_temp.f613_err($q$insert into guide.pages (key, title_es, slug_es) values ('about', 'x', 'x')$q$);
  if v not like '42501%' then raise exception 'LEAK anon F6.13: inserta página (%)', v; end if;
end $$;
reset role;

-- authenticated no admin: 42501 en RPC; 0 versiones; sin escribir
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ declare v text; begin
  v := pg_temp.f613_err($q$select guide.unpublish_page('e6130000-0000-4000-8000-000000000001')$q$);
  if v <> '42501 admin only' then raise exception 'LEAK user F6.13: unpublish_page (%)', v; end if;
  v := pg_temp.f613_err($q$select * from guide.admin_pages_list()$q$);
  if v <> '42501 admin only' then raise exception 'LEAK user F6.13: admin_pages_list (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.publish_draft('page', 'e6130000-0000-4000-8000-000000000001', false, 'today')$q$);
  if v <> '42501 admin only' then raise exception 'LEAK user F6.13: publish_draft (%)', v; end if;
  if exists (select 1 from guide.page_versions) then raise exception 'LEAK user F6.13: ve page_versions'; end if;
  v := pg_temp.f613_err($q$insert into guide.page_versions (key, locale, title, body_html, revised_on) values ('privacy', 'es', 'x', 'x', current_date)$q$);
  if v not like '42501%' then raise exception 'LEAK user F6.13: inserta versión (%)', v; end if;
  update guide.pages set title_es = 'hack' where id = 'e6130000-0000-4000-8000-000000000004';
  if found then raise exception 'LEAK user F6.13: edita una página'; end if;
end $$;
reset role;

-- Admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  c_a constant uuid := 'e6130000-0000-4000-8000-000000000001';
  c_t constant uuid := 'e6130000-0000-4000-8000-000000000002';
  c_l constant uuid := 'e6130000-0000-4000-8000-000000000003';
  c_p constant uuid := 'e6130000-0000-4000-8000-000000000004';
  c_c constant uuid := 'e6130000-0000-4000-8000-000000000005';
  v_today date := (now() at time zone 'Europe/Madrid')::date;
  v text;
  v_n int;
  r record;
begin
  -- Sin INSERT ni DELETE (ni el admin); clave y slugs inmutables
  v := pg_temp.f613_err($q$insert into guide.pages (key, title_es, slug_es) values ('about', 'x', 'rls-f613-x')$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: inserta página (%)', v; end if;
  v := pg_temp.f613_err($q$delete from guide.pages where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: borra página (%)', v; end if;
  -- O3: UPDATE por columnas → key, slugs y revised_on ni siquiera son escribibles para authenticated
  v := pg_temp.f613_err($q$update guide.pages set key = 'privacy' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '42501%' then raise exception 'FAIL admin F6.13: key mutable (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set slug_es = 'rls-f613-y' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '42501%' then raise exception 'FAIL admin F6.13: slug mutable (%)', v; end if;

  -- has_en sin slug_en: título + cuerpo EN en una legal sin publicar (edición directa)
  update guide.pages set title_en = 'F613 Cookies', body_json_en = '{"type":"doc","content":[]}', body_html_en = '<p>en</p>'
  where id = c_c;
  if not (select has_en from guide.pages where id = c_c) or (select slug_en from guide.pages where id = c_c) is not null then
    raise exception 'FAIL admin F6.13: has_en depende de slug_en'; end if;

  -- Legales: noindex fijo, sin OG, solo texto (también sin publicar)
  v := pg_temp.f613_err($q$update guide.pages set noindex = false where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '23514%pages_legal_fixed%' then raise exception 'FAIL admin F6.13: legal indexable (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set og_media_id = 'b0000000-0000-4000-8000-000000000001' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '23514%pages_legal_fixed%' then raise exception 'FAIL admin F6.13: legal con OG (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set body_json_es = '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"itemCard","attrs":{"kind":"gym","slug":"x"}}]}]}' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: legal con ficha (JSON) (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set body_html_en = '<p>x</p><IFRAME src="https://www.youtube-nocookie.com/embed/x"></iframe>' where id = 'e6130000-0000-4000-8000-000000000005'$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: legal con vídeo (HTML EN) (%)', v; end if;
  -- O2: lista blanca de etiquetas y atributos peligrosos
  foreach v in array array['<svg><image href="x"/></svg>', '<p><input type=image src=x></p>', '<link rel=stylesheet href=x>',
                           '<style>p{}</style>', '<p style="background:url(x)">x</p>', '<object data=x></object>', '<embed src=x>',
                           '<audio src=x></audio>', '<picture></picture>', '<source src=x>', '<script>x</script>',
                           '<p onclick="x">a</p>', '<a href="javascript:alert(1)">a</a>', '<a href=" data:text/html,x">a</a>',
                           '<!-- x -->', '< img src=x>'] loop
    if pg_temp.f613_err(format('update guide.pages set body_html_es = %L where id = %L', v, c_c)) not like '23514%pages_legal_text_only%' then
      raise exception 'FAIL admin F6.13 O2: legal acepta %', v; end if;
  end loop;
  -- …y el HTML normal del editor en modo texto sí entra
  update guide.pages set body_html_es = '<h2>Datos</h2><p>Hola <strong>x</strong> <em>y</em> <a href="https://x.com" rel="noopener">l</a> '
    || '<a href="mailto:a@b.c">m</a></p><ul><li><p>a</p></li></ul><ol><li><p>b</p></li></ol><blockquote><p>c</p></blockquote>'
    || '<p>a<br>b &lt; c</p><h3>z</h3>'
  where id = c_c;
  update guide.pages set body_html_es = '<p>cookies</p>' where id = c_c;
  -- …y no publicar con imagen en el mismo UPDATE
  v := pg_temp.f613_err($q$update guide.pages set published = true, body_html_es = '<p>x</p><img src="x.jpg" alt="x">' where id = 'e6130000-0000-4000-8000-000000000004'$q$);
  if v not like '23514%pages_legal_text_only%' or (select published from guide.pages where id = c_p) then
    raise exception 'FAIL admin F6.13: publica una legal con imagen (%)', v; end if;

  -- revised_on nunca la escribe el cliente
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date + 1 where id = 'e6130000-0000-4000-8000-000000000004'$q$);
  if v not like '42501%' then raise exception 'FAIL admin F6.13: revised_on futura (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date - 1 where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v not like '42501%' then raise exception 'FAIL admin F6.13: revised_on a mano (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date where id = 'e6130000-0000-4000-8000-000000000002'$q$);
  if v not like '42501%' and v not like '23514%' then raise exception 'FAIL admin F6.13: revised_on en no legal (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"revised_on":"2020-01-01"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '22023 column not allowed%' then raise exception 'FAIL admin F6.13: revised_on en el borrador (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000001', '{"page":{"slug_es":"rls-f613-z"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000001'))$q$);
  if v not like '22023 column not allowed%' then raise exception 'FAIL admin F6.13: slug en el borrador (%)', v; end if;

  -- Primera publicación de una legal: revised_on = hoy y una versión ES con el admin
  update guide.pages set published = true where id = c_p;
  if (select revised_on from guide.pages where id = c_p) is distinct from v_today then
    raise exception 'FAIL admin F6.13: la primera publicación no fija hoy'; end if;
  if (select count(*) from guide.page_versions where key = 'privacy' and locale = 'es' and title = 'F613 Privacidad'
        and body_html = '<p>privacidad</p>' and revised_on = v_today
        and published_by = 'a0000000-0000-4000-8000-000000000001') <> 1
     or exists (select 1 from guide.page_versions where key = 'privacy' and locale = 'en' and published_at = now()) then
    raise exception 'FAIL admin F6.13: versión de la primera publicación'; end if;
  -- Primera publicación con EN: dos versiones
  update guide.pages set published = true where id = c_c;
  -- Solo las versiones de esta transacción (now() es fijo en ella): la BD ya tiene versiones reales desde 2026-11-05.
  if (select count(*) from guide.page_versions where key = 'cookies' and published_at = now()) <> 2 then
    raise exception 'FAIL admin F6.13: versión EN de la primera publicación'; end if;

  -- PT423: lo publicado no se edita en directo (about y legal)
  v := pg_temp.f613_err($q$update guide.pages set title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v not like 'PT423 page is live%' then raise exception 'FAIL admin F6.13: PT423 directo about (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set seo_title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v not like 'PT423 page is live%' then raise exception 'FAIL admin F6.13: PT423 directo legal (%)', v; end if;
  -- apply:<otra> no exime; 'maintenance' sin BYPASSRLS tampoco
  perform set_config('guide.draft_op', 'apply:' || c_t::text, true);
  v := pg_temp.f613_err($q$update guide.pages set title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v not like 'PT423%' then raise exception 'LEAK admin F6.13: apply:<otra> exime (%)', v; end if;
  perform set_config('guide.draft_op', 'maintenance', true);
  v := pg_temp.f613_err($q$update guide.pages set title_es = 'x' where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v not like 'PT423%' then raise exception 'LEAK admin F6.13: maintenance sin bypass exime (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set revised_on = (now() at time zone 'Europe/Madrid')::date - 3 where id = 'e6130000-0000-4000-8000-000000000003'$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: maintenance sin bypass fija revised_on (%)', v; end if;
  perform set_config('guide.draft_op', '', true);

  -- PT409: borrador con versión vieja
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000001', '{"page":{"title_es":"x"}}', now() - interval '1 day')$q$);
  if v not like 'PT409%' then raise exception 'FAIL admin F6.13: PT409 (%)', v; end if;

  -- Vía borrador: publish_draft fija apply:<id> y publica
  perform guide.save_draft('page', c_a, '{"page":{"title_es":"F613 Sobre v2","seo_title_es":"SEO v2"}}',
                           guide.draft_entity_version('page', c_a));
  perform guide.publish_draft('page', c_a);
  if (select title_es from guide.pages where id = c_a) <> 'F613 Sobre v2'
     or exists (select 1 from guide.content_drafts where page_id = c_a)
     or coalesce(current_setting('guide.draft_op', true), '') <> ''
     or coalesce(current_setting('guide.page_revision', true), '') <> '' then
    raise exception 'FAIL admin F6.13: publish_draft de página'; end if;
  if (select revised_on from guide.pages where id = c_a) is not null then
    raise exception 'FAIL admin F6.13: revised_on en about'; end if;
  -- p_revision solo en legales y con valores cerrados
  perform guide.save_draft('page', c_a, '{"page":{"title_es":"F613 Sobre v3"}}', guide.draft_entity_version('page', c_a));
  v := pg_temp.f613_err($q$select guide.publish_draft('page', 'e6130000-0000-4000-8000-000000000001', false, 'keep')$q$);
  if v <> '22023 revision only for legal pages' then raise exception 'FAIL admin F6.13: p_revision en about (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.publish_draft('page', 'e6130000-0000-4000-8000-000000000003', false, '2020-01-01')$q$);
  if v <> '22023 invalid revision' then raise exception 'FAIL admin F6.13: p_revision libre (%)', v; end if;

  -- D27 (PT422): about con imagen sin alt en el cuerpo
  perform guide.save_draft('page', c_t,
    '{"page":{"body_json_es":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b6130000-0000-4000-8000-000000000001"}}]},"body_html_es":"<p>x</p>"}}',
    guide.draft_entity_version('page', c_t));
  v := pg_temp.f613_err($q$select guide.publish_draft('page', 'e6130000-0000-4000-8000-000000000002')$q$);
  if v not like 'PT422%' then raise exception 'FAIL admin F6.13: D27 en páginas (%)', v; end if;
  if (select body_html_es from guide.pages where id = c_t) <> '<p>es</p>' then
    raise exception 'FAIL admin F6.13: D27 deja cambios a medias'; end if;
  perform guide.discard_draft('page', c_t);

  -- Legal: borrador con imagen / vídeo / ficha / OG / indexable → 23514 al guardar
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"body_json_es":{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b0000000-0000-4000-8000-000000000001"}}]},"body_html_es":"<p>x</p>"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: borrador legal con imagen (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"body_json_en":{"type":"doc","content":[{"type":"videoEmbed","attrs":{"id":"x"}}]},"body_html_en":"<p>x</p>"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: borrador legal con vídeo (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"body_html_es":"<p><a href=\"/rocodromos/x\" data-item-card=\"gym:x\">x</a></p>"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: borrador legal con ficha (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"og_media_id":"b0000000-0000-4000-8000-000000000001"}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '23514%pages_legal_fixed%' then raise exception 'FAIL admin F6.13: borrador legal con OG (%)', v; end if;
  v := pg_temp.f613_err($q$select guide.save_draft('page', 'e6130000-0000-4000-8000-000000000003', '{"page":{"noindex":false}}', guide.draft_entity_version('page', 'e6130000-0000-4000-8000-000000000003'))$q$);
  if v not like '23514%pages_legal_fixed%' then raise exception 'FAIL admin F6.13: borrador legal indexable (%)', v; end if;

  -- revised_on al publicar cambios de una legal (base: hace 30 días)
  -- a) solo SEO, aunque se pida «hoy»: no cambia la fecha ni crea versión
  select count(*) into v_n from guide.page_versions where key = 'legal_notice';
  perform guide.save_draft('page', c_l, '{"page":{"seo_title_es":"SEO aviso"}}', guide.draft_entity_version('page', c_l));
  perform guide.publish_draft('page', c_l, false, 'today');
  if (select revised_on from guide.pages where id = c_l) <> v_today - 30
     or (select count(*) from guide.page_versions where key = 'legal_notice') <> v_n then
    raise exception 'FAIL admin F6.13: solo SEO cambia la fecha o versiona'; end if;
  -- b) errata con «Mantener la anterior»: fecha igual, versión nueva con la fecha antigua
  perform guide.save_draft('page', c_l, '{"page":{"body_html_es":"<p>aviso.</p>"}}', guide.draft_entity_version('page', c_l));
  perform guide.publish_draft('page', c_l, false, 'keep');
  if (select revised_on from guide.pages where id = c_l) <> v_today - 30
     or (select count(*) from guide.page_versions where key = 'legal_notice') <> v_n + 1
     or not exists (select 1 from guide.page_versions where key = 'legal_notice' and body_html = '<p>aviso.</p>'
                    and revised_on = v_today - 30 and published_by = 'a0000000-0000-4000-8000-000000000001') then
    raise exception 'FAIL admin F6.13: «Mantener la anterior»'; end if;
  -- c) cambio de título por defecto (sin p_revision) → hoy
  perform guide.save_draft('page', c_l, '{"page":{"title_es":"F613 Aviso v2"}}', guide.draft_entity_version('page', c_l));
  perform guide.publish_draft('page', c_l);
  if (select revised_on from guide.pages where id = c_l) <> v_today
     or not exists (select 1 from guide.page_versions where key = 'legal_notice' and title = 'F613 Aviso v2' and revised_on = v_today) then
    raise exception 'FAIL admin F6.13: «Hoy» por defecto'; end if;
  if coalesce(current_setting('guide.page_revision', true), '') <> '' then
    raise exception 'FAIL admin F6.13: queda guide.page_revision'; end if;

  -- Versiones: el admin las lee y no las cambia
  if (select count(*) from guide.page_versions) < 5 then raise exception 'FAIL admin F6.13: el admin no ve versiones'; end if;
  v := pg_temp.f613_err($q$update guide.page_versions set title = 'x'$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: modifica versiones (%)', v; end if;
  v := pg_temp.f613_err($q$delete from guide.page_versions$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: borra versiones (%)', v; end if;
  v := pg_temp.f613_err($q$insert into guide.page_versions (key, locale, title, body_html, revised_on) values ('privacy', 'es', 'x', 'x', current_date)$q$);
  if v not like '42501%' then raise exception 'LEAK admin F6.13: inserta versión (%)', v; end if;

  -- Despublicar: legales nunca (ni por RPC ni en directo)
  v := pg_temp.f613_err($q$select guide.unpublish_page('e6130000-0000-4000-8000-000000000003')$q$);
  if v <> 'PT423 legal_page_cannot_unpublish' then raise exception 'FAIL admin F6.13: unpublish_page legal (%)', v; end if;
  v := pg_temp.f613_err($q$update guide.pages set published = false where id = 'e6130000-0000-4000-8000-000000000004'$q$);
  if v <> 'PT423 legal_page_cannot_unpublish' or not (select published from guide.pages where id = c_p) then
    raise exception 'FAIL admin F6.13: despublica una legal en directo (%)', v; end if;

  -- about con borrador pendiente (v3): UPDATE directo published=false → PT423; unpublish_page lo aplica y registra
  v := pg_temp.f613_err($q$update guide.pages set published = false where id = 'e6130000-0000-4000-8000-000000000001'$q$);
  if v <> 'PT423 pending draft' then raise exception 'FAIL admin F6.13: despublicar con borrador en directo (%)', v; end if;
  perform guide.unpublish_page(c_a);
  select * into r from guide.pages where id = c_a;
  if r.published or r.title_es <> 'F613 Sobre v3' or exists (select 1 from guide.content_drafts where page_id = c_a)
     or coalesce(current_setting('guide.unpublish_op', true), '') <> ''
     or coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL admin F6.13: unpublish_page no aplica el borrador o deja GUC'; end if;
  if not exists (select 1 from guide.activity_log where action = 'unpublish' and entity_table = 'pages'
                 and entity_id = c_a::text and actor_id = 'a0000000-0000-4000-8000-000000000001'
                 and (details ->> 'draft_applied')::boolean and details ->> 'key' = 'about') then
    raise exception 'FAIL admin F6.13: registro de unpublish_page'; end if;
  v := pg_temp.f613_err($q$select guide.unpublish_page('e6130000-0000-4000-8000-000000000001')$q$);
  if v not like '22023 page not live%' then raise exception 'FAIL admin F6.13: despublicar dos veces (%)', v; end if;
  -- transparency sin borrador; O4: una GUC 'maintenance' heredada se limpia dentro de la DEFINER
  perform set_config('guide.draft_op', 'maintenance', true);
  perform guide.unpublish_page(c_t);
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL admin F6.13 O4: unpublish_page deja draft_op'; end if;
  if (select published from guide.pages where id = c_t)
     or not exists (select 1 from guide.activity_log where action = 'unpublish' and entity_id = c_t::text
                    and not (details ->> 'draft_applied')::boolean) then
    raise exception 'FAIL admin F6.13: unpublish_page sin borrador'; end if;
  -- Sobre mí y Transparencia sin publicar sí admiten imagen/OG (solo las legales son texto)
  update guide.pages set og_media_id = 'b0000000-0000-4000-8000-000000000001', noindex = true,
         body_json_es = '{"type":"doc","content":[{"type":"image","attrs":{"mediaId":"b0000000-0000-4000-8000-000000000001"}}]}'
  where id = c_t;

  -- Listado: 5 filas en orden fijo, cambios pendientes y revised_on
  perform guide.save_draft('page', c_l, '{"page":{"title_es":"F613 Aviso v3","seo_description_es":"x"}}',
                           guide.draft_entity_version('page', c_l));
  if (select array_agg(l.key) from guide.admin_pages_list() l)
       is distinct from array['about', 'transparency', 'legal_notice', 'privacy', 'cookies'] then
    raise exception 'FAIL admin F6.13: listado'; end if;
  select * into r from guide.admin_pages_list() l where l.key = 'legal_notice';
  if r.draft_changes <> 2 or r.revised_on <> v_today or r.versions_count < 3 or r.draft_updated_at is null then
    raise exception 'FAIL admin F6.13: contadores del listado (%)', row_to_json(r); end if;
  if (select l.draft_changes from guide.admin_pages_list() l where l.key = 'privacy') <> 0 then
    raise exception 'FAIL admin F6.13: cambios sin borrador'; end if;
  perform guide.discard_draft('page', c_l);
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- publish_draft revalida al publicar: un borrador legal con imagen colado sin trigger falla con 23514 y no cambia nada
alter table guide.content_drafts disable trigger content_drafts_before_write;
insert into guide.content_drafts (entity, page_id, payload, base_updated_at)
select 'page', p.id, '{"page":{"body_html_es":"<p>x</p><img src=\"x.jpg\" alt=\"x\">"}}', p.updated_at
from guide.pages p where p.id = 'e6130000-0000-4000-8000-000000000003';
alter table guide.content_drafts enable trigger content_drafts_before_write;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ declare v text; begin
  v := pg_temp.f613_err($q$select guide.publish_draft('page', 'e6130000-0000-4000-8000-000000000003', false, 'today')$q$);
  if v not like '23514%pages_legal_text_only%' then raise exception 'FAIL admin F6.13: publicar legal con imagen (%)', v; end if;
  if (select body_html_es from guide.pages where id = 'e6130000-0000-4000-8000-000000000003') like '%<img%' then
    raise exception 'FAIL admin F6.13: la imagen llegó a la legal'; end if;
  perform guide.discard_draft('page', 'e6130000-0000-4000-8000-000000000003');
end $$;
reset role;
select set_config('request.jwt.claims', '{}', true);

-- Inmutable también para postgres (sin desactivar el trigger a propósito)
do $$ declare v text; begin
  v := pg_temp.f613_err($q$update guide.page_versions set title = 'x'$q$);
  if v <> '42501 page versions are immutable' then raise exception 'FAIL F6.13: postgres modifica versiones (%)', v; end if;
  v := pg_temp.f613_err($q$delete from guide.page_versions$q$);
  if v <> '42501 page versions are immutable' then raise exception 'FAIL F6.13: postgres borra versiones (%)', v; end if;
  v := pg_temp.f613_err($q$truncate guide.page_versions$q$);
  if v <> '42501 page versions are immutable' then raise exception 'FAIL F6.13: postgres vacía versiones (%)', v; end if;
end $$;

-- Fin F6.13

-- ═════════════ F6.14: suscriptores (sin escritura directa, baja y supresión RGPD por RPC, consent_texts, doble opt-in) ═════════════
-- F6.14 V1: misma guarda que F6.13 (SAVEPOINT exige transacción explícita y el DO, la marca de suite completa).
savepoint f614_guard;
release savepoint f614_guard;
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
end $$;
create or replace function pg_temp.f614_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Fixtures (postgres). Tokens de confirmación conocidos: T1 = 64 × '1' (vigente), T2 = 64 × '2' (caducado).
insert into guide.subscribers (id, email, consent_at, consent_source, consent_version, consent_page, confirm_token_hash, confirm_expires_at)
values
  ('61400000-0000-4000-8000-000000000001', 'rls-f614-s1@chalkguide.test', now() - interval '1 hour', 'footer', 2, '/f614/a',
   sha256(convert_to(repeat('1', 64), 'UTF8')), now() + interval '1 day'),
  ('61400000-0000-4000-8000-000000000002', 'rls-f614-s2@chalkguide.test', now() - interval '3 days', 'home', 2, null,
   sha256(convert_to(repeat('2', 64), 'UTF8')), now() - interval '1 hour');
insert into guide.subscribers (id, email, locale, consent_at, consent_source, consent_version, consent_page, user_id)
values
  ('61400000-0000-4000-8000-000000000003', 'rls-f614-s3@chalkguide.test', 'es', now() - interval '20 days', 'footer', 2, null, null),
  ('61400000-0000-4000-8000-000000000004', 'rls-f614-s4@chalkguide.test', 'en', now() - interval '15 days', 'article_end', 2,
   '/en/blog/secreto-f614', 'a0000000-0000-4000-8000-000000000003'),
  ('61400000-0000-4000-8000-000000000005', 'rls-f614-s5@chalkguide.test', 'es', now() - interval '12 days', 'footer', 2, null, null),
  ('61400000-0000-4000-8000-000000000006', 'rls-f614-s6@chalkguide.test', 'es', now() - interval '10 days', 'footer', 2, null, null),
  ('61400000-0000-4000-8000-000000000007', 'rls-f614-s7@chalkguide.test', 'es', now() - interval '40 days', 'footer', 2, '/f614/b', null),
  ('61400000-0000-4000-8000-000000000008', 'rls-f614-s8@chalkguide.test', 'es', now() - interval '5 years', 'footer', 1, null, null),
  ('61400000-0000-4000-8000-000000000009', 'rls-f614_x%y@chalkguide.test', 'es', now(), 'footer', 2, null, null),
  ('61400000-0000-4000-8000-00000000000a', 'rls-f614axzy@chalkguide.test', 'es', now(), 'footer', 2, null, null);
update guide.subscribers set status = 'active', confirmed_at = consent_at + interval '1 day'
where id in ('61400000-0000-4000-8000-000000000003', '61400000-0000-4000-8000-000000000004',
             '61400000-0000-4000-8000-000000000005', '61400000-0000-4000-8000-000000000008');
update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '2 days', unsubscribe_source = 'link'
where id = '61400000-0000-4000-8000-000000000005';
update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '4 years', unsubscribe_source = 'link'
where id = '61400000-0000-4000-8000-000000000008';
create temp table _f614_tokens on commit drop as
  select id, unsubscribe_token from guide.subscribers where id::text like '61400000-%';
grant select on _f614_tokens to anon, authenticated;

-- Esquema y restricciones (como postgres: el dueño también las respeta)
do $$
declare v text;
begin
  v := pg_temp.f614_err($q$update guide.subscribers set consent_source = 'admin_import' where id = '61400000-0000-4000-8000-000000000003'$q$);
  if v not like '23514 %' then raise exception 'FAIL F6.14: admin_import sigue en consent_source (%)', v; end if;
  v := pg_temp.f614_err($q$insert into guide.subscribers (email, consent_source, consent_version) values (null, 'footer', 2)$q$);
  if v not like '23514 %subscribers_email_null_only_erased%' then raise exception 'FAIL F6.14: email null fuera de erased (%)', v; end if;
  v := pg_temp.f614_err($q$update guide.subscribers set email = 'otro@chalkguide.test' where id = '61400000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 subscriber email is immutable' then raise exception 'FAIL F6.14: email editable (%)', v; end if;
  v := pg_temp.f614_err($q$update guide.subscribers set status = 'erased', email = null where id = '61400000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 erase only through admin_erase_subscriber' then raise exception 'FAIL F6.14: erased sin exención (%)', v; end if;
  -- Baja irreversible: de Baja solo se sale con un alta nueva (pending), nunca a active
  v := pg_temp.f614_err($q$update guide.subscribers set status = 'active' where id = '61400000-0000-4000-8000-000000000005'$q$);
  if v not like '22023 invalid subscriber status transition%' then raise exception 'FAIL F6.14: baja → activo (%)', v; end if;
  -- Exención atada a la fila y solo para `page`
  perform set_config('guide.consent_op', 'erase:61400000-0000-4000-8000-000000000003', true);
  v := pg_temp.f614_err($q$update guide.subscriber_consent_events set page = null where subscriber_id = '61400000-0000-4000-8000-000000000007'$q$);
  if v <> '42501 subscriber_consent_events is append-only' then raise exception 'FAIL F6.14: exención vale para otra fila (%)', v; end if;
  v := pg_temp.f614_err($q$update guide.subscriber_consent_events set source = 'x' where subscriber_id = '61400000-0000-4000-8000-000000000003'$q$);
  if v <> '42501 subscriber_consent_events is append-only' then raise exception 'FAIL F6.14: exención toca algo más que page (%)', v; end if;
  perform set_config('guide.consent_op', '', true);
  -- Catálogo: sin RPC de alta, reactivación ni edición desde el panel
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'guide' and p.proname ~ '^admin_.*subscri'
               and p.proname not in ('admin_list_subscribers', 'admin_subscribers_summary', 'admin_get_subscriber',
                                     'admin_unsubscribe_subscribers', 'admin_erase_subscriber')) then
    raise exception 'FAIL F6.14: hay una RPC de panel de suscriptores no prevista (alta/reactivar/editar)'; end if;
  if exists (select 1 from pg_policies where schemaname = 'guide' and tablename = 'subscribers' and cmd <> 'SELECT') then
    raise exception 'LEAK F6.14: policy de escritura en subscribers'; end if;
  if has_table_privilege('authenticated', 'guide.subscribers', 'INSERT') or has_table_privilege('authenticated', 'guide.subscribers', 'UPDATE')
     or has_table_privilege('authenticated', 'guide.subscribers', 'DELETE')
     or has_column_privilege('authenticated', 'guide.subscribers', 'unsubscribe_token', 'SELECT')
     or has_column_privilege('authenticated', 'guide.subscribers', 'confirm_token_hash', 'SELECT')
     or has_column_privilege('authenticated', 'guide.subscribers', 'user_id', 'SELECT') then
    raise exception 'LEAK F6.14: grants de subscribers'; end if;
  if has_function_privilege('authenticated', 'guide.expire_pending_subscribers()', 'EXECUTE')
     or has_function_privilege('service_role', 'guide.subscriber_anonymize(uuid)', 'EXECUTE') then
    raise exception 'LEAK F6.14: tareas internas ejecutables por clientes'; end if;
  -- consent_texts: v1 no conservado, versión vigente con el texto actual
  if not exists (select 1 from guide.consent_texts where version = 1 and not preserved and text_es is null and valid_to is not null)
     or not exists (select 1 from guide.consent_texts c join guide.site_settings s on s.id = 1
                    where c.purpose = 'newsletter' and c.version = s.consent_version and c.preserved and c.text_es = s.newsletter_consent_text_es and c.valid_to is null) then
    raise exception 'FAIL F6.14: relleno de consent_texts'; end if;
end $$;

-- anon
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v text;
begin
  begin perform 1 from guide.consent_texts; raise exception 'LEAK anon F6.14: lee consent_texts'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_list_subscribers('all'); raise exception 'LEAK anon F6.14: admin_list_subscribers'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_subscribers_summary(); raise exception 'LEAK anon F6.14: admin_subscribers_summary'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_get_subscriber('61400000-0000-4000-8000-000000000003'); raise exception 'LEAK anon F6.14: admin_get_subscriber'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003']::uuid[], 'request');
    raise exception 'LEAK anon F6.14: admin_unsubscribe_subscribers'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000003', 'rls-f614-s3@chalkguide.test', 'request');
    raise exception 'LEAK anon F6.14: admin_erase_subscriber'; exception when insufficient_privilege then null; end;
  begin perform guide.expire_pending_subscribers(); raise exception 'LEAK anon F6.14: expire_pending_subscribers'; exception when insufficient_privilege then null; end;
  begin perform guide.subscriber_anonymize('61400000-0000-4000-8000-000000000003'); raise exception 'LEAK anon F6.14: subscriber_anonymize'; exception when insufficient_privilege then null; end;
  begin update guide.subscriber_consent_events set page = null; raise exception 'LEAK anon F6.14: edita historial'; exception when insufficient_privilege then null; end;

  -- confirm_newsletter: respuesta neutra, sin datos
  if guide.confirm_newsletter(null) <> 'invalid' or guide.confirm_newsletter('hack') <> 'invalid'
     or guide.confirm_newsletter(repeat('f', 64)) <> 'invalid' or guide.confirm_newsletter(upper(repeat('a', 64))) <> 'invalid'
     or guide.confirm_newsletter(repeat('1', 63) || '''') <> 'invalid' then
    raise exception 'FAIL F6.14: confirm_newsletter con token inválido'; end if;
  if guide.confirm_newsletter(repeat('2', 64)) <> 'expired' then raise exception 'FAIL F6.14: token caducado'; end if;
  if guide.confirm_newsletter(repeat('1', 64)) <> 'ok' then raise exception 'FAIL F6.14: confirma con token vigente'; end if;
  if guide.confirm_newsletter(repeat('1', 64)) <> 'ok' then raise exception 'FAIL F6.14: segundo clic'; end if;
end $$;
reset role;

-- authenticated sin rol de admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n bigint;
begin
  if exists (select 1 from guide.consent_texts) then raise exception 'LEAK user F6.14: lee consent_texts'; end if;
  begin perform guide.admin_list_subscribers('all'); raise exception 'LEAK user F6.14: admin_list_subscribers'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_subscribers_summary(); raise exception 'LEAK user F6.14: admin_subscribers_summary'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_get_subscriber('61400000-0000-4000-8000-000000000003'); raise exception 'LEAK user F6.14: admin_get_subscriber'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003']::uuid[], 'request');
    raise exception 'LEAK user F6.14: admin_unsubscribe_subscribers'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000003', 'rls-f614-s3@chalkguide.test', 'request');
    raise exception 'LEAK user F6.14: admin_erase_subscriber'; exception when insufficient_privilege then null; end;
  begin perform guide.expire_pending_subscribers(); raise exception 'LEAK user F6.14: expire_pending_subscribers'; exception when insufficient_privilege then null; end;
  begin update guide.subscribers set status = 'active'; raise exception 'LEAK user F6.14: UPDATE subscribers'; exception when insufficient_privilege then null; end;
  begin delete from guide.subscribers; raise exception 'LEAK user F6.14: DELETE subscribers'; exception when insufficient_privilege then null; end;
  if guide.confirm_newsletter(repeat('2', 64)) <> 'expired' then raise exception 'FAIL user F6.14: confirm_newsletter'; end if;
end $$;
reset role;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v    text;
  j    jsonb;
  r    jsonb;
begin
  -- Sin escritura directa ni lectura de secretos
  begin insert into guide.subscribers (email, consent_source, consent_version) values ('rls-f614-new@chalkguide.test', 'footer', 2);
    raise exception 'LEAK admin F6.14: INSERT directo'; exception when insufficient_privilege then null; end;
  begin update guide.subscribers set status = 'active' where id = '61400000-0000-4000-8000-000000000005';
    raise exception 'LEAK admin F6.14: reactiva una baja en directo'; exception when insufficient_privilege then null; end;
  begin delete from guide.subscribers where id = '61400000-0000-4000-8000-000000000003';
    raise exception 'LEAK admin F6.14: DELETE directo'; exception when insufficient_privilege then null; end;
  begin perform unsubscribe_token from guide.subscribers limit 1;
    raise exception 'LEAK admin F6.14: lee unsubscribe_token'; exception when insufficient_privilege then null; end;
  begin perform confirm_token_hash from guide.subscribers limit 1;
    raise exception 'LEAK admin F6.14: lee confirm_token_hash'; exception when insufficient_privilege then null; end;
  begin insert into guide.consent_texts (version, text_es) values (99, 'x');
    raise exception 'LEAK admin F6.14: escribe consent_texts'; exception when insufficient_privilege then null; end;
  if not exists (select 1 from guide.consent_texts where version = 1 and not preserved) then
    raise exception 'FAIL admin F6.14: no lee consent_texts'; end if;
  if not exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000001' and status = 'active') then
    raise exception 'FAIL F6.14: confirm_newsletter no activó'; end if;

  -- Listado
  j := guide.admin_list_subscribers('all', p_limit => 100);
  if exists (select 1 from jsonb_array_elements(j -> 'rows') x
             where x ?| array['unsubscribe_token', 'confirm_token_hash', 'user_id', 'brevo_contact_id']) then
    raise exception 'LEAK admin F6.14: el listado devuelve secretos'; end if;
  if (j ->> 'total_count')::int <> (j #>> '{tab_counts,all}')::int
     or (j #>> '{tab_counts,all}')::int <> (j #>> '{tab_counts,active}')::int + (j #>> '{tab_counts,pending}')::int
                                           + (j #>> '{tab_counts,unsubscribed}')::int then
    raise exception 'FAIL F6.14: recuentos por pestaña'; end if;
  j := guide.admin_list_subscribers('all', p_query => 'F614_X%');
  if (j ->> 'total_count')::int <> 1 or (j #>> '{rows,0,id}') <> '61400000-0000-4000-8000-000000000009' then
    raise exception 'FAIL F6.14: búsqueda sin escapar comodines (%)', j ->> 'total_count'; end if;
  j := guide.admin_list_subscribers('unsubscribed', p_query => 'rls-f614-s5');
  if (j ->> 'total_count')::int <> 1 then raise exception 'FAIL F6.14: vista Bajas'; end if;
  j := guide.admin_list_subscribers('pending', p_query => 'rls-f614', p_sources => array['home']);
  if (j ->> 'total_count')::int <> 1 or (j #>> '{source_counts,footer}')::int < 1 then
    raise exception 'FAIL F6.14: filtro de origen / facetas (%)', j; end if;
  v := pg_temp.f614_err($q$select guide.admin_list_subscribers('all', p_query => repeat('a', 201))$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: búsqueda de 201 (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_list_subscribers('all', p_sort => 'email; drop table x')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: orden fuera de lista (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_list_subscribers('erased')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: vista erased (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_list_subscribers('all', p_limit => 101)$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: límite 101 (%)', v; end if;

  -- Ficha
  j := guide.admin_get_subscriber('61400000-0000-4000-8000-000000000004');
  if (j -> 'subscriber') ?| array['unsubscribe_token', 'confirm_token_hash', 'user_id', 'brevo_contact_id']
     or not (j #>> '{subscriber,has_account}')::boolean or (j #>> '{subscriber,consent_page}') <> '/en/blog/secreto-f614'
     or jsonb_array_length(j -> 'events') <> 2 or not (j -> 'consent_texts') ? '2' then
    raise exception 'FAIL F6.14: ficha (%)', j; end if;

  -- Baja: motivo obligatorio, solo desde pending/active/bounced, en lote y atómica
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003']::uuid[], null)$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: baja sin motivo (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003']::uuid[], 'erasure')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: motivo fuera de lista (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers('{}'::uuid[], 'request')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: lote vacío (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003',
                                                                             '61400000-0000-4000-8000-000000000005']::uuid[], 'request')$q$);
  if v not like '22023 invalid subscriber state%' then raise exception 'FAIL F6.14: baja de una baja (%)', v; end if;
  if not exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000003' and status = 'active') then
    raise exception 'FAIL F6.14: el lote rechazado dio de baja a alguien'; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-0000000000ff']::uuid[], 'request')$q$);
  if v not like 'P0002 %' then raise exception 'FAIL F6.14: baja de inexistente (%)', v; end if;
  j := guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003', '61400000-0000-4000-8000-000000000003',
                                                 '61400000-0000-4000-8000-000000000002']::uuid[], 'wrong');
  if (j ->> 'unsubscribed')::int <> 2 then raise exception 'FAIL F6.14: baja en lote (%)', j; end if;
  if (select count(*) from guide.subscribers where id in ('61400000-0000-4000-8000-000000000003', '61400000-0000-4000-8000-000000000002')
        and status = 'unsubscribed' and unsubscribe_source = 'admin' and unsubscribed_at is not null) <> 2
     or (select count(*) from guide.subscriber_consent_events
         where subscriber_id in ('61400000-0000-4000-8000-000000000003', '61400000-0000-4000-8000-000000000002')
           and event = 'unsubscribe' and reason = 'wrong' and actor = 'admin') <> 2 then
    raise exception 'FAIL F6.14: baja sin vía/motivo en fila o historial'; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000003']::uuid[], 'request')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: segunda baja (%)', v; end if;
  if (guide.admin_list_subscribers('unsubscribed', p_query => 'rls-f614-s3') #>> '{rows,0,unsubscribe_reason}') <> 'wrong' then
    raise exception 'FAIL F6.14: motivo en el listado'; end if;

  -- Supresión RGPD: una fila, email exacto, motivo
  v := pg_temp.f614_err($q$select guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000004', 'rls-f614-s3@chalkguide.test', 'request')$q$);
  if v <> '22023 email confirmation mismatch' then raise exception 'FAIL F6.14: supresión con otro email (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000004', null, 'request')$q$);
  if v <> '22023 email confirmation mismatch' then raise exception 'FAIL F6.14: supresión sin email (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000004', 'rls-f614-s4@chalkguide.test', 'abuse')$q$);
  if v not like '22023 %' then raise exception 'FAIL F6.14: supresión con motivo fuera de lista (%)', v; end if;
  j := guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000004', '  RLS-F614-S4@chalkguide.test ', 'request');
  if not (j ->> 'erased')::boolean then raise exception 'FAIL F6.14: supresión'; end if;
  v := pg_temp.f614_err($q$select guide.admin_erase_subscriber('61400000-0000-4000-8000-000000000004', 'rls-f614-s4@chalkguide.test', 'request')$q$);
  if v not like 'P0002 %' then raise exception 'FAIL F6.14: segunda supresión (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_get_subscriber('61400000-0000-4000-8000-000000000004')$q$);
  if v not like 'P0002 %' then raise exception 'FAIL F6.14: ficha de un suprimido (%)', v; end if;
  v := pg_temp.f614_err($q$select guide.admin_unsubscribe_subscribers(array['61400000-0000-4000-8000-000000000004']::uuid[], 'request')$q$);
  if v not like 'P0002 %' then raise exception 'FAIL F6.14: baja de un suprimido (%)', v; end if;
  if exists (select 1 from jsonb_array_elements(guide.admin_list_subscribers('all', p_limit => 100) -> 'rows') x
             where x ->> 'id' = '61400000-0000-4000-8000-000000000004')
     or exists (select 1 from jsonb_array_elements(guide.admin_export('subscribers', 'json',
                  '{"purpose":"audit","columns":"proof","statuses":["pending","active","unsubscribed","bounced","expired"]}') -> 'rows') y
                where y ->> 'status' = 'erased' or y ->> 'email' is null) then
    raise exception 'LEAK F6.14: el suprimido sale en listado o exportación'; end if;
  if (guide.admin_subscribers_summary() ->> 'erased')::int < 1 then raise exception 'FAIL F6.14: resumen sin suprimidos'; end if;
  if (guide.admin_dashboard_stats() ->> 'subscribers_total')::int
     <> (guide.admin_export_count('subscribers', '{"statuses":["pending","active","unsubscribed","bounced","expired"]}') ->> 'total')::int then
    raise exception 'FAIL F6.14: subscribers_total cuenta suprimidos'; end if;
  perform * from guide.admin_timeseries('subscribers_total', current_date - 60, current_date, 'week');
  perform * from guide.admin_timeseries('subscribers_new', current_date - 60, current_date, 'week');
  if not exists (select 1 from guide.activity_log where entity_table = 'subscribers' and entity_id = '61400000-0000-4000-8000-000000000004'
                 and details ->> 'to' = 'erased' and details ->> 'reason' = 'request' and entity_label is null and actor_id is not null) then
    raise exception 'FAIL F6.14: supresión sin línea en Actividad'; end if;
end $$;
reset role;

-- Como postgres: lo que queda tras la supresión y la baja, caducidad y versionado del texto
do $$
declare
  v   text;
  j   jsonb;
  tok uuid;
begin
  -- La fila suprimida queda anónima y su historial se conserva sin page ni email
  if exists (select 1 from guide.subscribers s where s.id = '61400000-0000-4000-8000-000000000004'
             and (s.status <> 'erased' or s.email is not null or s.user_id is not null or s.consent_page is not null
                  or s.confirm_token_hash is not null or s.brevo_contact_id is not null)) then
    raise exception 'LEAK F6.14: la supresión dejó datos identificativos'; end if;
  if (select array_agg(event order by id) from guide.subscriber_consent_events
      where subscriber_id = '61400000-0000-4000-8000-000000000004') <> array['subscribe', 'confirm', 'erase']
     or exists (select 1 from guide.subscriber_consent_events where subscriber_id = '61400000-0000-4000-8000-000000000004' and page is not null) then
    raise exception 'FAIL F6.14: historial tras la supresión'; end if;
  if exists (select 1 from guide.subscribers s where (to_jsonb(s))::text like '%rls-f614-s4%' or (to_jsonb(s))::text like '%secreto-f614%')
     or exists (select 1 from guide.subscriber_consent_events e where (to_jsonb(e))::text like '%secreto-f614%')
     or exists (select 1 from guide.activity_log l where (to_jsonb(l))::text like '%rls-f614-s4%' or (to_jsonb(l))::text like '%secreto-f614%')
     or exists (select 1 from guide.activity_log l where l.entity_table = 'subscribers' and l.entity_label is not null) then
    raise exception 'LEAK F6.14: queda el email o la página del suprimido'; end if;
  if exists (select 1 from guide.subscribers s join _f614_tokens t on t.id = s.id
             where s.id in ('61400000-0000-4000-8000-000000000004', '61400000-0000-4000-8000-000000000003')
               and s.unsubscribe_token = t.unsubscribe_token) then
    raise exception 'FAIL F6.14: no se rotó el token de baja'; end if;
  if exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000002' and confirm_token_hash is not null) then
    raise exception 'FAIL F6.14: la baja no borró el token de confirmación'; end if;
  v := pg_temp.f614_err($q$update guide.subscribers set locale = 'es' where id = '61400000-0000-4000-8000-000000000004'$q$);
  if v <> '42501 erased subscriber is frozen' then raise exception 'FAIL F6.14: fila suprimida editable (%)', v; end if;
  v := pg_temp.f614_err($q$update guide.subscriber_consent_events set reason = null where subscriber_id = '61400000-0000-4000-8000-000000000004'$q$);
  if v <> '42501 subscriber_consent_events is append-only' then raise exception 'FAIL F6.14: historial editable tras suprimir (%)', v; end if;
end $$;

-- El token de baja antiguo no reabre nada; la persona sí puede volver con un alta nueva
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  perform guide.unsubscribe_newsletter((select unsubscribe_token from _f614_tokens where id = '61400000-0000-4000-8000-000000000004'));
  perform guide.subscribe_newsletter('rls-f614-s4@chalkguide.test', 'es', 'footer', true);
  perform guide.subscribe_newsletter('rls-f614-s3@chalkguide.test', 'es', 'home', true);
  -- O4: la página se guarda sin query string ni fragmento (pueden llevar utm_*, emails o tokens)
  perform guide.subscribe_newsletter('rls-f614-o4@chalkguide.test', 'es', 'article', true, '/blog/x?utm_source=a&email=b@c.de#frag');
  perform guide.subscribe_newsletter('rls-f614-o4b@chalkguide.test', 'es', 'article', true, '/blog/y#t?z=1');
end $$;
reset role;

do $$
declare j jsonb;
begin
  -- F6.14 V1: expire_pending_subscribers() anonimiza filas reales; solo dentro de la suite completa.
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if (select count(*) from guide.subscribers where email = 'rls-f614-s4@chalkguide.test' and status = 'pending'
        and id <> '61400000-0000-4000-8000-000000000004' and user_id is null) <> 1 then
    raise exception 'FAIL F6.14: alta nueva tras la supresión'; end if;
  if not exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000003' and status = 'pending'
                 and confirmed_at is null and unsubscribed_at is null and unsubscribe_source is null
                 and confirm_token_hash is not null and confirm_expires_at between now() + interval '47 hours' and now() + interval '49 hours') then
    raise exception 'FAIL F6.14: la re-suscripción no limpia la fila ni emite token de 48 h'; end if;
  if (select consent_page from guide.subscribers where email = 'rls-f614-o4@chalkguide.test') is distinct from '/blog/x'
     or (select consent_page from guide.subscribers where email = 'rls-f614-o4b@chalkguide.test') is distinct from '/blog/y'
     or exists (select 1 from guide.subscriber_consent_events e join guide.subscribers s on s.id = e.subscriber_id
                where s.email like 'rls-f614-o4%' and (e.page like '%?%' or e.page like '%#%')) then
    raise exception 'LEAK F6.14 O4: consent_page guarda query string o fragmento'; end if;

  -- Caducidad y retención (la función existe; el job de pg_cron no, hasta F4.6)
  if exists (select 1 from cron.job where command ilike '%expire_pending_subscribers%') then
    raise exception 'FAIL F6.14: expire_pending_subscribers programado antes de F4.6'; end if;
  j := guide.expire_pending_subscribers();
  if (j ->> 'expired')::int < 1 or (j ->> 'anonymized_unconfirmed')::int < 1 or (j ->> 'anonymized_unsubscribed')::int < 1 then
    raise exception 'FAIL F6.14: expire_pending_subscribers (%)', j; end if;
  if not exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000006' and status = 'expired')
     or not exists (select 1 from guide.subscriber_consent_events where subscriber_id = '61400000-0000-4000-8000-000000000006'
                    and event = 'expire' and actor = 'service')
     or exists (select 1 from guide.subscribers where id in ('61400000-0000-4000-8000-000000000007', '61400000-0000-4000-8000-000000000008')
                and (status <> 'erased' or email is not null))
     or not exists (select 1 from guide.subscriber_consent_events where subscriber_id = '61400000-0000-4000-8000-000000000007'
                    and event = 'erase' and actor = 'service' and source = 'retention' and reason is null)
     or exists (select 1 from guide.subscriber_consent_events where subscriber_id = '61400000-0000-4000-8000-000000000007' and page is not null)
     or exists (select 1 from guide.subscribers where id = '61400000-0000-4000-8000-000000000001' and status = 'expired') then
    raise exception 'FAIL F6.14: caducidad/anonimización'; end if;
  if exists (select 1 from guide.activity_log where entity_table = 'subscribers'
             and entity_id = '61400000-0000-4000-8000-000000000007' and actor_id is not null) then
    raise exception 'LEAK F6.14: actor_id en una línea del sistema'; end if;

  -- consent_texts: append-only y versionado desde Ajustes
  begin update guide.consent_texts set text_es = 'x' where version = 2;
    raise exception 'FAIL F6.14: consent_texts editable'; exception when insufficient_privilege then null; end;
  begin delete from guide.consent_texts where version = 1;
    raise exception 'FAIL F6.14: consent_texts borrable'; exception when insufficient_privilege then null; end;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v_ver integer := (select consent_version from guide.site_settings where id = 1);
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  begin update guide.site_settings set newsletter_consent_text_es = 'Texto F6.14 sin versión' where id = 1;
    raise exception 'FAIL F6.14: cambia el texto sin subir la versión'; exception when invalid_parameter_value then null; end;
  begin update guide.site_settings set consent_version = v_ver - 1 where id = 1;
    raise exception 'FAIL F6.14: baja la versión'; exception when invalid_parameter_value or check_violation then null; end;
  update guide.site_settings set newsletter_consent_text_es = 'Texto F6.14 nuevo', consent_version = v_ver + 1 where id = 1;
  if not exists (select 1 from guide.consent_texts where version = v_ver + 1 and text_es = 'Texto F6.14 nuevo' and valid_to is null
                 and created_by = 'a0000000-0000-4000-8000-000000000001')
     or not exists (select 1 from guide.consent_texts where version = v_ver and valid_to is not null) then
    raise exception 'FAIL F6.14: subir consent_version no versiona el texto'; end if;
  update guide.site_settings set site_name = site_name || '' where id = 1;   -- otros ajustes siguen editables
end $$;
reset role;

-- Fin F6.14

-- ═════════════ F6.15: exportar (D36: admin_export exporta y registra en una llamada; vistas al día) ═════════════
-- Misma guarda que F6.13/F6.14 (SAVEPOINT exige transacción explícita y el DO, la marca de suite completa).
savepoint f615_guard;
release savepoint f615_guard;
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
end $$;
create or replace function pg_temp.f615_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Fixtures (postgres): un activo y una baja propios de F6.15 (los de F6.14 pueden haber cambiado de estado).
-- O3: dentro del DO con la guarda, para que no se escriban nunca fuera de la suite completa.
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  insert into guide.subscribers (id, email, locale, consent_at, consent_source, consent_version)
  values ('61500000-0000-4000-8000-000000000001', 'rls-f615-a@chalkguide.test', 'es', now() - interval '3 days', 'footer', 2),
         ('61500000-0000-4000-8000-000000000002', 'rls-f615-b@chalkguide.test', 'en', now() - interval '9 days', 'home', 2);
  update guide.subscribers set status = 'active', confirmed_at = consent_at + interval '1 hour'
  where id in ('61500000-0000-4000-8000-000000000001', '61500000-0000-4000-8000-000000000002');
  update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '1 day', unsubscribe_source = 'link'
  where id = '61500000-0000-4000-8000-000000000002';
end $$;

-- Catálogo y grants (postgres)
do $$
declare v_fn regprocedure; v_role text;
begin
  foreach v_fn in array array['guide.export_build(text, text, jsonb, boolean)'::regprocedure,
                              'guide.export_f_text_array(text, jsonb, integer, text)'::regprocedure,
                              'guide.export_f_text(text, jsonb, text)'::regprocedure,
                              'guide.export_f_bool(text, jsonb)'::regprocedure,
                              'guide.export_f_ts(text, jsonb, boolean)'::regprocedure] loop
    foreach v_role in array array['anon', 'authenticated', 'service_role'] loop
      if has_function_privilege(v_role, v_fn, 'execute') then
        raise exception 'LEAK F6.15: % ejecuta el helper interno %', v_role, v_fn; end if;
    end loop;
  end loop;
  foreach v_fn in array array['guide.admin_export(text, text, jsonb)'::regprocedure,
                              'guide.admin_export_count(text, jsonb)'::regprocedure,
                              'guide.admin_recent_exports(integer, text)'::regprocedure] loop
    if has_function_privilege('anon', v_fn, 'execute') or has_function_privilege('service_role', v_fn, 'execute') then
      raise exception 'LEAK F6.15: anon/service_role ejecuta %', v_fn; end if;
    if not has_function_privilege('authenticated', v_fn, 'execute') then
      raise exception 'FAIL F6.15: authenticated no ejecuta %', v_fn; end if;
    if not exists (select 1 from pg_proc where oid = v_fn and prosecdef and proconfig @> array['search_path=""']) then
      raise exception 'FAIL F6.15: % sin DEFINER o sin search_path vacío', v_fn; end if;
  end loop;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'guide' and c.relname like 'export\_%' and c.relkind = 'v'
               and not coalesce(c.reloptions @> array['security_invoker=true'], false)) then
    raise exception 'LEAK F6.15: vista export_* sin security_invoker'; end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'guide' and c.relname like 'export\_%' and c.relkind = 'v') <> 6 then
    raise exception 'FAIL F6.15: no son 6 vistas export_* (F8 añade export_news)'; end if;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'guide' and c.relname like 'export\_%' and c.relkind = 'v'
               and (has_table_privilege('anon', c.oid, 'select')
                    or has_table_privilege('authenticated', c.oid, 'insert')
                    or has_table_privilege('authenticated', c.oid, 'update')
                    or has_table_privilege('authenticated', c.oid, 'delete'))) then
    raise exception 'LEAK F6.15: grants de las vistas export_*'; end if;
  -- Columnas que nunca salen
  if exists (select 1 from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'guide' and c.relname like 'export\_%' and a.attnum > 0 and not a.attisdropped
               and (a.attname in ('user_id', 'unsubscribe_token', 'confirm_token_hash', 'confirm_expires_at', 'brevo_contact_id',
                                  'brevo_sync_status', 'brevo_sync_error', 'synced_at', 'agent_meta', 'dedupe_key',
                                  'storage_path', 'public_path', 'rights_version')
                    or (a.attname = 'email' and c.relname <> 'export_subscribers'))) then
    raise exception 'LEAK F6.15: columna prohibida en una vista export_*'; end if;
  -- La vista de suscriptores empieza por el mínimo (§12.3) y no tiene suprimidos
  if (select array_agg(attname::text order by attnum) from pg_attribute
      where attrelid = 'guide.export_subscribers'::regclass and attnum between 1 and 5)
     <> array['email', 'locale', 'status', 'consent_at', 'confirmed_at'] then
    raise exception 'FAIL F6.15: export_subscribers no empieza por las 5 mínimas'; end if;
  -- Parte 3 (O1/O2): log_export retirado; vistas export_* y export_events_rows sin acceso de clientes
  foreach v_role in array array['anon', 'authenticated'] loop
    if has_function_privilege(v_role, 'guide.log_export(text, text, jsonb, integer)', 'execute')
       or has_function_privilege(v_role, 'guide.export_events_rows()', 'execute') then
      raise exception 'LEAK F6.15: % ejecuta log_export o export_events_rows', v_role; end if;
    if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'guide' and c.relname like 'export\_%' and c.relkind = 'v'
                 and has_table_privilege(v_role, c.oid, 'select')) then
      raise exception 'LEAK F6.15: % lee una vista export_*', v_role; end if;
  end loop;
end $$;

-- anon: nada
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.admin_export('subscribers', 'csv', '{"purpose":"backup"}');
    raise exception 'LEAK anon F6.15: admin_export'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_export_count('subscribers', '{}');
    raise exception 'LEAK anon F6.15: admin_export_count'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_recent_exports();
    raise exception 'LEAK anon F6.15: admin_recent_exports'; exception when insufficient_privilege then null; end;
  begin perform guide.export_build('subscribers', 'json', '{}', false);
    raise exception 'LEAK anon F6.15: export_build'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_articles; raise exception 'LEAK anon F6.15: export_articles'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_items; raise exception 'LEAK anon F6.15: export_items'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_user_reviews; raise exception 'LEAK anon F6.15: export_user_reviews'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_events; raise exception 'LEAK anon F6.15: export_events'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_subscribers; raise exception 'LEAK anon F6.15: export_subscribers'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- authenticated no admin: 42501 en las RPC y 0 filas en las vistas
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n bigint := (select count(*) from guide.activity_log where action = 'export');
begin
  begin perform guide.admin_export('articles', 'json', '{}');
    raise exception 'LEAK u1 F6.15: admin_export'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_export('subscribers', 'csv', '{"purpose":"backup"}');
    raise exception 'LEAK u1 F6.15: admin_export suscriptores'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_export_count('items', '{}');
    raise exception 'LEAK u1 F6.15: admin_export_count'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_recent_exports(5);
    raise exception 'LEAK u1 F6.15: admin_recent_exports'; exception when insufficient_privilege then null; end;
  begin perform guide.export_build('items', 'json', '{}', false);
    raise exception 'LEAK u1 F6.15: export_build'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_articles; raise exception 'LEAK u1 F6.15: export_articles'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_items; raise exception 'LEAK u1 F6.15: export_items'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_user_reviews; raise exception 'LEAK u1 F6.15: export_user_reviews'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_events; raise exception 'LEAK u1 F6.15: export_events'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.export_subscribers; raise exception 'LEAK u1 F6.15: export_subscribers'; exception when insufficient_privilege then null; end;
  if (select count(*) from guide.activity_log where action = 'export') <> 0 then
    raise exception 'LEAK u1 F6.15: lee el registro de exportaciones'; end if;
end $$;
reset role;

-- admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v       jsonb;
  v_log   guide.activity_log;
  v_n0    bigint;
  v_err   text;
  v_exp   bigint;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;

  -- Suscriptores: por defecto solo activos (D-C) y las 5 columnas mínimas; registro con las filas reales
  v_exp := (select count(*) from guide.subscribers where status = 'active');
  if v_exp < 1 then raise exception 'FAIL F6.15: fixture sin activos'; end if;
  v := guide.admin_export('subscribers', 'csv', '{"purpose":"backup"}');
  if (v -> 'export' ->> 'row_count')::bigint <> v_exp or jsonb_array_length(v -> 'rows') <> v_exp
     or v -> 'export' -> 'columns' <> '["email","locale","status","consent_at","confirmed_at"]'::jsonb
     or exists (select 1 from jsonb_array_elements(v -> 'rows') r
                where r ->> 'status' <> 'active' or (select count(*) from jsonb_object_keys(r)) <> 5)
     or (v -> 'export' ->> 'personal_data')::boolean is not true then
    raise exception 'FAIL F6.15: export de suscriptores por defecto: %', v -> 'export'; end if;
  select * into v_log from guide.activity_log where action = 'export' order by id desc limit 1;
  if v_log.entity_table <> 'export_subscribers' or v_log.actor_id <> 'a0000000-0000-4000-8000-000000000001'
     or (v_log.details ->> 'row_count')::bigint <> v_exp or v_log.details ->> 'purpose' <> 'backup'
     or (v_log.details ->> 'personal_data')::boolean is not true or v_log.details ->> 'format' <> 'csv'
     or v_log.details -> 'columns' <> v -> 'export' -> 'columns'
     or v_log.details::text like '%@%' or v_log.old_row is not null or v_log.entity_label is not null then
    raise exception 'FAIL F6.15: registro del export de suscriptores: %', v_log.details; end if;

  -- Preajuste con prueba de consentimiento; nunca suprimidos ni tokens
  v := guide.admin_export('subscribers', 'json',
         '{"purpose":"audit","columns":"proof","statuses":["active","unsubscribed","pending","expired","bounced"]}');
  -- 19 = 12 de F6.15 + 7 de consentimiento afín (D66: related_status … related_withdraw_source).
  if jsonb_array_length(v -> 'export' -> 'columns') <> 19
     or exists (select 1 from jsonb_array_elements(v -> 'rows') r
                where r ->> 'status' = 'erased' or r ->> 'email' is null or r ? 'unsubscribe_token' or r ? 'user_id')
     or not exists (select 1 from jsonb_array_elements(v -> 'rows') r where r ->> 'id' = '61500000-0000-4000-8000-000000000002') then
    raise exception 'FAIL F6.15: preajuste proof'; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'csv', '{}')$q$);
  if v_err <> '22023 purpose required' then raise exception 'FAIL F6.15: sin finalidad (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'csv', '{"purpose":"spam"}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: finalidad fuera de lista (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'csv', '{"purpose":"backup","statuses":["erased"]}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: pide suprimidos (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'csv', '{"purpose":"backup","columns":["email","unsubscribe_token"]}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: pide tokens (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'csv', '{"purpose":"backup","q":"pepe@x.test"}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: clave fuera de lista (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('subscribers', 'xml', '{"purpose":"backup"}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: formato (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('profiles', 'json', '{}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: módulo fuera de lista (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('events', 'json', '{"from":"ayer"}')$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: fecha inválida (%)', v_err; end if;

  -- Selección: los ids solo como número en el registro
  v := guide.admin_export('subscribers', 'json',
         '{"purpose":"data_request","statuses":["active","unsubscribed"],"ids":["61500000-0000-4000-8000-000000000001","61500000-0000-4000-8000-000000000002"]}');
  select * into v_log from guide.activity_log where action = 'export' order by id desc limit 1;
  if (v -> 'export' ->> 'row_count')::int <> 2 or (v_log.details -> 'filters' ->> 'ids_count')::int <> 2
     or v_log.details::text like '%61500000-%' then
    raise exception 'FAIL F6.15: selección por ids: %', v_log.details; end if;

  -- Opiniones: nombre público, sin user_id ni email; número de fotos
  v := guide.admin_export('user_reviews', 'csv', '{"statuses":["pending","visible","hidden"]}');
  if not (v -> 'export' -> 'columns') ? 'photos_approved' or (v -> 'export' -> 'columns') ? 'user_id'
     or exists (select 1 from jsonb_array_elements(v -> 'rows') r where r ? 'user_id' or r ? 'email')
     or (v -> 'export' ->> 'row_count')::bigint <> (select count(*) from guide.user_reviews) then
    raise exception 'FAIL F6.15: export de opiniones'; end if;

  -- Fichas: CSV solo por categoría (D-B); cuerpo solo en JSON (D-A); reseña de autor con visit_type
  v_err := pg_temp.f615_err($q$select guide.admin_export('items', 'csv', '{}')$q$);
  if v_err <> '22023 csv needs category' then raise exception 'FAIL F6.15: CSV de fichas sin categoría (%)', v_err; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_export('items', 'csv', '{"category":"gym","with_body":true}')$q$);
  if v_err <> '22023 with_body only in json' then raise exception 'FAIL F6.15: cuerpo en CSV (%)', v_err; end if;
  v := guide.admin_export('items', 'csv', '{"category":"gym"}');
  if not (v -> 'export' -> 'columns') ? 'visit_type' or not (v -> 'export' -> 'columns') ? 'author_scores'
     or (v -> 'export' -> 'columns') ? 'author_body_html_es'
     or exists (select 1 from jsonb_array_elements(v -> 'rows') r where r ->> 'category' <> 'gym') then
    raise exception 'FAIL F6.15: CSV de rocódromos'; end if;
  v := guide.admin_export('items', 'json', '{"with_body":true}');
  if not (v -> 'export' -> 'columns') ? 'author_body_html_es' then raise exception 'FAIL F6.15: JSON de fichas sin cuerpo'; end if;
  v := guide.admin_export('articles', 'json', '{}');
  if (v -> 'export' -> 'columns') ? 'body_html_es' or not (v -> 'export' -> 'columns') ? 'has_pending_draft' then
    raise exception 'FAIL F6.15: artículos por defecto'; end if;
  v := guide.admin_export('articles', 'json', '{"with_body":true}');
  if not (v -> 'export' -> 'columns') ? 'body_html_es' then raise exception 'FAIL F6.15: artículos con cuerpo'; end if;

  -- 0 filas: no se registra nada
  v_n0 := (select count(*) from guide.activity_log where action = 'export');
  v := guide.admin_export('events', 'json', '{"from":"2099-01-01"}');
  if (v -> 'export' ->> 'row_count')::int <> 0 or (select count(*) from guide.activity_log where action = 'export') <> v_n0 then
    raise exception 'FAIL F6.15: export vacío registrado'; end if;

  -- El recuento no registra
  v := guide.admin_export_count('subscribers', '{}');
  if (v ->> 'total')::bigint <> (select count(*) from guide.subscribers where status = 'active')
     or (select count(*) from guide.activity_log where action = 'export') <> v_n0 then
    raise exception 'FAIL F6.15: admin_export_count'; end if;

  -- Tope y truncated (la sesión baja el tope a 2; nunca lo sube)
  perform set_config('guide.export_cap', '2', true);
  v := guide.admin_export('items', 'json', '{}');
  select * into v_log from guide.activity_log where action = 'export' order by id desc limit 1;
  if (v -> 'export' ->> 'row_count')::int <> 2 or jsonb_array_length(v -> 'rows') <> 2
     or (v -> 'export' ->> 'truncated')::boolean is not true or (v -> 'export' ->> 'total')::int <= 2
     or (v_log.details ->> 'row_count')::int <> 2 or (v_log.details ->> 'truncated')::boolean is not true then
    raise exception 'FAIL F6.15: tope/truncated: %', v -> 'export'; end if;
  if ((guide.admin_export_count('items', '{}')) ->> 'truncated')::boolean is not true then
    raise exception 'FAIL F6.15: recuento sin truncated'; end if;
  perform set_config('guide.export_cap', '9999999', true);
  v := guide.admin_export('items', 'json', '{}');
  if (v -> 'export' ->> 'truncated')::boolean then raise exception 'FAIL F6.15: el tope inválido no se ignora'; end if;
  perform set_config('guide.export_cap', '', true);

  -- Últimas exportaciones: las más recientes primero y sin datos personales
  v := guide.admin_recent_exports(3);
  if jsonb_array_length(v) <> 3 or v -> 0 ->> 'module' <> 'items' or v::text like '%@%' then
    raise exception 'FAIL F6.15: admin_recent_exports: %', v; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_recent_exports(500)$q$);
  if v_err not like '22023 %' then raise exception 'FAIL F6.15: límite de recientes (%)', v_err; end if;
  -- D37: la última exportación de un módulo (modal de cada módulo)
  v := guide.admin_recent_exports(1, 'subscribers');
  if jsonb_array_length(v) <> 1 or v -> 0 ->> 'module' <> 'subscribers' or v -> 0 ->> 'purpose' <> 'data_request'
     or v::text like '%@%' then
    raise exception 'FAIL F6.15 (D37): última exportación de suscriptores: %', v; end if;
  if exists (select 1 from jsonb_array_elements(guide.admin_recent_exports(50, 'items')) x where x ->> 'module' <> 'items') then
    raise exception 'FAIL F6.15 (D37): el filtro por módulo deja pasar otros'; end if;
  v_err := pg_temp.f615_err($q$select guide.admin_recent_exports(1, 'profiles')$q$);
  if v_err <> '22023 invalid module' then raise exception 'FAIL F6.15 (D37): módulo desconocido (%)', v_err; end if;

  -- El admin tampoco escribe el registro a mano
  begin insert into guide.activity_log (action, entity_table, entity_id) values ('export', 'export_items', '*');
    raise exception 'LEAK admin F6.15: inserta en activity_log'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Fin F6.15

-- ═════════════ D41: fotos del hero (site_settings.hero_photo_1/2_media_id, FK on delete set null) ═════════════
-- Medios b41…: 01 y 02 con los dos alts (uno por ranura); 03 sin alt_en; 04 con los dos y sin usar (testigo oculto, y
-- luego la misma foto en ambas ranuras). La migración deja fotos de ejemplo en las ranuras: se vacían antes de contar.
select set_config('guide.draft_op', '', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b4100000-0000-4000-8000-0000000000%s/1-d41.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','02','03','04']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es, alt_en)
select format('b4100000-0000-4000-8000-0000000000%s', n)::uuid, format('b4100000-0000-4000-8000-0000000000%s/1-d41.jpg', n),
       'd41.jpg', 'image/jpeg', 1, 10, 10, 'Imagen ' || n, case when n <> '03' then 'Image ' || n end
from unnest(array['01','02','03','04']) n;
update guide.site_settings set hero_photo_1_media_id = null, hero_photo_2_media_id = null where id = 1;

-- Como admin cambia la ranura; como anon comprueba el total respecto a la base y qué medios b41… ve. Vuelve a postgres.
create or replace function pg_temp.d41_slot_anon_sees(p_col text, p_media uuid, p_extra integer, p_visible uuid, p_tag text)
returns void
language plpgsql
as $$
declare v_n bigint;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
  execute format('update guide.site_settings set %I = %L where id = 1', p_col, p_media);
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL % : el admin actualiza % filas', p_tag, v_n; end if;

  set local role anon;
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  select count(*) into v_n from guide.media;
  if v_n <> current_setting('guide.d41_anon_base')::bigint + p_extra then
    raise exception 'LEAK % : anon ve % medios (base %, esperados % más)', p_tag, v_n, current_setting('guide.d41_anon_base'), p_extra; end if;
  if exists (select 1 from guide.media where id::text like 'b4100000-%' and id is distinct from p_visible) then
    raise exception 'LEAK % : anon ve otro medio no público', p_tag; end if;
  if p_visible is not null and not exists (select 1 from guide.media where id = p_visible) then
    raise exception 'FAIL % : anon no ve la foto de la ranura', p_tag; end if;
  reset role;
end;
$$;

-- a. Anon: 42501 en cada ranura; fija la base de medios visibles con las ranuras vacías
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin update guide.site_settings set hero_photo_1_media_id = 'b4100000-0000-4000-8000-000000000001' where id = 1;
    raise exception 'LEAK anon D41: escribe la ranura 1'; exception when insufficient_privilege then null; end;
  begin update guide.site_settings set hero_photo_2_media_id = 'b4100000-0000-4000-8000-000000000001' where id = 1;
    raise exception 'LEAK anon D41: escribe la ranura 2'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.media where id::text like 'b4100000-%') then
    raise exception 'LEAK anon D41: ve medios sin usar'; end if;
  perform set_config('guide.d41_anon_base', (select count(*) from guide.media)::text, true);
end $$;
reset role;

-- b. No admin: 0 filas en cada ranura
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  update guide.site_settings set hero_photo_1_media_id = 'b4100000-0000-4000-8000-000000000001' where id = 1;
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D41: escribe la ranura 1'; end if;
  update guide.site_settings set hero_photo_2_media_id = 'b4100000-0000-4000-8000-000000000001' where id = 1;
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D41: escribe la ranura 2'; end if;
  if exists (select 1 from guide.site_settings where id = 1 and (hero_photo_1_media_id is not null or hero_photo_2_media_id is not null)) then
    raise exception 'LEAK user D41: las ranuras cambian'; end if;
end $$;
reset role;

-- c. Admin: foto sin alt_en → PT422 en cada ranura, y la ranura sigue vacía
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_col text;
  v_j   jsonb;
begin
  foreach v_col in array array['hero_photo_1_media_id', 'hero_photo_2_media_id'] loop
    begin
      execute format('update guide.site_settings set %I = %L where id = 1', v_col, 'b4100000-0000-4000-8000-000000000003');
      raise exception 'FAIL D41 c: % acepta una foto sin alt_en', v_col;
    exception when sqlstate 'PT422' then
      get stacked diagnostics v_j = pg_exception_detail;
      if v_j ->> 'entity' <> 'site_settings' or (v_j ->> 'setting_id')::smallint <> 1
         or v_j -> 'missing' <> '[{"lang":"en","media_id":"b4100000-0000-4000-8000-000000000003"}]'::jsonb then
        raise exception 'FAIL D41 c: details de % (%)', v_col, v_j; end if;
    end;
  end loop;
  if exists (select 1 from guide.site_settings where id = 1 and (hero_photo_1_media_id is not null or hero_photo_2_media_id is not null)) then
    raise exception 'FAIL D41 c: la ranura no sigue vacía'; end if;
end $$;
reset role;

-- d. Un medio no público en una ranura suma exactamente 1 fila para anon (el testigo 04 sigue oculto) y deja de verse al vaciarla
select pg_temp.d41_slot_anon_sees('hero_photo_1_media_id', 'b4100000-0000-4000-8000-000000000001', 1, 'b4100000-0000-4000-8000-000000000001', 'D41 d ranura 1');
select pg_temp.d41_slot_anon_sees('hero_photo_1_media_id', null, 0, null, 'D41 d ranura 1 vaciada');
select pg_temp.d41_slot_anon_sees('hero_photo_2_media_id', 'b4100000-0000-4000-8000-000000000002', 1, 'b4100000-0000-4000-8000-000000000002', 'D41 d ranura 2');
select pg_temp.d41_slot_anon_sees('hero_photo_2_media_id', null, 0, null, 'D41 d ranura 2 vaciada');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_m   uuid;
  v_ver integer;
  v_col text;
  v_j   jsonb;
  v_n   integer;
  v_1   uuid;
  v_2   uuid;
begin
  update guide.site_settings set hero_photo_1_media_id = 'b4100000-0000-4000-8000-000000000001',
                                 hero_photo_2_media_id = 'b4100000-0000-4000-8000-000000000002' where id = 1;

  foreach v_m in array array['b4100000-0000-4000-8000-000000000001', 'b4100000-0000-4000-8000-000000000002']::uuid[] loop
    -- e. Medio en uso: role hero en media_usages y 23503 en delete_media
    if not exists (select 1 from guide.media_usages(v_m) u where u.role = 'hero' and u.owner_table = 'site_settings') then
      raise exception 'FAIL D41 e: media_usages no da role hero para %', v_m; end if;
    select m.version into v_ver from guide.media m where m.id = v_m;
    begin
      perform guide.delete_media(v_m, v_ver);
      raise exception 'FAIL D41 e: delete_media borra %', v_m;
    exception when foreign_key_violation then null;
    end;
    if not exists (select 1 from guide.media m where m.id = v_m) then
      raise exception 'FAIL D41 e: % desaparece tras el 23503', v_m; end if;

    -- f. Vaciar cualquier alt de una foto en uso: PT422 con site_settings en used_by
    foreach v_col in array array['alt_es', 'alt_en'] loop
      begin
        execute format('update guide.media set %I = %L where id = %L', v_col, '', v_m);
        raise exception 'FAIL D41 f: vacía % de %', v_col, v_m;
      exception when sqlstate 'PT422' then
        get stacked diagnostics v_j = pg_exception_detail;
        if v_j ->> 'entity' <> 'media' or (v_j ->> 'entity_id')::uuid <> v_m
           or not (v_j -> 'used_by') @> '[{"entity":"site_settings","entity_id":1}]'::jsonb
           or v_j -> 'missing' <> jsonb_build_array(jsonb_build_object('lang', substr(v_col, 5), 'media_id', v_m)) then
          raise exception 'FAIL D41 f: details de % en % (%)', v_col, v_m, v_j; end if;
      end;
    end loop;
  end loop;

  -- g. Borrado directo como admin: vacía solo la ranura de esa foto, sin error
  delete from guide.media where id = 'b4100000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  select hero_photo_1_media_id, hero_photo_2_media_id into v_1, v_2 from guide.site_settings where id = 1;
  if v_n <> 1 or v_1 is not null or v_2 is distinct from 'b4100000-0000-4000-8000-000000000002' then
    raise exception 'FAIL D41 g: ranura 1 (filas %, ranuras %, %)', v_n, v_1, v_2; end if;
  delete from guide.media where id = 'b4100000-0000-4000-8000-000000000002';
  get diagnostics v_n = row_count;
  select hero_photo_1_media_id, hero_photo_2_media_id into v_1, v_2 from guide.site_settings where id = 1;
  if v_n <> 1 or v_1 is not null or v_2 is not null then
    raise exception 'FAIL D41 g: ranura 2 (filas %, ranuras %, %)', v_n, v_1, v_2; end if;
  -- la misma foto en las dos ranuras
  update guide.site_settings set hero_photo_1_media_id = 'b4100000-0000-4000-8000-000000000004',
                                 hero_photo_2_media_id = 'b4100000-0000-4000-8000-000000000004' where id = 1;
  delete from guide.media where id = 'b4100000-0000-4000-8000-000000000004';
  get diagnostics v_n = row_count;
  select hero_photo_1_media_id, hero_photo_2_media_id into v_1, v_2 from guide.site_settings where id = 1;
  if v_n <> 1 or v_1 is not null or v_2 is not null then
    raise exception 'FAIL D41 g: misma foto en ambas (filas %, ranuras %, %)', v_n, v_1, v_2; end if;
end $$;
reset role;
drop function pg_temp.d41_slot_anon_sees(text, uuid, integer, uuid, text);
-- Los bloques siguientes corren con los claims que dejó F6.15: no se altera su contexto.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

-- Fin D41

-- ═════════════ F6.15b (D50): importar fichas ═════════════
-- admin_import_items (dry_run / apply con huella), publish_items, undo_import_batch, item_publish_blockers e import_*.
-- Las guardas dependen de guide.draft_op: los fixtures van en mantenimiento y las pruebas, con la marca vacía
-- (si no, las guardas estarían apagadas y las pruebas pasarían en falso).
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b6150000-0000-4000-8000-0000000000%s/1-f615b.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','02','03','04']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es)
values
  ('b6150000-0000-4000-8000-000000000001', 'b6150000-0000-4000-8000-000000000001/1-f615b.jpg', 'f615b-cover.jpg', 'image/jpeg', 1, 10, 10, 'Portada F615B'),
  ('b6150000-0000-4000-8000-000000000002', 'b6150000-0000-4000-8000-000000000002/1-f615b.jpg', 'f615b-noalt.jpg', 'image/jpeg', 1, 10, 10, null),
  ('b6150000-0000-4000-8000-000000000003', 'b6150000-0000-4000-8000-000000000003/1-f615b.jpg', 'f615b-dup.jpg', 'image/jpeg', 1, 10, 10, 'Dup 1'),
  ('b6150000-0000-4000-8000-000000000004', 'b6150000-0000-4000-8000-000000000004/1-f615b.jpg', 'F615B-DUP.jpg', 'image/jpeg', 1, 10, 10, 'Dup 2');
-- Pie de gato publicado (los cambios del archivo deben ir a borrador) y una redirección de slug antigua.
insert into guide.items (id, category, name, slug, published, cover_media_id)
values ('b6150000-0000-4000-8000-0000000000a1', 'shoe', 'F615B Live', 'f615b-live', false, 'b6150000-0000-4000-8000-000000000001');
insert into guide.shoes (item_id, brand, model, owned_by_author) values ('b6150000-0000-4000-8000-0000000000a1', 'F615B', 'Live', true);
update guide.items set published = true, summary_es = 'Resumen vivo' where id = 'b6150000-0000-4000-8000-0000000000a1';
insert into guide.slug_redirects (kind, item_category, old_slug, item_id)
values ('item', 'shoe', 'f615b-old', 'b6150000-0000-4000-8000-0000000000a1');
select set_config('guide.draft_op', '', true);
select set_config('guide.unpublish_op', '', true);

-- Error esperado (SQLSTATE) de una sentencia; NULL si no falla.
create or replace function pg_temp.f615b_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlstate;
end;
$$;

-- a. Anon: 42501 en todas las RPC y funciones auxiliares, y sin acceso a las tablas de lotes
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_sql text;
begin
  foreach v_sql in array array[
    $q$select guide.admin_import_items('shoe', '[{"slug":"f615b-anon","name":"x"}]'::jsonb, 'dry_run')$q$,
    $q$select guide.admin_import_items('shoe', '[{"slug":"f615b-anon","name":"x"}]'::jsonb, 'apply', md5('x'))$q$,
    $q$select guide.publish_items(array['b6150000-0000-4000-8000-0000000000a1'::uuid])$q$,
    $q$select guide.undo_import_batch(gen_random_uuid())$q$,
    $q$select guide.item_publish_blockers('b6150000-0000-4000-8000-0000000000a1')$q$,
    $q$select * from guide.admin_item_publish_blockers('shoe')$q$,
    $q$select guide.import_row('shoe', '{"slug":"f615b-anon","name":"x"}'::jsonb, false, false, null)$q$,
    $q$select guide.import_resolve_media('f615b-cover.jpg')$q$,
    $q$select guide.import_check_value('items', 'name', '"x"'::jsonb)$q$,
    $q$select guide.import_check_constraints('items', '{}'::jsonb, '{}', '{}')$q$,
    $q$select guide.plain_text_doc('x')$q$,
    $q$select count(*) from guide.import_batches$q$,
    $q$select count(*) from guide.import_batch_items$q$,
    $q$insert into guide.import_batches (category) values ('shoe')$q$] loop
    if pg_temp.f615b_err(v_sql) is distinct from '42501' then
      raise exception 'LEAK anon F6.15b: % → %', v_sql, coalesce(pg_temp.f615b_err(v_sql), 'ok'); end if;
  end loop;
end $$;
reset role;

-- b. Authenticated sin rol de admin: 42501 en las RPC; 0 filas y sin escritura en los lotes
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_sql text; v_n integer;
begin
  foreach v_sql in array array[
    $q$select guide.admin_import_items('shoe', '[{"slug":"f615b-user","name":"x"}]'::jsonb, 'dry_run')$q$,
    $q$select guide.publish_items(array['b6150000-0000-4000-8000-0000000000a1'::uuid])$q$,
    $q$select guide.undo_import_batch(gen_random_uuid())$q$,
    $q$select * from guide.admin_item_publish_blockers('shoe')$q$,
    $q$select guide.import_row('shoe', '{"slug":"f615b-user","name":"x"}'::jsonb, false, false, null)$q$,
    $q$select guide.import_resolve_media('f615b-cover.jpg')$q$,
    $q$select guide.import_check_value('items', 'name', '"x"'::jsonb)$q$,
    $q$select guide.import_check_constraints('items', '{}'::jsonb, '{}', '{}')$q$,
    $q$insert into guide.import_batches (category) values ('shoe')$q$,
    $q$insert into guide.import_batch_items (batch_id, item_id, action, version_after)
       values (gen_random_uuid(), 'b6150000-0000-4000-8000-0000000000a1', 'created', now())$q$] loop
    if pg_temp.f615b_err(v_sql) is distinct from '42501' then
      raise exception 'LEAK user F6.15b: % → %', v_sql, coalesce(pg_temp.f615b_err(v_sql), 'ok'); end if;
  end loop;
  -- item_publish_blockers es INVOKER: a un no admin solo le responde de lo que ya ve (la ficha publicada).
  if guide.item_publish_blockers('b6150000-0000-4000-8000-0000000000a1') is distinct from '{}'::text[] then
    raise exception 'FAIL user F6.15b: item_publish_blockers de una ficha publicada'; end if;
end $$;
reset role;

-- c. Admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  c_live   constant uuid := 'b6150000-0000-4000-8000-0000000000a1';
  v_rows   jsonb := jsonb_build_array(
    jsonb_build_object('_row', 7, 'slug', 'f615b-new', 'name', 'F615B New', 'brand', 'F615B', 'model', 'New',
                       'owned_by_author', true, 'cover', 'f615b-cover.jpg', 'scores', jsonb_build_object('rls_comfort', 4),
                       'review_text_es', E'<script>alert(1)</script>\n\nDos & tres'),
    jsonb_build_object('_row', 8, 'slug', 'f615b-live', 'summary_es', 'Resumen del archivo'));
  v_counts text;
  v_dry    jsonb;
  v_res    jsonb;
  v_batch  uuid;
  v_new    uuid;
  v_html   text;
  v_err    text;
  v_r      jsonb;
  v_b2     uuid;
  v_nocover uuid;
begin
  -- Una marca de mantenimiento heredada en la sesión no debe apagar ninguna guarda.
  perform set_config('guide.draft_op', 'maintenance', true);

  -- Criterio de la suite (rls_comfort): los fixtures globales desactivan los criterios reales, incluido «comfort».
  -- 1. dry_run: informe completo y nada escrito (ni fichas, ni borradores, ni registro, ni lotes)
  v_counts := (select format('%s/%s/%s/%s/%s/%s', (select count(*) from guide.items), (select count(*) from guide.shoes),
                (select count(*) from guide.content_drafts), (select count(*) from guide.activity_log),
                (select count(*) from guide.import_batches), (select count(*) from guide.author_reviews)));
  v_dry := guide.admin_import_items('shoe', v_rows, 'dry_run');
  if v_counts <> (select format('%s/%s/%s/%s/%s/%s', (select count(*) from guide.items), (select count(*) from guide.shoes),
                   (select count(*) from guide.content_drafts), (select count(*) from guide.activity_log),
                   (select count(*) from guide.import_batches), (select count(*) from guide.author_reviews))) then
    raise exception 'FAIL F6.15b 1: dry_run escribe algo'; end if;
  if (v_dry ->> 'applied')::boolean or v_dry ->> 'hash' !~ '^[0-9a-f]{32}$'
     or v_dry #>> '{summary,created}' <> '1' or v_dry #>> '{summary,drafted}' <> '1' or v_dry #>> '{summary,errors}' <> '0'
     or v_dry #> '{rows,0}' ? 'item_id' or v_dry #> '{rows,0,blockers}' <> '[]'::jsonb
     or (v_dry #>> '{rows,1,published}')::boolean is not true
     or v_dry #> '{rows,1,changes,0}' <> '{"column":"summary_es","before":"Resumen vivo","after":"Resumen del archivo"}'::jsonb then
    raise exception 'FAIL F6.15b 1: informe en seco % · filas %', v_dry - 'rows', v_dry -> 'rows'; end if;
  if coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.15b 1: la RPC no vacía guide.draft_op'; end if;

  -- 2. apply sin huella → 22023; con otra huella → stale y nada escrito
  if pg_temp.f615b_err(format('select guide.admin_import_items(%L, %L::jsonb, %L)', 'shoe', v_rows, 'apply')) <> '22023' then
    raise exception 'FAIL F6.15b 2: apply sin huella'; end if;
  v_res := guide.admin_import_items('shoe', v_rows, 'apply', md5('otro archivo'));
  if (v_res ->> 'applied')::boolean or not (v_res ->> 'stale')::boolean or v_res ->> 'hash' <> v_dry ->> 'hash'
     or exists (select 1 from guide.items where slug = 'f615b-new') then
    raise exception 'FAIL F6.15b 2: apply con huella ajena %', v_res - 'rows'; end if;

  -- 3. apply con la huella: alta sin publicar, la viva solo recibe un borrador, texto escapado, lote y registro
  v_res := guide.admin_import_items('shoe', v_rows, 'apply', v_dry ->> 'hash');
  v_batch := (v_res ->> 'batch_id')::uuid;
  select id into v_new from guide.items where category = 'shoe' and slug = 'f615b-new';
  if not (v_res ->> 'applied')::boolean or v_batch is null or v_new is null
     or (select published or published_at is not null from guide.items where id = v_new) then
    raise exception 'FAIL F6.15b 3: apply %', v_res - 'rows'; end if;
  if (select summary_es from guide.items where id = c_live) <> 'Resumen vivo'
     or (select payload from guide.content_drafts where entity = 'item' and entity_id = c_live)
        <> '{"item":{"summary_es":"Resumen del archivo"}}'::jsonb then
    raise exception 'LEAK F6.15b 3: el archivo pisa una ficha publicada'; end if;
  select body_html_es into v_html from guide.author_reviews where item_id = v_new;
  if v_html is distinct from '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p><p>Dos &amp; tres</p>' then
    raise exception 'LEAK F6.15b 3: reseña sin escapar: %', v_html; end if;
  if (select count(*) from guide.author_review_scores s join guide.author_reviews r on r.id = s.review_id where r.item_id = v_new) <> 1
     or (select cover_media_id from guide.items where id = v_new) <> 'b6150000-0000-4000-8000-000000000001' then
    raise exception 'FAIL F6.15b 3: notas o portada'; end if;
  if (select format('%s/%s', status, chunks) from guide.import_batches where id = v_batch) <> 'applied/1'
     or (select count(*) from guide.import_batch_items where batch_id = v_batch) <> 2
     or not exists (select 1 from guide.activity_log where action = 'import' and entity_table = 'import_batches'
                    and entity_id = v_batch::text and details ->> 'category' = 'shoe' and not details ? 'rows_data')
     or not exists (select 1 from guide.activity_log where entity_table = 'items' and entity_id = v_new::text
                    and details ->> 'import_batch' = v_batch::text) then
    raise exception 'FAIL F6.15b 3: lote o registro'; end if;

  -- 4. Reimportar el mismo archivo: todo sin cambios y la reseña del panel se conserva
  v_res := guide.admin_import_items('shoe', v_rows, 'dry_run');
  if v_res #>> '{summary,unchanged}' <> '2'
     or not exists (select 1 from jsonb_array_elements(v_res #> '{rows,0,issues}') x where x ->> 'code' = 'review_body_kept') then
    raise exception 'FAIL F6.15b 4: reimportar %', v_res; end if;

  -- 5. Errores por fila: borrador distinto, null, published, slugs, fotos, URL, owned_only, CHECK y criterios
  v_res := guide.admin_import_items('shoe', jsonb_build_array(
    jsonb_build_object('_row', 1, 'slug', 'f615b-live', 'summary_es', 'Otro resumen'),
    jsonb_build_object('_row', 2, 'slug', 'f615b-a', 'name', 'A', 'summary_es', null),
    jsonb_build_object('_row', 3, 'slug', 'f615b-b', 'name', 'B', 'published', true),
    jsonb_build_object('_row', 4, 'slug', 'sin-nombre', 'name', 'C'),
    jsonb_build_object('_row', 5, 'slug', 'f615b-old', 'name', 'D'),
    jsonb_build_object('_row', 6, 'slug', 'f615b-e', 'name', 'E', 'cover', 'https://evil.example/x.jpg'),
    jsonb_build_object('_row', 7, 'slug', 'f615b-f', 'name', 'F', 'cover', 'b6150000-0000-4000-8000-000000000001/../x.jpg'),
    jsonb_build_object('_row', 8, 'slug', 'f615b-g', 'name', 'G', 'scores', jsonb_build_object('rls_comfort', 4)),
    jsonb_build_object('_row', 9, 'slug', 'f615b-h', 'name', 'H', 'fit', 'robot', 'source_url', 'javascript:alert(1)'),
    jsonb_build_object('_row', 10, 'slug', 'f615b-i', 'name', 'I', 'brand', 'F615B', 'model', 'Live'),
    jsonb_build_object('_row', 11, 'slug', 'f615b-j', 'name', 'J', 'owned_by_author', true, 'scores', jsonb_build_object('nope', 3)),
    jsonb_build_object('_row', 12, 'slug', 'f615b-k', 'name', 'K'),
    jsonb_build_object('_row', 13, 'slug', 'f615b-k', 'name', 'K2')), 'dry_run');
  foreach v_err in array array['1:pending_draft', '2:null_not_allowed', '3:unknown_column', '4:slug_placeholder',
                               '5:slug_is_redirect', '6:media_external_url', '7:invalid_value', '8:owned_only',
                               '9:not_allowed_value', '9:invalid_url', '10:exists_as', '11:unknown_criterion',
                               '12:duplicate_in_file', '13:duplicate_in_file'] loop
    select r into v_r from jsonb_array_elements(v_res -> 'rows') r where r ->> 'row' = split_part(v_err, ':', 1);
    if v_r ->> 'action' <> 'error' or not exists (select 1 from jsonb_array_elements(v_r -> 'issues') x
                                                  where x ->> 'code' = split_part(v_err, ':', 2) and x ->> 'level' = 'error') then
      raise exception 'FAIL F6.15b 5: fila % sin %: %', split_part(v_err, ':', 1), split_part(v_err, ':', 2), v_r; end if;
  end loop;
  -- Con errores, apply no escribe nada (todo o nada por llamada)
  v_r := guide.admin_import_items('shoe', jsonb_build_array(jsonb_build_object('slug', 'f615b-ok', 'name', 'OK'),
                                                            jsonb_build_object('slug', 'f615b-bad', 'name', 'Bad', 'fit', 'robot')), 'dry_run');
  v_r := guide.admin_import_items('shoe', jsonb_build_array(jsonb_build_object('slug', 'f615b-ok', 'name', 'OK'),
                                                            jsonb_build_object('slug', 'f615b-bad', 'name', 'Bad', 'fit', 'robot')),
                                  'apply', v_r ->> 'hash');
  if (v_r ->> 'applied')::boolean or exists (select 1 from guide.items where slug = 'f615b-ok') then
    raise exception 'FAIL F6.15b 5: apply con una fila errónea escribe'; end if;
  -- Avisos de fotos: nombre repetido (sin distinguir mayúsculas), sin alt y no encontrada
  v_r := guide.admin_import_items('shoe', jsonb_build_array(
    jsonb_build_object('slug', 'f615b-m', 'name', 'M', 'cover', 'f615b-dup.jpg', 'og_image', 'f615b-noalt.jpg',
                       'gallery', jsonb_build_array('no-existe.jpg'))), 'dry_run');
  if v_r #>> '{rows,0,action}' <> 'created'
     or (select array_agg(x ->> 'code' order by x ->> 'code') from jsonb_array_elements(v_r #> '{rows,0,issues}') x where x ->> 'level' = 'warning')
        <> array['media_ambiguous', 'media_no_alt', 'media_not_found']
     or v_r #> '{rows,0,blockers}' <> '["brand_model", "cover", "alt"]'::jsonb then
    raise exception 'FAIL F6.15b 5: avisos de fotos %', v_r -> 'rows'; end if;
  -- Límites por llamada
  if pg_temp.f615b_err(format('select guide.admin_import_items(%L, %L::jsonb)', 'shoe',
       (select jsonb_agg(jsonb_build_object('slug', 'f615b-n' || i, 'name', 'N')) from generate_series(1, 101) i))) <> '22023'
     or pg_temp.f615b_err($q$select guide.admin_import_items('rope', '[{"slug":"x","name":"x"}]'::jsonb)$q$) <> '22023'
     or pg_temp.f615b_err($q$select guide.admin_import_items('shoe', '[{"slug":"x","name":"x"}]'::jsonb, 'publish')$q$) <> '22023' then
    raise exception 'FAIL F6.15b 5: límites'; end if;

  -- 6. Publicación: el trigger exige portada en el paso a publicada; publish_items publica la lista y no las demás
  perform guide.admin_import_items('shoe', '[{"slug":"f615b-nocover","name":"Sin portada","brand":"F615B","model":"NoCover"}]'::jsonb,
    'apply', (guide.admin_import_items('shoe', '[{"slug":"f615b-nocover","name":"Sin portada","brand":"F615B","model":"NoCover"}]'::jsonb) ->> 'hash'));
  select id into v_nocover from guide.items where slug = 'f615b-nocover';
  select batch_id into v_b2 from guide.import_batch_items where item_id = v_nocover;
  if pg_temp.f615b_err(format('update guide.items set published = true where id = %L', v_nocover)) <> '23514' then
    raise exception 'FAIL F6.15b 6: se publica sin portada en directo'; end if;
  v_r := guide.publish_items(array[v_new, v_nocover, c_live]);
  if (v_r ->> 'published')::integer <> 1
     or not (select published from guide.items where id = v_new)
     or (select published from guide.items where id = v_nocover)
     or not exists (select 1 from jsonb_array_elements(v_r -> 'results') x
                    where x ->> 'id' = v_nocover::text and x ->> 'code' = 'blocked' and x -> 'blockers' = '["cover"]'::jsonb)
     or not exists (select 1 from jsonb_array_elements(v_r -> 'results') x
                    where x ->> 'id' = c_live::text and x ->> 'code' = 'already_published') then
    raise exception 'FAIL F6.15b 6: publish_items %', v_r; end if;
  if pg_temp.f615b_err('select guide.publish_items(''{}''::uuid[])') <> '22023' then
    raise exception 'FAIL F6.15b 6: publish_items sin ids'; end if;

  -- 7. Deshacer: no borra la publicada, descarta el borrador intacto; la tocada no se borra; la intacta sí
  v_r := guide.undo_import_batch(v_batch);
  if v_r ->> 'status' <> 'partially_undone' or not exists (select 1 from guide.items where id = v_new)
     or exists (select 1 from guide.content_drafts where entity = 'item' and entity_id = c_live)
     or v_r -> 'summary' <> '{"published":1,"discarded":1}'::jsonb then
    raise exception 'FAIL F6.15b 7: deshacer lote 1 %', v_r; end if;
  -- En una sola transacción now() no avanza: se simula «tocada después» retrasando la versión guardada.
  update guide.import_batch_items set version_after = version_after - interval '1 minute' where batch_id = v_b2;
  v_r := guide.undo_import_batch(v_b2);
  if v_r -> 'summary' <> '{"modified":1}'::jsonb or not exists (select 1 from guide.items where id = v_nocover) then
    raise exception 'FAIL F6.15b 7: deshacer borra una ficha tocada %', v_r; end if;
  update guide.import_batch_items set version_after = guide.draft_entity_version('item', v_nocover) where batch_id = v_b2;
  v_r := guide.undo_import_batch(v_b2);
  if v_r ->> 'status' <> 'undone' or exists (select 1 from guide.items where id = v_nocover)
     or not exists (select 1 from guide.activity_log where action = 'import_undo' and entity_id = v_b2::text) then
    raise exception 'FAIL F6.15b 7: deshacer lote 2 %', v_r; end if;
  if pg_temp.f615b_err(format('select guide.undo_import_batch(%L)', v_b2)) <> '22023' then
    raise exception 'FAIL F6.15b 7: deshacer dos veces'; end if;
  perform set_config('guide.f615b_batch', v_batch::text, true);
end $$;
reset role;

-- d. El no admin no ve los lotes que ha creado el admin ni puede cambiarlos
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if exists (select 1 from guide.import_batches) or exists (select 1 from guide.import_batch_items) then
    raise exception 'LEAK user F6.15b: ve lotes de importación'; end if;
  update guide.import_batches set status = 'undone' where id = current_setting('guide.f615b_batch')::uuid;
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user F6.15b: cambia un lote'; end if;
end $$;
reset role;
drop function pg_temp.f615b_err(text);
-- Los bloques siguientes corren con los claims del admin, como tras D41.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

-- Fin F6.15b

-- ═════════════ F6.15b O1: import_row vacía draft_op y unpublish_op aunque se llame suelta ═════════════
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  perform set_config('guide.draft_op', 'publish', true);
  perform set_config('guide.unpublish_op', 'unpublish', true);
  perform guide.import_row('gym', '{"_row":1}'::jsonb, false, false, null);  -- sin slug: informe de error, no escribe
  if coalesce(current_setting('guide.draft_op', true), '') <> '' or coalesce(current_setting('guide.unpublish_op', true), '') <> '' then
    raise exception 'FAIL F6.15b O1: import_row deja draft_op=% unpublish_op=%',
      current_setting('guide.draft_op', true), current_setting('guide.unpublish_op', true); end if;
end $$;
reset role;

-- Fin F6.15b O1

-- ═════════════ D51: datos del autor en site_settings (lectura pública, escritura admin, foto con alt es/en) ═════════════
-- Medios b5100000…: 01 con los dos alts; 02 sin alt_en; 03 con los dos y sin usar (testigo oculto).
select set_config('guide.draft_op', '', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b5100000-0000-4000-8000-0000000000%s/1-d51.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','02','03']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es, alt_en)
select format('b5100000-0000-4000-8000-0000000000%s', n)::uuid, format('b5100000-0000-4000-8000-0000000000%s/1-d51.jpg', n),
       'd51.jpg', 'image/jpeg', 1, 10, 10, 'Retrato ' || n, case when n <> '02' then 'Portrait ' || n end
from unnest(array['01','02','03']) n;
update guide.site_settings set author_photo_media_id = null where id = 1;

-- a. Anon: lee las columnas públicas del autor (y contact_email); no escribe ninguna; no ve los medios sin usar
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_col text;
begin
  perform author_name, author_role_es, author_role_en, author_lede_es, author_lede_en, author_bio_es, author_bio_en,
          author_photo_media_id, author_stats, contact_email
  from guide.site_settings where id = 1;
  if not found then raise exception 'FAIL anon D51: no lee site_settings'; end if;
  foreach v_col in array array['author_name', 'author_role_es', 'author_role_en', 'author_lede_es', 'author_lede_en',
                               'author_bio_es', 'author_bio_en'] loop
    begin
      execute format('update guide.site_settings set %I = %L where id = 1', v_col, 'hack');
      raise exception 'LEAK anon D51: escribe %', v_col;
    exception when insufficient_privilege then null;
    end;
  end loop;
  begin update guide.site_settings set author_stats = '[]' where id = 1;
    raise exception 'LEAK anon D51: escribe author_stats'; exception when insufficient_privilege then null; end;
  begin update guide.site_settings set author_photo_media_id = 'b5100000-0000-4000-8000-000000000001' where id = 1;
    raise exception 'LEAK anon D51: escribe la foto'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.media where id::text like 'b5100000-%') then
    raise exception 'LEAK anon D51: ve medios sin usar'; end if;
end $$;
reset role;

-- b. No admin: lee, pero cada escritura afecta 0 filas
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  perform author_bio_es, author_stats from guide.site_settings where id = 1;
  if not found then raise exception 'FAIL user D51: no lee site_settings'; end if;
  update guide.site_settings set author_name = 'hack', author_bio_es = 'hack', author_stats = '[]' where id = 1;
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D51: escribe datos del autor'; end if;
  update guide.site_settings set author_photo_media_id = 'b5100000-0000-4000-8000-000000000001' where id = 1;
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D51: escribe la foto'; end if;
  if exists (select 1 from guide.site_settings where id = 1 and (author_name = 'hack' or author_photo_media_id is not null)) then
    raise exception 'LEAK user D51: los datos del autor cambian'; end if;
end $$;
reset role;

-- c. Admin: topes de longitud y forma de author_stats (23514); valores válidos se guardan
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_bad jsonb;
  v_n   integer;
begin
  begin update guide.site_settings set author_bio_es = repeat('x', 161) where id = 1;
    raise exception 'FAIL D51 c: bio de 161'; exception when check_violation then null; end;
  begin update guide.site_settings set author_lede_en = repeat('x', 121) where id = 1;
    raise exception 'FAIL D51 c: lede de 121'; exception when check_violation then null; end;
  foreach v_bad in array array[
    'null'::jsonb, '{}', '[1]', '[{}]', '[{"value":"1"}]', '[{"value":2,"label_es":"a"}]', '[{"value":" ","label_es":"a"}]',
    '[{"value":"1","label_es":"a","label_en":null}]', '[{"value":"1","label_es":"a","url":"https://x.test"}]',
    '[{"value":"1","label_es":"a"},{"value":"2","label_es":"b"},{"value":"3","label_es":"c"}]'
  ] loop
    begin
      update guide.site_settings set author_stats = v_bad where id = 1;
      raise exception 'FAIL D51 c: author_stats acepta %', v_bad;
    exception when check_violation or not_null_violation then null;
    end;
  end loop;
  update guide.site_settings
  set author_name = '[Dummy] Autor', author_bio_es = repeat('x', 160), author_lede_es = repeat('x', 120),
      author_stats = '[{"value":"15","label_es":"años escalando"},{"value":"7b","label_es":"grado máximo","label_en":"top grade"}]'
  where id = 1;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL D51 c: el admin no guarda (% filas)', v_n; end if;
end $$;
reset role;

-- d. Foto: PT422 sin alt_en; con los dos alts se guarda, anon la ve (y no el testigo), cuenta como medio en uso
--    (role author, 23503 en delete_media, PT422 al vaciar un alt) y el borrado directo vacía la columna.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_j   jsonb;
  v_ver integer;
  v_col text;
begin
  begin
    update guide.site_settings set author_photo_media_id = 'b5100000-0000-4000-8000-000000000002' where id = 1;
    raise exception 'FAIL D51 d: acepta una foto sin alt_en';
  exception when sqlstate 'PT422' then
    get stacked diagnostics v_j = pg_exception_detail;
    if v_j ->> 'entity' <> 'site_settings' or (v_j ->> 'setting_id')::smallint <> 1
       or v_j -> 'missing' <> '[{"lang":"en","media_id":"b5100000-0000-4000-8000-000000000002"}]'::jsonb then
      raise exception 'FAIL D51 d: details (%)', v_j; end if;
  end;
  update guide.site_settings set author_photo_media_id = 'b5100000-0000-4000-8000-000000000001' where id = 1;
  if not exists (select 1 from guide.media_usages('b5100000-0000-4000-8000-000000000001') u
                 where u.role = 'author' and u.owner_table = 'site_settings') then
    raise exception 'FAIL D51 d: media_usages no da role author'; end if;
  select m.version into v_ver from guide.media m where m.id = 'b5100000-0000-4000-8000-000000000001';
  begin
    perform guide.delete_media('b5100000-0000-4000-8000-000000000001', v_ver);
    raise exception 'FAIL D51 d: delete_media borra la foto del autor';
  exception when foreign_key_violation then null;
  end;
  foreach v_col in array array['alt_es', 'alt_en'] loop
    begin
      execute format('update guide.media set %I = %L where id = %L', v_col, '', 'b5100000-0000-4000-8000-000000000001');
      raise exception 'FAIL D51 d: vacía % de la foto del autor', v_col;
    exception when sqlstate 'PT422' then
      get stacked diagnostics v_j = pg_exception_detail;
      if not (v_j -> 'used_by') @> '[{"entity":"site_settings","entity_id":1}]'::jsonb then
        raise exception 'FAIL D51 d: used_by de % (%)', v_col, v_j; end if;
    end;
  end loop;
end $$;
reset role;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if not exists (select 1 from guide.media where id = 'b5100000-0000-4000-8000-000000000001') then
    raise exception 'FAIL anon D51: no ve la foto del autor'; end if;
  if exists (select 1 from guide.media where id::text like 'b5100000-%' and id <> 'b5100000-0000-4000-8000-000000000001') then
    raise exception 'LEAK anon D51: ve otro medio no público'; end if;
  if not exists (select 1 from guide.site_settings where id = 1 and author_name = '[Dummy] Autor'
                 and jsonb_array_length(author_stats) = 2) then
    raise exception 'FAIL anon D51: no lee los datos del autor guardados'; end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  delete from guide.media where id = 'b5100000-0000-4000-8000-000000000001';
  get diagnostics v_n = row_count;
  if v_n <> 1 or exists (select 1 from guide.site_settings where id = 1 and author_photo_media_id is not null) then
    raise exception 'FAIL D51 d: el borrado directo no vacía la foto (% filas)', v_n; end if;
end $$;
reset role;
-- Los bloques siguientes corren con los claims del admin, como tras F6.15b.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

-- Fin D51

-- ═════════════ D56 · D55: consentimiento v3, Inicio v2 (admin_dashboard_stats) y búsqueda ⌘K (admin_search) ═════════════
-- Fixtures propios (ids d5500000…, texto «zqxd55»), como postgres. Las comprobaciones de recuentos comparan con lo que
-- ve postgres (sin RLS), así que no dependen del resto de la suite. La suite puede haber subido consent_version (F6.14).
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata) values ('media', 'd5500000-0000-4000-8000-000000000001/1-zqxd55.jpg',
  '{"mimetype":"image/jpeg","size":1000}');
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, alt_es)
values ('d5500000-0000-4000-8000-000000000001', 'd5500000-0000-4000-8000-000000000001/1-zqxd55.jpg', 'zqxd55-foto.jpg',
        'image/jpeg', 1000, null);
insert into guide.article_categories (id, name_es, slug_es) values ('d5500000-0000-4000-8000-0000000000c1', 'Cat D55', 'd55-cat');
insert into guide.articles (id, category_id, status, title_es, slug_es, excerpt_es, body_html_es, title_en, slug_en) values
  ('d5500000-0000-4000-8000-0000000000a1', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Zqxd55 Búsqueda primera', 'd55-a1',
   null, '', null, null),
  ('d5500000-0000-4000-8000-0000000000a2', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Título sin la clave', 'd55-a2',
   null, '', 'English zqxd55 title', 'd55-a2-en'),
  ('d5500000-0000-4000-8000-0000000000a3', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Otro título D55', 'd55-a3',
   'Un extracto con zqxd55 dentro', '', null, null),
  ('d5500000-0000-4000-8000-0000000000a4', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Cuarto título D55', 'd55-a4',
   null, '<p>Texto con zqxd55cuerpo &amp; <b>más</b> cosas para el fragmento.</p>', null, null),
  ('d5500000-0000-4000-8000-0000000000a5', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Zqxd55 100% real', 'd55-a5',
   null, '', null, null),
  ('d5500000-0000-4000-8000-0000000000a6', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Zqxd55 100x real', 'd55-a6',
   null, '', null, null),
  ('d5500000-0000-4000-8000-0000000000a7', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Zqxd55 a_b', 'd55-a7',
   null, '', null, null),
  ('d5500000-0000-4000-8000-0000000000a8', 'd5500000-0000-4000-8000-0000000000c1', 'draft', 'Zqxd55 axb', 'd55-a8',
   null, '', null, null);
insert into guide.items (id, category, name, slug, published) values
  ('d5500000-0000-4000-8000-0000000000f1', 'gym', 'Zqxd55 Gym importado', 'd55-gym', false);
insert into guide.import_batches (id, category) values ('d5500000-0000-4000-8000-0000000000b1', 'gym');
insert into guide.import_batch_items (batch_id, item_id, action, version_after)
values ('d5500000-0000-4000-8000-0000000000b1', 'd5500000-0000-4000-8000-0000000000f1', 'created', now());
insert into guide.events (id, title_es, starts_at, status, source, location_text, dedupe_key, agent_meta, approved_at) values
  ('d5500000-0000-4000-8000-0000000000e1', 'Zqxd55 evento aprobado', now() + interval '20 days', 'approved', 'manual',
   'Sala D55', null, null, now()),
  ('d5500000-0000-4000-8000-0000000000e2', 'Zqxd55 evento del agente', now() + interval '1 day', 'draft', 'agent',
   'Sala D55', 'd55-agent', '{"confidence":0.7,"duplicate_of":"d5500000-0000-4000-8000-0000000000e1"}', null),
  ('d5500000-0000-4000-8000-0000000000e3', 'Zqxd55 evento descartado', now() + interval '2 days', 'rejected', 'manual',
   'Sala D55', null, null, null);
select set_config('guide.draft_op', '', true);

-- Valores esperados (como postgres, sin RLS) para comparar con lo que devuelve la RPC al admin.
select set_config('d55.expect', jsonb_build_object(
  'next_at', (select min(e.starts_at) from guide.events e
              where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
  'dups', (select count(*) from guide.events e join guide.events d
             on d.id = case when (e.agent_meta ->> 'duplicate_of') ~* '^[0-9a-f-]{36}$' then (e.agent_meta ->> 'duplicate_of')::uuid end
            and d.id <> e.id
           where e.status = 'draft' and not guide.event_is_past(e.starts_at, e.ends_at, e.all_day)),
  'imported', (select count(distinct i.id) from guide.import_batch_items bi join guide.items i on i.id = bi.item_id
               where bi.action = 'created' and bi.undone_at is null and not i.published),
  'photos', (select count(*) from guide.user_review_photos where status = 'pending'),
  'published', (select count(*) from guide.items where published),
  'alt_in_use', (select count(*) from guide.media m where (m.alt_es is null or btrim(m.alt_es) = '')
                   and exists (select 1 from guide.media_usage u where u.media_id = m.id))
)::text, true);

-- D56 (como postgres): v3 con el mismo es que v2 y el en aprobado; v2 cerrada justo al abrir v3.
do $$
begin
  if not exists (select 1 from guide.consent_texts c3 join guide.consent_texts c2 on c2.version = 2
                 where c3.version = 3 and c3.preserved
                   and c3.text_es = 'Quiero recibir novedades de ChalkGuide por email. Puedo darme de baja cuando quiera.'
                   and c3.text_es = c2.text_es
                   and c3.text_en = 'I''d like to receive news from ChalkGuide by email. I can unsubscribe at any time.'
                   and c2.valid_to is not null and c2.valid_to = c3.valid_from) then
    raise exception 'FAIL D56: consent_texts v3 / cierre de v2'; end if;
  if (select consent_version from guide.site_settings where id = 1) < 3 then
    raise exception 'FAIL D56: consent_version < 3'; end if;
  if (select count(*) from guide.consent_texts where purpose = 'newsletter' and valid_to is null) <> 1 then  -- D66: una abierta por finalidad
    raise exception 'FAIL D56: más de una versión vigente'; end if;
  -- Las guardas siguen igual: v3 no se edita ni se borra, ni como postgres.
  begin update guide.consent_texts set text_en = 'x' where version = 3;
    raise exception 'FAIL D56: consent_texts v3 editable'; exception when insufficient_privilege then null; end;
  begin delete from guide.consent_texts where version = 3;
    raise exception 'FAIL D56: consent_texts v3 borrable'; exception when insufficient_privilege then null; end;
end $$;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  -- El texto EN que pinta el sitio es el de la versión vigente.
  if not exists (select 1 from guide.site_settings s where s.id = 1
                 and s.newsletter_consent_text_en = 'I''d like to receive news from ChalkGuide by email. I can unsubscribe at any time.') then
    raise exception 'FAIL anon D56: no lee el texto EN del consentimiento'; end if;
  perform guide.subscribe_newsletter('rls-d56@chalkguide.test', 'en', 'footer', true, '/en');
  begin perform guide.admin_search('zqxd55'); raise exception 'LEAK anon D55: admin_search';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_events_agent_info(array['d5500000-0000-4000-8000-0000000000e2']::uuid[]);
    raise exception 'LEAK anon D55: admin_events_agent_info'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_dashboard_stats(); raise exception 'LEAK anon D55: admin_dashboard_stats';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

do $$
begin
  -- La alta nueva queda con la versión vigente (3, o la que haya subido la suite), y esa versión es la abierta.
  if not exists (select 1 from guide.subscribers sb join guide.site_settings s on s.id = 1
                 join guide.consent_texts c on c.purpose = 'newsletter' and c.version = sb.consent_version
                 where sb.email = 'rls-d56@chalkguide.test' and sb.consent_version = s.consent_version
                   and sb.consent_version >= 3 and c.valid_to is null) then
    raise exception 'FAIL D56: subscribe_newsletter no registra la versión vigente'; end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_ver integer := (select consent_version from guide.site_settings where id = 1);
begin
  begin update guide.site_settings set consent_version = v_ver + 1, newsletter_consent_text_en = 'x' where id = 1;
  exception when insufficient_privilege then null; end;
  if (select consent_version from guide.site_settings where id = 1) <> v_ver then
    raise exception 'LEAK user D56: cambia consent_version'; end if;
  begin perform guide.admin_search('zqxd55'); raise exception 'LEAK user D55: admin_search';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_events_agent_info(array['d5500000-0000-4000-8000-0000000000e2']::uuid[]);
    raise exception 'LEAK user D55: admin_events_agent_info'; exception when insufficient_privilege then null; end;
  begin perform guide.admin_dashboard_stats(); raise exception 'LEAK user D55: admin_dashboard_stats';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$
begin
  if exists (select 1 from guide.consent_texts where text_en = 'x') then raise exception 'LEAK user D56: versiona el consentimiento'; end if;
end $$;

-- Inicio v2: campos nuevos, solo admin, iguales a lo que ve postgres.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  s   jsonb := guide.admin_dashboard_stats();
  x   jsonb := current_setting('d55.expect')::jsonb;
  k   text;
  v_n bigint;
begin
  foreach k in array array['events_drafts_next_at', 'items_stale_by_category', 'review_photos_pending',
                           'items_imported_unpublished', 'items_imported_unpublished_by_category', 'user_reviews_low_since',
                           'media_without_alt_in_use', 'events_drafts_duplicates', 'items_published',
                           'items_published_by_category', 'items_total_by_category', 'recent_activity'] loop
    if not s ? k then raise exception 'FAIL D55: falta % en admin_dashboard_stats', k; end if;
  end loop;
  if (s ->> 'events_drafts_next_at')::timestamptz is distinct from (x ->> 'next_at')::timestamptz
     or (s ->> 'events_drafts_next_at')::timestamptz > now() + interval '1 day' then
    raise exception 'FAIL D55: events_drafts_next_at (% / %)', s ->> 'events_drafts_next_at', x ->> 'next_at'; end if;
  if (s ->> 'events_drafts_duplicates')::bigint <> (x ->> 'dups')::bigint or (x ->> 'dups')::bigint < 1 then
    raise exception 'FAIL D55: events_drafts_duplicates (% / %)', s ->> 'events_drafts_duplicates', x ->> 'dups'; end if;
  if (s ->> 'items_imported_unpublished')::bigint <> (x ->> 'imported')::bigint or (x ->> 'imported')::bigint < 1
     or (s #>> '{items_imported_unpublished_by_category,gym}')::bigint < 1 then
    raise exception 'FAIL D55: items_imported_unpublished (%)', s ->> 'items_imported_unpublished'; end if;
  if (s ->> 'review_photos_pending')::bigint <> (x ->> 'photos')::bigint
     or (s ->> 'review_photos_pending')::bigint <> (guide.admin_reviews_summary() ->> 'photos_pending')::bigint then
    raise exception 'FAIL D55: review_photos_pending'; end if;
  if (s ->> 'media_without_alt_in_use')::bigint <> (x ->> 'alt_in_use')::bigint
     or (s ->> 'media_without_alt_in_use')::bigint > (s ->> 'media_without_alt')::bigint then
    raise exception 'FAIL D55: media_without_alt_in_use'; end if;
  if (s ->> 'items_published')::bigint <> (x ->> 'published')::bigint then raise exception 'FAIL D55: items_published'; end if;
  select coalesce(sum(value::bigint), 0) into v_n from jsonb_each_text(s -> 'items_published_by_category');
  if v_n <> (s ->> 'items_published')::bigint then raise exception 'FAIL D55: items_published_by_category no suma'; end if;
  select coalesce(sum(value::bigint), 0) into v_n from jsonb_each_text(s -> 'items_stale_by_category');
  if v_n <> (s ->> 'items_stale')::bigint then raise exception 'FAIL D55: items_stale_by_category no suma'; end if;
  if not (s -> 'items_total_by_category') ?& array(select key from guide.item_categories) then
    raise exception 'FAIL D55: faltan categorías en items_total_by_category'; end if;
  if (s ->> 'user_reviews_low_since')::bigint > (guide.admin_reviews_summary() ->> 'new_since_seen')::bigint then
    raise exception 'FAIL D55: user_reviews_low_since > new_since_seen'; end if;
  -- El helper da la procedencia al admin.
  if not exists (select 1 from guide.admin_events_agent_info(array['d5500000-0000-4000-8000-0000000000e2']::uuid[]) a
                 where a.source = 'agent' and a.duplicate_of = 'd5500000-0000-4000-8000-0000000000e1') then
    raise exception 'FAIL D55: admin_events_agent_info'; end if;
end $$;

-- ⌘K: admin_search
do $$
declare
  r   record;
  v_n integer;
  v_e text;
begin
  -- Sin tildes ni mayúsculas; título que empieza → rank 1.
  select * into r from guide.admin_search('ZQXD55 busqueda', array['article']) s;
  if r.id is distinct from 'd5500000-0000-4000-8000-0000000000a1'::uuid or r.rank <> 1 or r.matched_field <> 'title_es'
     or r.status <> 'draft' or (r.data ->> 'category_name_es') <> 'Cat D55' or r.snippet is not null then
    raise exception 'FAIL D55 search: título sin tildes (%)', to_jsonb(r); end if;
  -- Orden 1 → 2 → 3 → 4 y campos en inglés.
  if (select string_agg(s.rank::text || ':' || s.matched_field, ',' order by s.rank, s.matched_field)
      from guide.admin_search('zqxd55', array['article'], 20) s
      where s.id in ('d5500000-0000-4000-8000-0000000000a1', 'd5500000-0000-4000-8000-0000000000a2',
                     'd5500000-0000-4000-8000-0000000000a3', 'd5500000-0000-4000-8000-0000000000a4'))
     is distinct from '1:title_es,2:title_en,3:excerpt_es,4:body_es' then
    raise exception 'FAIL D55 search: rangos o campos en inglés'; end if;
  select array_agg(s.rank order by s.ord) into strict v_e
  from (select s.rank, row_number() over () as ord from guide.admin_search('zqxd55', array['article'], 20) s) s;
  if v_e::integer[] is distinct from (select array_agg(x order by x) from unnest(v_e::integer[]) x) then
    raise exception 'FAIL D55 search: filas fuera de orden (%)', v_e; end if;
  -- Fragmento del cuerpo: texto plano, sin etiquetas.
  select * into r from guide.admin_search('zqxd55cuerpo', array['article']) s;
  if r.id is distinct from 'd5500000-0000-4000-8000-0000000000a4'::uuid or r.rank <> 4
     or r.snippet not like '%zqxd55cuerpo & más%' or r.snippet like '%<%' then
    raise exception 'FAIL D55 search: fragmento del cuerpo (%)', r.snippet; end if;
  -- Comodines de LIKE literales (rank < 4: el cuerpo busca por palabras de 3+ letras, no por la frase).
  if (select array_agg(s.id) from guide.admin_search('zqxd55 100%', array['article']) s where s.rank < 4)
     is distinct from array['d5500000-0000-4000-8000-0000000000a5']::uuid[] then
    raise exception 'FAIL D55 search: %% sin escapar'; end if;
  if (select array_agg(s.id) from guide.admin_search('zqxd55 a_b', array['article']) s where s.rank < 4)
     is distinct from array['d5500000-0000-4000-8000-0000000000a7']::uuid[] then
    raise exception 'FAIL D55 search: _ sin escapar'; end if;
  -- Los comodines van literales: solo puede salir lo que contiene «%%» o «__» de verdad (la BD real tiene medios
  -- con «__» en el nombre de archivo, p. ej. de Barrabes), nunca «todo».
  if exists (select 1 from guide.admin_search('%%', null, 20) s
             where coalesce(s.title, '') || ' ' || coalesce(s.key, '') not like '%\%\%%')
     or exists (select 1 from guide.admin_search('__', null, 20) s
                where coalesce(s.title, '') || ' ' || coalesce(s.key, '') not like '%\_\_%') then
    raise exception 'FAIL D55 search: %% o __ casan con todo'; end if;
  -- Límite por tipo y total por tipo; tope de 20.
  select count(*) into v_n from guide.admin_search('zqxd55', array['article'], 2) s;
  if v_n <> 2 or (select max(s.total_in_kind) from guide.admin_search('zqxd55', array['article'], 2) s) < 8 then
    raise exception 'FAIL D55 search: límite por tipo / total (%)', v_n; end if;
  if (select count(*) from guide.admin_search('zqxd55', array['article'], 500) s) > 20 then
    raise exception 'FAIL D55 search: límite sin tope'; end if;
  -- Ámbito y tipos: fichas, eventos (sin descartados, con procedencia) y medios.
  if exists (select 1 from guide.admin_search('zqxd55', array['media']) s where s.kind <> 'media') then
    raise exception 'FAIL D55 search: el ámbito no filtra'; end if;
  if not exists (select 1 from guide.admin_search('zqxd55', array['gym']) s
                 where s.id = 'd5500000-0000-4000-8000-0000000000f1' and s.status = 'unpublished' and s.rank = 1) then
    raise exception 'FAIL D55 search: ficha'; end if;
  if exists (select 1 from guide.admin_search('zqxd55', array['event'], 20) s where s.id = 'd5500000-0000-4000-8000-0000000000e3') then
    raise exception 'FAIL D55 search: devuelve eventos descartados'; end if;
  if (select string_agg(s.id::text || ':' || (s.data ->> 'source'), ',' order by s.rank, (s.data ->> 'starts_at')::timestamptz)
      from guide.admin_search('zqxd55 evento', array['event'], 20) s)
     is distinct from 'd5500000-0000-4000-8000-0000000000e2:agent,d5500000-0000-4000-8000-0000000000e1:manual' then
    raise exception 'FAIL D55 search: eventos (orden o procedencia)'; end if;
  if not exists (select 1 from guide.admin_search('zqxd55', array['event'], 20) s
                 where s.id = 'd5500000-0000-4000-8000-0000000000e2' and (s.data ->> 'duplicate_of') = 'd5500000-0000-4000-8000-0000000000e1') then
    raise exception 'FAIL D55 search: duplicate_of del evento'; end if;
  if not exists (select 1 from guide.admin_search('zqxd55', array['media']) s
                 where s.id = 'd5500000-0000-4000-8000-000000000001' and s.status = 'missing_alt' and s.data ? 'usage_count') then
    raise exception 'FAIL D55 search: medio'; end if;
  perform * from guide.admin_search('zqxd55', array['page']);
  -- Validación.
  foreach v_e in array array['a', ' a ', '', null] loop
    begin perform guide.admin_search(v_e); raise exception 'FAIL D55 search: acepta «%»', v_e;
    exception when invalid_parameter_value then null; end;
  end loop;
  foreach v_e in array array['user_review', 'subscriber', 'user_profile', 'admin', 'activity_log'] loop
    begin perform guide.admin_search('zqxd55', array[v_e]); raise exception 'FAIL D55 search: tipo %', v_e;
    exception when invalid_parameter_value then null; end;
  end loop;
  begin perform guide.admin_search('zqxd55', array['article', null]); raise exception 'FAIL D55 search: tipo null';
  exception when invalid_parameter_value then null; end;
  perform * from guide.admin_search(repeat('zqxd55 ', 1000));   -- se recorta, no falla
end $$;
reset role;

-- Forma de las funciones: INVOKER donde se puede, search_path fijo, sin EXECUTE para anon y sin tocar tablas privadas.
do $$
declare v_def text := pg_get_functiondef('guide.admin_search(text, text[], integer)'::regprocedure);
begin
  if (select prosecdef from pg_proc where oid = 'guide.admin_search(text, text[], integer)'::regprocedure)
     or not (select prosecdef from pg_proc where oid = 'guide.admin_events_agent_info(uuid[])'::regprocedure)
     or (select prosecdef from pg_proc where oid = 'guide.admin_dashboard_stats()'::regprocedure) then
    raise exception 'FAIL D55: SECURITY DEFINER/INVOKER'; end if;
  if exists (select 1 from pg_proc where oid in ('guide.admin_search(text, text[], integer)'::regprocedure,
                                                 'guide.admin_events_agent_info(uuid[])'::regprocedure)
             and not (proconfig @> array['search_path=""'])) then
    raise exception 'FAIL D55: search_path'; end if;
  if has_function_privilege('anon', 'guide.admin_search(text, text[], integer)', 'execute')
     or has_function_privilege('anon', 'guide.admin_events_agent_info(uuid[])', 'execute') then
    raise exception 'LEAK D55: EXECUTE para anon'; end if;
  if v_def ~ '(user_reviews|subscribers|user_profiles|guide\.admins|activity_log)' then
    raise exception 'LEAK D55: admin_search lee tablas privadas'; end if;
end $$;
-- Los bloques siguientes corren con los claims del admin, como antes de este bloque.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);

-- Fin D56 · D55

-- ═════════════ D51 O3 · O7 · F6.13 O2 (CHECK puros, como postgres en mantenimiento para saltar PT423) ═════════════
reset role;
select set_config('guide.draft_op', 'maintenance', true);
do $$
declare
  c_c constant uuid := 'e6130000-0000-4000-8000-000000000005';   -- cookies (legal)
  c_t constant uuid := 'e6130000-0000-4000-8000-000000000002';   -- transparency (no legal)
  v text; v_n int; v_tbl text; v_id uuid;
begin
  -- O3: tope 300000 en body_html_* (el límite exacto entra, uno más da 23514 con el nombre del CHECK)
  foreach v_tbl in array array['articles', 'pages', 'author_reviews'] loop
    execute format('select id from guide.%I order by id limit 1', v_tbl) into v_id;
    if v_id is null then raise exception 'FAIL D51 O3: sin filas en %', v_tbl; end if;
    foreach v in array array['es', 'en'] loop
      if pg_temp.f613_err(format('update guide.%I set body_json_%s = coalesce(body_json_%s, %L), body_html_%s = repeat(%L, 300001) where id = %L',
           v_tbl, v, v, '{"type":"doc"}', v, 'x', v_id)) not like format('23514%%%s_body_html_size%%', v_tbl) then
        raise exception 'FAIL D51 O3: %.body_html_% acepta 300001', v_tbl, v; end if;
    end loop;
    if v_tbl <> 'pages' then
      execute format('update guide.%I set body_json_es = coalesce(body_json_es, %L), body_html_es = repeat(%L, 300000) where id = %L',
        v_tbl, '{"type":"doc"}', 'x', v_id);
      get diagnostics v_n = row_count;
      if v_n <> 1 then raise exception 'FAIL D51 O3: %.body_html_es no acepta 300000', v_tbl; end if;
    end if;
  end loop;
  update guide.pages set body_html_es = '<p>' || repeat('x', 299993) || '</p>' where id = c_t;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL D51 O3: pages no acepta 300000'; end if;
  if not exists (select 1 from pg_constraint where conname = 'page_versions_body_html_size'
                 and conrelid = 'guide.page_versions'::regclass and contype = 'c') then
    raise exception 'FAIL D51 O3: falta page_versions_body_html_size'; end if;

  -- O7: nodos v2 en el JSON de una legal → 23514 (ES y EN)
  foreach v in array array['imageFigure', 'caption', 'table', 'tableRow', 'tableCell', 'tableHeader', 'authorNote'] loop
    if pg_temp.f613_err(format('update guide.pages set body_json_es = %L where id = %L',
         jsonb_build_object('type', 'doc', 'content', jsonb_build_array(jsonb_build_object('type', v))), c_c))
       not like '23514%pages_legal_text_only%'
    or pg_temp.f613_err(format('update guide.pages set body_json_en = %L, body_html_en = %L where id = %L',
         jsonb_build_object('type', 'doc', 'content', jsonb_build_array(jsonb_build_object('type', 'paragraph',
           'content', jsonb_build_array(jsonb_build_object('type', v))))), '<p>x</p>', c_c))
       not like '23514%pages_legal_text_only%' then
      raise exception 'FAIL D51 O7: legal acepta nodo %', v; end if;
  end loop;
  -- …y en una no legal sí entran
  update guide.pages set body_json_es = '{"type":"doc","content":[{"type":"table"},{"type":"authorNote"},{"type":"imageFigure"}]}'
  where id = c_t;

  -- F6.13 O2 (resto): atributos tras «/» o comilla, «>» entre comillas, esquemas con entidades/tabulador, //, vacío
  foreach v in array array['<p/onclick=x>a</p>', '<a href="https://x.com"onclick=y>a</a>', '<a title=">" onclick=x>a</a>',
                           '<p/style="x">a</p>', '<a href="&#106;avascript:x">a</a>', '<a href="javascript&colon;x">a</a>',
                           E'<a href="java\tscript:x">a</a>', '<a href=JAVASCRIPT:x>a</a>', '<a href="//evil.com">a</a>',
                           '<a href="/\evil.com">a</a>', '<a href="">a</a>', '<a href="ftp://x">a</a>', '<a href=x>a</a>',
                           '<a/href="data:x">a</a>'] loop
    if pg_temp.f613_err(format('update guide.pages set body_html_es = %L where id = %L', v, c_c)) not like '23514%pages_legal_text_only%' then
      raise exception 'FAIL D51 F6.13 O2: legal acepta %', v; end if;
  end loop;
  -- …y los enlaces del editor sí entran (https, mailto, ruta, ancla; mayúsculas; sin comillas)
  update guide.pages set body_html_es = '<p><a target="_blank" rel="noopener noreferrer nofollow" href="HTTPS://x.com">a</a> '
    || '<a href=https://x.com>b</a> <a href="mailto:a@b.c">c</a> <a href="/cookies">d</a> <a href=''#s''>e</a> a = 3 on x</p>'
  where id = c_c;
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL D51 F6.13 O2: legal no acepta enlaces válidos'; end if;
end $$;
select set_config('guide.draft_op', '', true);
-- Los bloques siguientes corren con los claims del admin, como antes de este bloque.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin D51 O3 · O7 · F6.13 O2

-- ═════════════ D57: multiautor (guide.authors + articles.author_id) ═════════════
-- Medios b5700000…: 01 con los dos alts; 02 sin alt_en. Artículos d5700000…a1 vivo y a2 borrador.
reset role;
select set_config('guide.draft_op', 'maintenance', true);
insert into storage.objects (bucket_id, name, metadata)
select 'media', format('b5700000-0000-4000-8000-0000000000%s/1-d57.jpg', n), '{"mimetype":"image/jpeg","size":900}'
from unnest(array['01','02']) n;
insert into guide.media (id, storage_path, original_filename, mime_type, size_bytes, width, height, alt_es, alt_en)
select format('b5700000-0000-4000-8000-0000000000%s', n)::uuid, format('b5700000-0000-4000-8000-0000000000%s/1-d57.jpg', n),
       'd57.jpg', 'image/jpeg', 1, 10, 10, 'Retrato ' || n, case when n <> '02' then 'Portrait ' || n end
from unnest(array['01','02']) n;
insert into guide.article_categories (id, name_es, slug_es) values ('d5700000-0000-4000-8000-0000000000c1', 'Cat D57', 'd57-cat');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d5700000-0000-4000-8000-0000000000a1', 'd5700000-0000-4000-8000-0000000000c1', 'published', now() - interval '1 day',
   'Zqxd57 vivo', 'd57-vivo'),
  ('d5700000-0000-4000-8000-0000000000a2', 'd5700000-0000-4000-8000-0000000000c1', 'draft', null, 'Zqxd57 borrador', 'd57-borrador');
select set_config('guide.draft_op', '', true);

-- a. Anon: lee autores (seed «ana») y articles.author_id; no escribe en authors
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if not exists (select 1 from guide.authors where slug = 'ana' and name = 'Ana' and role_es = 'Redactora'
                 and role_en = 'Writer' and has_en and photo_media_id is null) then
    raise exception 'FAIL anon D57: no lee la autora seed ana'; end if;
  perform a.author_id from guide.articles a where a.id = 'd5700000-0000-4000-8000-0000000000a1';
  if not found then raise exception 'FAIL anon D57: no lee el artículo vivo'; end if;
  begin insert into guide.authors (slug, name) values ('rls-d57-anon', 'Hack');
    raise exception 'LEAK anon D57: inserta autor'; exception when insufficient_privilege then null; end;
  begin update guide.authors set name = 'Hack';
    raise exception 'LEAK anon D57: edita autor'; exception when insufficient_privilege then null; end;
  begin delete from guide.authors;
    raise exception 'LEAK anon D57: borra autor'; exception when insufficient_privilege then null; end;
  begin update guide.articles set author_id = null where id = 'd5700000-0000-4000-8000-0000000000a2';
    raise exception 'LEAK anon D57: asigna autor'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- b. No admin: lee; insertar da 42501 y editar/borrar/asignar afecta 0 filas
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  if not exists (select 1 from guide.authors where slug = 'ana') then raise exception 'FAIL user D57: no lee autores'; end if;
  begin insert into guide.authors (slug, name) values ('rls-d57-user', 'Hack');
    raise exception 'LEAK user D57: inserta autor'; exception when insufficient_privilege then null; end;
  update guide.authors set name = 'Hack' where slug = 'ana';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D57: edita autor'; end if;
  delete from guide.authors where slug = 'ana';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D57: borra autor'; end if;
  update guide.articles set author_id = (select id from guide.authors where slug = 'ana')
  where id = 'd5700000-0000-4000-8000-0000000000a2';
  get diagnostics v_n = row_count;
  if v_n <> 0 then raise exception 'LEAK user D57: asigna autor'; end if;
end $$;
reset role;

-- c. Admin: topes y slug (23514), slug único y un solo is_primary (23505), foto con alt es/en (PT422) y «medio en uso»;
--    author_id en directo solo fuera de lo vivo (PT423 en lo vivo), en lo vivo por borrador.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  c_b  constant uuid := 'd5700000-0000-4000-8000-0000000000b1';
  c_a1 constant uuid := 'd5700000-0000-4000-8000-0000000000a1';
  c_a2 constant uuid := 'd5700000-0000-4000-8000-0000000000a2';
  v_j   jsonb;
  v_ver integer;
  v_col text;
  v_sql text;
begin
  foreach v_sql in array array[
    format('insert into guide.authors (slug, name) values (%L, %L)', 'rls-d57-c', ''),
    format('insert into guide.authors (slug, name) values (%L, %L)', 'rls-d57-c', '   '),
    format('insert into guide.authors (slug, name) values (%L, %L)', 'rls-d57-c', repeat('x', 81)),
    format('insert into guide.authors (slug, name, role_en) values (%L, %L, %L)', 'rls-d57-c', 'C', repeat('x', 81)),
    format('insert into guide.authors (slug, name, bio_es) values (%L, %L, %L)', 'rls-d57-c', 'C', repeat('x', 161)),
    format('insert into guide.authors (slug, name, bio_en) values (%L, %L, %L)', 'rls-d57-c', 'C', repeat('x', 161)),
    format('insert into guide.authors (slug, name) values (%L, %L)', 'Mal Slug', 'C')
  ] loop
    begin
      execute v_sql;
      raise exception 'FAIL D57 c: acepta %', v_sql;
    exception when check_violation then null;
    end;
  end loop;
  begin insert into guide.authors (slug, name) values ('ana', 'Otra Ana');
    raise exception 'FAIL D57 c: slug repetido'; exception when unique_violation then null; end;

  insert into guide.authors (id, slug, name, role_es, bio_es, is_primary, sort_order)
  values (c_b, 'rls-d57-b', 'Autora D57', 'Redactora', repeat('x', 160), true, 5);
  if exists (select 1 from guide.authors where id = c_b and has_en) then raise exception 'FAIL D57 c: has_en sin inglés'; end if;
  begin insert into guide.authors (slug, name, is_primary) values ('rls-d57-p', 'Otra principal', true);
    raise exception 'FAIL D57 c: dos is_primary'; exception when unique_violation then null; end;

  -- Foto
  begin
    update guide.authors set photo_media_id = 'b5700000-0000-4000-8000-000000000002' where id = c_b;
    raise exception 'FAIL D57 c: acepta una foto sin alt_en';
  exception when sqlstate 'PT422' then
    get stacked diagnostics v_j = pg_exception_detail;
    if v_j ->> 'entity' <> 'author' or (v_j ->> 'entity_id')::uuid <> c_b
       or v_j -> 'missing' <> '[{"lang":"en","media_id":"b5700000-0000-4000-8000-000000000002"}]'::jsonb then
      raise exception 'FAIL D57 c: details (%)', v_j; end if;
  end;
  update guide.authors set photo_media_id = 'b5700000-0000-4000-8000-000000000001' where id = c_b;
  if not exists (select 1 from guide.media_usages('b5700000-0000-4000-8000-000000000001') u
                 where u.role = 'author' and u.owner_table = 'authors' and u.owner_id = c_b and u.label = 'Autora D57') then
    raise exception 'FAIL D57 c: media_usages no da role author / authors'; end if;
  select m.version into v_ver from guide.media m where m.id = 'b5700000-0000-4000-8000-000000000001';
  begin
    perform guide.delete_media('b5700000-0000-4000-8000-000000000001', v_ver);
    raise exception 'FAIL D57 c: delete_media borra la foto de un autor';
  exception when foreign_key_violation then null;
  end;
  foreach v_col in array array['alt_es', 'alt_en'] loop
    begin
      execute format('update guide.media set %I = %L where id = %L', v_col, '', 'b5700000-0000-4000-8000-000000000001');
      raise exception 'FAIL D57 c: vacía % de la foto de un autor', v_col;
    exception when sqlstate 'PT422' then
      get stacked diagnostics v_j = pg_exception_detail;
      if not (v_j -> 'used_by') @> jsonb_build_array(jsonb_build_object('entity', 'author', 'entity_id', c_b)) then
        raise exception 'FAIL D57 c: used_by de % (%)', v_col, v_j; end if;
    end;
  end loop;

  -- author_id: borrador en directo; vivo → PT423; vivo por save_draft/publish_draft
  update guide.articles set author_id = c_b where id = c_a2;
  if not exists (select 1 from guide.articles where id = c_a2 and author_id = c_b) then
    raise exception 'FAIL D57 c: no asigna autor a un borrador'; end if;
  begin
    update guide.articles set author_id = c_b where id = c_a1;
    raise exception 'FAIL D57 c: cambia author_id de lo vivo en directo';
  exception when sqlstate 'PT423' then null;
  end;
  begin
    perform set_config('guide.draft_op', 'detach_author:' || c_b::text, true);
    update guide.articles set author_id = c_b where id = c_a1;
    raise exception 'FAIL D57 c: detach_author asigna (no solo vacía) en lo vivo';
  exception when sqlstate 'PT423' then null;
  end;
  perform set_config('guide.draft_op', '', true);
  begin
    perform guide.save_draft('article', c_a1, jsonb_build_object('article', jsonb_build_object('author_id', 'x')),
                             guide.draft_entity_version('article', c_a1));
    raise exception 'FAIL D57 c: borrador acepta author_id no uuid';
  exception when invalid_text_representation then null;
  end;
  perform guide.save_draft('article', c_a1, jsonb_build_object('article', jsonb_build_object('author_id', c_b)),
                           guide.draft_entity_version('article', c_a1));
  perform guide.publish_draft('article', c_a1);
  if not exists (select 1 from guide.articles where id = c_a1 and author_id = c_b) then
    raise exception 'FAIL D57 c: publish_draft no aplica author_id'; end if;
  -- borrador pendiente que apunta al autor (para d)
  perform guide.save_draft('article', c_a1, jsonb_build_object('article', jsonb_build_object('author_id', c_b,
                           'title_es', 'Zqxd57 vivo v2')), guide.draft_entity_version('article', c_a1));
end $$;
reset role;

-- Anon: ve author_id del vivo y en search_articles; ve la foto elegida, no la otra
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if not exists (select 1 from guide.articles where id = 'd5700000-0000-4000-8000-0000000000a1'
                 and author_id = 'd5700000-0000-4000-8000-0000000000b1') then
    raise exception 'FAIL anon D57: no ve author_id del artículo vivo'; end if;
  if not exists (select 1 from guide.search_articles('zqxd57', 'es') s
                 where s.id = 'd5700000-0000-4000-8000-0000000000a1' and s.author_id = 'd5700000-0000-4000-8000-0000000000b1') then
    raise exception 'FAIL anon D57: search_articles sin author_id'; end if;
  if exists (select 1 from guide.search_articles('zqxd57', 'es') s where s.id = 'd5700000-0000-4000-8000-0000000000a2') then
    raise exception 'LEAK anon D57: búsqueda devuelve el borrador'; end if;
  if not exists (select 1 from guide.media where id = 'b5700000-0000-4000-8000-000000000001') then
    raise exception 'FAIL anon D57: no ve la foto del autor'; end if;
  if exists (select 1 from guide.media where id = 'b5700000-0000-4000-8000-000000000002') then
    raise exception 'LEAK anon D57: ve un medio no público'; end if;
end $$;
reset role;

-- d. Admin borra el autor: desasigna lo vivo sin PT423 y el borrador, vacía author_id en el payload y restaura draft_op
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v_n integer;
begin
  perform set_config('guide.draft_op', 'rls-d57-prev', true);
  delete from guide.authors where id = 'd5700000-0000-4000-8000-0000000000b1';
  get diagnostics v_n = row_count;
  if v_n <> 1 then raise exception 'FAIL D57 d: el admin no borra el autor (% filas)', v_n; end if;
  if current_setting('guide.draft_op', true) <> 'rls-d57-prev' then
    raise exception 'FAIL D57 d: no restaura draft_op (%)', current_setting('guide.draft_op', true); end if;
  perform set_config('guide.draft_op', '', true);
  if exists (select 1 from guide.articles where id in ('d5700000-0000-4000-8000-0000000000a1',
                                                       'd5700000-0000-4000-8000-0000000000a2') and author_id is not null) then
    raise exception 'FAIL D57 d: los artículos conservan el autor borrado'; end if;
  if not exists (select 1 from guide.content_drafts d where d.article_id = 'd5700000-0000-4000-8000-0000000000a1'
                 and d.payload -> 'article' -> 'author_id' = 'null'::jsonb
                 and d.payload -> 'article' ->> 'title_es' = 'Zqxd57 vivo v2') then
    raise exception 'FAIL D57 d: el borrador conserva author_id o pierde el resto'; end if;
  if exists (select 1 from guide.media_usage where media_id = 'b5700000-0000-4000-8000-000000000001') then
    raise exception 'FAIL D57 d: la foto sigue en uso tras borrar el autor'; end if;
end $$;
reset role;

-- e. Catálogo: export_articles lleva author_id y author_name y ningún rol de la API la lee
do $$
begin
  if (select count(*) from pg_attribute where attrelid = 'guide.export_articles'::regclass
      and attname in ('author_id', 'author_name') and not attisdropped) <> 2 then
    raise exception 'FAIL D57 e: export_articles sin author_id/author_name'; end if;
  if has_table_privilege('anon', 'guide.export_articles', 'select')
     or has_table_privilege('authenticated', 'guide.export_articles', 'select') then
    raise exception 'LEAK D57 e: export_articles legible por la API'; end if;
  if not (select c.relrowsecurity from pg_class c where c.oid = 'guide.authors'::regclass) then
    raise exception 'FAIL D57 e: authors sin RLS'; end if;
end $$;
-- Los bloques siguientes corren con los claims del admin, como antes de este bloque.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin D57

-- Horarios: cierre a medianoche ('24:00' solo como cierre, sin tramos que crucen la medianoche)
do $$
begin
  if not guide.opening_hours_valid('{"mon":[["07:00","24:00"]]}') then
    raise exception 'FAIL hours: 24:00 no vale como cierre'; end if;
  if guide.opening_hours_valid('{"mon":[["24:00","24:00"]]}') then
    raise exception 'FAIL hours: 24:00-24:00 vale'; end if;
  if guide.opening_hours_valid('{"mon":[["24:00","23:00"]]}') then
    raise exception 'FAIL hours: 24:00 vale como apertura'; end if;
  if not guide.opening_hours_valid('{"mon":[["23:00","24:00"]]}') then
    raise exception 'FAIL hours: 23:00-24:00 no vale'; end if;
  if guide.opening_hours_valid('{"mon":[["10:00","25:00"]]}') or guide.opening_hours_valid('{"mon":[["25:00","26:00"]]}') then
    raise exception 'FAIL hours: 25:00 vale'; end if;
  if guide.opening_hours_valid('{"mon":[["10:00","24:01"]]}') or guide.opening_hours_valid('{"mon":[["10:00","24:30"]]}') then
    raise exception 'FAIL hours: 24:xx distinto de 24:00 vale'; end if;
  if guide.opening_hours_valid('{"mon":[["22:00","02:00"]]}') then
    raise exception 'FAIL hours: tramo que cruza la medianoche vale'; end if;
end $$;

-- ═════════════ F6.17: Ajustes (una sola fila, redes https, topes, admin_update_settings, admin_my_sessions) ═════════════
-- Fixture (postgres): dos sesiones del admin y una de user1 en auth.sessions (el ROLLBACK final las descarta).
insert into auth.sessions (id, user_id, created_at, updated_at, user_agent, ip) values
  ('f6170000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', now() - interval '2 hours', now(), 'RLS Mac', '10.0.0.1'),
  ('f6170000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', now() - interval '1 day', now() - interval '2 hours', 'RLS iPhone', '10.0.0.2'),
  ('f6170000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', now(), now(), 'RLS User', '10.0.0.3');

-- a. anon: sin EXECUTE en las RPC nuevas
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.admin_update_settings('{"site_name":"hack"}', '{"site_name":"ChalkGuide"}');
    raise exception 'LEAK anon F6.17: ejecuta admin_update_settings'; exception when insufficient_privilege then null; end;
  begin perform * from guide.admin_my_sessions();
    raise exception 'LEAK anon F6.17: ejecuta admin_my_sessions'; exception when insufficient_privilege then null; end;
  begin insert into guide.site_settings (id) values (2);
    raise exception 'LEAK anon F6.17: inserta ajustes'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- b. No admin: 42501 en las RPC; ni alta ni borrado de ajustes
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated","session_id":"f6170000-0000-4000-8000-000000000003"}', true);
do $$
declare v_name text := (select site_name from guide.site_settings where id = 1);
begin
  begin perform guide.admin_update_settings(jsonb_build_object('site_name', 'hack'), jsonb_build_object('site_name', v_name));
    raise exception 'LEAK user F6.17: admin_update_settings'; exception when insufficient_privilege then null; end;
  begin perform * from guide.admin_my_sessions();
    raise exception 'LEAK user F6.17: admin_my_sessions'; exception when insufficient_privilege then null; end;
  begin insert into guide.site_settings (id) values (2);
    raise exception 'LEAK user F6.17: inserta ajustes'; exception when insufficient_privilege then null; end;
  begin delete from guide.site_settings;
    raise exception 'LEAK user F6.17: borra ajustes'; exception when insufficient_privilege then null; end;
  if (select site_name from guide.site_settings where id = 1) is distinct from v_name then
    raise exception 'LEAK user F6.17: cambia site_name'; end if;
end $$;
reset role;

-- c. Admin: una sola fila, redes https, topes, RPC (claves, base, vacíos, conflicto, todo o nada, consentimiento), sesiones
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated","session_id":"f6170000-0000-4000-8000-000000000001"}', true);
do $$
declare
  v_row  guide.site_settings;
  v_ver  integer;
  v_ctid tid;
  v_d    text;
  v_sql  text;
  v_n    integer;
  v_j    jsonb;
begin
  -- Una sola fila: sin INSERT ni DELETE para la API, ni siquiera el admin
  begin insert into guide.site_settings (id) values (2);
    raise exception 'FAIL F6.17 c: el admin crea otra fila de ajustes'; exception when insufficient_privilege then null; end;
  begin delete from guide.site_settings where id = 1;
    raise exception 'FAIL F6.17 c: el admin borra los ajustes'; exception when insufficient_privilege then null; end;
  begin update guide.site_settings set id = 2 where id = 1;
    raise exception 'FAIL F6.17 c: cambia el id de la fila'; exception when check_violation then null; end;
  if (select count(*) from guide.site_settings) <> 1 then raise exception 'FAIL F6.17 c: site_settings no tiene una sola fila'; end if;

  -- Redes: solo https con host, claves acotadas, máximo 8
  foreach v_sql in array array[
    '{"youtube":"youtube.com/@chalkguide"}', '{"instagram":"http://instagram.com/x"}', '{"x":"javascript:alert(1)"}',
    '{"instagram":"https://evil.com@instagram.com"}', '{"instagram":"https://instagram.com/a b"}',
    '{"instagram":"https://instagram.com/\"><script>"}', '{"instagram":"https://localhost"}', '{"instagram":5}',
    '{"instagram":""}', '{"Bad-Key":"https://a.com"}', '[]',
    '{"a1":"https://a.com","a2":"https://a.com","a3":"https://a.com","a4":"https://a.com","a5":"https://a.com","a6":"https://a.com","a7":"https://a.com","a8":"https://a.com","a9":"https://a.com"}'
  ] loop
    begin
      update guide.site_settings set social_links = v_sql::jsonb where id = 1;
      raise exception 'FAIL F6.17 c: social_links acepta %', v_sql;
    exception when check_violation then null;
    end;
  end loop;
  update guide.site_settings set social_links = '{"instagram":"https://instagram.com/chalkguide","youtube":"https://www.youtube.com/@chalkguide?si=1"}'
  where id = 1;
  update guide.site_settings set social_links = '{}' where id = 1;

  -- Topes
  select consent_version into v_ver from guide.site_settings where id = 1;
  foreach v_sql in array array[
    format('update guide.site_settings set footer_text_es = %L where id = 1', repeat('x', 301)),
    format('update guide.site_settings set footer_text_en = %L where id = 1', repeat('x', 301)),
    format('update guide.site_settings set newsletter_title_es = %L where id = 1', repeat('x', 121)),
    format('update guide.site_settings set newsletter_title_en = %L where id = 1', repeat('x', 121)),
    format('update guide.site_settings set newsletter_body_es = %L where id = 1', repeat('x', 401)),
    format('update guide.site_settings set newsletter_body_en = %L where id = 1', repeat('x', 401)),
    format('update guide.site_settings set contact_email = %L where id = 1', repeat('x', 250) || '@a.com'),
    format('update guide.site_settings set newsletter_consent_text_es = %L, consent_version = %s where id = 1', '   ', v_ver + 1),
    format('update guide.site_settings set newsletter_consent_text_en = %L, consent_version = %s where id = 1', repeat('x', 2001), v_ver + 1)
  ] loop
    begin
      execute v_sql;
      raise exception 'FAIL F6.17 c: acepta %', left(v_sql, 90);
    exception when check_violation then null;
    end;
  end loop;

  -- RPC: claves bloqueadas o desconocidas y base incompleta → 22023
  foreach v_sql in array array['{"id":2}', '{"updated_at":"2020-01-01"}', '{"consent_version":99}', '{"nope":1}'] loop
    begin
      perform guide.admin_update_settings(v_sql::jsonb, v_sql::jsonb);
      raise exception 'FAIL F6.17 c: admin_update_settings acepta %', v_sql;
    exception when invalid_parameter_value then null;
    end;
  end loop;
  begin perform guide.admin_update_settings('{"site_name":"X"}', '{}');
    raise exception 'FAIL F6.17 c: acepta cambios sin base'; exception when invalid_parameter_value then null; end;
  begin perform guide.admin_update_settings('[]', '{}');
    raise exception 'FAIL F6.17 c: acepta un payload que no es objeto'; exception when invalid_parameter_value then null; end;

  -- Guardado normal: '' en un texto opcional se guarda como null
  update guide.site_settings set site_name = 'RLS F617', tagline_en = 'Old en', footer_text_es = 'Pie viejo' where id = 1;
  v_row := guide.admin_update_settings(
    '{"site_name":"RLS F617 nuevo","tagline_en":"  ","footer_text_es":"Pie nuevo"}',
    '{"site_name":"RLS F617","tagline_en":"Old en","footer_text_es":"Pie viejo"}');
  if v_row.site_name <> 'RLS F617 nuevo' or v_row.tagline_en is not null or v_row.footer_text_es <> 'Pie nuevo' then
    raise exception 'FAIL F6.17 c: admin_update_settings no guarda (%, %, %)', v_row.site_name, v_row.tagline_en, v_row.footer_text_es; end if;
  -- site_name es obligatorio: '' no pasa a null, lo para el CHECK
  begin perform guide.admin_update_settings('{"site_name":""}', '{"site_name":"RLS F617 nuevo"}');
    raise exception 'FAIL F6.17 c: vacía site_name'; exception when check_violation then null; end;

  -- Conflicto: otra pestaña cambió site_name → PT409 con la clave y el valor vigente; no se escribe nada (ni el pie)
  update guide.site_settings set site_name = 'Otra pestaña' where id = 1;
  begin
    perform guide.admin_update_settings('{"site_name":"Mío","footer_text_es":"Pie mío"}',
                                        '{"site_name":"RLS F617 nuevo","footer_text_es":"Pie nuevo"}');
    raise exception 'FAIL F6.17 c: no detecta el conflicto';
  exception when sqlstate 'PT409' then
    get stacked diagnostics v_d = pg_exception_detail;
    v_j := v_d::jsonb;
    if v_j -> 'keys' <> '["site_name"]'::jsonb or v_j #>> '{current,site_name}' <> 'Otra pestaña' or not (v_j ? 'updated_at') then
      raise exception 'FAIL F6.17 c: detail del conflicto (%)', v_d; end if;
  end;
  if (select footer_text_es from guide.site_settings where id = 1) <> 'Pie nuevo' then
    raise exception 'FAIL F6.17 c: el conflicto escribe a medias'; end if;
  -- Una columna ajena cambiada en otra pestaña no es conflicto
  update guide.site_settings set min_user_reviews_for_average = 4 where id = 1;
  v_row := guide.admin_update_settings('{"footer_text_es":"Pie mío"}', '{"footer_text_es":"Pie nuevo"}');
  if v_row.footer_text_es <> 'Pie mío' or v_row.min_user_reviews_for_average <> 4 then
    raise exception 'FAIL F6.17 c: falso conflicto o pisa otra columna'; end if;

  -- Todo o nada: un campo inválido tumba el resto
  begin
    perform guide.admin_update_settings(
      jsonb_build_object('site_name', 'No debe quedar', 'footer_text_en', repeat('x', 301)),
      jsonb_build_object('site_name', 'Otra pestaña',
                         'footer_text_en', (select footer_text_en from guide.site_settings where id = 1)));
    raise exception 'FAIL F6.17 c: guarda con un campo inválido';
  exception when check_violation then null;
  end;
  if (select site_name from guide.site_settings where id = 1) <> 'Otra pestaña' then
    raise exception 'FAIL F6.17 c: guardado parcial'; end if;
  begin
    perform guide.admin_update_settings('{"social_links":{"youtube":"youtube.com/@x"}}', '{"social_links":{}}');
    raise exception 'FAIL F6.17 c: la RPC acepta una red sin https';
  exception when check_violation then null;
  end;

  -- Sin cambios reales: no escribe (now() es fijo en la transacción, así que se mira el ctid de la fila)
  select ctid, consent_version into v_ctid, v_ver from guide.site_settings where id = 1;
  v_row := guide.admin_update_settings('{"site_name":"Otra pestaña"}', '{"site_name":"Otra pestaña"}');
  if (select ctid from guide.site_settings where id = 1) <> v_ctid then raise exception 'FAIL F6.17 c: escribe sin cambios'; end if;

  -- Consentimiento: cambiar el en sube la versión en 1, cierra la vigente y crea la nueva; el es se conserva
  v_row := guide.admin_update_settings(
    jsonb_build_object('newsletter_consent_text_en', 'RLS F617 consent en'),
    jsonb_build_object('newsletter_consent_text_en', (select newsletter_consent_text_en from guide.site_settings where id = 1)));
  if v_row.consent_version <> v_ver + 1 then raise exception 'FAIL F6.17 c: no sube consent_version'; end if;
  if not exists (select 1 from guide.consent_texts where version = v_ver + 1 and valid_to is null
                 and text_en = 'RLS F617 consent en' and text_es = v_row.newsletter_consent_text_es)
     or not exists (select 1 from guide.consent_texts where version = v_ver and valid_to is not null) then
    raise exception 'FAIL F6.17 c: la versión nueva no queda en consent_texts'; end if;
  -- Vaciar el en también es versión nueva (null en consent_texts: /en muestra el es)
  v_row := guide.admin_update_settings('{"newsletter_consent_text_en":""}', '{"newsletter_consent_text_en":"RLS F617 consent en"}');
  if v_row.consent_version <> v_ver + 2 or v_row.newsletter_consent_text_en is not null
     or not exists (select 1 from guide.consent_texts where version = v_ver + 2 and text_en is null and valid_to is null) then
    raise exception 'FAIL F6.17 c: vaciar el en no versiona'; end if;
  -- es en blanco: CHECK, sin versión nueva
  begin perform guide.admin_update_settings('{"newsletter_consent_text_es":"  "}',
          jsonb_build_object('newsletter_consent_text_es', v_row.newsletter_consent_text_es));
    raise exception 'FAIL F6.17 c: acepta el consentimiento es en blanco'; exception when check_violation then null; end;
  if (select max(version) from guide.consent_texts) <> v_ver + 2 then raise exception 'FAIL F6.17 c: versión huérfana'; end if;

  -- Sesiones: solo las propias, la actual marcada y primero, sin IP ni id
  select count(*) into v_n from guide.admin_my_sessions() s where s.user_agent like 'RLS %';
  if v_n <> 2 then raise exception 'FAIL F6.17 c: admin_my_sessions devuelve % sesiones de prueba', v_n; end if;
  if exists (select 1 from guide.admin_my_sessions() s where s.user_agent = 'RLS User') then
    raise exception 'LEAK F6.17 c: admin_my_sessions muestra sesiones de otro usuario'; end if;
  if (select s.user_agent from guide.admin_my_sessions() s limit 1) <> 'RLS Mac'
     or not (select s.is_current from guide.admin_my_sessions() s where s.user_agent = 'RLS Mac')
     or (select s.is_current from guide.admin_my_sessions() s where s.user_agent = 'RLS iPhone') then
    raise exception 'FAIL F6.17 c: sesión actual mal marcada u ordenada'; end if;
end $$;
reset role;

-- d. Catálogo: firma de admin_my_sessions sin ip ni id; DEFINER con search_path vacío; RPC de guardado INVOKER
do $$
begin
  if exists (select 1 from pg_proc p cross join lateral unnest(p.proargnames) a(n)
             where p.oid = 'guide.admin_my_sessions()'::regprocedure and a.n in ('ip', 'id', 'session_id', 'user_id')) then
    raise exception 'LEAK F6.17 d: admin_my_sessions expone ip o ids'; end if;
  if not (select p.prosecdef and p.proconfig @> array['search_path=""'] from pg_proc p
          where p.oid = 'guide.admin_my_sessions()'::regprocedure) then
    raise exception 'FAIL F6.17 d: admin_my_sessions sin DEFINER o search_path'; end if;
  if (select p.prosecdef from pg_proc p where p.oid = 'guide.admin_update_settings(jsonb, jsonb)'::regprocedure) then
    raise exception 'FAIL F6.17 d: admin_update_settings no es INVOKER'; end if;
  if has_table_privilege('authenticated', 'guide.site_settings', 'insert')
     or has_table_privilege('authenticated', 'guide.site_settings', 'delete')
     or has_table_privilege('anon', 'guide.site_settings', 'update') then
    raise exception 'LEAK F6.17 d: GRANT de alta/borrado en site_settings'; end if;
end $$;
-- Los bloques siguientes corren con los claims del admin, como antes de este bloque.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin F6.17

-- ═════════════ F6.18 · Actividad (admin_activity_list) y F6.16 · Estadísticas (admin_stats) ═════════════
-- Fixtures (como postgres): líneas del registro de tablas privadas con datos que no deben salir.
reset role;
insert into guide.activity_log (occurred_at, actor_id, action, entity_table, entity_id, entity_label, details, old_row)
values
  (now() - interval '3 minutes', null, 'update', 'subscribers', 'e1800000-0000-4000-8000-000000000001', 'rls-leak@chalkguide.test',
   '{"from":"pending","to":"active","by":"person","email":"rls-leak@chalkguide.test","note":"secreto"}', '{"email":"rls-leak@chalkguide.test"}'),
  (now() - interval '2 minutes', 'a0000000-0000-4000-8000-000000000001', 'insert', 'admins', 'a0000000-0000-4000-8000-000000000001',
   'rls-admin@chalkguide.test', null, null),
  (now() - interval '1 minute', null, 'update', 'user_reviews', 'e1800000-0000-4000-8000-000000000002', 'Ficha RLS',
   '{"from":"visible","to":"hidden","by":"admin","user_id":"a0000000-0000-4000-8000-000000000002","body":"texto del lector"}', null);

-- a. anon: sin EXECUTE en las RPC ni en los helpers
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare v_f text;
begin
  foreach v_f in array array[
    'select guide.admin_activity_list()', 'select guide.admin_stats()',
    'select guide.admin_stats(''12m'', ''day'', current_date - 10, current_date - 1)',
    'select guide.activity_target(''articles'', ''x'', null, false, null)',
    'select guide.activity_safe_label(''admins'', ''x'')', 'select guide.activity_safe_details(''admins'', ''{}'')'] loop
    begin
      execute v_f;
      raise exception 'LEAK F6.18 a: anon ejecuta %', v_f;
    exception when insufficient_privilege then null;
    end;
  end loop;
end $$;
reset role;

-- b. authenticated no admin: 42501 en las dos RPC
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  begin perform guide.admin_activity_list(); raise exception 'LEAK F6.18 b: no admin lee la actividad';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_stats('30d', 'day'); raise exception 'LEAK F6.18 b: no admin lee estadísticas';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_stats(p_granularity => 'day', p_from => current_date - 10, p_to => current_date - 1);
    raise exception 'LEAK F6.18 b: no admin lee estadísticas con rango personalizado';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- c. admin: saneado, paginación, filtros y validación
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_r   jsonb;
  v_e   jsonb;
  v_ids bigint[] := '{}';
  v_cur jsonb;
  v_i   integer := 0;
  v_s   text;
begin
  v_r := guide.admin_activity_list(p_from => now() - interval '10 minutes', p_limit => 100);
  for v_e in select * from jsonb_array_elements(v_r -> 'entries') loop
    if v_e ? 'old_row' or v_e ? 'actor_id' then
      raise exception 'LEAK F6.18 c: la lista devuelve old_row o actor_id'; end if;
    if v_e ->> 'entity_table' in ('subscribers', 'admins') and v_e ->> 'label' is not null then
      raise exception 'LEAK F6.18 c: etiqueta de % visible', v_e ->> 'entity_table'; end if;
    if v_e ->> 'entity_table' = 'admins' and v_e ->> 'entity_id' is not null then
      raise exception 'LEAK F6.18 c: entity_id de admins visible'; end if;
    if v_e ->> 'entity_table' in ('subscribers', 'user_reviews')
       and (v_e -> 'details' ?| array['email', 'note', 'user_id', 'body']) then
      raise exception 'LEAK F6.18 c: details privados en %', v_e ->> 'entity_table'; end if;
    if v_e::text like '%rls-leak@%' or v_e::text like '%texto del lector%' then
      raise exception 'LEAK F6.18 c: dato personal en la salida'; end if;
  end loop;
  if (v_r -> 'counts' ->> 'mod')::int < 1 or (v_r -> 'counts' ->> 'sys')::int < 2 then
    raise exception 'FAIL F6.18 c: recuentos por pestaña (%)', v_r -> 'counts'; end if;
  if (select (e ->> 'group') from jsonb_array_elements(v_r -> 'entries') e where e ->> 'entity_table' = 'user_reviews'
      and e ->> 'entity_id' = 'e1800000-0000-4000-8000-000000000002') <> 'mod' then
    raise exception 'FAIL F6.18 c: opinión fuera de Moderación'; end if;

  -- Búsqueda: el email de details/old_row no es buscable (solo el email actual de subscribers, exacto)
  if (guide.admin_activity_list(p_search => 'rls-leak@chalkguide.test') -> 'counts' ->> 'all')::int <> 0 then
    raise exception 'LEAK F6.18 c: se encuentra por un email guardado en el registro'; end if;
  if (guide.admin_activity_list(p_search => '%%') -> 'counts' ->> 'all')::int <> 0 then
    raise exception 'FAIL F6.18 c: comodines sin escapar en la búsqueda'; end if;

  -- Cursor: páginas de 2 sin repetir ni perder
  loop
    v_r := guide.admin_activity_list(p_from => now() - interval '10 minutes', p_limit => 2,
             p_cursor_at => (v_cur ->> 'occurred_at')::timestamptz, p_cursor_id => (v_cur ->> 'id')::bigint);
    v_ids := v_ids || array(select (e ->> 'id')::bigint from jsonb_array_elements(v_r -> 'entries') e);
    v_cur := v_r -> 'next_cursor';
    v_i := v_i + 1;
    -- Tope alto: la suite completa (F8 incluida) deja más de 400 entradas en el registro dentro de la transacción.
    exit when jsonb_typeof(v_cur) is distinct from 'object' or v_i > 5000;
  end loop;
  if cardinality(v_ids) <> (select count(distinct x) from unnest(v_ids) x)
     or cardinality(v_ids) <> (guide.admin_activity_list(p_from => now() - interval '10 minutes') -> 'counts' ->> 'all')::int then
    raise exception 'FAIL F6.18 c: paginación por cursor repite o pierde filas (% ids, % distintos, % total, % páginas)',
      cardinality(v_ids), (select count(distinct x) from unnest(v_ids) x),
      (guide.admin_activity_list(p_from => now() - interval '10 minutes') -> 'counts' ->> 'all'), v_i; end if;

  -- Validación de parámetros
  foreach v_s in array array[
    'select guide.admin_activity_list(p_limit => 0)', 'select guide.admin_activity_list(p_limit => 101)',
    'select guide.admin_activity_list(p_group => ''x'')', 'select guide.admin_activity_list(p_actor => ''root'')',
    'select guide.admin_activity_list(p_entities => array[''Bad;'' ])', 'select guide.admin_activity_list(p_actions => array[''drop''])',
    'select guide.admin_activity_list(p_cursor_at => now())', 'select guide.admin_activity_list(p_search => ''a'')',
    'select guide.admin_activity_list(p_from => now(), p_to => now() - interval ''1 day'')',
    'select guide.admin_stats(''30d'', ''month'')', 'select guide.admin_stats(''12m'', ''day'')',
    'select guide.admin_stats(''24m'', ''month'')', 'select guide.admin_stats(null, null)'] loop
    begin
      execute v_s;
      raise exception 'FAIL F6.18 c: acepta %', v_s;
    exception when invalid_parameter_value then null;
    end;
  end loop;

  -- Dashboard: recent_activity con el mismo saneado
  for v_e in select * from jsonb_array_elements(guide.admin_dashboard_stats() -> 'recent_activity') loop
    if v_e ? 'old_row' or v_e ? 'actor_id' then raise exception 'LEAK F6.18 c: recent_activity con old_row o actor_id'; end if;
    if v_e ->> 'entity_table' in ('subscribers', 'admins') and v_e ->> 'entity_label' is not null then
      raise exception 'LEAK F6.18 c: recent_activity con etiqueta privada'; end if;
    if v_e::text like '%rls-leak@%' or v_e::text like '%texto del lector%' then
      raise exception 'LEAK F6.18 c: recent_activity con dato personal'; end if;
  end loop;
end $$;

-- d. admin_stats: forma del contrato (§16.8), solo recuentos, subs_total coherente
do $$
declare
  v_r    jsonb;
  v_e    jsonb;
  v_keys text[] := array['bucket_start', 'bucket_end', 'partial', 'subs_in', 'subs_out', 'subs_total',
                         'articles_published', 'reviews_visible', 'reviews_hidden'];
  v_g    text[];
  v_n    int[] := array[30, 0, 52, 12];
  v_k    int := 0;
begin
  foreach v_g slice 1 in array array[['30d', 'day'], ['30d', 'week'], ['12m', 'week'], ['12m', 'month']] loop
    v_k := v_k + 1;
    v_r := guide.admin_stats(v_g[1], v_g[2]);
    if v_n[v_k] > 0 and jsonb_array_length(v_r -> 'series') <> v_n[v_k] then
      raise exception 'FAIL F6.16 d: % / % da % periodos', v_g[1], v_g[2], jsonb_array_length(v_r -> 'series'); end if;
    for v_e in select * from jsonb_array_elements(v_r -> 'series') loop
      if (select array_agg(k order by k) from jsonb_object_keys(v_e) k) <> (select array_agg(k order by k) from unnest(v_keys) k) then
        raise exception 'FAIL F6.16 d: claves del periodo %', v_e; end if;
    end loop;
    if not ((v_r -> 'series' -> -1 ->> 'partial')::boolean) then
      raise exception 'FAIL F6.16 d: el periodo actual no sale como parcial'; end if;
    if (v_r -> 'series' -> -1 ->> 'subs_total')::bigint <> (select count(*) from guide.subscribers where status = 'active') then
      raise exception 'FAIL F6.16 d: subs_total actual distinto de los activos'; end if;
    if not (v_r ? 'items_published' and v_r ? 'items_new_in_range' and v_r ? 'articles_published_total') then
      raise exception 'FAIL F6.16 d: faltan los totales aparte'; end if;
    if v_r::text ~ '@' then raise exception 'LEAK F6.16 d: email en la salida'; end if;
  end loop;
end $$;

-- d2. admin_stats: rango personalizado (validación 22023) y comparación con el periodo anterior
do $$
declare
  v_today date := (now() at time zone 'Europe/Madrid')::date;
  v_cut   date := ((now() at time zone 'Europe/Madrid') - interval '24 months')::date;  -- purga de activity_log
  v_r     jsonb;
  v_c     jsonb;
  v_p     jsonb;
  v_keys  text[] := array['from', 'to', 'subs_in', 'subs_out', 'subs_total_end', 'articles_published',
                          'reviews_visible', 'reviews_hidden', 'items_new_in_range'];
  v_g     text[];
  v_s     text;
begin
  if to_regprocedure('guide.admin_stats(text, text)') is not null then
    raise exception 'FAIL F6.16 d2: sigue la firma vieja admin_stats(text, text)'; end if;

  -- Inválidos: uno solo, from > to, futuro, antes del corte de 24 meses, granularidad que no encaja con la duración
  foreach v_s in array array[
    format('select guide.admin_stats(''30d'', ''day'', %L::date, null)', v_today - 5),
    format('select guide.admin_stats(''30d'', ''day'', null, %L::date)', v_today - 5),
    format('select guide.admin_stats(''30d'', ''day'', %L::date, %L::date)', v_today - 1, v_today - 2),
    format('select guide.admin_stats(''30d'', ''day'', %L::date, %L::date)', v_today - 2, v_today + 1),
    format('select guide.admin_stats(''30d'', ''month'', %L::date, %L::date)', v_cut - 1, v_today),
    format('select guide.admin_stats(''30d'', ''day'', %L::date, %L::date)', v_cut - 1, v_cut + 5),
    format('select guide.admin_stats(''30d'', ''month'', %L::date, %L::date)', v_today - 30, v_today),
    format('select guide.admin_stats(''30d'', ''day'', %L::date, %L::date)', v_today - 62, v_today),
    format('select guide.admin_stats(''30d'', ''week'', %L::date, %L::date)', v_cut - 1, v_today),
    format('select guide.admin_stats(''30d'', ''day'', %L::date, %L::date)', v_today - 100, v_today - 10),
    format('select guide.admin_stats(''30d'', ''year'', %L::date, %L::date)', v_today - 5, v_today)] loop
    begin
      execute v_s;
      raise exception 'FAIL F6.16 d2: acepta %', v_s;
    exception when invalid_parameter_value then null;
    end;
  end loop;

  -- Válidos en los límites de cada tramo: [from, to, granularidad, periodos esperados (0 = no se comprueba),
  -- previous esperado: obj | null (null si su inicio cae antes del corte de 24 meses)]
  foreach v_g slice 1 in array array[
    [(v_today - 61)::text, v_today::text, 'day', '62', 'obj'],
    [(v_today - 61)::text, v_today::text, 'week', '0', 'obj'],
    [(v_today - 62)::text, (v_today - 1)::text, 'week', '0', 'obj'],
    [(v_today - 200)::text, (v_today - 100)::text, 'month', '0', 'obj'],
    [v_cut::text, v_today::text, 'week', '0', 'null'],
    [v_cut::text, v_today::text, 'month', '0', 'null'],
    [(v_cut + 10)::text, (v_cut + 19)::text, 'day', '10', 'obj'],
    [(v_cut + 10)::text, (v_cut + 20)::text, 'day', '11', 'null'],
    [(v_today - 9)::text, (v_today - 3)::text, 'day', '7', 'obj']] loop
    -- p_range 'xx' a propósito: con p_from/p_to manda el rango personalizado
    v_r := guide.admin_stats('xx', v_g[3], v_g[1]::date, v_g[2]::date);
    if v_r ->> 'range' <> 'custom' or v_r ->> 'from' <> v_g[1] or v_r ->> 'to' <> v_g[2] then
      raise exception 'FAIL F6.16 d2: rango personalizado % / % / % da % – %', v_g[1], v_g[2], v_g[3], v_r ->> 'from', v_r ->> 'to'; end if;
    if v_g[4] <> '0' and jsonb_array_length(v_r -> 'series') <> v_g[4]::int then
      raise exception 'FAIL F6.16 d2: % periodos en lugar de %', jsonb_array_length(v_r -> 'series'), v_g[4]; end if;
    if v_r -> 'series' -> 0 ->> 'bucket_start' <> v_g[1] or v_r -> 'series' -> -1 ->> 'bucket_end' <> v_g[2] then
      raise exception 'FAIL F6.16 d2: la serie no cubre el rango (%)', v_g; end if;
    if not (v_r ? 'items_published' and v_r ? 'items_new_in_range' and v_r ? 'articles_published_total') then
      raise exception 'FAIL F6.16 d2: faltan los totales aparte'; end if;

    v_c := v_r -> 'current_totals';
    v_p := v_r -> 'previous';
    if not (v_r ? 'previous') or jsonb_typeof(v_p) <> replace(v_g[5], 'obj', 'object') then
      raise exception 'FAIL F6.16 d2: previous de % – % debería ser %, es %', v_g[1], v_g[2], v_g[5], v_p; end if;
    if (select array_agg(k order by k) from jsonb_object_keys(v_c) k) <> (select array_agg(k order by k) from unnest(v_keys) k) then
      raise exception 'FAIL F6.16 d2: claves de current_totals'; end if;
    if v_c ->> 'from' <> v_g[1] or v_c ->> 'to' <> v_g[2] then
      raise exception 'FAIL F6.16 d2: current_totals con otro rango'; end if;
    if v_g[5] = 'obj' then
      if (select array_agg(k order by k) from jsonb_object_keys(v_p) k) <> (select array_agg(k order by k) from unnest(v_keys) k) then
        raise exception 'FAIL F6.16 d2: claves de previous'; end if;
      -- previous: inmediatamente anterior, con la misma duración y sin pasar del corte
      if (v_p ->> 'from')::date < v_cut or (v_p ->> 'to')::date <> (v_c ->> 'from')::date - 1
         or (v_p ->> 'to')::date - (v_p ->> 'from')::date <> (v_c ->> 'to')::date - (v_c ->> 'from')::date then
        raise exception 'FAIL F6.16 d2: previous % – % no es el anterior de % – %', v_p ->> 'from', v_p ->> 'to', v_c ->> 'from', v_c ->> 'to'; end if;
    end if;
    -- current_totals coherente con la serie
    if (v_c ->> 'subs_in')::bigint <> (select coalesce(sum((e ->> 'subs_in')::bigint), 0) from jsonb_array_elements(v_r -> 'series') e)
       or (v_c ->> 'articles_published')::bigint <> (select coalesce(sum((e ->> 'articles_published')::bigint), 0) from jsonb_array_elements(v_r -> 'series') e)
       or (v_c ->> 'reviews_visible')::bigint <> (select coalesce(sum((e ->> 'reviews_visible')::bigint), 0) from jsonb_array_elements(v_r -> 'series') e)
       or (v_c ->> 'subs_total_end')::bigint <> (v_r -> 'series' -> -1 ->> 'subs_total')::bigint
       or v_c -> 'items_new_in_range' <> v_r -> 'items_new_in_range' then
      raise exception 'FAIL F6.16 d2: current_totals no cuadra con la serie'; end if;
    -- saldo de suscriptores: el cierre anterior + altas - bajas = el cierre actual
    if v_g[5] = 'obj' and (v_p ->> 'subs_total_end')::bigint + (v_c ->> 'subs_in')::bigint - (v_c ->> 'subs_out')::bigint
       <> (v_c ->> 'subs_total_end')::bigint then
      raise exception 'FAIL F6.16 d2: saldo de suscriptores incoherente entre previous y current_totals'; end if;
    if v_r::text ~ '@' then raise exception 'LEAK F6.16 d2: email en la salida'; end if;
  end loop;

  -- Rangos predefinidos: también traen previous de la misma duración
  v_r := guide.admin_stats('30d', 'day');
  if v_r -> 'previous' ->> 'from' <> (v_today - 59)::text or v_r -> 'previous' ->> 'to' <> (v_today - 30)::text
     or (v_r -> 'current_totals' ->> 'subs_total_end')::bigint <> (select count(*) from guide.subscribers where status = 'active') then
    raise exception 'FAIL F6.16 d2: previous/current_totals de 30d'; end if;
  if jsonb_typeof(guide.admin_stats('12m', 'month') -> 'previous') <> 'object'
     or (guide.admin_stats('12m', 'week') -> 'previous' ->> 'from')::date < v_cut then
    raise exception 'FAIL F6.16 d2: previous de 12m'; end if;
end $$;

-- e. Catálogo: INVOKER con search_path vacío; sin EXECUTE de anon ni service_role
do $$
declare v_p regprocedure;
begin
  foreach v_p in array array[
    'guide.admin_activity_list(text, text[], text[], text, timestamptz, timestamptz, text, integer, timestamptz, bigint)'::regprocedure,
    'guide.admin_stats(text, text, date, date)'::regprocedure,
    'guide.activity_target(text, text, uuid, boolean, text)'::regprocedure] loop
    if (select p.prosecdef or not coalesce(p.proconfig @> array['search_path=""'], false) from pg_proc p where p.oid = v_p) then
      raise exception 'FAIL F6.18 e: % no es INVOKER con search_path vacío', v_p; end if;
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('service_role', v_p, 'execute') then
      raise exception 'LEAK F6.18 e: EXECUTE de anon o service_role en %', v_p; end if;
  end loop;
end $$;
reset role;
-- Los bloques siguientes corren con los claims del admin, como antes de este bloque.
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin F6.18 / F6.16

-- D60 · Retención de activity_log (24 meses): purge_activity_log solo para el sistema (pg_cron como postgres)
insert into guide.activity_log (occurred_at, actor_id, action, entity_table, entity_id, entity_label)
values
  (now() - interval '25 months', null, 'update', 'articles', 'd60-old-1', 'D60 antigua'),
  (now() - interval '24 months' - interval '1 day', null, 'update', 'articles', 'd60-old-2', 'D60 antigua'),
  (now() - interval '24 months' + interval '1 day', null, 'update', 'articles', 'd60-keep-1', 'D60 reciente'),
  (now() - interval '1 day', null, 'update', 'articles', 'd60-keep-2', 'D60 reciente');

-- a. anon y authenticated (no admin y admin): sin EXECUTE
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform guide.purge_activity_log(); raise exception 'LEAK D60 a: anon purga activity_log';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  begin perform guide.purge_activity_log(); raise exception 'LEAK D60 a: no admin purga activity_log';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  begin perform guide.purge_activity_log(); raise exception 'LEAK D60 a: admin purga activity_log desde la API';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- b. sistema (postgres): borra lo de más de 24 meses y conserva lo reciente; INVOKER, search_path vacío, job diario
do $$
declare v_n bigint;
begin
  v_n := guide.purge_activity_log();
  if v_n < 2 then raise exception 'FAIL D60 b: purga devuelve % (esperado >= 2)', v_n; end if;
  if exists (select 1 from guide.activity_log where entity_id in ('d60-old-1', 'd60-old-2')) then
    raise exception 'FAIL D60 b: quedan filas de más de 24 meses'; end if;
  if (select count(*) from guide.activity_log where entity_id in ('d60-keep-1', 'd60-keep-2')) <> 2 then
    raise exception 'FAIL D60 b: borra filas recientes'; end if;
  if exists (select 1 from guide.activity_log where occurred_at < now() - interval '24 months') then
    raise exception 'FAIL D60 b: quedan filas antiguas'; end if;
  if guide.purge_activity_log() <> 0 then raise exception 'FAIL D60 b: segunda purga no es idempotente'; end if;
  if (select p.prosecdef or not coalesce(p.proconfig @> array['search_path=""'], false)
      from pg_proc p where p.oid = 'guide.purge_activity_log()'::regprocedure) then
    raise exception 'FAIL D60 b: purge_activity_log no es INVOKER con search_path vacío'; end if;
  if has_function_privilege('anon', 'guide.purge_activity_log()', 'execute')
     or has_function_privilege('authenticated', 'guide.purge_activity_log()', 'execute')
     or has_function_privilege('service_role', 'guide.purge_activity_log()', 'execute') then
    raise exception 'LEAK D60 b: EXECUTE de anon, authenticated o service_role'; end if;
  if not exists (select 1 from cron.job where jobname = 'guide-activity-log-purge' and schedule = '15 3 * * *'
                 and command = 'select guide.purge_activity_log()' and active) then
    raise exception 'FAIL D60 b: falta el job diario guide-activity-log-purge'; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin D60

-- ═════════════ D66: consentimiento de comunicaciones afines (related_products), independiente de la newsletter ═════════════
-- Casilla opcional en subscribe_newsletter (pending hasta el doble opt-in), dar/retirar con token tras confirmar, versión de
-- texto propia, historial por finalidad, retirada independiente de la baja, retención de 3 años desde la retirada.
savepoint d66_guard;
release savepoint d66_guard;
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
end $$;
create or replace function pg_temp.d66_err(p_sql text)
returns text
language plpgsql
as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ' ' || sqlerrm;
end;
$$;

-- Fixtures de retención (postgres). R1: baja hace 4 años con afines vigente → se conserva. R2: baja hace 4 años y afines
-- retirado hace 1 año → se conserva. R3: baja y retirada hace 4 años → se anonimiza. R4: pendiente de 8 días con afines
-- pendiente → caduca y afines se descarta. R5: pendiente de hace 2 días con afines pendiente (para la re-suscripción).
insert into guide.subscribers (id, email, consent_at, consent_source, consent_version, related_status, related_consent_at,
                               related_consent_source, related_consent_version)
values
  ('66600000-0000-4000-8000-000000000001', 'rls-d66-r1@chalkguide.test', now() - interval '6 years', 'footer', 1, 'pending', now() - interval '6 years', 'footer', 1),
  ('66600000-0000-4000-8000-000000000002', 'rls-d66-r2@chalkguide.test', now() - interval '6 years', 'footer', 1, 'pending', now() - interval '6 years', 'footer', 1),
  ('66600000-0000-4000-8000-000000000003', 'rls-d66-r3@chalkguide.test', now() - interval '6 years', 'footer', 1, 'pending', now() - interval '6 years', 'footer', 1),
  ('66600000-0000-4000-8000-000000000004', 'rls-d66-r4@chalkguide.test', now() - interval '8 days', 'home', 3, 'pending', now() - interval '8 days', 'home', 1),
  ('66600000-0000-4000-8000-000000000005', 'rls-d66-r5@chalkguide.test', now() - interval '2 days', 'home', 3, 'pending', now() - interval '2 days', 'home', 1),
  ('66600000-0000-4000-8000-000000000006', 'rls-d66-r6@chalkguide.test', now() - interval '2 days', 'home', 3, 'pending', now() - interval '2 days', 'home', 1),
  ('66600000-0000-4000-8000-000000000007', 'rls-d66-r7@chalkguide.test', now() - interval '2 days', 'home', 3, 'none', null, null, null),
  ('66600000-0000-4000-8000-000000000008', 'rls-d66-r8@chalkguide.test', now() - interval '2 days', 'home', 3, 'pending', now() - interval '2 days', 'home', 1);
update guide.subscribers set status = 'active', confirmed_at = consent_at + interval '1 day',
       related_status = 'granted', related_confirmed_at = consent_at + interval '1 day'
where id in ('66600000-0000-4000-8000-000000000001', '66600000-0000-4000-8000-000000000002', '66600000-0000-4000-8000-000000000003');
update guide.subscribers set related_status = 'withdrawn', related_withdrawn_at = now() - interval '1 year', related_withdraw_source = 'link'
where id = '66600000-0000-4000-8000-000000000002';
update guide.subscribers set related_status = 'withdrawn', related_withdrawn_at = now() - interval '4 years', related_withdraw_source = 'link'
where id = '66600000-0000-4000-8000-000000000003';
update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '4 years', unsubscribe_source = 'link'
where id in ('66600000-0000-4000-8000-000000000001', '66600000-0000-4000-8000-000000000002', '66600000-0000-4000-8000-000000000003');
-- Veto D66. R6: baja reciente con afines vigente (V1, el token no rota). R7: baja reciente sin afines (el token sí rota).
-- R8: activo con afines vigente (O3, supresión).
update guide.subscribers set status = 'active', confirmed_at = consent_at + interval '1 hour',
       related_status = case when related_status = 'pending' then 'granted'::guide.related_consent_status else related_status end,
       related_confirmed_at = case when related_status = 'pending' then consent_at + interval '1 hour' end
where id in ('66600000-0000-4000-8000-000000000006', '66600000-0000-4000-8000-000000000007', '66600000-0000-4000-8000-000000000008');
update guide.subscribers set status = 'unsubscribed', unsubscribed_at = now() - interval '1 day', unsubscribe_source = 'link'
where id in ('66600000-0000-4000-8000-000000000006', '66600000-0000-4000-8000-000000000007');

-- Esquema, guardas y catálogo (postgres)
do $$
declare v text;
begin
  -- Texto v1 (doc §1, versión principal) en es/en, igual al vigente de site_settings, una versión abierta por finalidad
  if not exists (select 1 from guide.consent_texts c join guide.site_settings s on s.id = 1
                 where c.purpose = 'related_products' and c.version = 1 and c.preserved and c.valid_to is null
                   and c.version = s.related_consent_version
                   and c.text_es = s.related_consent_text_es and c.text_en = s.related_consent_text_en
                   and c.text_es = 'Quiero que me avisen por email de novedades de Chalk app y de otros productos de ChalkGuide relacionados con la escalada. Puedo retirar mi consentimiento cuando quiera.'
                   and c.text_en = 'I''d like to be told by email about news from Chalk app and other climbing-related ChalkGuide products. I can withdraw my consent at any time.') then
    raise exception 'FAIL D66: texto v1 de afines'; end if;
  if (select count(*) from guide.consent_texts where valid_to is null) <> 2
     or (select count(*) from guide.consent_texts where purpose = 'newsletter' and valid_to is null) <> 1 then
    raise exception 'FAIL D66: una versión abierta por finalidad'; end if;
  if pg_get_constraintdef((select oid from pg_constraint where conname = 'consent_texts_pkey')) <> 'PRIMARY KEY (purpose, version)' then
    raise exception 'FAIL D66: PK de consent_texts por finalidad'; end if;
  v := pg_temp.d66_err($q$insert into guide.consent_texts (purpose, version, text_es) values ('affiliates', 1, 'x')$q$);
  if v not like '23514 %' then raise exception 'FAIL D66: finalidad affiliates aceptada (%)', v; end if;
  v := pg_temp.d66_err($q$update guide.consent_texts set text_es = 'x' where purpose = 'related_products'$q$);
  if v <> '42501 consent_texts is append-only' then raise exception 'FAIL D66: texto de afines editable (%)', v; end if;

  -- Alta directa en granted o con retirada: no (solo none/pending al insertar)
  v := pg_temp.d66_err($q$insert into guide.subscribers (email, consent_source, consent_version, related_status, related_consent_at,
      related_consent_source, related_consent_version, related_confirmed_at)
      values ('rls-d66-x@chalkguide.test', 'footer', 3, 'granted', now(), 'footer', 1, now())$q$);
  if v <> '22023 invalid related consent state' then raise exception 'FAIL D66: alta en granted (%)', v; end if;
  v := pg_temp.d66_err($q$insert into guide.subscribers (email, consent_source, consent_version, related_status)
      values ('rls-d66-x@chalkguide.test', 'footer', 3, 'pending')$q$);
  if v not like '23514 %subscribers_related_state_check%' then raise exception 'FAIL D66: pending sin fecha/origen/versión (%)', v; end if;
  v := pg_temp.d66_err($q$insert into guide.subscribers (email, consent_source, consent_version, related_status, related_consent_at,
      related_consent_source, related_consent_version) values ('rls-d66-x@chalkguide.test', 'footer', 3, 'pending', now(), 'affiliates', 1)$q$);
  if v not like '23514 %subscribers_related_source_check%' then raise exception 'FAIL D66: origen affiliates aceptado (%)', v; end if;
  -- Transiciones: granted no vuelve a pending ni se re-sella; la retirada solo al retirar
  v := pg_temp.d66_err($q$update guide.subscribers set related_status = 'pending', related_confirmed_at = null
      where id = '66600000-0000-4000-8000-000000000001'$q$);
  if v not like '22023 invalid related consent transition%' then raise exception 'FAIL D66: granted → pending (%)', v; end if;
  v := pg_temp.d66_err($q$update guide.subscribers set related_consent_at = now() where id = '66600000-0000-4000-8000-000000000001'$q$);
  if v <> '22023 granted related consent is immutable' then raise exception 'FAIL D66: re-sella un vigente (%)', v; end if;
  v := pg_temp.d66_err($q$update guide.subscribers set related_withdrawn_at = now() where id = '66600000-0000-4000-8000-000000000002'$q$);
  if v <> '22023 related withdrawal only on withdraw' then raise exception 'FAIL D66: mueve la fecha de retirada (%)', v; end if;
  v := pg_temp.d66_err($q$update guide.subscribers set related_withdraw_source = 'hack' where id = '66600000-0000-4000-8000-000000000002'$q$);
  if v not like '23514 %' and v <> '22023 related withdrawal only on withdraw' then
    raise exception 'FAIL D66: origen de retirada fuera de lista (%)', v; end if;

  -- Historial por finalidad: el alta, la confirmación y la retirada de afines quedan con purpose related_products
  if (select array_agg(event order by id) from guide.subscriber_consent_events
      where subscriber_id = '66600000-0000-4000-8000-000000000002' and purpose = 'related_products')
     is distinct from array['subscribe', 'confirm', 'unsubscribe'] then
    raise exception 'FAIL D66: historial de afines'; end if;
  if (select array_agg(event order by id) from guide.subscriber_consent_events
      where subscriber_id = '66600000-0000-4000-8000-000000000002' and purpose = 'newsletter')
     is distinct from array['subscribe', 'confirm', 'unsubscribe'] then
    raise exception 'FAIL D66: historial de newsletter mezclado'; end if;

  -- Grants y funciones
  if has_table_privilege('anon', 'guide.subscribers', 'SELECT')
     or has_column_privilege('anon', 'guide.subscribers', 'related_status', 'SELECT')
     or has_column_privilege('authenticated', 'guide.subscribers', 'related_status', 'UPDATE')
     or not has_column_privilege('authenticated', 'guide.subscribers', 'related_status', 'SELECT')
     or not has_column_privilege('anon', 'guide.site_settings', 'related_consent_text_es', 'SELECT')
     or has_table_privilege('anon', 'guide.site_settings', 'UPDATE') then
    raise exception 'LEAK D66: grants de columnas'; end if;
  if to_regprocedure('guide.subscribe_newsletter(text, guide.locale, text, boolean, text)') is not null then
    raise exception 'FAIL D66: sigue la firma antigua de subscribe_newsletter'; end if;
  if exists (select 1 from pg_proc where oid in ('guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)'::regprocedure,
               'guide.set_related_consent(text, boolean, text)'::regprocedure, 'guide.get_consent_preferences(text)'::regprocedure,
               'guide.confirm_newsletter(text)'::regprocedure)
             and not (prosecdef and proconfig @> array['search_path=""'])) then
    raise exception 'FAIL D66: RPC sin DEFINER o sin search_path vacío'; end if;
  if exists (select 1 from unnest(array['guide.set_related_consent(text, boolean, text)'::regprocedure,
                                        'guide.get_consent_preferences(text)'::regprocedure]) f(fn)
             where not has_function_privilege('anon', f.fn, 'EXECUTE') or not has_function_privilege('authenticated', f.fn, 'EXECUTE')
                or has_function_privilege('service_role', f.fn, 'EXECUTE')
                or exists (select 1 from aclexplode((select proacl from pg_proc where oid = f.fn)) a where a.grantee = 0)) then
    raise exception 'FAIL D66: EXECUTE de las RPC de afines'; end if;
  if exists (select 1 from unnest(array['guide.subscriber_by_token(text)'::regprocedure, 'guide.subscribers_related_guard()'::regprocedure,
               'guide.subscriber_anonymize_at(guide.subscriber_status, timestamptz, timestamptz, timestamptz, guide.related_consent_status, timestamptz)'::regprocedure]) f(fn),
             unnest(array['anon', 'authenticated', 'service_role']) r(role)
             where has_function_privilege(r.role, f.fn, 'EXECUTE')) then
    raise exception 'LEAK D66: helpers internos ejecutables por clientes'; end if;
  -- Veto D66 O6: el alta solo para anon y authenticated. O5: retirada del panel solo authenticated (assert_admin dentro)
  if not has_function_privilege('anon', 'guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)', 'EXECUTE')
     or has_function_privilege('service_role', 'guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)', 'EXECUTE') then
    raise exception 'LEAK D66 O6: EXECUTE de subscribe_newsletter'; end if;
  if not exists (select 1 from pg_proc where oid = 'guide.admin_withdraw_related(uuid, text)'::regprocedure
                 and prosecdef and proconfig @> array['search_path=""'])
     or has_function_privilege('anon', 'guide.admin_withdraw_related(uuid, text)', 'EXECUTE')
     or has_function_privilege('service_role', 'guide.admin_withdraw_related(uuid, text)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'guide.admin_withdraw_related(uuid, text)', 'EXECUTE')
     or exists (select 1 from aclexplode((select proacl from pg_proc where oid = 'guide.admin_withdraw_related(uuid, text)'::regprocedure)) a
                where a.grantee = 0) then
    raise exception 'LEAK D66 O5: admin_withdraw_related sin DEFINER, search_path o EXECUTE acotado'; end if;
  v := pg_temp.d66_err($q$update guide.subscribers set related_status = 'withdrawn', related_withdrawn_at = now(),
      related_withdraw_source = 'hack' where id = '66600000-0000-4000-8000-000000000008'$q$);
  if v not like '23514 %subscribers_related_withdraw_source_check%' then
    raise exception 'FAIL D66: origen de retirada hack aceptado (%)', v; end if;
  -- Solo estas funciones escriben afines (ni el login, ni el alta de cuenta, ni las opiniones)
  if exists (select 1 from pg_proc p where p.pronamespace = 'guide'::regnamespace
               and p.prosrc ~ 'related_status\s*='
               and p.proname not in ('subscribe_newsletter', 'confirm_newsletter', 'set_related_consent', 'expire_pending_subscribers',
                                     'subscribers_related_guard', 'subscribers_log_consent', 'admin_list_subscribers',
                                     'admin_get_subscriber', 'get_consent_preferences', 'subscriber_anonymize_at',
                                     'admin_withdraw_related', 'subscriber_anonymize')) then
    raise exception 'FAIL D66: otra función escribe afines'; end if;
  if exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
             where t.tgrelid = 'auth.users'::regclass and p.prosrc ~ 'related_') then
    raise exception 'LEAK D66: un trigger de auth.users toca afines'; end if;
end $$;
create temp table _d66_tokens (email text primary key, unsubscribe_token uuid not null) on commit drop;
grant select on _d66_tokens to anon, authenticated;

-- anon: altas con y sin casilla
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  begin perform 1 from guide.subscribers; raise exception 'LEAK anon D66: lee subscribers'; exception when insufficient_privilege then null; end;
  if not exists (select 1 from guide.site_settings where id = 1 and related_consent_version >= 1
                 and related_consent_text_es like 'Quiero que me avisen%' and related_consent_text_en like 'I''d like to be told%') then
    raise exception 'FAIL anon D66: no lee el texto vigente de afines'; end if;
  perform guide.subscribe_newsletter('rls-d66-a@chalkguide.test', 'es', 'footer', true, '/d66?utm=1');
  perform guide.subscribe_newsletter('rls-d66-b@chalkguide.test', 'en', 'article_end', true, '/en/d66#x', true);
  perform guide.subscribe_newsletter(p_email => 'rls-d66-c@chalkguide.test', p_locale => 'es', p_source => 'home',
                                     p_consent => true, p_related_consent => null);
  begin perform guide.subscribe_newsletter('rls-d66-d@chalkguide.test', 'es', 'footer', false, null, true);
    raise exception 'FAIL anon D66: afines sin newsletter en el formulario';
  exception when invalid_parameter_value then null; end;
  -- R5: re-suscripción sin la casilla descarta el afines pendiente sin verificar
  perform guide.subscribe_newsletter('rls-d66-r5@chalkguide.test', 'es', 'home', true);
end $$;
reset role;

do $$
begin
  if not exists (select 1 from guide.subscribers where email = 'rls-d66-a@chalkguide.test' and related_status = 'none'
                 and related_consent_at is null)
     or not exists (select 1 from guide.subscribers where email = 'rls-d66-c@chalkguide.test' and related_status = 'none') then
    raise exception 'FAIL D66: sin casilla no queda en none'; end if;
  if not exists (select 1 from guide.subscribers s join guide.site_settings st on st.id = 1
                 where s.email = 'rls-d66-b@chalkguide.test' and s.status = 'pending' and s.related_status = 'pending'
                   and s.related_consent_source = 'article_end' and s.related_consent_version = st.related_consent_version
                   and s.related_consent_at is not null and s.related_confirmed_at is null) then
    raise exception 'FAIL D66: con casilla no queda pending con origen y versión'; end if;
  if not exists (select 1 from guide.subscriber_consent_events e join guide.subscribers s on s.id = e.subscriber_id
                 where s.email = 'rls-d66-b@chalkguide.test' and e.purpose = 'related_products' and e.event = 'subscribe'
                   and e.source = 'article_end' and e.page = '/en/d66' and e.actor = 'anon') then
    raise exception 'FAIL D66: historial del alta con casilla'; end if;
  if exists (select 1 from guide.subscribers where email = 'rls-d66-d@chalkguide.test') then
    raise exception 'FAIL D66: alta sin consentimiento de newsletter'; end if;
  if not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000005' and related_status = 'none'
                 and related_consent_at is null)
     or not exists (select 1 from guide.subscriber_consent_events where subscriber_id = '66600000-0000-4000-8000-000000000005'
                    and purpose = 'related_products' and event = 'expire' and source = 'resubscribe') then
    raise exception 'FAIL D66: re-suscripción sin casilla no descarta el pendiente'; end if;
  -- Token de confirmación conocido para B (64 × '6'); A sin confirmar
  update guide.subscribers set confirm_token_hash = sha256(convert_to(repeat('6', 64), 'UTF8')), confirm_expires_at = now() + interval '1 day'
  where email = 'rls-d66-b@chalkguide.test';
  insert into _d66_tokens select email, unsubscribe_token from guide.subscribers
  where email in ('rls-d66-a@chalkguide.test', 'rls-d66-b@chalkguide.test', 'rls-d66-r6@chalkguide.test',
                  'rls-d66-r7@chalkguide.test');
end $$;

-- anon: doble opt-in, preferencias, retirada y baja independientes
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare j jsonb;
begin
  begin perform guide.subscriber_by_token(repeat('6', 64)); raise exception 'LEAK anon D66: subscriber_by_token';
  exception when insufficient_privilege then null; end;
  if guide.confirm_newsletter(repeat('6', 64)) <> 'ok' then raise exception 'FAIL anon D66: confirma'; end if;
  j := guide.get_consent_preferences(repeat('6', 64));
  if j is distinct from '{"newsletter":"active","related_products":"granted","can_grant_related":false,"locale":"en"}'::jsonb then
    raise exception 'FAIL anon D66: preferencias tras confirmar (%)', j; end if;
  if guide.get_consent_preferences('hack') is not null or guide.get_consent_preferences(null) is not null
     or guide.get_consent_preferences(repeat('7', 64)) is not null
     or guide.get_consent_preferences('00000000-0000-4000-8000-000000000000') is not null then
    raise exception 'FAIL anon D66: preferencias con token inválido'; end if;
  if guide.set_related_consent('hack', false) <> 'invalid' or guide.set_related_consent(null, true) <> 'invalid'
     or guide.set_related_consent(repeat('7', 64), true) <> 'invalid' then
    raise exception 'FAIL anon D66: token inválido'; end if;
  begin perform guide.set_related_consent(repeat('6', 64), true, 'link'); raise exception 'FAIL anon D66: dar por el enlace de baja';
  exception when invalid_parameter_value then null; end;
  begin perform guide.set_related_consent(repeat('6', 64), null); raise exception 'FAIL anon D66: p_granted null';
  exception when invalid_parameter_value then null; end;
  begin perform guide.set_related_consent(repeat('6', 64), false, 'admin'); raise exception 'FAIL anon D66: canal fuera de lista';
  exception when invalid_parameter_value then null; end;
  -- Retirada en un clic con el token de confirmación todavía vigente: la newsletter sigue activa
  if guide.set_related_consent(repeat('6', 64), false, 'link') <> 'ok' then raise exception 'FAIL anon D66: retira'; end if;
  if (guide.get_consent_preferences(repeat('6', 64)) ->> 'newsletter') <> 'active'
     or (guide.get_consent_preferences(repeat('6', 64)) ->> 'related_products') <> 'none' then
    raise exception 'FAIL anon D66: la retirada toca la newsletter'; end if;
  -- Volver a dar desde preferencias
  if guide.set_related_consent(repeat('6', 64), true) <> 'ok' then raise exception 'FAIL anon D66: vuelve a dar'; end if;
  if guide.set_related_consent(repeat('6', 64), true) <> 'ok' then raise exception 'FAIL anon D66: dar dos veces'; end if;
end $$;
reset role;

do $$
declare v_b uuid := (select id from guide.subscribers where email = 'rls-d66-b@chalkguide.test');
begin
  if not exists (select 1 from guide.subscribers s join guide.site_settings st on st.id = 1
                 where s.id = v_b and s.status = 'active' and s.related_status = 'granted' and s.related_consent_source = 'preferences'
                   and s.related_consent_version = st.related_consent_version and s.related_confirmed_at is not null
                   and s.related_withdraw_source = 'link' and s.related_withdrawn_at is not null
                   and s.brevo_sync_status = 'pending') then
    raise exception 'FAIL D66: estado tras retirar y volver a dar'; end if;
  if (select array_agg(event || ':' || source order by id) from guide.subscriber_consent_events
      where subscriber_id = v_b and purpose = 'related_products')
     is distinct from array['subscribe:article_end', 'confirm:double_opt_in', 'unsubscribe:link', 'subscribe:preferences'] then
    raise exception 'FAIL D66: historial de B'; end if;
end $$;

-- anon con el unsubscribe_token: baja de newsletter sin tocar afines, y al revés
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare
  v_ta uuid := (select unsubscribe_token from _d66_tokens where email = 'rls-d66-a@chalkguide.test');
  v_tb uuid := (select unsubscribe_token from _d66_tokens where email = 'rls-d66-b@chalkguide.test');
begin
  -- A (sin confirmar): no puede dar afines; retirar lo que no tiene es neutro
  if guide.set_related_consent(v_ta::text, true) <> 'unconfirmed' then raise exception 'FAIL anon D66: da afines sin email verificado'; end if;
  if guide.set_related_consent(v_ta::text, false) <> 'ok' then raise exception 'FAIL anon D66: retirar sin tener'; end if;
  if (guide.get_consent_preferences(v_ta::text) ->> 'can_grant_related')::boolean then
    raise exception 'FAIL anon D66: can_grant_related sin verificar'; end if;
  -- B: baja de newsletter; afines sigue vigente
  perform guide.unsubscribe_newsletter(v_tb);
  if guide.get_consent_preferences(upper(v_tb::text)) is distinct from
     '{"newsletter":"inactive","related_products":"granted","can_grant_related":false,"locale":"en"}'::jsonb then
    raise exception 'FAIL anon D66: la baja de newsletter toca afines'; end if;
  -- Retirar afines tras la baja, y volver a darlo (email verificado antes)
  -- Sentencias separadas: get_consent_preferences es STABLE y no ve cambios de la misma sentencia
  if guide.set_related_consent(v_tb::text, false, 'preferences') <> 'ok' then
    raise exception 'FAIL anon D66: retira tras la baja de newsletter'; end if;
  if (guide.get_consent_preferences(v_tb::text) ->> 'can_grant_related')::boolean is not true then
    raise exception 'FAIL anon D66: can_grant_related tras la baja de newsletter'; end if;
  if guide.set_related_consent(v_tb::text, true) <> 'ok' then
    raise exception 'FAIL anon D66: vuelve a dar tras la baja de newsletter'; end if;
end $$;
reset role;

-- Veto D66 V1: re-suscribir una fila unsubscribed + granted no rota el token; el antiguo sigue retirando en un clic
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
declare
  v_t6 uuid := (select unsubscribe_token from _d66_tokens where email = 'rls-d66-r6@chalkguide.test');
  v_t7 uuid := (select unsubscribe_token from _d66_tokens where email = 'rls-d66-r7@chalkguide.test');
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  perform guide.subscribe_newsletter('rls-d66-r6@chalkguide.test', 'es', 'footer', true);
  perform guide.subscribe_newsletter('rls-d66-r7@chalkguide.test', 'es', 'footer', true);
  if guide.set_related_consent(v_t6::text, false, 'link') <> 'ok' then
    raise exception 'FAIL anon D66 V1: la re-suscripción invalida el token de una fila con afines vigente'; end if;
  if guide.set_related_consent(v_t7::text, false, 'link') <> 'invalid' then
    raise exception 'FAIL anon D66 V1: sin afines vigente el token ya no rota'; end if;
end $$;
reset role;

do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if not exists (select 1 from guide.subscribers s join _d66_tokens t on t.email = s.email
                 where s.id = '66600000-0000-4000-8000-000000000006' and s.status = 'pending'
                   and s.unsubscribe_token = t.unsubscribe_token and s.related_status = 'withdrawn'
                   and s.related_withdraw_source = 'link') then
    raise exception 'FAIL D66 V1: estado de R6 tras re-suscribir y retirar'; end if;
  if exists (select 1 from guide.subscribers s join _d66_tokens t on t.email = s.email
             where s.id = '66600000-0000-4000-8000-000000000007' and s.unsubscribe_token = t.unsubscribe_token) then
    raise exception 'FAIL D66 V1: el token de R7 no rotó'; end if;
end $$;

-- Retención y caducidad (como la tarea programada)
do $$
declare j jsonb;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  j := guide.expire_pending_subscribers();
  if not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000001' and status = 'unsubscribed'
                 and email is not null)
     or not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000002' and status = 'unsubscribed'
                    and email is not null)
     or not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000003' and status = 'erased'
                    and email is null and related_status = 'withdrawn' and related_consent_at is not null) then
    raise exception 'FAIL D66: retención con afines (vigente / retirado < 3 años / retirado > 3 años)'; end if;
  if not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000004' and status = 'expired'
                 and related_status = 'none' and related_consent_at is null)
     or not exists (select 1 from guide.subscriber_consent_events where subscriber_id = '66600000-0000-4000-8000-000000000004'
                    and purpose = 'related_products' and event = 'expire' and source = 'timeout' and actor = 'service') then
    raise exception 'FAIL D66: caducidad del afines pendiente'; end if;
end $$;

-- authenticated sin rol de admin
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  if exists (select 1 from guide.subscribers) then raise exception 'LEAK user D66: lee subscribers'; end if;
  if exists (select 1 from guide.consent_texts) then raise exception 'LEAK user D66: lee consent_texts'; end if;
  begin update guide.subscribers set related_status = 'granted'; raise exception 'LEAK user D66: UPDATE afines';
  exception when insufficient_privilege then null; end;
  -- site_settings: UPDATE de tabla para authenticated, pero la policy solo deja al admin (0 filas)
  update guide.site_settings set related_consent_text_es = 'x', related_consent_version = related_consent_version + 1 where id = 1;
  if guide.set_related_consent('hack', true) <> 'invalid' then raise exception 'FAIL user D66: set_related_consent'; end if;
end $$;
reset role;

do $$
begin
  if exists (select 1 from guide.consent_texts where purpose = 'related_products' and text_es = 'x')
     or exists (select 1 from guide.site_settings where id = 1 and related_consent_text_es = 'x') then
    raise exception 'LEAK user D66: versiona el texto de afines'; end if;
end $$;

-- admin: lectura en el panel y exportación; sin escritura
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  v_b uuid;
  j   jsonb;
  r   jsonb;
begin
  begin update guide.subscribers set related_status = 'withdrawn'; raise exception 'LEAK admin D66: UPDATE afines en directo';
  exception when insufficient_privilege then null; end;
  -- Como el de la newsletter (Ajustes): el admin solo cambia el texto subiendo la versión, y queda versionado
  begin update guide.site_settings set related_consent_text_en = 'D66 admin' where id = 1;
    raise exception 'FAIL admin D66: cambia el texto de afines sin versión'; exception when invalid_parameter_value then null; end;
  select (x ->> 'id')::uuid into v_b from jsonb_array_elements(guide.admin_list_subscribers('all', 'rls-d66-b@') -> 'rows') x;
  j := guide.admin_get_subscriber(v_b);
  if j -> 'subscriber' ->> 'related_status' <> 'granted' or j -> 'subscriber' ->> 'related_consent_source' <> 'preferences'
     or (j -> 'subscriber' ->> 'related_withdrawn_at') is null
     or not (j -> 'related_consent_texts') ? '1' or (j -> 'consent_texts') ? '1'
     or not exists (select 1 from jsonb_array_elements(j -> 'events') e where e ->> 'purpose' = 'related_products')
     or exists (select 1 from jsonb_array_elements(j -> 'events') e where e ->> 'purpose' is null)
     or (j -> 'subscriber' ->> 'anonymize_at') is not null then
    raise exception 'FAIL admin D66: ficha (%)', j -> 'subscriber'; end if;
  j := guide.admin_list_subscribers('all', 'rls-d66-');
  if (j -> 'related_counts' ->> 'granted')::int < 2 or (j -> 'related_counts' ->> 'none') is null then
    raise exception 'FAIL admin D66: related_counts (%)', j -> 'related_counts'; end if;
  select x into r from jsonb_array_elements(j -> 'rows') x where x ->> 'email' = 'rls-d66-r2@chalkguide.test';
  if r ->> 'related_status' <> 'withdrawn'
     or (r ->> 'anonymize_at')::timestamptz < now() + interval '1 year' then
    raise exception 'FAIL admin D66: fila con retirada reciente (%)', r; end if;
  -- Exportar (D36): la vista sigue sin SELECT directo; admin_export la sirve con las columnas de afines
  begin perform 1 from guide.export_subscribers; raise exception 'LEAK admin D66: SELECT directo de export_subscribers';
  exception when insufficient_privilege then null; end;
  j := guide.admin_export('subscribers', 'json', '{"purpose":"audit","columns":"all","statuses":["unsubscribed"]}'::jsonb);
  if not exists (select 1 from jsonb_array_elements(j -> 'rows') x where (x ->> 'id')::uuid = v_b
                 and x ->> 'related_status' = 'granted' and x ->> 'related_withdraw_source' = 'preferences'
                 and x ? 'related_consent_version' and x ? 'related_confirmed_at') then
    raise exception 'FAIL admin D66: exportación sin columnas de afines'; end if;
  -- Series del Inicio: solo eventos de la newsletter
  if (select value from guide.admin_timeseries('subscribers_new', current_date, current_date, 'day'))
     <> (select count(*) from guide.subscriber_consent_events where event = 'confirm' and purpose = 'newsletter'
         and occurred_at >= current_date and occurred_at < current_date + 1) then
    raise exception 'FAIL admin D66: admin_timeseries cuenta eventos de afines'; end if;
end $$;
reset role;

-- Veto D66 O5: retirada de afines desde el panel. anon y authenticated sin rol de admin: no
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  begin perform guide.admin_withdraw_related('66600000-0000-4000-8000-000000000001', 'request');
    raise exception 'LEAK anon D66 O5: admin_withdraw_related'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  begin perform guide.admin_withdraw_related('66600000-0000-4000-8000-000000000001', 'request');
    raise exception 'LEAK user D66 O5: admin_withdraw_related'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- admin: retira afines de R1 (baja de newsletter, afines vigente) y suprime R8 (O3)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare v text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  v := pg_temp.d66_err($q$select guide.admin_withdraw_related('66600000-0000-4000-8000-000000000001', 'hack')$q$);
  if v <> '22023 invalid reason' then raise exception 'FAIL admin D66 O5: motivo fuera de lista (%)', v; end if;
  v := pg_temp.d66_err($q$select guide.admin_withdraw_related('66600000-0000-4000-8000-000000000001', null)$q$);
  if v <> '22023 invalid reason' then raise exception 'FAIL admin D66 O5: motivo null (%)', v; end if;
  v := pg_temp.d66_err($q$select guide.admin_withdraw_related('00000000-0000-4000-8000-000000000000', 'request')$q$);
  if v <> 'P0002 subscriber not found' then raise exception 'FAIL admin D66 O5: fila inexistente (%)', v; end if;
  v := pg_temp.d66_err($q$select guide.admin_withdraw_related('66600000-0000-4000-8000-000000000002', 'request')$q$);
  if v <> '22023 invalid related consent state' then raise exception 'FAIL admin D66 O5: retira un afines ya retirado (%)', v; end if;
  if guide.admin_withdraw_related('66600000-0000-4000-8000-000000000001', 'request') ->> 'related_status' <> 'withdrawn' then
    raise exception 'FAIL admin D66 O5: retira'; end if;
  perform guide.admin_erase_subscriber('66600000-0000-4000-8000-000000000008', 'rls-d66-r8@chalkguide.test', 'request');
  v := pg_temp.d66_err($q$select guide.admin_withdraw_related('66600000-0000-4000-8000-000000000008', 'request')$q$);
  if v <> 'P0002 subscriber not found' then raise exception 'FAIL admin D66 O5: retira en una fila suprimida (%)', v; end if;
end $$;
reset role;

do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  -- O5: solo afines; la newsletter de R1 sigue dada de baja y el historial lleva origen, actor y motivo
  if not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000001' and status = 'unsubscribed'
                 and email is not null and related_status = 'withdrawn' and related_withdraw_source = 'admin'
                 and related_withdrawn_at is not null and brevo_sync_status = 'pending') then
    raise exception 'FAIL D66 O5: estado de R1 tras la retirada del admin'; end if;
  if not exists (select 1 from guide.subscriber_consent_events where subscriber_id = '66600000-0000-4000-8000-000000000001'
                 and purpose = 'related_products' and event = 'unsubscribe' and source = 'admin' and actor = 'admin'
                 and reason = 'request')
     or exists (select 1 from guide.subscriber_consent_events where subscriber_id = '66600000-0000-4000-8000-000000000001'
                and purpose = 'newsletter' and source = 'admin') then
    raise exception 'FAIL D66 O5: historial de la retirada del admin'; end if;
  -- O3: una fila suprimida nunca queda granted; sin evento de afines tras la supresión (basta el erase)
  if not exists (select 1 from guide.subscribers where id = '66600000-0000-4000-8000-000000000008' and status = 'erased'
                 and email is null and related_status = 'withdrawn' and related_withdraw_source = 'erase'
                 and related_withdrawn_at is not null) then
    raise exception 'FAIL D66 O3: la supresión deja afines vigente'; end if;
  if exists (select 1 from guide.subscribers where status = 'erased' and related_status in ('granted', 'pending')) then
    raise exception 'FAIL D66 O3: fila suprimida con afines granted o pending'; end if;
  if exists (select 1 from guide.subscriber_consent_events where subscriber_id = '66600000-0000-4000-8000-000000000008'
             and purpose = 'related_products' and event = 'unsubscribe') then
    raise exception 'FAIL D66 O3: evento de afines en la supresión'; end if;
end $$;

-- Versionado del texto de afines (postgres; en producción, por migración): sin subir versión no cambia
do $$
declare v text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  v := pg_temp.d66_err($q$update guide.site_settings set related_consent_text_es = 'Texto D66 nuevo' where id = 1$q$);
  if v <> '22023 consent_text_requires_version_bump' then raise exception 'FAIL D66: cambia el texto sin versión (%)', v; end if;
  v := pg_temp.d66_err($q$update guide.site_settings set related_consent_version = 0 where id = 1$q$);
  if v not like '22023 %' and v not like '23514 %' then raise exception 'FAIL D66: baja la versión (%)', v; end if;
  update guide.site_settings set related_consent_text_es = 'Texto D66 nuevo', related_consent_version = related_consent_version + 1 where id = 1;
  if not exists (select 1 from guide.consent_texts c join guide.site_settings s on s.id = 1
                 where c.purpose = 'related_products' and c.version = s.related_consent_version and c.text_es = 'Texto D66 nuevo'
                   and c.valid_to is null)
     or not exists (select 1 from guide.consent_texts where purpose = 'related_products' and version = 1 and valid_to is not null)
     or (select count(*) from guide.consent_texts where purpose = 'newsletter' and valid_to is null) <> 1 then
    raise exception 'FAIL D66: versionado de afines'; end if;
end $$;
-- Fin D66


-- ═════════════ F6.19 · arreglos de la revisión integral del panel (docs/security/F6.19-panel-review.md) ═════════════
-- Punto 3 (draft_op 'publish:<id>' y guardas de content_drafts_log_write), punto 4 (18 casos de href en legales),
-- punto 5 (articles_unpublish_guard también para published → scheduled futuro), punto 6 (desempate de quintiles igual en
-- vista y preview), punto 7 (invisibles en marca/modelo y «'» en affiliate_url), punto 8 (purga de cron.job_run_details,
-- job_health y cleanup_* en admin_dashboard_stats), B1 y B2 (EXECUTE). Fixtures propios con ids 6190…; sin barras
-- invertidas en el SQL (los caracteres de control y la barra invertida van con chr()).
select set_config('guide.draft_op', 'maintenance', true);
insert into guide.article_categories (id, name_es, slug_es)
values ('c6190000-0000-4000-8000-000000000001', 'F619 cat', 'rls-f619-cat');
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d6190000-0000-4000-8000-000000000001', 'c6190000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'F619 uno', 'rls-f619-uno'),
  ('d6190000-0000-4000-8000-000000000002', 'c6190000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'F619 dos', 'rls-f619-dos'),
  ('d6190000-0000-4000-8000-000000000003', 'c6190000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'F619 tres', 'rls-f619-tres'),
  ('d6190000-0000-4000-8000-000000000004', 'c6190000-0000-4000-8000-000000000001', 'published', now() - interval '1 day', 'F619 cuatro', 'rls-f619-cuatro');
-- Punto 6: 10 rocódromos publicados con precio (fuerzan quintiles); 01 y 02 empatan a 40 €.
insert into guide.items (id, category, name, slug, published)
select format('f6190000-0000-4000-8000-0000000000%s', lpad(n::text, 2, '0'))::uuid, 'gym', 'F619 gym ' || n, 'rls-f619-gym-' || n, true
from generate_series(1, 10) n;
insert into guide.gyms (item_id, price_monthly_eur)
select format('f6190000-0000-4000-8000-0000000000%s', lpad(n::text, 2, '0'))::uuid, case when n <= 2 then 40 else 30 + 7 * n end
from generate_series(1, 10) n;
-- Punto 5: programado con fecha ya pasada (vivo). articles_before_write no deja crearlo así (23514), así que se inserta
-- sin triggers de usuario, solo en esta transacción.
set local session_replication_role = replica;
insert into guide.articles (id, category_id, status, published_at, title_es, slug_es) values
  ('d6190000-0000-4000-8000-000000000005', 'c6190000-0000-4000-8000-000000000001', 'scheduled', now() - interval '1 hour', 'F619 cinco', 'rls-f619-cinco');
set local session_replication_role = origin;
-- Punto 7: pie de gato sin publicar
insert into guide.items (id, category, name, slug, published)
values ('f6190000-0000-4000-8000-000000000101', 'shoe', 'F619 shoe', 'rls-f619-shoe', false);
insert into guide.shoes (item_id, brand, model) values ('f6190000-0000-4000-8000-000000000101', 'F619', 'Modelo');
select set_config('guide.draft_op', '', true);

-- ── Punto 3 · a/b/c: descarte con 'publish' genérico, publicación y cascada (admin) ──
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  a1 constant uuid := 'd6190000-0000-4000-8000-000000000001';
  a4 constant uuid := 'd6190000-0000-4000-8000-000000000004';
begin
  -- a. Borrado directo del borrador con draft_op = 'publish' (el valor antiguo): registra draft_discard
  perform guide.save_draft('article', a1, '{"article":{"excerpt_es":"F619 a"}}', guide.draft_entity_version('article', a1));
  perform set_config('guide.draft_op', 'publish', true);
  delete from guide.content_drafts where entity = 'article' and entity_id = a1;
  perform set_config('guide.draft_op', '', true);
  if exists (select 1 from guide.activity_log where entity_id = a1::text and action = 'draft_publish')
     or not exists (select 1 from guide.activity_log where entity_id = a1::text and action = 'draft_discard') then
    raise exception 'FAIL F6.19 3a: draft_op=publish genérico no registra draft_discard'; end if;
  -- 'publish:<otro id>' tampoco vale
  perform guide.save_draft('article', a1, '{"article":{"excerpt_es":"F619 a2"}}', guide.draft_entity_version('article', a1));
  perform set_config('guide.draft_op', 'publish:d6190000-0000-4000-8000-000000000002', true);
  delete from guide.content_drafts where entity = 'article' and entity_id = a1;
  perform set_config('guide.draft_op', '', true);
  if exists (select 1 from guide.activity_log where entity_id = a1::text and action = 'draft_publish') then
    raise exception 'FAIL F6.19 3a: publish:<otro id> registra draft_publish'; end if;
  -- b. publish_draft sí registra draft_publish y deja draft_op vacío
  perform guide.save_draft('article', a1, '{"article":{"excerpt_es":"F619 b"}}', guide.draft_entity_version('article', a1));
  perform guide.publish_draft('article', a1);
  if (select count(*) from guide.activity_log where entity_id = a1::text and action = 'draft_publish') <> 1
     or (select excerpt_es from guide.articles where id = a1) <> 'F619 b'
     or coalesce(current_setting('guide.draft_op', true), '') <> '' then
    raise exception 'FAIL F6.19 3b: publish_draft no registra draft_publish'; end if;
  -- c. (preparación) borrador sobre a4; el borrado en cascada va después, como postgres en mantenimiento
  perform guide.save_draft('article', a4, '{"article":{"excerpt_es":"F619 c"}}', guide.draft_entity_version('article', a4));
  -- Llamada directa (fuera de trigger): 42501
  begin perform guide.content_drafts_log_write('article', a1, '{}'::jsonb);
    raise exception 'LEAK F6.19 3: content_drafts_log_write por RPC';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- c. Borrar un artículo vivo con borrador (mantenimiento como postgres): la cascada no escribe línea de borrador
--    (el artículo ya no existe → label null) ni da error
select set_config('guide.draft_op', 'maintenance', true);
do $$
begin
  delete from guide.articles where id = 'd6190000-0000-4000-8000-000000000004';
  if exists (select 1 from guide.articles where id = 'd6190000-0000-4000-8000-000000000004')
     or exists (select 1 from guide.content_drafts where entity_id = 'd6190000-0000-4000-8000-000000000004')
     or exists (select 1 from guide.activity_log where entity_id = 'd6190000-0000-4000-8000-000000000004'
                and action in ('draft_publish', 'draft_discard')) then
    raise exception 'FAIL F6.19 3c: cascada de borrador al borrar el artículo'; end if;
end $$;
select set_config('guide.draft_op', '', true);

-- ── Punto 3 · d: línea fabricada desde un trigger mientras el borrador sigue vivo → 42501 'draft still exists' ──
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
begin
  perform guide.save_draft('article', 'd6190000-0000-4000-8000-000000000002', '{"article":{"excerpt_es":"F619 d"}}',
                           guide.draft_entity_version('article', 'd6190000-0000-4000-8000-000000000002'));
end $$;
reset role;
create temp table f619_fake (x int);
create function pg_temp.f619_fake_log() returns trigger language plpgsql as $f$
begin
  perform guide.content_drafts_log_write('article', 'd6190000-0000-4000-8000-000000000002', '{}'::jsonb);
  return null;
end $f$;
create trigger f619_fake_log after insert on f619_fake for each row execute function pg_temp.f619_fake_log();
do $$
begin
  begin
    insert into f619_fake values (1);
    raise exception 'LEAK F6.19 3d: línea fabricada con el borrador vivo';
  exception when insufficient_privilege then
    if sqlerrm <> 'draft still exists' then raise exception 'FAIL F6.19 3d: %', sqlerrm; end if;
  end;
  if exists (select 1 from guide.activity_log
             where entity_id = 'd6190000-0000-4000-8000-000000000002' and action in ('draft_publish', 'draft_discard')) then
    raise exception 'LEAK F6.19 3d: quedó línea fabricada'; end if;
end $$;
drop table f619_fake;
drop function pg_temp.f619_fake_log();

-- ── Punto 3 · d (rama 'not allowed'): la sesión de la herramienta es postgres, así que la guarda de session_user
--    siempre pasa. Copia del cuerpo desplegado en pg_temp con el literal de session_user sustituido, invocada desde
--    un trigger: no admin y service_role sin JWT → 42501 'not allowed'; admin pasa la guarda (cae en 'draft still exists').
do $$
declare
  v_def text := pg_get_functiondef('guide.content_drafts_log_write(text, uuid, jsonb)'::regprocedure);
begin
  if position('session_user = ''postgres''' in v_def) = 0 then
    raise exception 'FAIL F6.19 3d: el cuerpo desplegado ya no compara session_user con postgres'; end if;
  v_def := replace(v_def, 'FUNCTION guide.content_drafts_log_write(', 'FUNCTION pg_temp.f619_log_write_copy(');
  v_def := replace(v_def, 'session_user = ''postgres''', 'session_user = ''f619_no_such_role''');
  execute v_def;
end $$;
create temp table f619_fake2 (x int);
create function pg_temp.f619_fake_log2() returns trigger language plpgsql as $f$
begin
  perform pg_temp.f619_log_write_copy('article', 'd6190000-0000-4000-8000-000000000002', '{}'::jsonb);
  return null;
end $f$;
create trigger f619_fake_log2 after insert on f619_fake2 for each row execute function pg_temp.f619_fake_log2();
do $$
declare
  r record;
begin
  for r in select * from (values
      ('{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', 'not allowed', 'no admin'),
      ('{"role":"service_role"}', 'not allowed', 'service_role sin JWT'),
      ('{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', 'draft still exists', 'admin')
    ) v(claims, expect, label) loop
    perform set_config('request.jwt.claims', r.claims, true);
    begin
      insert into f619_fake2 values (1);
      raise exception 'LEAK F6.19 3d: copia sin guarda de session_user acepta %', r.label;
    exception when insufficient_privilege then
      if sqlerrm <> r.expect then raise exception 'FAIL F6.19 3d (%): %', r.label, sqlerrm; end if;
    end;
  end loop;
  if exists (select 1 from guide.activity_log
             where entity_id = 'd6190000-0000-4000-8000-000000000002' and action in ('draft_publish', 'draft_discard')) then
    raise exception 'LEAK F6.19 3d: quedó línea fabricada (copia)'; end if;
end $$;
select set_config('request.jwt.claims', '', true);
drop table f619_fake2;
drop function pg_temp.f619_fake_log2();
drop function pg_temp.f619_log_write_copy(text, uuid, jsonb);

-- anon y no admin: content_drafts_log_write sigue cerrado
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin perform guide.content_drafts_log_write('article', 'd6190000-0000-4000-8000-000000000002', '{}'::jsonb);
    raise exception 'LEAK F6.19 3: anon content_drafts_log_write'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  begin perform guide.content_drafts_log_write('article', 'd6190000-0000-4000-8000-000000000002', '{}'::jsonb);
    raise exception 'LEAK F6.19 3: no admin content_drafts_log_write'; exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.content_drafts) then raise exception 'LEAK F6.19 3: no admin ve borradores'; end if;
end $$;
reset role;

-- ── Punto 5: lo vivo con borrador no pasa a programado futuro ni mueve published_at al futuro (PT423) ──
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  a2 constant uuid := 'd6190000-0000-4000-8000-000000000002';
  a3 constant uuid := 'd6190000-0000-4000-8000-000000000003';
  a5 constant uuid := 'd6190000-0000-4000-8000-000000000005';
begin
  begin update guide.articles set status = 'scheduled', published_at = now() + interval '1 day' where id = a2;
    raise exception 'FAIL F6.19 5: published → scheduled futuro con borrador';
  exception when sqlstate 'PT423' then null; end;
  -- Programado ya vivo: mover solo published_at al futuro lo ocultaría → PT423
  perform guide.save_draft('article', a5, '{"article":{"excerpt_es":"F619 e"}}', guide.draft_entity_version('article', a5));
  begin update guide.articles set published_at = now() + interval '1 day' where id = a5;
    raise exception 'FAIL F6.19 5: published_at al futuro con borrador (programado vivo)';
  exception when sqlstate 'PT423' then null; end;
  begin update guide.articles set status = 'scheduled', published_at = now() + interval '2 days' where id = a5;
    raise exception 'FAIL F6.19 5: reprogramar al futuro con borrador (programado vivo)';
  exception when sqlstate 'PT423' then null; end;
  -- Publicado: published_at futuro se normaliza a now() (articles_before_write) y sigue vivo, no se oculta
  update guide.articles set published_at = now() + interval '1 day' where id = a2;
  if not guide.article_is_live((select status from guide.articles where id = a2), (select published_at from guide.articles where id = a2)) then
    raise exception 'FAIL F6.19 5: published_at futuro oculta un publicado'; end if;
  begin update guide.articles set status = 'draft' where id = a2;
    raise exception 'FAIL F6.19 5: published → draft con borrador';
  exception when sqlstate 'PT423' then null; end;
  if not guide.article_is_live((select status from guide.articles where id = a2), (select published_at from guide.articles where id = a2))
     or not guide.article_is_live((select status from guide.articles where id = a5), (select published_at from guide.articles where id = a5)) then
    raise exception 'FAIL F6.19 5: el rechazo dejó efectos'; end if;
  -- Sin borrador se sigue permitiendo
  update guide.articles set status = 'scheduled', published_at = now() + interval '1 day' where id = a3;
  if guide.article_is_live((select status from guide.articles where id = a3), (select published_at from guide.articles where id = a3)) then
    raise exception 'FAIL F6.19 5: sin borrador no reprograma'; end if;
  -- unpublish_article sigue funcionando con borrador pendiente (lo aplica y despublica)
  perform guide.unpublish_article(a2);
  if (select status::text from guide.articles where id = a2) <> 'draft'
     or (select excerpt_es from guide.articles where id = a2) <> 'F619 d'
     or exists (select 1 from guide.content_drafts where entity = 'article' and entity_id = a2) then
    raise exception 'FAIL F6.19 5: unpublish_article con borrador'; end if;
  if (select pg_get_triggerdef(t.oid) from pg_trigger t
      where t.tgrelid = 'guide.articles'::regclass and t.tgname = 'articles_unpublish_guard') not like '%UPDATE OF status, published_at%' then
    raise exception 'FAIL F6.19 5: trigger sin published_at'; end if;
end $$;
reset role;

-- ── Punto 4: los 18 casos de href/src en legales (postgres, mantenimiento) ──
select set_config('guide.draft_op', 'maintenance', true);
do $$
declare
  r record;
  v_rejected boolean;
  v_n integer;
begin
  for r in select * from (values
    (1, '<p><a href="/&#47;evil.test">x</a></p>', true),
    (2, '<p><a href="/' || chr(9) || '/evil.test">x</a></p>', true),
    (3, '<p><a href="/' || chr(10) || '/evil.test">x</a></p>', true),
    (4, '<p><a href="/&#92;evil.test">x</a></p>', true),
    (5, '<p><a href="//evil.test">x</a></p>', true),
    (6, '<p><a href="javascript:alert(1)">x</a></p>', true),
    (7, '<p><a href="&#106;avascript:alert(1)">x</a></p>', true),
    (8, '<p><a href=" javascript:alert(1)">x</a></p>', true),
    (9, '<p><a href="https:&#47;&#47;evil.test">x</a></p>', true),
    (10, '<p><a href="/&amp;x">x</a></p>', true),            -- falso positivo aceptado
    (11, '<p><a href= "https://chalkguide.test">x</a></p>', false),
    (12, '<p><a href = "https://chalkguide.test">x</a></p>', false),
    (13, '<p><a href="/privacidad">x</a></p>', false),
    (14, '<p><a href="/ruta?a=1">x</a></p>', false),
    (15, '<p><a href="#s1">x</a></p>', false),
    (16, '<p><a href="mailto:hola@chalkguide.test">x</a></p>', false),
    (17, '<p><a href=https://chalkguide.test>x</a></p>', false),
    (18, '<p><a href="/%2f/evil">x</a></p>', false)           -- inocuo: no se convierte en //
  ) c(n, html, expect_reject) loop
    -- es
    begin
      update guide.pages set body_html_es = r.html where key = 'cookies';
      get diagnostics v_n = row_count;
      if v_n <> 1 then raise exception 'FAIL F6.19 4: no hay página cookies'; end if;
      v_rejected := false;
    exception when check_violation then v_rejected := true; end;
    if v_rejected <> r.expect_reject then raise exception 'FAIL F6.19 4: caso % es (rechazado=%)', r.n, v_rejected; end if;
    -- en
    begin
      update guide.pages set body_html_en = r.html where key = 'cookies';
      v_rejected := false;
    exception when check_violation then v_rejected := true; end;
    if v_rejected <> r.expect_reject then raise exception 'FAIL F6.19 4: caso % en (rechazado=%)', r.n, v_rejected; end if;
  end loop;
end $$;
select set_config('guide.draft_op', '', true);

-- ── Punto 6: desempate determinista, igual en vista y preview (admin) ──
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  r record;
  v_prev smallint;
  v_a smallint;
  v_b smallint;
begin
  if (select count(*) from guide.gym_indices where monthly_cost_2pw_eur is not null) < guide.gym_price_quintile_min() then
    raise exception 'FAIL F6.19 6: no hay quintiles'; end if;
  for r in select item_id, price_index from guide.gym_indices where monthly_cost_2pw_eur is not null loop
    select p.price_index into v_prev from guide.gym_indices_preview(r.item_id) p;
    if v_prev is distinct from r.price_index then
      raise exception 'FAIL F6.19 6: preview % <> vista % en %', v_prev, r.price_index, r.item_id; end if;
  end loop;
  if exists (select 1 from guide.gym_indices a join guide.gym_indices b using (item_id)
             where a.price_index is distinct from b.price_index) then
    raise exception 'FAIL F6.19 6: vista no estable'; end if;
  -- Empate: el de menor item_id ordena antes (ntile menor → índice igual o mayor)
  select price_index into v_a from guide.gym_indices where item_id = 'f6190000-0000-4000-8000-000000000001';
  select price_index into v_b from guide.gym_indices where item_id = 'f6190000-0000-4000-8000-000000000002';
  if v_a is null or v_b is null or v_a < v_b then
    raise exception 'FAIL F6.19 6: desempate por item_id (% / %)', v_a, v_b; end if;
end $$;
reset role;

-- ── Punto 7: invisibles en los extremos de marca/modelo y «'» en affiliate_url (postgres) ──
do $$
declare
  cp integer;
  v_val text;
  v_col text;
begin
  foreach cp in array array[x'00AD'::int, x'034F'::int, x'115F'::int, x'1160'::int, x'17B4'::int, x'17B5'::int,
                            x'180B'::int, x'180D'::int, x'2066'::int, x'2069'::int, x'3164'::int, x'FFA0'::int,
                            x'E0000'::int, x'E0001'::int, x'E007F'::int, x'00A0'::int, x'200B'::int, x'FEFF'::int,
                            x'061C'::int] loop
    foreach v_col in array array['brand', 'model'] loop
      foreach v_val in array array[chr(cp) || 'F619', 'F619' || chr(cp)] loop
        begin
          execute format('update guide.shoes set %I = $1 where item_id = %L', v_col, 'f6190000-0000-4000-8000-000000000101') using v_val;
          raise exception 'FAIL F6.19 7: % acepta U+%', v_col, upper(to_hex(cp));
        exception when check_violation then null; end;
      end loop;
    end loop;
  end loop;
  -- Dentro del texto sí se admite (no es un extremo) y los nombres normales pasan
  update guide.shoes set brand = 'La' || chr(x'00AD'::int) || 'Sportiva', model = 'Solution Comp'
  where item_id = 'f6190000-0000-4000-8000-000000000101';
  begin
    update guide.shoes set affiliate_url = 'https://tienda.test/a' || chr(39) || 'b' where item_id = 'f6190000-0000-4000-8000-000000000101';
    raise exception 'FAIL F6.19 7: affiliate_url acepta comilla simple';
  exception when check_violation then null; end;
  update guide.shoes set affiliate_url = 'https://tienda.test/p(1)?a=1&b=2#x' where item_id = 'f6190000-0000-4000-8000-000000000101';
end $$;

-- ── Punto 8: purga semanal de cron, job_health, check_review_photos_cleanup y cleanup_* ──
do $$
declare v_s integer;
begin
  if not exists (select 1 from cron.job where jobname = 'guide-cron-history-purge' and schedule = '0 4 * * 0'
                 and username = 'postgres' and active
                 and command = 'delete from cron.job_run_details where end_time < now() - interval ''30 days''') then
    raise exception 'FAIL F6.19 8: falta guide-cron-history-purge'; end if;
  if not exists (select 1 from cron.job where jobname = 'guide-review-photos-cleanup-check' and schedule = '20 3 * * *'
                 and username = 'postgres' and active and command = 'select guide.check_review_photos_cleanup()') then
    raise exception 'FAIL F6.19 8: falta guide-review-photos-cleanup-check'; end if;
  if not (select relrowsecurity from pg_class where oid = 'guide.job_health'::regclass) then
    raise exception 'LEAK F6.19 8: job_health sin RLS'; end if;
  if has_table_privilege('anon', 'guide.job_health', 'select')
     or has_table_privilege('authenticated', 'guide.job_health', 'insert')
     or has_table_privilege('authenticated', 'guide.job_health', 'update')
     or has_table_privilege('authenticated', 'guide.job_health', 'delete')
     or has_table_privilege('service_role', 'guide.job_health', 'select') then
    raise exception 'LEAK F6.19 8: grants de job_health'; end if;
  if (select p.prosecdef or not coalesce(p.proconfig @> array['search_path=""'], false)
      from pg_proc p where p.oid = 'guide.check_review_photos_cleanup()'::regprocedure) then
    raise exception 'FAIL F6.19 8: check_review_photos_cleanup no es INVOKER con search_path vacío'; end if;
  if has_function_privilege('anon', 'guide.check_review_photos_cleanup()', 'execute')
     or has_function_privilege('authenticated', 'guide.check_review_photos_cleanup()', 'execute')
     or has_function_privilege('service_role', 'guide.check_review_photos_cleanup()', 'execute') then
    raise exception 'LEAK F6.19 8: EXECUTE de check_review_photos_cleanup'; end if;
  -- Sin respuesta para el id guardado (caducada o job sin ejecutar): estado null y fecha de comprobación ahora
  insert into guide.job_health (job, request_id) values ('review-photos-cleanup', -619)
  on conflict (job) do update set request_id = excluded.request_id;
  v_s := guide.check_review_photos_cleanup();
  if v_s is not null or (select status_code from guide.job_health where job = 'review-photos-cleanup') is not null
     or (select checked_at from guide.job_health where job = 'review-photos-cleanup') < now() then
    raise exception 'FAIL F6.19 8: comprobación sin respuesta'; end if;
  -- Respuesta 401 (secreto desincronizado): se copia tal cual
  insert into net._http_response (id, status_code, created) values (-619, 401, now());
  v_s := guide.check_review_photos_cleanup();
  if v_s is distinct from 401 or (select status_code from guide.job_health where job = 'review-photos-cleanup') <> 401 then
    raise exception 'FAIL F6.19 8: no copia el 401'; end if;
end $$;

-- anon: sin lectura de job_health; no admin: 0 filas; admin: la ve en la tabla y en admin_dashboard_stats
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin perform 1 from guide.job_health; raise exception 'LEAK F6.19 8: anon lee job_health';
  exception when insufficient_privilege then null; end;
  begin perform guide.check_review_photos_cleanup(); raise exception 'LEAK F6.19 8: anon ejecuta la comprobación';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  if exists (select 1 from guide.job_health) then raise exception 'LEAK F6.19 8: no admin lee job_health'; end if;
  begin perform guide.check_review_photos_cleanup(); raise exception 'LEAK F6.19 8: no admin ejecuta la comprobación';
  exception when insufficient_privilege then null; end;
  begin update guide.job_health set status_code = 200; raise exception 'LEAK F6.19 8: no admin escribe job_health';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare s jsonb := guide.admin_dashboard_stats();
begin
  if not (s ? 'cleanup_last_status' and s ? 'cleanup_checked_at')
     or (s ->> 'cleanup_last_status')::int is distinct from 401
     or (s ->> 'cleanup_checked_at')::timestamptz is distinct from (select checked_at from guide.job_health where job = 'review-photos-cleanup') then
    raise exception 'FAIL F6.19 8: cleanup_* en admin_dashboard_stats (%)', s ->> 'cleanup_last_status'; end if;
  begin insert into guide.job_health (job) values ('f619'); raise exception 'LEAK F6.19 8: admin inserta en job_health';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- ── B1 y B2: EXECUTE ──
do $$
declare v_p regprocedure;
begin
  foreach v_p in array array['guide.items_publish_ready()'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('authenticated', v_p, 'execute')
       or has_function_privilege('service_role', v_p, 'execute')
       or exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = v_p and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      raise exception 'LEAK F6.19 B1: EXECUTE en %', v_p; end if;
  end loop;
  foreach v_p in array array['guide.admin_dashboard_stats()'::regprocedure, 'guide.mark_reviews_seen()'::regprocedure,
                             'guide.get_my_review(uuid)'::regprocedure,
                             'guide.submit_user_review(uuid, integer, jsonb, text, guide.locale)'::regprocedure] loop
    if has_function_privilege('service_role', v_p, 'execute') then
      raise exception 'LEAK F6.19 B2: service_role ejecuta %', v_p; end if;
    if not has_function_privilege('authenticated', v_p, 'execute') then
      raise exception 'FAIL F6.19 B2: authenticated perdió EXECUTE en %', v_p; end if;
  end loop;
end $$;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin F6.19

-- ═════════════ D66 p_related y D69 analítica propia (guide.analytics_*, sin IP ni identificadores) ═════════════
-- p_related en admin_list_subscribers (faceta); analytics_events / _daily / _event_rate: solo track_event escribe, lista
-- cerrada, rutas y slugs sin tokens, tope global por minuto, newsletter_confirmed solo desde confirm_newsletter, purga a
-- agregado diario (90 días / 24 meses) y RPC agregadas solo admin.
savepoint d69_guard;
release savepoint d69_guard;

-- Catálogo (postgres)
do $$
declare v_p regprocedure; v_t text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if to_regprocedure('guide.admin_list_subscribers(text,text,text[],guide.locale,text,timestamptz,timestamptz,integer[],guide.subscriber_status[],text,integer,integer)') is not null then
    raise exception 'FAIL D66 p_related: sigue la firma antigua de admin_list_subscribers'; end if;
  v_p := 'guide.admin_list_subscribers(text,text,text[],guide.locale,text,timestamptz,timestamptz,integer[],guide.subscriber_status[],text,integer,integer,guide.related_consent_status[])'::regprocedure;
  if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('service_role', v_p, 'execute')
     or not has_function_privilege('authenticated', v_p, 'execute') then
    raise exception 'LEAK D66 p_related: EXECUTE de admin_list_subscribers'; end if;
  -- Columnas exactas: nada de IP, user agent, sesión, usuario ni email
  if (select string_agg(column_name, ',' order by ordinal_position) from information_schema.columns
      where table_schema = 'guide' and table_name = 'analytics_events')
     <> 'id,occurred_at,name,path,locale,content_type,content_slug,pillar,partner,source,device' then
    raise exception 'LEAK D69: columnas de analytics_events'; end if;
  foreach v_t in array array['analytics_events', 'analytics_events_daily', 'analytics_event_rate'] loop
    if not (select c.relrowsecurity from pg_class c where c.oid = ('guide.' || v_t)::regclass) then
      raise exception 'LEAK D69: RLS desactivada en %', v_t; end if;
    if has_table_privilege('anon', 'guide.' || v_t, 'select, insert, update, delete, truncate')
       or has_table_privilege('service_role', 'guide.' || v_t, 'select, insert, update, delete, truncate')
       or has_table_privilege('authenticated', 'guide.' || v_t, 'insert, update, delete, truncate') then
      raise exception 'LEAK D69: privilegios de tabla en %', v_t; end if;
  end loop;
  if has_table_privilege('authenticated', 'guide.analytics_event_rate', 'select')
     or exists (select 1 from pg_policies where schemaname = 'guide' and tablename = 'analytics_event_rate') then
    raise exception 'LEAK D69: analytics_event_rate legible'; end if;
  if exists (select 1 from pg_policies where schemaname = 'guide' and tablename in ('analytics_events', 'analytics_events_daily')
             and (cmd <> 'SELECT' or roles <> '{authenticated}' or qual not like '%is_admin()%')) then
    raise exception 'LEAK D69: policies de analytics_events'; end if;
  v_p := 'guide.track_event(text,text,text,text,text,text,text,text,text)'::regprocedure;
  if not has_function_privilege('anon', v_p, 'execute') or not has_function_privilege('authenticated', v_p, 'execute')
     or has_function_privilege('service_role', v_p, 'execute')
     or not (select p.prosecdef from pg_proc p where p.oid = v_p) then
    raise exception 'FAIL D69: EXECUTE / SECURITY DEFINER de track_event'; end if;
  foreach v_p in array array['guide.analytics_record(text,text,text,text,text,text,text,text,text,timestamptz)'::regprocedure,
                             'guide.purge_analytics_events()'::regprocedure, 'guide.analytics_rows(date,date)'::regprocedure,
                             'guide.analytics_range(text,text,date,date)'::regprocedure,
                             'guide.analytics_token_safe(text)'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('authenticated', v_p, 'execute')
       or has_function_privilege('service_role', v_p, 'execute')
       or exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = v_p and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      raise exception 'LEAK D69: EXECUTE en %', v_p; end if;
  end loop;
  foreach v_p in array array['guide.admin_analytics_stats(text,text,date,date)'::regprocedure,
                             'guide.admin_analytics_top(text,text,text,date,date,integer)'::regprocedure,
                             'guide.admin_analytics_article_conversion(text,date,date,text,integer)'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('service_role', v_p, 'execute')
       or not has_function_privilege('authenticated', v_p, 'execute') then
      raise exception 'LEAK D69: EXECUTE en %', v_p; end if;
  end loop;
  if not exists (select 1 from cron.job where jobname = 'guide-analytics-purge'
                 and command = 'select guide.purge_analytics_events()') then
    raise exception 'FAIL D69: falta el job de purga'; end if;
end $$;

-- p_related (admin): filtra, null = todos, related_counts es faceta (no depende de p_related)
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare j jsonb; j2 jsonb;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  j2 := guide.admin_list_subscribers('all', 'rls-d66-');
  j := guide.admin_list_subscribers('all', 'rls-d66-', p_related => array['withdrawn']::guide.related_consent_status[]);
  if (j ->> 'total_count')::int < 1
     or exists (select 1 from jsonb_array_elements(j -> 'rows') x where x ->> 'related_status' <> 'withdrawn')
     or (j ->> 'total_count')::int <> (j2 -> 'related_counts' ->> 'withdrawn')::int then
    raise exception 'FAIL D66 p_related: filtro withdrawn (%)', j ->> 'total_count'; end if;
  if j -> 'related_counts' <> j2 -> 'related_counts' then
    raise exception 'FAIL D66 p_related: related_counts no es faceta'; end if;
  j := guide.admin_list_subscribers('all', 'rls-d66-', p_related => array['granted', 'none']::guide.related_consent_status[]);
  if (j ->> 'total_count')::int <> (j2 -> 'related_counts' ->> 'granted')::int + (j2 -> 'related_counts' ->> 'none')::int then
    raise exception 'FAIL D66 p_related: varios valores'; end if;
  if guide.admin_list_subscribers('all', 'rls-d66-', p_related => null) ->> 'total_count' <> j2 ->> 'total_count' then
    raise exception 'FAIL D66 p_related: null no es todos'; end if;
  begin
    perform guide.admin_list_subscribers('all', p_related => array['none', 'none', 'none', 'none', 'none']::guide.related_consent_status[]);
    raise exception 'FAIL D66 p_related: acepta más de 4 valores';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;

-- anon: escribe solo por track_event, valida en silencio, no lee nada ni llama a lo interno
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  -- Válido: la query y el hash se cortan, la ruta pasa a minúsculas, el socio se ignora fuera de affiliate_click
  perform guide.track_event('page_view', '/RLS-D69/?email=a@b.example#x', 'es', 'article', 'rls-d69-art', null, 'barrabes',
                            'organic', 'mobile');
  -- Inválidos: no escriben y no fallan
  perform guide.track_event('newsletter_confirmed', '/rls-d69-bad-nc', 'es');
  perform guide.track_event('purchase', '/rls-d69-bad-name', 'es');
  perform guide.track_event(null, '/rls-d69-bad-null', 'es');
  perform guide.track_event('page_view', '/administrador/rls-d69-bad', 'es');
  perform guide.track_event('page_view', '/en/administrador', 'es');
  perform guide.track_event('page_view', '/api/rls-d69-bad', 'es');
  perform guide.track_event('page_view', 'rls-d69-bad-relative', 'es');
  perform guide.track_event('page_view', '/rls-d69-bad/0123456789abcdef0123456789abcdef', 'es');
  perform guide.track_event('page_view', '/rls-d69-bad/a0000000-0000-4000-8000-000000000002', 'es');
  perform guide.track_event('page_view', '/rls-d69-bad/612345678', 'es');
  perform guide.track_event('page_view', '/rls-d69-bad/pepe@gmail.com', 'es');
  perform guide.track_event('page_view', '/rls-d69-bad-' || repeat('x', 2000), 'es');
  perform guide.track_event('page_view', '/rls-d69-bad-locale', 'fr');
  perform guide.track_event('page_view', '/rls-d69-bad-ctype', 'es', 'rope');
  perform guide.track_event('page_view', '/rls-d69-bad-slug', 'es', 'article', 'a0000000-0000-4000-8000-000000000002');
  perform guide.track_event('page_view', '/rls-d69-bad-slug2', 'es', 'article', 'Pepe Pérez');
  perform guide.track_event('page_view', '/rls-d69-bad-pillar', 'es', 'article', 'x', 'rls-no-existe');
  perform guide.track_event('page_view', '/rls-d69-bad-source', 'es', null, null, null, null, 'https://google.com/?q=x');
  perform guide.track_event('page_view', '/rls-d69-bad-device', 'es', null, null, null, null, null, 'tablet');
  perform guide.track_event('search_blog', '/rls-d69-search', 'es', null, 'texto-buscado');
  begin perform 1 from guide.analytics_events; raise exception 'LEAK D69 anon: lee analytics_events';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.analytics_events_daily; raise exception 'LEAK D69 anon: lee analytics_events_daily';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.analytics_event_rate; raise exception 'LEAK D69 anon: lee analytics_event_rate';
  exception when insufficient_privilege then null; end;
  begin insert into guide.analytics_events (name, path, locale) values ('page_view', '/rls-d69-direct', 'es');
    raise exception 'LEAK D69 anon: INSERT directo'; exception when insufficient_privilege then null; end;
  begin perform guide.analytics_record('newsletter_confirmed', '/rls-d69-direct', 'es', null, null, null, null, null, null);
    raise exception 'LEAK D69 anon: llama a analytics_record'; exception when insufficient_privilege then null; end;
  begin perform guide.purge_analytics_events(); raise exception 'LEAK D69 anon: llama a la purga';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_stats(); raise exception 'LEAK D69 anon: admin_analytics_stats';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_top(); raise exception 'LEAK D69 anon: admin_analytics_top';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_article_conversion(); raise exception 'LEAK D69 anon: admin_analytics_article_conversion';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- authenticated sin rol de admin: escribe por track_event, no ve filas ni agregados, no actualiza
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$
declare n int;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  perform guide.track_event('scroll_75', '/rls-d69-user', 'en', 'article', 'rls-d69-art');
  select count(*) into n from guide.analytics_events;
  if n <> 0 then raise exception 'LEAK D69 user: ve % eventos', n; end if;
  select count(*) into n from guide.analytics_events_daily;
  if n <> 0 then raise exception 'LEAK D69 user: ve % agregados', n; end if;
  begin update guide.analytics_events set path = '/x'; raise exception 'LEAK D69 user: UPDATE';
  exception when insufficient_privilege then null; end;
  begin delete from guide.analytics_events; raise exception 'LEAK D69 user: DELETE';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_stats(); raise exception 'LEAK D69 user: admin_analytics_stats';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_top(); raise exception 'LEAK D69 user: admin_analytics_top';
  exception when insufficient_privilege then null; end;
  begin perform guide.admin_analytics_article_conversion(); raise exception 'LEAK D69 user: admin_analytics_article_conversion';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Lo escrito (postgres) y tope de tasa (now() es fijo dentro de la transacción: mismo minuto)
do $$
declare r record;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if exists (select 1 from guide.analytics_events where path like '/rls-d69-bad%' or path like '/administrador%'
             or path like '/en/administrador%' or path like '/api/%'
             -- newsletter_confirmed legítimo: lo registra confirm_newsletter en bloques anteriores; el intento por
             -- track_event va con ruta /rls-d69-bad-nc y lo cubre la primera condición.
             or (name = 'newsletter_confirmed' and path like '/rls-d69%')
             or path = '/rls-d69-direct') then
    raise exception 'LEAK D69: escribió un evento inválido'; end if;
  select * into r from guide.analytics_events where path = '/rls-d69';
  if r is null or r.name <> 'page_view' or r.locale <> 'es' or r.content_type <> 'article' or r.content_slug <> 'rls-d69-art'
     or r.partner is not null or r.source <> 'organic' or r.device <> 'mobile' then
    raise exception 'FAIL D69: evento válido de anon (%)', r; end if;
  if not exists (select 1 from guide.analytics_events where path = '/rls-d69-search' and content_slug is null)
     or not exists (select 1 from guide.analytics_events where path = '/rls-d69-user' and name = 'scroll_75') then
    raise exception 'FAIL D69: search_blog / scroll_75'; end if;
  -- Tope por nombre (300/min) y total (1.000/min): descarta sin escribir y sin fallar
  insert into guide.analytics_event_rate (bucket, name, n) values (date_trunc('minute', now()), 'video_play', 300)
  on conflict (bucket, name) do update set n = 300;
  perform guide.track_event('video_play', '/rls-d69-rate-name', 'es');
  if exists (select 1 from guide.analytics_events where path = '/rls-d69-rate-name') then
    raise exception 'FAIL D69: no aplica el tope por nombre'; end if;
  perform guide.track_event('outbound_gym', '/rls-d69-rate-ok', 'es');
  if not exists (select 1 from guide.analytics_events where path = '/rls-d69-rate-ok') then
    raise exception 'FAIL D69: el tope de un nombre bloquea otro'; end if;
  insert into guide.analytics_event_rate (bucket, name, n) values (date_trunc('minute', now()), '*', 1000)
  on conflict (bucket, name) do update set n = 1000;
  perform guide.track_event('outbound_gym', '/rls-d69-rate-total', 'es');
  if exists (select 1 from guide.analytics_events where path = '/rls-d69-rate-total') then
    raise exception 'FAIL D69: no aplica el tope total'; end if;
  update guide.analytics_event_rate set n = 0 where bucket = date_trunc('minute', now());
end $$;

-- newsletter_confirmed: solo desde confirm_newsletter (servidor), con artículo de origen y hora truncada; una sola vez
do $$
declare v_slug text; v_pillar text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  select a.slug_es, c.slug_es into v_slug, v_pillar from guide.articles a join guide.article_categories c on c.id = a.category_id
  where a.id = 'd0000000-0000-4000-8000-000000000001';
  insert into guide.subscribers (id, email, consent_at, consent_source, consent_version, consent_page, locale,
                                 confirm_token_hash, confirm_expires_at)
  values ('69690000-0000-4000-8000-000000000001', 'rls-d69-c1@chalkguide.test', now(), 'article', 1, '/en/blog/' || v_slug,
          'en', pg_catalog.sha256(convert_to(repeat('d69a', 16), 'UTF8')), now() + interval '1 day'),
         ('69690000-0000-4000-8000-000000000002', 'rls-d69-c2@chalkguide.test', now(), 'footer', 1, null,
          'es', pg_catalog.sha256(convert_to(repeat('d69b', 16), 'UTF8')), now() + interval '1 day');
end $$;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if guide.confirm_newsletter(repeat('d69a', 16)) <> 'ok' or guide.confirm_newsletter(repeat('d69a', 16)) <> 'ok'
     or guide.confirm_newsletter(repeat('d69b', 16)) <> 'ok' then
    raise exception 'FAIL D69: confirm_newsletter'; end if;
end $$;
reset role;
do $$
declare v_slug text; v_pillar text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  select a.slug_es, c.slug_es into v_slug, v_pillar from guide.articles a join guide.article_categories c on c.id = a.category_id
  where a.id = 'd0000000-0000-4000-8000-000000000001';
  if (select count(*) from guide.analytics_events where name = 'newsletter_confirmed' and path = '/en/blog/' || v_slug
      and locale = 'en' and content_type = 'article' and content_slug = v_slug and pillar = v_pillar
      and occurred_at = date_trunc('hour', now())) <> 1 then
    raise exception 'FAIL D69: newsletter_confirmed del artículo (uno, con slug y pilar, hora truncada)'; end if;
  if (select count(*) from guide.analytics_events where name = 'newsletter_confirmed' and path = '/newsletter/confirmed'
      and locale = 'es' and content_slug is null and pillar is null) <> 1 then
    raise exception 'FAIL D69: newsletter_confirmed sin página de origen'; end if;
  if (select status from guide.subscribers where id = '69690000-0000-4000-8000-000000000001') <> 'active' then
    raise exception 'FAIL D69: confirm_newsletter no activa'; end if;
end $$;

-- Retención (postgres): bruto > 90 días al agregado diario (acumula), agregado > 24 meses y tasa > 1 h fuera
do $$
declare v_day date := ((now() - interval '100 days') at time zone 'Europe/Madrid')::date; v_n bigint;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  insert into guide.analytics_events (occurred_at, name, path, locale, content_type, content_slug)
  values (now() - interval '100 days', 'page_view', '/rls-d69-old', 'es', 'article', 'rls-d69-old'),
         (now() - interval '100 days', 'page_view', '/rls-d69-old', 'es', 'article', 'rls-d69-old'),
         (now() - interval '100 days', 'newsletter_submit', '/rls-d69-old', 'es', 'article', 'rls-d69-old'),
         (now() - interval '89 days', 'page_view', '/rls-d69-recent', 'es', null, null);
  insert into guide.analytics_events_daily (day, name, path, locale, n)
  values ((now() at time zone 'Europe/Madrid')::date - interval '25 months', 'page_view', '/rls-d69-ancient', 'es', 5);
  insert into guide.analytics_event_rate (bucket, name, n) values (date_trunc('minute', now() - interval '2 hours'), 'page_view', 9);
  v_n := guide.purge_analytics_events();
  if v_n < 3 or exists (select 1 from guide.analytics_events where occurred_at < now() - interval '90 days')
     or not exists (select 1 from guide.analytics_events where path = '/rls-d69-recent') then
    raise exception 'FAIL D69: purga del bruto (%)', v_n; end if;
  if (select n from guide.analytics_events_daily where day = v_day and name = 'page_view' and path = '/rls-d69-old'
      and content_slug = 'rls-d69-old' and pillar is null and source is null) <> 2
     or (select n from guide.analytics_events_daily where day = v_day and name = 'newsletter_submit' and path = '/rls-d69-old') <> 1 then
    raise exception 'FAIL D69: agregado diario'; end if;
  if exists (select 1 from guide.analytics_events_daily where path = '/rls-d69-ancient')
     or exists (select 1 from guide.analytics_event_rate where name <> '*day' and bucket < now() - interval '1 hour') then
    raise exception 'FAIL D69: purga de agregado > 24 meses o de tasa'; end if;
  -- Una segunda pasada suma en la misma fila (cada evento se cuenta una vez)
  insert into guide.analytics_events (occurred_at, name, path, locale, content_type, content_slug)
  values (now() - interval '100 days', 'page_view', '/rls-d69-old', 'es', 'article', 'rls-d69-old');
  perform guide.purge_analytics_events();
  if (select n from guide.analytics_events_daily where day = v_day and name = 'page_view' and path = '/rls-d69-old') <> 3 then
    raise exception 'FAIL D69: el agregado no acumula'; end if;
end $$;

-- Admin: lectura directa y RPC agregadas (bruto + agregado sin solaparse), validación de rango
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$
declare
  j       jsonb;
  v_day   date := ((now() - interval '100 days') at time zone 'Europe/Madrid')::date;
  v_today date := (now() at time zone 'Europe/Madrid')::date;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  if not exists (select 1 from guide.analytics_events where path = '/rls-d69')
     or not exists (select 1 from guide.analytics_events_daily where path = '/rls-d69-old') then
    raise exception 'FAIL D69 admin: lectura directa'; end if;
  begin insert into guide.analytics_events (name, path, locale) values ('page_view', '/rls-d69-admin', 'es');
    raise exception 'LEAK D69 admin: INSERT directo'; exception when insufficient_privilege then null; end;
  begin perform 1 from guide.analytics_event_rate; raise exception 'LEAK D69 admin: lee analytics_event_rate';
  exception when insufficient_privilege then null; end;

  j := guide.admin_analytics_stats('30d', 'day');
  if jsonb_array_length(j -> 'series') <> 30 or (select count(*) from jsonb_object_keys(j -> 'current_totals')) <> 12
     or (j -> 'current_totals' ->> 'page_view')::int < 1 or (j -> 'current_totals' ->> 'newsletter_confirmed')::int < 2
     or (j -> 'breakdowns' -> 'page_view_by_source' ->> 'organic')::int < 1 or j -> 'previous' -> 'totals' is null
     or (j -> 'series' -> 29 ->> 'partial')::boolean is not true then
    raise exception 'FAIL D69 admin: admin_analytics_stats 30d (%)', j -> 'current_totals'; end if;
  j := guide.admin_analytics_stats('12m', 'month');
  if jsonb_array_length(j -> 'series') <> 12 or (j -> 'current_totals' ->> 'page_view')::int < 3 then
    raise exception 'FAIL D69 admin: 12m incluye el agregado (%)', j -> 'current_totals'; end if;
  j := guide.admin_analytics_stats(null, 'day', v_day, v_day);
  if (j -> 'current_totals' ->> 'page_view')::int < 3 or (j -> 'current_totals' ->> 'newsletter_submit')::int < 1 then
    raise exception 'FAIL D69 admin: día agregado (%)', j -> 'current_totals'; end if;
  begin perform guide.admin_analytics_stats('30d', 'month'); raise exception 'FAIL D69 admin: 30d por mes';
  exception when invalid_parameter_value then null; end;
  begin perform guide.admin_analytics_stats(null, 'month', (v_today - interval '25 months')::date, v_today);
    raise exception 'FAIL D69 admin: rango > 24 meses'; exception when invalid_parameter_value then null; end;
  begin perform guide.admin_analytics_stats(null, 'day', v_today, v_today + 1);
    raise exception 'FAIL D69 admin: rango futuro'; exception when invalid_parameter_value then null; end;
  begin perform guide.admin_analytics_stats('7d', 'day'); raise exception 'FAIL D69 admin: rango libre';
  exception when invalid_parameter_value then null; end;

  j := guide.admin_analytics_top('page_view', 'path', null, v_day, v_day);
  if not exists (select 1 from jsonb_array_elements(j -> 'rows') x where x ->> 'path' = '/rls-d69-old' and (x ->> 'n')::int = 3) then
    raise exception 'FAIL D69 admin: top por ruta (%)', j -> 'rows'; end if;
  j := guide.admin_analytics_top('page_view', 'content', null, v_today, v_today, 50);
  if not exists (select 1 from jsonb_array_elements(j -> 'rows') x where x ->> 'content_slug' = 'rls-d69-art') then
    raise exception 'FAIL D69 admin: top por contenido'; end if;
  begin perform guide.admin_analytics_top('purchase'); raise exception 'FAIL D69 admin: top con nombre libre';
  exception when invalid_parameter_value then null; end;
  begin perform guide.admin_analytics_top('page_view', 'email'); raise exception 'FAIL D69 admin: top con grupo libre';
  exception when invalid_parameter_value then null; end;
  begin perform guide.admin_analytics_top(p_limit => 51); raise exception 'FAIL D69 admin: top sin tope';
  exception when invalid_parameter_value then null; end;

  j := guide.admin_analytics_article_conversion(null, v_day, v_day, 'rate', 100);
  if not exists (select 1 from jsonb_array_elements(j -> 'rows') x where x ->> 'content_slug' = 'rls-d69-old'
                 and (x ->> 'page_views')::int = 3 and (x ->> 'newsletter_submits')::int = 1
                 and (x ->> 'rate')::numeric = 0.3333) then
    raise exception 'FAIL D69 admin: conversión por artículo (%)', j -> 'rows'; end if;
  begin perform guide.admin_analytics_article_conversion(p_sort => 'email'); raise exception 'FAIL D69 admin: orden libre';
  exception when invalid_parameter_value then null; end;
end $$;
reset role;
-- Veto D69 (docs/security/D69-analytics-events-review.md). V2: hora truncada en todos y sin source/device en los tres
-- eventos que casan con una fila identificable. V1: tope diario global '*day' (20 000/día UTC) y señal de salud.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  perform guide.track_event('newsletter_submit', '/rls-d69v-submit', 'es', 'article', 'rls-d69-art', null, null, 'social', 'mobile');
  perform guide.track_event('review_submitted', '/rls-d69v-review', 'es', 'gym', 'rls-d69-gym', null, null, 'organic', 'desktop');
  perform guide.track_event('login_for_review', '/rls-d69v-login', 'en', 'gym', 'rls-d69-gym', null, null, 'email', 'mobile');
  perform guide.track_event('page_view', '/rls-d69v-view', 'es', null, null, null, null, 'social', 'mobile');
end $$;
reset role;
do $$
declare v_job record;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos';
  end if;
  -- V2: truncado a la hora (todo lo escrito por track_event y confirm_newsletter en esta suite)
  if (select count(*) from guide.analytics_events where path like '/rls-d69v-%') <> 4
     or exists (select 1 from guide.analytics_events
                where (path like '/rls-d69v-%' or path in ('/rls-d69', '/rls-d69-search', '/rls-d69-user', '/rls-d69-rate-ok')
                       or name = 'newsletter_confirmed')
                  and occurred_at <> date_trunc('hour', occurred_at)) then
    raise exception 'FAIL veto D69 V2: occurred_at sin truncar a la hora'; end if;
  if exists (select 1 from guide.analytics_events where path in ('/rls-d69v-submit', '/rls-d69v-review', '/rls-d69v-login')
             and (source is not null or device is not null))
     or not exists (select 1 from guide.analytics_events where path = '/rls-d69v-view' and source = 'social' and device = 'mobile') then
    raise exception 'FAIL veto D69 V2: source/device en submit, review o login'; end if;
  -- V1: con el tope diario alcanzado no se escribe; la señal de salud lo avisa; '*day' sobrevive a la purga horaria
  insert into guide.analytics_event_rate (bucket, name, n) values (date_trunc('day', now(), 'UTC'), '*day', 20000)
  on conflict (bucket, name) do update set n = 20000;
  perform guide.track_event('page_view', '/rls-d69v-daycap', 'es');
  if exists (select 1 from guide.analytics_events where path = '/rls-d69v-daycap') then
    raise exception 'FAIL veto D69 V1: no aplica el tope diario'; end if;
  insert into guide.analytics_event_rate (bucket, name, n)
  values (date_trunc('day', now(), 'UTC') - interval '3 days', '*day', 7);
  perform guide.purge_analytics_events();
  select * into v_job from guide.job_health where job = 'analytics';
  if v_job is null or v_job.status_code <> 500 or not (v_job.details -> 'alerts') ? 'daily_cap_reached'
     or (v_job.details ->> 'today_attempts')::int <= 20000 then
    raise exception 'FAIL veto D69 V1: señal de salud con tope (%)', v_job.details; end if;
  if not exists (select 1 from guide.analytics_event_rate where name = '*day' and bucket = date_trunc('day', now(), 'UTC'))
     or exists (select 1 from guide.analytics_event_rate where name = '*day'
                and bucket < date_trunc('day', now(), 'UTC') - interval '2 days') then
    raise exception 'FAIL veto D69 V1: purga de *day'; end if;
  update guide.analytics_event_rate set n = 0 where name = '*day';
  perform guide.purge_analytics_events();
  if (select status_code from guide.job_health where job = 'analytics') <> 200 then
    raise exception 'FAIL veto D69 V1: señal de salud sin tope'; end if;
  perform guide.track_event('page_view', '/rls-d69v-after', 'es');
  if not exists (select 1 from guide.analytics_events where path = '/rls-d69v-after') then
    raise exception 'FAIL veto D69 V1: bajo el tope no escribe'; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin D69

-- ═════════════ F8 · ingesta (docs/security/F8.1-ingest-spec.md, J1–J40), noticias y newsletter ═════════════
-- Una sola transacción de la suite; los roles se cambian dentro del DO (set_config('role')). Sin barras invertidas en el
-- SQL (los caracteres especiales van con chr()). Fixtures propios: fuente f8test.org, rocódromo f8000000-….
-- Antes de nada se neutralizan, solo dentro de esta transacción, los tokens y runs reales (topes globales J4/J30/J31).
-- V2 (D66): todo dentro de DO con la marca de suite, para que nada haga COMMIT fuera de la transacción explícita.
do $$
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos'; end if;
  perform set_config('guide.draft_op', 'maintenance', true);
  update guide.ingest_tokens set revoked_at = coalesce(revoked_at, now()) where revoked_at is null;
  update guide.ingest_runs set status = 'abandoned', finished_at = now() where status = 'open';
  delete from guide.ingest_runs where started_at > now() - interval '24 hours';
  insert into guide.items (id, category, name, slug, published)
  values ('f8000000-0000-4000-8000-000000000001', 'gym', 'F8 gym', 'rls-f8-gym', true);
  insert into guide.gyms (item_id, city) values ('f8000000-0000-4000-8000-000000000001', 'Barcelona');
  perform set_config('guide.draft_op', '', true);
end $$;

-- ── Estático: J8, J9, J22, J25, J35 ──
do $$
declare v_p regprocedure; v_src text;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos'; end if;
  foreach v_p in array array[
    'guide.ingest_start_run(text, text, boolean)'::regprocedure, 'guide.ingest_context(text)'::regprocedure,
    'guide.ingest_submit_event(text, uuid, jsonb)'::regprocedure, 'guide.ingest_submit_news(text, uuid, jsonb)'::regprocedure,
    'guide.ingest_submit_newsletter_intro(text, uuid, jsonb)'::regprocedure,
    'guide.ingest_finish_run(text, uuid, jsonb, text)'::regprocedure] loop
    if (select p.provolatile from pg_proc p where p.oid = v_p) <> 'v' then
      raise exception 'FAIL F8 J8: % no es VOLATILE', v_p; end if;
    if not (select p.prosecdef from pg_proc p where p.oid = v_p) then
      raise exception 'FAIL F8: % no es DEFINER', v_p; end if;
    if not has_function_privilege('anon', v_p, 'execute') then
      raise exception 'FAIL F8 J9: anon sin EXECUTE en %', v_p; end if;
    if has_function_privilege('authenticated', v_p, 'execute') or has_function_privilege('service_role', v_p, 'execute')
       or exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = v_p and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      raise exception 'LEAK F8 J9: EXECUTE de más en %', v_p; end if;
    v_src := (select p.prosrc from pg_proc p where p.oid = v_p);
    if v_src ilike '%draft_op%' then raise exception 'LEAK F8 J22: % toca guide.draft_op', v_p; end if;
    if v_src ilike '%net.%' or v_src ilike '%http_%' or v_src ilike '%extensions.http%' then
      raise exception 'LEAK F8 J25: % hace red', v_p; end if;
  end loop;
  foreach v_p in array array[
    'guide.ingest_auth(text)'::regprocedure, 'guide.ingest_run_for(uuid, uuid, text)'::regprocedure,
    'guide.ingest_field_text(jsonb, text, integer, boolean, boolean)'::regprocedure, 'guide.ingest_has_pii(text)'::regprocedure,
    'guide.ingest_has_secret(text, text)'::regprocedure, 'guide.ingest_url(text)'::regprocedure,
    'guide.ingest_norm_title(text)'::regprocedure, 'guide.ingest_dedupe_key(text, date, text)'::regprocedure,
    'guide.ingest_queue_pending()'::regprocedure, 'guide.ingest_count_invalid(uuid, text)'::regprocedure,
    'guide.newsletter_compose(date)'::regprocedure, 'guide.ingest_health_check()'::regprocedure,
    'guide.news_before_write()'::regprocedure, 'guide.news_log_activity()'::regprocedure,
    'guide.ingest_tokens_log()'::regprocedure, 'guide.ingest_newsletter_context(timestamptz)'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('authenticated', v_p, 'execute')
       or has_function_privilege('service_role', v_p, 'execute')
       or exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = v_p and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      raise exception 'LEAK F8 J9: interna % ejecutable desde la API', v_p; end if;
  end loop;
  foreach v_p in array array[
    'guide.admin_create_ingest_token(text, integer)'::regprocedure, 'guide.admin_revoke_ingest_token(uuid)'::regprocedure,
    'guide.admin_list_ingest_tokens()'::regprocedure, 'guide.admin_set_ingest_window(boolean)'::regprocedure,
    'guide.admin_release_event_dedupe(uuid)'::regprocedure, 'guide.admin_release_news_dedupe(uuid)'::regprocedure,
    'guide.admin_list_news(guide.news_status, uuid, guide.news_scope, uuid, uuid, text, uuid, integer, integer)'::regprocedure,
    'guide.admin_news_summary()'::regprocedure, 'guide.compose_issue(date)'::regprocedure,
    'guide.newsletter_quota_today()'::regprocedure, 'guide.approve_news(uuid[])'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or has_function_privilege('service_role', v_p, 'execute') then
      raise exception 'LEAK F8 J9: admin % ejecutable por anon/service_role', v_p; end if;
  end loop;
  if not exists (select 1 from cron.job where jobname = 'guide-ingest-health' and command ilike '%ingest_health_check%') then
    raise exception 'FAIL F8 J35: falta el job guide-ingest-health'; end if;
  if exists (select 1 from information_schema.role_table_grants
             where table_schema = 'guide' and table_name in ('ingest_tokens', 'ingest_runs', 'ingest_config')
               and grantee in ('anon', 'service_role')) then
    raise exception 'LEAK F8 J28: grants de anon/service_role en tablas de ingesta'; end if;
  if exists (select 1 from information_schema.column_privileges
             where table_schema = 'guide' and table_name = 'news' and grantee in ('anon', 'authenticated')
               and privilege_type = 'SELECT'
               and column_name in ('dedupe_key', 'url_key', 'agent_meta', 'run_id', 'source', 'reject_reason',
                                   'approved_by', 'similarity', 'created_at')) then
    raise exception 'LEAK F8 J27: columna interna de news con SELECT para la API'; end if;
end $$;

-- ── Dinámico: J1–J7, J10–J21, J23, J24, J26, J27, J27b, J29–J34, J36, R1 y newsletter ──
do $$
declare
  c_admin constant text := '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}';
  c_user  constant text := '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}';
  c_anon  constant text := '{"role":"anon"}';
  fut  text := to_char((now() + interval '20 days') at time zone 'Europe/Madrid', 'YYYY-MM-DD') || 'T18:00:00+01:00';
  today text := to_char((now() at time zone 'Europe/Madrid')::date, 'YYYY-MM-DD');
  v jsonb; ta text; tb text; tc text; ida uuid; idc uuid; run1 uuid; run2 uuid; run3 uuid; ev uuid; nw uuid; iss uuid;
  i integer; n integer; last jsonb; ctx text;
  ev_base jsonb;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos'; end if;
  -- Admin: tokens (J1, J4), fuente (J24), ventana (R1)
  perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  v := guide.admin_create_ingest_token('rls A', 30); ta := v ->> 'token'; ida := (v ->> 'id')::uuid;
  if ta !~ '^cgi_[0-9a-f]{64}$' or v ->> 'hint' <> right(ta, 4) then raise exception 'FAIL F8 J1: formato del token'; end if;
  begin perform guide.admin_create_ingest_token('rls X', 31); raise exception 'FAIL F8 J4: caducidad > 30 días';
  exception when invalid_parameter_value then null; end;
  tb := guide.admin_create_ingest_token('rls B', 30) ->> 'token';
  begin perform guide.admin_create_ingest_token('rls C', 30); raise exception 'FAIL F8 J4: tercer token vigente';
  exception when object_not_in_prerequisite_state then null; end;
  insert into guide.news_sources (name, domain, url, kind, scope, lang)
  values ('F8 Test', 'f8test.org', 'https://f8test.org/noticias', 'both', 'cat', 'ca');
  perform guide.admin_set_ingest_window(false);

  -- J10 / J9: con usuario (admin o no) no se entra
  begin perform guide.ingest_start_run(ta, 'both', false); raise exception 'LEAK F8 J10: admin llama a ingest_start_run';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims', c_user, true);
  begin perform guide.ingest_context(ta); raise exception 'LEAK F8 J10: authenticated llama a ingest_context';
  exception when insufficient_privilege then null; end;

  -- anon: J3, J6 (error uniforme)
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  foreach v in array array[to_jsonb(''::text), to_jsonb('cgi_x'::text), to_jsonb('cgi_' || repeat('a', 64)),
                           to_jsonb(upper(ta)), to_jsonb(ta || 'a')] loop
    begin perform guide.ingest_start_run(v #>> '{}', 'both', false); raise exception 'LEAK F8 J3: token inválido aceptado';
    exception when insufficient_privilege then
      if sqlerrm <> 'ingest_unauthorized' then raise exception 'FAIL F8 J6: mensaje no uniforme'; end if; end;
  end loop;
  begin perform guide.ingest_start_run(null, 'both', false); raise exception 'LEAK F8 J3: token nulo';
  exception when insufficient_privilege then null; end;

  -- R1: fuera de la ventana (si hoy no es lun/jue 03–12 Madrid) o con la ventana cerrada
  if not (extract(isodow from now() at time zone 'Europe/Madrid') in (1, 4)
          and (now() at time zone 'Europe/Madrid')::time between time '03:00' and time '11:59') then
    if guide.ingest_start_run(ta, 'both', false) ->> 'result' <> 'outside_window' then
      raise exception 'FAIL F8 R1: run fuera de la ventana'; end if;
  end if;
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  perform guide.admin_set_ingest_window(true);

  -- J33: tope global de borradores del agente (como postgres, sin JWT: camino del agente)
  reset role; perform set_config('request.jwt.claims', '', true);
  insert into guide.events (title_es, starts_at, status, source, source_url, dedupe_key, agent_meta)
  select 'F8 cola ' || g, now() + interval '30 days', 'draft', 'agent', 'https://f8test.org/c' || g, 'rls-f8-queue-' || g,
         '{"confidence":0.5}'::jsonb
  from generate_series(1, 151 - guide.ingest_queue_pending()) g;
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  if guide.ingest_start_run(ta, 'both', false) ->> 'result' <> 'queue_full' then
    raise exception 'FAIL F8 J33: sin queue_full con > 150 borradores'; end if;
  reset role; perform set_config('request.jwt.claims', '', true);
  perform set_config('guide.draft_op', 'maintenance', true);
  delete from guide.events where dedupe_key like 'rls-f8-queue-%';
  perform set_config('guide.draft_op', '', true);

  -- Run 1 (J29–J32)
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  v := guide.ingest_start_run(ta, 'both', false);
  if v ->> 'result' <> 'ok' then raise exception 'FAIL F8: start_run %', v ->> 'result'; end if;
  run1 := (v ->> 'run_id')::uuid;
  if guide.ingest_start_run(tb, 'both', false) ->> 'result' <> 'run_open' then
    raise exception 'FAIL F8 J30: segundo run abierto'; end if;
  begin perform guide.ingest_submit_event(tb, run1, '{}'::jsonb); raise exception 'LEAK F8 J29: run de otro token';
  exception when insufficient_privilege then null; end;
  begin perform guide.ingest_submit_event(ta, gen_random_uuid(), '{}'::jsonb); raise exception 'LEAK F8 J29: run inexistente';
  exception when insufficient_privilege then null; end;

  ev_base := jsonb_build_object('title_es', 'F8 evento base', 'starts_at', fut, 'location_text', 'Barcelona',
                                'source_url', 'https://www.f8test.org/agenda/1?utm_source=x&id=7#top', 'confidence', 0.9,
                                'excerpt', 'cita literal', 'item_id', 'f8000000-0000-4000-8000-000000000001');
  v := guide.ingest_submit_event(ta, run1, ev_base);
  if v ->> 'result' <> 'inserted' then raise exception 'FAIL F8: evento válido %', v; end if;

  -- J11: claves prohibidas → fila rechazada
  foreach last in array array['{"status":"approved"}'::jsonb, '{"approved_at":"2026-01-01T00:00:00Z"}'::jsonb,
                              '{"published_at":"2026-01-01T00:00:00Z"}'::jsonb, '{"dedupe_key":"x"}'::jsonb,
                              '{"id":"f8000000-0000-4000-8000-000000000009"}'::jsonb, '{"source":"manual"}'::jsonb,
                              '{"agent_meta":{}}'::jsonb] loop
    v := guide.ingest_submit_event(ta, run1, (ev_base || jsonb_build_object('title_es', 'F8 prohibida')) || last);
    if v ->> 'result' <> 'invalid' or v ->> 'reason' <> 'unknown_key' then
      raise exception 'LEAK F8 J11: clave prohibida aceptada %', last; end if;
  end loop;
  -- J23: URLs
  foreach last in array array[to_jsonb('javascript:alert(1)'::text), to_jsonb('http://f8test.org/a'::text),
                              to_jsonb('https://user@f8test.org/a'::text), to_jsonb('https://10.0.0.1/a'::text),
                              to_jsonb('https://localhost/a'::text), to_jsonb('https://f8test.org:8443/a'::text),
                              to_jsonb('https://[::1]/a'::text), to_jsonb('data:text/html,x'::text)] loop
    v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 url', 'source_url', last));
    if v ->> 'result' <> 'invalid' or v ->> 'reason' <> 'bad_url' then
      raise exception 'LEAK F8 J23: URL aceptada %', last; end if;
  end loop;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 short', 'source_url', 'https://bit.ly/x'));
  if v ->> 'reason' is distinct from 'shortener' then raise exception 'LEAK F8 J23: acortador aceptado'; end if;
  -- J12–J17
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'confidence', '0.9'));
  if v ->> 'reason' is distinct from 'confidence' then raise exception 'LEAK F8 J12: número en texto aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'location_text', jsonb_build_object('a', 1)));
  if v ->> 'reason' is distinct from 'invalid_type' then raise exception 'LEAK F8 J12: objeto anidado aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 ' || repeat('x', 17000)));
  if v ->> 'reason' is distinct from 'too_large' then raise exception 'LEAK F8 J12: payload > 16 KB aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', repeat('x', 201)));
  if v ->> 'reason' is distinct from 'too_long' then raise exception 'LEAK F8 J13: título > 200 aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 ' || chr(8238) || 'bidi'));
  if v ->> 'reason' is distinct from 'bad_chars' then raise exception 'LEAK F8 J14: bidi aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 ' || chr(8203) || 'zw'));
  if v ->> 'reason' is distinct from 'bad_chars' then raise exception 'LEAK F8 J14: zero-width aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 ' || chr(9) || 'tab'));
  if v ->> 'reason' is distinct from 'bad_chars' then raise exception 'LEAK F8 J14: control aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'starts_at', '2027-01-01T10:00:00'));
  if v ->> 'reason' is distinct from 'invalid_date' then raise exception 'LEAK F8 J15: fecha sin zona aceptada'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'starts_at', '2021-01-01T10:00:00Z'));
  if v ->> 'reason' is distinct from 'past' then raise exception 'LEAK F8 J15: evento pasado aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x',
         'starts_at', to_char(now() + interval '20 months', 'YYYY-MM-DD') || 'T10:00:00Z'));
  if v ->> 'reason' is distinct from 'too_far' then raise exception 'LEAK F8 J15: evento a > 18 meses aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'event_type', 'party'));
  if v ->> 'reason' is distinct from 'event_type' then raise exception 'LEAK F8 J15: event_type fuera de lista'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'item_id', 'a0000000-0000-4000-8000-000000000001'));
  if v ->> 'reason' is distinct from 'item' then raise exception 'LEAK F8 J15: item_id que no es rocódromo publicado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'description_es', 'Escribe a nadie' || chr(64) || 'f8test.org'));
  if v ->> 'reason' is distinct from 'pii' then raise exception 'LEAK F8 J16: email aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'note', 'Tel 612 345 678'));
  if v ->> 'reason' is distinct from 'pii' then raise exception 'LEAK F8 J16: teléfono aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'note', ta));
  if v ->> 'reason' is distinct from 'secret' then raise exception 'LEAK F8 J17: eco del token aceptado'; end if;
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 x', 'note', 'sb_secret_abc'));
  if v ->> 'reason' is distinct from 'secret' then raise exception 'LEAK F8 J17: sb_secret_ aceptado'; end if;
  -- J18 / J19: mismo host (sin www), día y título normalizado → duplicate sin más datos
  v := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8   EVENTO base!', 'source_url', 'https://f8test.org/otra'));
  if v <> '{"result":"duplicate"}'::jsonb then raise exception 'FAIL F8 J18/J19: duplicado %', v; end if;

  -- J24 (noticias): allowlist; categoría; J18 por URL canónica
  v := guide.ingest_submit_news(ta, run1, jsonb_build_object('title_es', 'F8 noticia', 'summary_es', 'Resumen propio F8.',
         'category', 'material', 'published_on_source', today, 'source_url', 'https://news.f8test.org/n/1/?fbclid=z',
         'confidence', 0.4, 'excerpt', 'Resumen propio F8 copiado'));
  if v ->> 'result' <> 'inserted' then raise exception 'FAIL F8: noticia válida %', v; end if;
  v := guide.ingest_submit_news(ta, run1, jsonb_build_object('title_es', 'F8 otra', 'summary_es', 'x', 'category', 'material',
         'published_on_source', today, 'source_url', 'https://news.f8test.org/n/1', 'confidence', 0.8));
  if v <> '{"result":"duplicate"}'::jsonb then raise exception 'FAIL F8 J18: URL canónica no deduplica'; end if;
  v := guide.ingest_submit_news(ta, run1, jsonb_build_object('title_es', 'F8 otra', 'summary_es', 'x', 'category', 'material',
         'published_on_source', today, 'source_url', 'https://evil-f8.org/n', 'confidence', 0.8));
  if v ->> 'reason' is distinct from 'source' then raise exception 'LEAK F8 J24: fuente fuera de la allowlist'; end if;
  v := guide.ingest_submit_news(ta, run1, jsonb_build_object('title_es', 'F8 otra', 'summary_es', 'x', 'category', 'material',
         'published_on_source', today, 'source_url', 'https://f8test.org/n2', 'confidence', 0.8, 'author_note', 'x'));
  if v ->> 'reason' is distinct from 'unknown_key' then raise exception 'LEAK F8 J11: author_note aceptado'; end if;
  v := guide.ingest_submit_news(ta, run1, jsonb_build_object('title_es', 'F8 otra', 'summary_es', 'x', 'category', 'material',
         'published_on_source', '2020-01-01', 'source_url', 'https://f8test.org/n3', 'confidence', 0.8));
  if v ->> 'reason' is distinct from 'stale' then raise exception 'LEAK F8 J15: noticia antigua aceptada'; end if;

  -- J26: el contexto no lleva borradores, claves ni procedencia
  ctx := guide.ingest_context(ta)::text;
  if ctx ilike '%F8 evento base%' or ctx ilike '%F8 noticia%' or ctx ilike '%dedupe%' or ctx ilike '%agent_meta%'
     or ctx ilike '%source_url%' or ctx ilike '%rls-admin%' or octet_length(ctx) > 65536 then
    raise exception 'LEAK F8 J26: ingest_context expone datos no públicos'; end if;

  -- J27: anon no ve borradores ni procedencia; sin escritura
  select count(*) into n from guide.news;
  if n > (select count(*) from guide.news where status = 'published') then raise exception 'LEAK F8 J27: anon ve borradores'; end if;
  if exists (select 1 from guide.news where title_es like 'F8 %') then raise exception 'LEAK F8 J27: anon ve el borrador F8'; end if;
  begin perform agent_meta from guide.news limit 1; raise exception 'LEAK F8 J27: anon lee agent_meta';
  exception when insufficient_privilege then null; end;
  begin perform dedupe_key from guide.news limit 1; raise exception 'LEAK F8 J27: anon lee dedupe_key';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.ingest_runs limit 1; raise exception 'LEAK F8 J28: anon lee ingest_runs';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.ingest_tokens limit 1; raise exception 'LEAK F8 J28: anon lee ingest_tokens';
  exception when insufficient_privilege then null; end;
  begin insert into guide.news (slug, title_es, summary_es, category_id, source_name, source_url)
        values ('x-f8', 'x', 'x', (select id from guide.news_categories limit 1), 'x', 'https://f8test.org/x');
        raise exception 'LEAK F8 J27: anon inserta noticia';
  exception when insufficient_privilege then null; end;

  -- J32: 41.ª fila y 81.ª llamada
  for i in 1..45 loop
    last := guide.ingest_submit_event(ta, run1, ev_base || jsonb_build_object('title_es', 'F8 lote ' || i,
              'source_url', 'https://f8test.org/l' || i));
    exit when last ->> 'result' = 'rejected';
  end loop;
  if last <> '{"result":"rejected","reason":"row_limit"}'::jsonb then raise exception 'FAIL F8 J32: sin row_limit (%)', last; end if;
  for i in 1..90 loop
    last := guide.ingest_submit_event(ta, run1, '{}'::jsonb);
    exit when last ->> 'reason' = 'call_limit';
  end loop;
  if last ->> 'reason' is distinct from 'call_limit' then raise exception 'FAIL F8 J32: sin call_limit'; end if;
  -- J17 en finish_run; J28 cierre
  begin perform guide.ingest_finish_run(ta, run1, null, 'error con ' || ta); raise exception 'LEAK F8 J17: token en errors';
  exception when invalid_parameter_value then null; end;
  begin perform guide.ingest_finish_run(ta, run1, '{"x":1}'::jsonb, null); raise exception 'LEAK F8 J28: stats fuera de lista';
  exception when invalid_parameter_value then null; end;
  v := guide.ingest_finish_run(ta, run1, '{"sources_checked":2}'::jsonb, 'Fuente caída');
  if v ->> 'status' <> 'ok' or (v ->> 'inserted')::integer <> 40 then raise exception 'FAIL F8: finish_run %', v; end if;
  begin perform guide.ingest_submit_event(ta, run1, ev_base); raise exception 'LEAK F8 J29: envío a run cerrado';
  exception when object_not_in_prerequisite_state then null; end;

  -- J34: dry_run no escribe; J29 kind
  run2 := (guide.ingest_start_run(ta, 'events', true) ->> 'run_id')::uuid;
  v := guide.ingest_submit_event(ta, run2, ev_base || jsonb_build_object('title_es', 'F8 seco', 'source_url', 'https://f8test.org/seco'));
  if v ->> 'result' <> 'would_insert' then raise exception 'FAIL F8 J34: dry_run %', v; end if;
  begin perform guide.ingest_submit_news(ta, run2, '{}'::jsonb); raise exception 'LEAK F8 J29: noticia en run de eventos';
  exception when invalid_parameter_value then null; end;
  perform guide.ingest_finish_run(ta, run2, null, null);

  -- J31: 4.º run en 24 h; J5: revocar cierra el run abierto y el token deja de valer
  run3 := (guide.ingest_start_run(ta, 'both', false) ->> 'run_id')::uuid;
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  v := guide.admin_revoke_ingest_token(ida);
  if (v ->> 'runs_closed')::integer <> 1 then raise exception 'FAIL F8 J5: revocar no cierra el run'; end if;
  perform guide.admin_revoke_ingest_token(ida);
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  begin perform guide.ingest_context(ta); raise exception 'LEAK F8 J5: token revocado sigue valiendo';
  exception when insufficient_privilege then null; end;
  if guide.ingest_start_run(tb, 'both', false) ->> 'result' <> 'rate_limited' then
    raise exception 'FAIL F8 J31: cuarto run en 24 h'; end if;

  -- J4: token caducado (como postgres) → mismo 42501
  reset role; perform set_config('request.jwt.claims', '', true);
  update guide.ingest_tokens set created_at = now() - interval '10 days', expires_at = now() - interval '1 second'
  where token_hash = extensions.digest(convert_to(tb, 'UTF8'), 'sha256');
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  begin perform guide.ingest_context(tb); raise exception 'LEAK F8 J4: token caducado sigue valiendo';
  exception when insufficient_privilege then
    if sqlerrm <> 'ingest_unauthorized' then raise exception 'FAIL F8 J6: mensaje no uniforme (caducado)'; end if; end;

  -- Admin: J21, J27b, J36, J18b, lote, newsletter
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  select e.id into ev from guide.admin_list_events(p_query => 'F8 evento base') e limit 1;
  select x.id into nw from guide.admin_list_news(p_query => 'F8 noticia') x limit 1;
  if ev is null or nw is null then raise exception 'FAIL F8: no se encuentran los borradores'; end if;
  if (select x.similarity from guide.admin_list_news(p_id => nw) x) is null
     or array_position((select x.warnings from guide.admin_list_news(p_id => nw) x), 'low_confidence'::text) is null then
    raise exception 'FAIL F8 19.6: similarity/avisos'; end if;
  if (select x.scope from guide.admin_list_news(p_id => nw) x) <> 'cat'
     or (select x.source_url from guide.admin_list_news(p_id => nw) x) <> 'https://news.f8test.org/n/1/' then
    raise exception 'FAIL F8 J23/J24: URL limpia o alcance de la fuente'; end if;
  if (select e.source_url from guide.admin_list_events(p_id => ev) e) <> 'https://www.f8test.org/agenda/1?id=7' then
    raise exception 'FAIL F8 J23: limpieza de tracking/fragmento'; end if;
  if exists (select 1 from guide.activity_log l where l.entity_id in (ev::text, nw::text) and l.action = 'insert'
             and l.details ->> 'by' is distinct from 'agent') then
    raise exception 'FAIL F8 J36: by distinto de agent'; end if;
  if exists (select 1 from guide.activity_log l where l.entity_table = 'ingest_tokens'
             and (l.old_row::text ilike '%token_hash%' or l.details::text ilike '%token_hash%')) then
    raise exception 'LEAK F8 J36: token_hash en el registro'; end if;
  begin update guide.news set source_url = 'https://f8test.org/cambiada' where id = nw;
        raise exception 'LEAK F8 J21: admin cambia source_url del agente';
  exception when insufficient_privilege then null; end;
  v := guide.approve_news(array[nw]);
  if jsonb_array_length(v -> 'ok') <> 1 then raise exception 'FAIL F8: approve_news %', v; end if;
  if (select x.agent_meta from guide.admin_list_news(p_id => nw) x) <> '{"confidence":0.4}'::jsonb then
    raise exception 'FAIL F8 J27b: agent_meta no reducido al publicar'; end if;
  if (guide.reopen_news(array[nw]) -> 'ok' -> 0 ->> 'status') <> 'draft' then raise exception 'FAIL F8: reopen_news'; end if;
  perform guide.approve_news(array[nw]);
  perform guide.set_event_status(ev, 'rejected', 'duplicate');
  begin perform guide.admin_release_event_dedupe(ev); raise exception 'LEAK F8 J18b: libera con motivo distinto de wrong_data';
  exception when object_not_in_prerequisite_state then null; end;
  perform guide.set_event_status(ev, 'draft');
  perform guide.set_event_status(ev, 'rejected', 'wrong_data');
  if (select e.agent_meta from guide.admin_list_events(p_id => ev) e) <> '{"confidence":0.9}'::jsonb then
    raise exception 'FAIL F8 J27b: agent_meta del evento no reducido'; end if;
  perform guide.admin_release_event_dedupe(ev);
  begin update guide.events set dedupe_key = 'x' where id = ev; raise exception 'LEAK F8 J18b: dedupe_key editable';
  exception when insufficient_privilege then null; end;

  -- Newsletter: compose, aprobar (+1 h), editar programada (no), desprogramar (D77), cancelar; borrador no entra
  v := guide.compose_issue(); iss := (v ->> 'id')::uuid;
  if not exists (select 1 from guide.newsletter_issue_items where issue_id = iss and kind = 'news' and ref_id = nw) then
    raise exception 'FAIL F8 D75: la noticia aprobada no entra en la carta'; end if;
  begin insert into guide.newsletter_issue_items (issue_id, kind, ref_id, position) values (iss, 'event', ev, 9);
        raise exception 'LEAK F8: un evento no aprobado entra en la carta';
  exception when check_violation then null; end;
  begin perform guide.approve_issue(iss); raise exception 'FAIL F8: aprueba sin asunto ni intro';
  exception when check_violation then null; end;
  update guide.newsletter_issues set subject_es = 'F8 asunto', intro_es = 'F8 intro' where id = iss;
  v := guide.approve_issue(iss);
  if (v ->> 'scheduled_for')::timestamptz <> now() + interval '1 hour' then raise exception 'FAIL F8 D75: +1 h'; end if;
  begin update guide.newsletter_issues set intro_es = 'cambio' where id = iss; raise exception 'FAIL F8 D77: edita programada';
  exception when object_not_in_prerequisite_state then null; end;
  if guide.unschedule_issue(iss) ->> 'status' <> 'draft' then raise exception 'FAIL F8 D77: desprogramar'; end if;
  if guide.cancel_issue(iss) ->> 'status' <> 'cancelled' then raise exception 'FAIL F8: cancelar'; end if;

  -- No admin: nada de lo de admin
  perform set_config('request.jwt.claims', c_user, true);
  begin perform guide.admin_create_ingest_token('x', 1); raise exception 'LEAK F8: no admin crea token';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.admin_list_news(); raise exception 'LEAK F8: no admin lista noticias';
  exception when insufficient_privilege then null; end;
  if exists (select 1 from guide.ingest_runs) or exists (select 1 from guide.newsletter_issues) then
    raise exception 'LEAK F8: no admin ve runs o cartas'; end if;
  begin perform guide.approve_news(array[nw]); raise exception 'LEAK F8: no admin aprueba';
  exception when insufficient_privilege then null; end;

  reset role; perform set_config('request.jwt.claims', '', true);
  if guide.ingest_health_check() is null then raise exception 'FAIL F8 J35: health'; end if;
end $$;
reset role;

-- ── F8.6 (docs/security/F8.6-ingest-review.md): C1, C2 (intro del agente, anon), O1, O2, decisión 1 ──
-- Sigue a la transacción anterior: usa la noticia publicada «F8 noticia» y la fuente f8test.org.
do $$
declare
  c_admin constant text := '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}';
  c_anon  constant text := '{"role":"anon"}';
  wk  date := date_trunc('week', now() at time zone 'Europe/Madrid')::date;
  ok  constant jsonb := '{"subject_es":"F8 asunto agente","intro_es":"F8 intro agente"}'::jsonb;
  tk text; r1 uuid; r2 uuid; iss uuid; v jsonb; nl jsonb; ctx jsonb;
  thu timestamptz;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos'; end if;

  -- Estático O1: el cupo vive en la guarda (draft → scheduled), no solo en approve_issue
  if pg_get_functiondef('guide.newsletter_issues_before_write()'::regprocedure) not ilike '%newsletter_quota_today%' then
    raise exception 'FAIL F8.6 O1: la guarda no comprueba el cupo'; end if;

  -- Los runs del bloque anterior agotan el tope de 24 h (J31): se envejecen solo en esta transacción
  reset role; perform set_config('request.jwt.claims', '', true);
  update guide.ingest_runs set started_at = now() - interval '25 hours' where started_at > now() - interval '24 hours';

  -- Admin: token nuevo, ventana abierta, carta de la semana cancelada (issue_locked)
  perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  tk := guide.admin_create_ingest_token('rls F86', 1) ->> 'token';
  perform guide.admin_set_ingest_window(true);
  delete from guide.newsletter_issues where week_start = wk;
  iss := (guide.compose_issue() ->> 'id')::uuid;
  perform guide.cancel_issue(iss);

  -- anon (agente): validación de la intro
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  v := guide.ingest_start_run(tk, 'both', false);
  if v ->> 'result' <> 'ok' then raise exception 'FAIL F8.6: start_run %', v; end if;
  r1 := (v ->> 'run_id')::uuid;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok || jsonb_build_object('subject_es', repeat('x', 81)));
  if v ->> 'reason' is distinct from 'too_long' then raise exception 'LEAK F8.6 C2: asunto > 80 aceptado (%)', v; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok || '{"status":"scheduled"}'::jsonb);
  if v ->> 'reason' is distinct from 'unknown_key' then raise exception 'LEAK F8.6 C2: clave status aceptada'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok || '{"scheduled_for":"2027-01-01T00:00:00Z"}'::jsonb);
  if v ->> 'reason' is distinct from 'unknown_key' then raise exception 'LEAK F8.6 C2: clave scheduled_for aceptada'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, '{"subject_es":"F8 sin intro"}'::jsonb);
  if v ->> 'reason' is distinct from 'missing_field' then raise exception 'FAIL F8.6 C2: falta intro_es aceptado'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok || jsonb_build_object('intro_es', 'Llama al 612 345 678'));
  if v ->> 'reason' is distinct from 'pii' then raise exception 'LEAK F8.6 C2: teléfono en la intro aceptado'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok || jsonb_build_object('intro_es', 'F8 ' || chr(8238) || 'bidi'));
  if v ->> 'reason' is distinct from 'bad_chars' then raise exception 'LEAK F8.6 C2: bidi en la intro aceptado'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok);
  if v ->> 'reason' is distinct from 'issue_locked' then raise exception 'LEAK F8.6 C2: escribe en carta cancelada (%)', v; end if;

  -- C1 caso 1: Xavi escribe asunto y preheader sin intro → el agente no la pisa
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  delete from guide.newsletter_issues where id = iss;
  insert into guide.newsletter_issues (week_start, subject_es, preheader_es) values (wk, 'Asunto de Xavi', 'Preheader de Xavi');
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok);
  if v ->> 'reason' is distinct from 'intro_owned' then raise exception 'LEAK F8.6 C1: el agente pisa asunto/preheader (%)', v; end if;
  -- Misma regla en la guarda, rama no admin (camino DEFINER del agente: postgres sin JWT ni mantenimiento)
  reset role; perform set_config('request.jwt.claims', '', true);
  begin update guide.newsletter_issues set intro_es = 'F8 directo' where week_start = wk;
        raise exception 'LEAK F8.6 C1: la guarda no admin deja pisar la carta de Xavi';
  exception when insufficient_privilege then
    if sqlerrm <> 'newsletter_intro_owned' then raise exception 'FAIL F8.6 C1: error inesperado %', sqlerrm; end if; end;
  perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  if (select (i.subject_es, i.preheader_es, i.intro_es) from guide.newsletter_issues i where i.week_start = wk)
     is distinct from ('Asunto de Xavi'::text, 'Preheader de Xavi'::text, null::text) then
    raise exception 'LEAK F8.6 C1: la carta de Xavi ha cambiado'; end if;

  -- Carta vacía otra vez: el agente escribe; segunda llamada del run → already_sent
  update guide.newsletter_issues set subject_es = null, preheader_es = null where week_start = wk;
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok);
  if v ->> 'result' <> 'inserted' then raise exception 'FAIL F8.6: intro válida %', v; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r1, ok);
  if v ->> 'reason' is distinct from 'already_sent' then raise exception 'LEAK F8.6 C2: segunda intro en el mismo run'; end if;
  perform guide.ingest_finish_run(tk, r1, null, null);

  -- C1 caso 2: Xavi retoca solo el asunto → la carta pasa a ser suya y el siguiente run no la pisa
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  if not (select i.intro_by_agent from guide.newsletter_issues i where i.week_start = wk) then
    raise exception 'FAIL F8.6: intro_by_agent no queda en true tras la intro del agente'; end if;
  update guide.newsletter_issues set subject_es = 'Asunto retocado' where week_start = wk;
  if (select i.intro_by_agent from guide.newsletter_issues i where i.week_start = wk) then
    raise exception 'LEAK F8.6 C1: editar el asunto no quita intro_by_agent'; end if;
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  r2 := (guide.ingest_start_run(tk, 'both', false) ->> 'run_id')::uuid;
  if r2 is null then raise exception 'FAIL F8.6: segundo run'; end if;
  v := guide.ingest_submit_newsletter_intro(tk, r2, ok);
  if v ->> 'reason' is distinct from 'intro_owned' then raise exception 'LEAK F8.6 C1: el agente pisa el asunto retocado (%)', v; end if;

  -- Decisión 1 (J26): el contexto lleva url e instructions de las fuentes activas, y nada interno
  ctx := guide.ingest_context(tk);
  if not exists (select 1 from jsonb_array_elements(ctx -> 'sources') s
                 where s ->> 'domain' = 'f8test.org' and s ->> 'url' = 'https://f8test.org/noticias' and s ? 'instructions') then
    raise exception 'FAIL F8.6 J26: sources sin url/instructions'; end if;
  if ctx::text ilike '%dedupe%' or ctx::text ilike '%agent_meta%' or ctx::text ilike '%token_hash%' then
    raise exception 'LEAK F8.6 J26: ingest_context expone datos internos'; end if;
  perform guide.ingest_finish_run(tk, r2, null, null);

  -- C2: anon no lee cartas, ítems, configuración ni instrucciones de las fuentes
  begin perform 1 from guide.newsletter_issues limit 1; raise exception 'LEAK F8.6 C2: anon lee newsletter_issues';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.newsletter_issue_items limit 1; raise exception 'LEAK F8.6 C2: anon lee newsletter_issue_items';
  exception when insufficient_privilege then null; end;
  begin perform 1 from guide.ingest_config limit 1; raise exception 'LEAK F8.6 C2: anon lee ingest_config';
  exception when insufficient_privilege then null; end;
  begin perform instructions from guide.news_sources limit 1; raise exception 'LEAK F8.6 C2: anon lee news_sources.instructions';
  exception when insufficient_privilege then null; end;

  -- O2: contexto del jueves con fecha inyectada (como postgres; la función es interna)
  reset role; perform set_config('request.jwt.claims', '', true);
  thu := ((wk + 3)::timestamp + time '10:00') at time zone 'Europe/Madrid';
  nl := guide.ingest_newsletter_context(thu);
  if nl is null or nl ->> 'week_start' <> to_char(wk, 'YYYY-MM-DD') then raise exception 'FAIL F8.6 O2: sin contexto en jueves'; end if;
  if (nl ->> 'news') not ilike '%F8 noticia%' then raise exception 'FAIL F8.6 O2: falta la noticia publicada'; end if;
  if nl::text ilike '%F8 evento base%' or nl::text ilike '%F8 lote%' or nl::text ilike '%F8 cola%'
     or nl::text ilike '%source_url%' or nl::text ilike '%agent_meta%' then
    raise exception 'LEAK F8.6 O2: el contexto del jueves expone borradores o procedencia'; end if;
  if guide.ingest_newsletter_context(thu - interval '1 day') is not null then
    raise exception 'FAIL F8.6 O2: contexto fuera de jueves'; end if;
end $$;
reset role;
-- ── F8 huecos 8.9/8.10 (guide_f8_backend_gaps): origen 'noticias', events.run_id, search_news p_scope/has_note,
--    ⌘K 'news' y exportar noticias. Sigue a los bloques anteriores: usa «F8 evento base» (run1) y «F8 noticia» (cat).
do $$
declare
  c_admin constant text := '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}';
  c_user  constant text := '{"sub":"a0000000-0000-4000-8000-000000000002","role":"authenticated"}';
  c_anon  constant text := '{"role":"anon"}';
  c_hidden constant text[] := array['agent_meta', 'dedupe_key', 'url_key', 'run_id', 'similarity', 'approved_by'];
  v_p regprocedure; ev uuid; rid uuid; nw uuid; man uuid; v jsonb; r record; n integer;
begin
  if coalesce(current_setting('guide.rls_suite', true), '') <> 'running' then
    raise exception 'ABORT: ejecuta guide_rls_leaks.sql entero (BEGIN … ROLLBACK), nunca fragmentos'; end if;
  reset role; perform set_config('request.jwt.claims', '', true);

  -- Estático: search_path vacío, EXECUTE exactos, firma vieja de search_news retirada, export_news sin roles de la API
  foreach v_p in array array[
    'guide.subscribe_newsletter(text, guide.locale, text, boolean, text, boolean)'::regprocedure,
    'guide.events_before_write()'::regprocedure, 'guide.ingest_submit_event(text, uuid, jsonb)'::regprocedure,
    'guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz, uuid, text[], text, uuid, text, integer, integer)'::regprocedure,
    'guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope)'::regprocedure,
    'guide.admin_search(text, text[], integer)'::regprocedure,
    'guide.export_build(text, text, jsonb, boolean)'::regprocedure,
    'guide.admin_export(text, text, jsonb)'::regprocedure, 'guide.admin_export_count(text, jsonb)'::regprocedure] loop
    if not coalesce((select p.proconfig from pg_proc p where p.oid = v_p) @> array['search_path=""'], false) then
      raise exception 'FAIL F8 gaps: % sin search_path vacío', v_p; end if;
    if has_function_privilege('service_role', v_p, 'execute')
       or exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                  where p.oid = v_p and a.grantee = 0 and a.privilege_type = 'EXECUTE') then
      raise exception 'LEAK F8 gaps: EXECUTE de PUBLIC/service_role en %', v_p; end if;
  end loop;
  foreach v_p in array array[
    'guide.admin_list_events(guide.event_status, guide.event_source, text, timestamptz, timestamptz, uuid, text[], text, uuid, text, integer, integer)'::regprocedure,
    'guide.admin_search(text, text[], integer)'::regprocedure,
    'guide.admin_export(text, text, jsonb)'::regprocedure, 'guide.admin_export_count(text, jsonb)'::regprocedure] loop
    if has_function_privilege('anon', v_p, 'execute') or not has_function_privilege('authenticated', v_p, 'execute') then
      raise exception 'LEAK F8 gaps: EXECUTE de % no es solo authenticated', v_p; end if;
  end loop;
  if has_function_privilege('anon', 'guide.export_build(text, text, jsonb, boolean)', 'execute')
     or has_function_privilege('authenticated', 'guide.export_build(text, text, jsonb, boolean)', 'execute')
     or has_function_privilege('authenticated', 'guide.events_before_write()', 'execute') then
    raise exception 'LEAK F8 gaps: interna ejecutable desde la API'; end if;
  if not has_function_privilege('anon', 'guide.search_news(text, guide.locale, uuid, integer, integer, guide.news_scope)', 'execute') then
    raise exception 'FAIL F8 gaps: anon sin EXECUTE en search_news'; end if;
  if to_regprocedure('guide.search_news(text, guide.locale, uuid, integer, integer)') is not null then
    raise exception 'FAIL F8 gaps: sigue la firma vieja de search_news'; end if;
  if has_table_privilege('anon', 'guide.export_news', 'select') or has_table_privilege('authenticated', 'guide.export_news', 'select')
     or has_table_privilege('service_role', 'guide.export_news', 'select') then
    raise exception 'LEAK F8 gaps: export_news legible desde la API'; end if;
  if exists (select 1 from pg_attribute a where a.attrelid = 'guide.export_news'::regclass and a.attnum > 0
             and a.attname::text = any (c_hidden)) then
    raise exception 'LEAK F8 gaps: export_news con columnas internas o personales'; end if;
  if exists (select 1 from information_schema.column_privileges
             where table_schema = 'guide' and table_name = 'events' and column_name = 'run_id'
               and grantee in ('anon', 'authenticated') and privilege_type = 'SELECT') then
    raise exception 'LEAK F8 gaps: events.run_id con SELECT para la API'; end if;

  -- 1. Origen 'noticias' (anon), también como origen de afines; un origen fuera de lista sigue rechazado
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  perform guide.subscribe_newsletter('rls-f8-noticias' || chr(64) || 'example.com', 'es', 'noticias', true, '/noticias?utm=x', true);
  begin
    perform guide.subscribe_newsletter('rls-f8-bad' || chr(64) || 'example.com', 'es', 'noticias_x', true);
    raise exception 'LEAK F8 gaps: origen fuera de lista aceptado';
  exception when invalid_parameter_value then null; end;
  reset role; perform set_config('request.jwt.claims', '', true);
  select s.consent_source, s.related_consent_source, s.consent_page into r
  from guide.subscribers s where s.email = 'rls-f8-noticias' || chr(64) || 'example.com';
  if r.consent_source is distinct from 'noticias' or r.related_consent_source is distinct from 'noticias'
     or r.consent_page is distinct from '/noticias' then
    raise exception 'FAIL F8 gaps: alta con origen noticias %', r; end if;

  -- 2. events.run_id: lo pone la ingesta en el INSERT, sale en admin_list_events, inmutable y nulo en altas del admin
  select e.id into ev from guide.events e where e.title_es = 'F8 evento base' and e.source = 'agent';
  rid := (select e.run_id from guide.events e where e.id = ev);
  if ev is null or rid is null
     or not exists (select 1 from guide.ingest_runs r2 join guide.events e on e.run_id = r2.id where e.id = ev) then
    raise exception 'FAIL F8 gaps: la ingesta no rellena events.run_id'; end if;
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  begin perform e.run_id from guide.events e limit 1; raise exception 'LEAK F8 gaps: anon lee events.run_id';
  exception when insufficient_privilege then null; end;
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_user, true);
  begin perform guide.admin_list_events(p_id => ev); raise exception 'LEAK F8 gaps: no admin llama a admin_list_events';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims', c_admin, true);
  select x.run_id, x.run_started_at into r from guide.admin_list_events(p_id => ev) x;
  if r.run_id is distinct from rid or r.run_started_at is null then
    raise exception 'FAIL F8 gaps: admin_list_events sin run_id/run_started_at'; end if;
  begin update guide.events set run_id = null where id = ev; raise exception 'LEAK F8 gaps: el admin borra run_id';
  exception when insufficient_privilege then
    if sqlerrm <> 'event_provenance_immutable' then raise exception 'FAIL F8 gaps: error inesperado %', sqlerrm; end if; end;
  begin update guide.events set run_id = gen_random_uuid() where id = ev; raise exception 'LEAK F8 gaps: el admin cambia run_id';
  exception when insufficient_privilege then null; end;
  insert into guide.events (title_es, starts_at, location_text, status, run_id)
  values ('F8 manual run', now() + interval '10 days', 'Barcelona', 'draft', rid) returning id into man;
  if (select x.run_id from guide.admin_list_events(p_id => man) x) is not null then
    raise exception 'LEAK F8 gaps: el admin falsea run_id al crear'; end if;

  -- 3. search_news: p_scope y has_note
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  select x.id, x.scope, x.has_note into r from guide.search_news('F8 noticia', 'es') x where x.title = 'F8 noticia';
  if r.id is null or r.scope <> 'cat' or r.has_note then raise exception 'FAIL F8 gaps: search_news sin scope/has_note %', r; end if;
  nw := r.id;
  if not exists (select 1 from guide.search_news('F8 noticia', 'es', p_scope => 'cat') x where x.id = nw)
     or exists (select 1 from guide.search_news('F8 noticia', 'es', p_scope => 'intl') x where x.id = nw) then
    raise exception 'FAIL F8 gaps: search_news no filtra por p_scope'; end if;
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_admin, true);
  update guide.news set author_note_es = 'Nota de Xavi F8.' where id = nw;
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  if not coalesce((select x.has_note from guide.search_news('F8 noticia', 'es') x where x.id = nw), false) then
    raise exception 'FAIL F8 gaps: has_note no refleja la nota'; end if;

  -- 4. ⌘K: tipo news (solo admin, sin descartadas)
  reset role; perform set_config('role', 'authenticated', true); perform set_config('request.jwt.claims', c_user, true);
  begin perform guide.admin_search('F8 noticia', array['news']); raise exception 'LEAK F8 gaps: no admin usa admin_search news';
  exception when insufficient_privilege then null; end;
  perform set_config('request.jwt.claims', c_admin, true);
  select x.kind, x.key, x.status, x.data into r from guide.admin_search('F8 noticia', array['news']) x where x.id = nw;
  if r.kind is distinct from 'news' or r.status <> 'published' or not (r.data ->> 'has_note')::boolean
     or r.data ->> 'scope' <> 'cat' then
    raise exception 'FAIL F8 gaps: admin_search sin la noticia %', r; end if;
  if exists (select 1 from guide.admin_search('F8 noticia', array['news']) x
             where x.data ?| c_hidden or x.data ? 'source_url') then
    raise exception 'LEAK F8 gaps: admin_search news expone procedencia'; end if;
  if exists (select 1 from guide.admin_search('F8') x join guide.news n2 on n2.id = x.id
             where x.kind = 'news' and n2.status = 'rejected') then
    raise exception 'FAIL F8 gaps: admin_search muestra noticias descartadas'; end if;

  -- 5. Exportar noticias: solo admin, filtros en lista blanca, sin columnas internas, registra la exportación
  v := guide.admin_export_count('news', '{"statuses":["published"],"scopes":["cat"]}');
  if (v ->> 'total')::integer < 1 or (v -> 'columns') ?| c_hidden then
    raise exception 'FAIL F8 gaps: admin_export_count news %', v; end if;
  foreach v in array array['{"sources":["footer"]}'::jsonb, '{"scopes":["mars"]}'::jsonb, '{"statuses":["approved"]}'::jsonb,
                           '{"columns":["agent_meta"]}'::jsonb, '{"date_field":"starts_at"}'::jsonb] loop
    begin perform guide.admin_export_count('news', v); raise exception 'LEAK F8 gaps: filtro de news aceptado %', v;
    exception when invalid_parameter_value then null; end;
  end loop;
  n := (select count(*) from guide.activity_log l where l.action = 'export' and l.entity_table = 'export_news');
  v := guide.admin_export('news', 'json', jsonb_build_object('ids', jsonb_build_array(nw)));
  if (v -> 'export' ->> 'row_count')::integer <> 1 or (v -> 'export' ->> 'personal_data')::boolean
     or (v -> 'rows' -> 0) ?| c_hidden or v -> 'rows' -> 0 ->> 'author_note_es' <> 'Nota de Xavi F8.' then
    raise exception 'FAIL F8 gaps: admin_export news %', v -> 'export'; end if;
  if (select count(*) from guide.activity_log l where l.action = 'export' and l.entity_table = 'export_news') <> n + 1 then
    raise exception 'FAIL F8 gaps: la exportación de news no queda registrada'; end if;
  perform set_config('request.jwt.claims', c_user, true);
  begin perform guide.admin_export('news', 'csv', '{}'); raise exception 'LEAK F8 gaps: no admin exporta noticias';
  exception when insufficient_privilege then null; end;
  reset role; perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', c_anon, true);
  begin perform guide.admin_export_count('news', '{}'); raise exception 'LEAK F8 gaps: anon cuenta noticias';
  exception when insufficient_privilege then null; end;
  reset role; perform set_config('request.jwt.claims', '', true);
end $$;
reset role;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
-- Fin F8

-- public intacto tras todo lo anterior
do $$
declare r record; v_n bigint; v_h text;
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relkind in ('r', 'p')) <> (select count(*) from _unpub_public_snap) then
    raise exception 'LEAK F6.4 unpublish: cambian las tablas de public'; end if;
  for r in select * from _unpub_public_snap loop
    execute format('select count(*), coalesce(md5(string_agg(t::text, %L order by t::text)), %L) from public.%I t', ',', '', r.tbl)
      into v_n, v_h;
    if v_n is distinct from r.n or v_h is distinct from r.h then
      raise exception 'LEAK F6.4 unpublish: cambió public.%', r.tbl; end if;
  end loop;
end $$;

-- Mantenimiento explícito (como postgres, p. ej. guide_dummy_purge.sql): sí borra lo vivo y sus relacionados
select set_config('guide.draft_op', 'maintenance', true);
do $$
begin
  insert into guide.article_items (article_id, item_id, sort_order)
  values ('d0000000-0000-4000-8000-000000000005', 'f0000000-0000-4000-8000-000000000001', 1);
  delete from guide.articles where id = 'd0000000-0000-4000-8000-000000000005';
  if exists (select 1 from guide.articles where id = 'd0000000-0000-4000-8000-000000000005') then
    raise exception 'FAIL F6.4: maintenance como postgres no borra'; end if;
end $$;
select set_config('guide.draft_op', '', true);

select 'ALL RLS TESTS PASSED' as result;

rollback;
