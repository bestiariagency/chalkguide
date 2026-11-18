# D62 · Autores en el panel · Revisión de seguridad

- Revisora: leona-lia
- Fecha: 2026-11-12
- Proyecto: `eqtjlafxtrzbjazhhyin`, schema `guide`
- Veredicto: **APROBADO**

## Alcance

- `supabase/migrations/20261112122318_guide_d62_authors_panel.sql`: vista `guide.admin_author_article_counts` y RPC `guide.admin_reorder_authors(p_ids uuid[])`.
- `supabase/migrations/20261112122509_guide_d62_author_counts_nonadmin_empty.sql`: redefine la vista con `having (select guide.is_admin())` en la rama del autor del sitio.
- Contexto: D57 (`docs/security/D57-authors-review.md`, exención `detach_author`) y §17 de `docs/design/admin/README.md`.

No hay cambios en tablas, policies, triggers ni en el schema `public`.

## Revisión estática

### Vista `guide.admin_author_article_counts`

- `security_invoker = true`. La RLS de `guide.articles` y `guide.authors` se aplica al rol que consulta. No hay escalada por el propietario `postgres`.
- Doble puerta de admin. La rama por autor filtra con `where (select guide.is_admin())`. La rama del autor del sitio (`author_id is null`) es un agregado sin `group by` y filtra con `having (select guide.is_admin())`. Sin el `having`, un no-admin recibía la fila `(null, 0, 0)`. La segunda migración lo corrige.
- La definición en BD (`pg_get_viewdef`) coincide con la segunda migración.
- ACL real: `postgres=arwdDxtm`, `authenticated=r`. Sin grant a `anon`, `service_role` ni `PUBLIC`.
- El filtro `(select guide.is_admin())` es un InitPlan de una sola evaluación. Un no-admin no provoca un recorrido de `articles`.

### RPC `guide.admin_reorder_authors(p_ids uuid[])`

- `SECURITY INVOKER`, `search_path = ''`, volátil, propietario `postgres`.
- La primera sentencia es `perform guide.assert_admin()`. Esa función lanza `42501 admin only` si `guide.is_admin()` es falso. Por tanto ninguna validación de entrada se evalúa antes de la comprobación de admin.
- Validaciones (todas `22023`): `ids required` (array nulo o con elemento nulo), `duplicate ids`, `unknown author`, `list must include every author`.
- La única escritura es `update guide.authors set sort_order = ...`. No toca otras columnas ni otras tablas. Al ser INVOKER, la escritura pasa además por la policy `authors_update` (`using`/`with check` `(select guide.is_admin())`).
- ACL real: `postgres=X`, `authenticated=X`. Sin `anon`, `service_role` ni `PUBLIC`.

### `guide.is_admin()` y `guide.assert_admin()`

Sin cambios. `is_admin` es SECURITY DEFINER, tiene `search_path = ''` y consulta `guide.admins` sin recursión. `assert_admin` es INVOKER y tiene `search_path = ''`.

## Pruebas en BD real

Todas las pruebas se ejecutaron en una transacción con fixtures temporales: un segundo autor, un borrador firmado por el autor existente y un borrador sin autor (autor del sitio). La transacción terminó con una excepción provocada, así que se revirtió entera. Después se comprobó que el estado de la BD no había cambiado.

### anon

| Prueba | Resultado |
| --- | --- |
| SELECT de la vista | `42501 permission denied for view` |
| Llamada al RPC | `42501 permission denied for function` |
| UPDATE de `guide.authors` | `42501 permission denied for table` |
| Ver borradores en `guide.articles` | 0 filas |

### service_role

| Prueba | Resultado |
| --- | --- |
| SELECT de la vista | `42501 permission denied for view` |
| Llamada al RPC | `42501 permission denied for function` |

### authenticated no admin

| Prueba | Resultado |
| --- | --- |
| SELECT de la vista | 0 filas, sin la fila del autor del sitio |
| RPC con `null`, con duplicados, con id desconocido, con lista parcial y con lista válida | Siempre `42501 admin only` |
| UPDATE de `guide.authors` | 0 filas |
| DELETE de `guide.authors` | 0 filas |
| Ver borradores en `guide.articles` | 0 filas |

El mensaje es idéntico con cualquier entrada. Los errores no sirven de oráculo sobre la existencia de autores ni sobre su número.

### admin

| Prueba | Resultado |
| --- | --- |
| SELECT de la vista | Autor existente 13/12 (incluye el borrador en el total, no en vivos); autor nuevo 0/0; autor del sitio 1/0 |
| RPC con `null` y con `{null}` | `22023 ids required` |
| RPC con `{}` | `22023 list must include every author` |
| RPC con duplicados | `22023 duplicate ids` |
| RPC con id desconocido | `22023 unknown author` |
| RPC con lista parcial | `22023 list must include every author` |
| RPC con lista válida | Solo cambia `sort_order`: el hash de cada fila sin `sort_order` ni `updated_at` es idéntico antes y después |
| `activity_log` tras el reorden | Una entrada `update authors {sort_order}` por autor modificado, con `actor_id` del admin |

### Borrado de autor (D57)

- El admin borra el autor que firma 12 artículos publicados y 1 borrador.
- Los 13 artículos pasan a `author_id = null` en el momento, por la exención `detach_author:<id>` del trigger `authors_before_delete`. En total quedan 14 artículos sin autor, contando el borrador del autor del sitio.
- Los 12 artículos publicados siguen publicados. El estado y la publicación no cambian.
- La vista refleja el cambio: la fila del autor del sitio pasa a 14/12.
- `activity_log` registra `delete authors <nombre>` con `actor_id` del admin.
- Ningún `content_draft` se modificó: no había borradores de contenido que apuntaran al autor.

## Advisors (security)

No hay avisos nuevos atribuibles a D62. El RPC es INVOKER y la vista es `security_invoker`, así que no disparan los lints de SECURITY DEFINER ni de vista definer. Los avisos que aparecen son todos previos:

- `rls_enabled_no_policy` en `guide.user_review_photo_quota` (INFO, intencionado).
- Funciones SECURITY DEFINER de `guide` ya revisadas en decisiones anteriores.
- Funciones de `public` de Chalk app. Están fuera del alcance de ChalkGuide y no se tocan.
- Protección de contraseñas filtradas desactivada en Auth.

## Schema `public`

Las migraciones de D62 no mencionan `public`. Ninguna vista fuera de `guide` depende de `guide.authors` ni de `guide.articles`. Ningún GRANT ni policy de `public` ha cambiado.

## Observaciones no bloqueantes

1. **O1. Base de `sort_order`.** El RPC numera desde 1 (`with ordinality`). Los datos existentes usaban 0 y 10. No es un problema de seguridad. El frontend debe ordenar solo por `sort_order` y no asumir una base concreta.
2. **O2. Volumen de registro.** Cada reorden escribe una entrada en `activity_log` por autor cuyo `sort_order` cambia. Con pocos autores es aceptable. Si el registro se vuelve ruidoso, se puede agrupar en una sola entrada en el futuro, pero eso necesitaría una nueva revisión.
3. **O3. Carrera de concurrencia.** Entre la validación "lista completa" y el UPDATE, otro admin podría crear un autor. Solo hay un superadmin, así que no es explotable por terceros. No se requiere cambio.

## Veredicto

**APROBADO.** No hay vetos abiertos.

## Addendum 2026-11-12: visibilidad de la foto del autor (front de D62)

Veredicto: **APROBADO**, sin vetos.

La visibilidad la decide el backend. `guide.media` no tiene columna de publicidad: la policy `media_select` usa `is_admin() OR guide.media_is_public(id)`, y `media_is_public` (SECURITY DEFINER, `search_path` vacío) se calcula al vuelo y ya cuenta `authors.photo_media_id` y `site_settings.author_photo_media_id`, igual que portadas y galerías. Pruebas como anon sobre una media privada (en un bloque revertido): 0 filas antes; 1 con la foto de autor puesta y 0 al quitarla; lo mismo con la foto del autor del sitio vía `admin_update_settings`; si la usan los dos y se quita de uno, sigue visible. No hay otra vía para hacer pública una media: anon y no admin obtienen 0 filas o 42501 al escribir en `authors`, `site_settings` o la RPC, y `content_media_refs` solo la llena un trigger.

D27 se cumple en base de datos: `authors_require_alt` y `site_settings_require_alt` (que cubre `author_photo_media_id`) devuelven PT422, y `media_require_alt` impide vaciar el alt de una media en uso.

El cliente (`app/services/admin/authors.ts`, `authorPayload` en `app/utils/admin-authors.ts`) solo escribe `name`, `slug`, `role_es/en`, `bio_es/en` y `photo_media_id`, más `sort_order` al insertar. No escribe `is_primary`. Ajustes solo escribe mediante `admin_update_settings`, que exige admin, rechaza columnas inexistentes o bloqueadas y detecta conflictos.

Nota: lo que el backend oculta es la fila de metadatos de `guide.media`. El archivo vive en el bucket `media`, público por diseño (`docs/data-model.md`) y no listable: quien ya tenga la URL completa, que incluye el UUID, puede seguir descargándolo aunque la foto deje de usarse. Por eso la ayuda del panel dice ahora que la foto «deja de salir en el sitio» y que quien tenga el enlace aún puede abrirlo, en lugar de «vuelve a ser privada». La privacidad real del archivo exigiría un bucket privado con URLs firmadas, fuera del alcance de D62.
