-- D18 · Servicios de resoladores: qué trabajos hace cada taller (filtrable en la tabla del listado).
-- Claves estables en inglés; las etiquetas es/en viven en i18n del frontend.
--   half_sole       media suela (resolado estándar)
--   full_sole       suela completa
--   rand            cambio/reparación de rand (goma de puntera y laterales)
--   toe_patch       parche de puntera sobre el rand (refuerzo sin rand completo)
--   closure_repair  cierres: velcros, cordones, ojales, tiras
--   stitching       costuras y reparación del upper
--   other           otros trabajos (se detallan en el resumen de la ficha)
-- Sin índice GIN: la tabla tendrá decenas de filas y el filtro (services @> '{...}') es un seq scan trivial.

alter table guide.resolers add column if not exists services text[] not null default '{}';

do $$ begin
  alter table guide.resolers
    add constraint resolers_services_allowed check (
      services <@ array['half_sole', 'full_sole', 'rand', 'toe_patch', 'closure_repair', 'stitching', 'other']::text[]
      and array_position(services, null) is null
    );
exception when duplicate_object then null; end $$;
