# Revisión de seguridad D57 · Autores

Fecha: 2026-11-06. Revisora: leona-lia. Migración: `supabase/migrations/20261106121719_guide_d57_authors.sql` (aplicada en `eqtjlafxtrzbjazhhyin`).

## Veredicto

APROBADO. Hay dos observaciones menores no bloqueantes.

## Comprobaciones

- **guide.authors.** RLS está activado. Hay una policy por operación. La lectura `using (true)` para anon y authenticated se acepta: el autor es contenido público y no tiene estado de borrador, igual que `article_categories`. Insert, update y delete van restringidos a `authenticated` con `guide.is_admin()` en `using` y `with check`. Los GRANT son mínimos: anon solo tiene SELECT.
- **Exención `detach_author:<id>` en `articles_before_write`.** La exención está atada a `old.author_id`. Solo permite el cambio exacto `author_id` a NULL. Un cliente no puede fijar `guide.draft_op`: PostgREST no expone `set_config`, y además la RLS de `articles` impide cualquier UPDATE a quien no es admin. Incluso un admin que fije el GUC a mano recibe PT423 en tres casos: si asigna otro autor, si cambia otra columna a la vez o si usa el id de un autor que no es el actual.
- **Trigger `authors_before_delete`.** Es INVOKER y solo lo alcanza el admin, por la RLS de delete. En la prueba desasignó el artículo vivo y puso a null `author_id` en el borrador. `updated_by` quedó con el uid del admin, no null (se respeta D24). Restauró el valor previo de `guide.draft_op`. No introduce funciones DEFINER que escriban en `content_drafts` (se respeta O6).
- **`media_is_public`.** Es DEFINER con `search_path=''`. La única cláusula nueva cubre las fotos de autores. Como los autores son públicos, la foto elegida también lo es (patrón D51). No expone medios de contenido sin publicar.
- **`search_articles`.** Se recreó como INVOKER con `search_path=''`. EXECUTE solo para anon y authenticated, sin PUBLIC. Solo devuelve artículos vivos. La nueva columna `author_id` no filtra nada sensible.
- **`export_articles` y `media_usage`.** Las dos usan `security_invoker` y filtran con `is_admin()`. `export_articles` no tiene grant para ningún rol de la API.
- **public.** La migración no toca ningún objeto de `public`.
- **Advisors (security).** No hay avisos nuevos atribuibles a D57.

## Pruebas de fuga

Todas se hicieron en transacción con rollback, y el estado final quedó verificado intacto.

- **anon.** SELECT de authors funciona. INSERT, UPDATE y DELETE dan 42501. UPDATE de `articles.author_id` da 42501. `export_articles` da 42501.
- **authenticated sin admin.** INSERT da 42501. UPDATE y DELETE de authors afectan 0 filas. UPDATE de `articles.author_id` afecta 0 filas, también con `draft_op=detach_author`. `export_articles`, `media_usages` y `save_draft` dan 42501.
- **admin.** Cambiar el autor de un artículo vivo da PT423. Los tres intentos de abusar de la exención dan PT423. El borrado del autor funciona como se espera.

## Observaciones (no bloqueantes)

1. `guide.authors_before_delete()` y `guide.authors_require_alt()` mantienen EXECUTE para PUBLIC, porque su ACL está a null. No se puede explotar, ya que una función de trigger no se llama como RPC. Aun así, por coherencia con el resto del schema conviene `revoke all on function guide.authors_before_delete(), guide.authors_require_alt() from public;`. **Resuelta** en `guide_d57_o1_revoke_trigger_fns`.
2. Conviene añadir `detach_author:<author_id>` a la lista de exenciones de `guide.draft_op` en `.ai/security-rls.md`. La condición es: comprobada contra `old.author_id` y solo `author_id` pasa a NULL. **Resuelta.**
