-- F7.1 · Borra TODOS los datos dummy del seed F2.11 (uuids con prefijo d0d0d0d0-).
-- No toca configuración (item_categories, site_settings) ni datos reales, con una excepción: si
-- site_settings.hero_photo_1/2_media_id apuntan a una foto dummy, el FK on delete set null (D41) vacía esa ranura.
-- Ejecutar como postgres.
-- Orden por dependencias; las tablas de detalle (gyms, resolers, shoes), notas y article_items
-- caen en cascada, pero se borran explícitamente para que el script sea legible y verificable.

begin;
-- F6.4: los triggers de guide.articles/article_items bloquean escribir o borrar lo vivo (PT423). Este script
-- de mantenimiento (solo como postgres, con bypassrls) lo declara explícitamente para su transacción.
select set_config('guide.draft_op', 'maintenance', true);

delete from guide.article_items        where article_id::text like 'd0d0d0d0-%' or item_id::text like 'd0d0d0d0-%';
delete from guide.author_review_scores where review_id::text like 'd0d0d0d0-%';
delete from guide.author_reviews       where id::text like 'd0d0d0d0-%';
delete from guide.events               where id::text like 'd0d0d0d0-%';
delete from guide.articles             where id::text like 'd0d0d0d0-%';
delete from guide.article_categories   where id::text like 'd0d0d0d0-%';
delete from guide.pages                where id::text like 'd0d0d0d0-%';
-- D24 · Las fichas con opiniones no se borran (trigger + FK restrict): primero las opiniones de las fichas dummy
-- (el seed no crea ninguna, pero las pruebas manuales sí pueden haberlas dejado). Sus notas caen en cascada.
delete from guide.user_reviews         where item_id::text like 'd0d0d0d0-%';
delete from guide.item_media           where item_id::text like 'd0d0d0d0-%';
delete from guide.gyms                 where item_id::text like 'd0d0d0d0-%';
delete from guide.resolers             where item_id::text like 'd0d0d0d0-%';
delete from guide.shoes                where item_id::text like 'd0d0d0d0-%';
delete from guide.items                where id::text like 'd0d0d0d0-%';
-- Criterios: solo los dummy. Si ya hay notas reales con ellos, el delete falla (restrict): revisar antes.
delete from guide.criteria             where id::text like 'd0d0d0d0-%';
-- D22 · Fotos dummy: filas de guide.media (después de items/articles, que las usan como portada). Si un contenido
-- real usa alguna, el delete falla por FK (restrict): cambiar antes esa portada desde el panel.
-- Excepción D41: las fotos del hero (Ajustes) no hacen fallar el delete. Si se eligió una foto dummy, su ranura se
-- queda vacía sin ningún error (on delete set null): elegir antes fotos reales en Ajustes para no perder el carrusel.
delete from guide.media                where id::text like 'd0d0d0d0-%';
-- Rastro del seed y de la purga en el registro de actividad.
delete from guide.activity_log         where entity_id like 'd0d0d0d0-%';

-- Comprobación: no debe quedar nada con el prefijo.
do $$
declare v integer;
begin
  select (select count(*) from guide.items where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.articles where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.article_categories where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.pages where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.events where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.criteria where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.author_reviews where id::text like 'd0d0d0d0-%')
       + (select count(*) from guide.media where id::text like 'd0d0d0d0-%')
    into v;
  if v <> 0 then
    raise exception 'Quedan % filas dummy', v;
  end if;
end $$;

commit;

-- D22 · Objetos del bucket `media`: NO se pueden borrar por SQL (storage.protect_delete lo impide a cualquier rol).
-- Después de este script, bórralos de una de estas dos formas:
--   1. Dashboard → Storage → media: seleccionar las 9 carpetas d0d0d0d0-000a-4000-8000-00000000000{1..9} y borrar.
--   2. Storage API con la secret/service key (solo en un entorno de servidor, nunca en el cliente):
--      supabase.storage.from('media').remove([
--        'd0d0d0d0-000a-4000-8000-000000000001/1-escaladora-bloque-colores.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000002/1-pared-roja-desplomada.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000003/1-bloque-granito-bosque.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000004/1-techo-roca-mar.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000005/1-bloque-amarillo-presas.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000006/1-sala-bloque-amplia.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000007/1-desplome-presas-rojas-verdes.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000008/1-escalador-desde-abajo.jpg',
--        'd0d0d0d0-000a-4000-8000-000000000009/1-pared-amarilla-presas-pequenas.jpg',
--      ])
-- Comprobación final (debe dar 0): select count(*) from storage.objects where bucket_id = 'media' and name like 'd0d0d0d0-%';
