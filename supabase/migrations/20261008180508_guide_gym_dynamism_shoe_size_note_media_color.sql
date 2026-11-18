-- D22 · Iteración 2 de 3.17–3.19: dinamismo de vías/bloques, nota de ajuste de talla y color dominante de la foto.
--
-- gyms.setting_dynamism: 1 = estático/técnico … 5 = dinámico/coordinación. Escala descriptiva como
-- grading_difficulty: no es un criterio, no entra en author_review_scores ni en ninguna media o índice derivado.
--
-- shoes.author_size_note_es/_en: nota libre de ajuste de la talla del autor (≤ 140). Igual que las tallas
-- (D21), solo tiene sentido si el autor tiene el modelo; y no hay traducción sin original.
--
-- media.dominant_color: hex en minúsculas (#rrggbb) que calcula el panel al subir o reemplazar la foto
-- (README §9.9.3). El hero lo lee para derivar sus tonos en servidor; null = colores por defecto.
--
-- Visibilidad: las de gyms/shoes/media. anon y authenticated tienen SELECT a nivel de tabla (sin grants por
-- columna), así que las columnas nuevas no necesitan GRANT propio.

alter table guide.gyms add column if not exists setting_dynamism smallint;

do $$ begin
  alter table guide.gyms add constraint gyms_setting_dynamism_range check (setting_dynamism between 1 and 5);
exception when duplicate_object then null; end $$;

alter table guide.shoes add column if not exists author_size_note_es text;
alter table guide.shoes add column if not exists author_size_note_en text;

do $$ begin
  alter table guide.shoes add constraint shoes_author_size_note_es_length check (char_length(author_size_note_es) between 1 and 140);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table guide.shoes add constraint shoes_author_size_note_en_length check (char_length(author_size_note_en) between 1 and 140);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table guide.shoes add constraint shoes_author_size_note_en_needs_es check (author_size_note_en is null or author_size_note_es is not null);
exception when duplicate_object then null; end $$;

-- Sustituye a shoes_author_sizes_owned (D21) para incluir las notas: sin el modelo, ni tallas ni nota.
alter table guide.shoes drop constraint if exists shoes_author_sizes_owned;
alter table guide.shoes add constraint shoes_author_sizes_owned check (
  owned_by_author
  or (author_size_eu is null and author_street_size_eu is null and author_size_note_es is null and author_size_note_en is null)
);

alter table guide.media add column if not exists dominant_color text;

do $$ begin
  alter table guide.media add constraint media_dominant_color_hex check (dominant_color ~ '^#[0-9a-f]{6}$');
exception when duplicate_object then null; end $$;
