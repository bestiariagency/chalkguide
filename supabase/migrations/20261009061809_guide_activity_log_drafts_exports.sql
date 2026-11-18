-- D23: acciones nuevas del registro de actividad (publicar/descartar borrador de cambios, exportar)
-- y columna `details` para metadatos sin datos personales (formato, nº de filas, filtros saneados).
alter type guide.activity_action add value if not exists 'draft_publish';
alter type guide.activity_action add value if not exists 'draft_discard';
alter type guide.activity_action add value if not exists 'export';

alter table guide.activity_log add column if not exists details jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'activity_log_details_check' and conrelid = 'guide.activity_log'::regclass) then
    alter table guide.activity_log add constraint activity_log_details_check
      check (details is null or (jsonb_typeof(details) = 'object' and octet_length(details::text) <= 4000));
  end if;
end $$;

comment on column guide.activity_log.details is
  'D23. Metadatos de la acción (exportación: formato, filas, filtros saneados). Nunca datos personales.';
