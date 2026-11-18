-- D21 / 3.17 · Talla del autor en pies de gato y dificultad de graduación de los rocódromos.
--
-- Tallas en guide.shoes (no en author_reviews): son datos específicos de la categoría `shoe`, y el modelo
-- genérico pone lo específico de cada categoría en su tabla de detalle; meterlas en author_reviews
-- obligaría a un CHECK con `category = 'shoe'` cableado en una tabla común. Siguen el precedente de
-- `owned_by_author` (solo tienen sentido si el autor tiene el modelo, por eso el CHECK). El comparador y la
-- ficha ya leen `shoes`, así que no hay consulta extra. Visibilidad: la de `shoes` (ítem publicado).
--   author_size_eu         talla EU que usa el autor en ese modelo
--   author_street_size_eu  talla EU de calle del autor (referencia para comparar el ajuste)
-- Rango 30–50 y paso de media talla.
--
-- gyms.grading_difficulty: 1 = grados generosos … 5 = grados duros. Descriptivo: no es un criterio,
-- no entra en author_review_scores ni en ninguna media o índice derivado.

alter table guide.shoes add column if not exists author_size_eu numeric(3,1);
alter table guide.shoes add column if not exists author_street_size_eu numeric(3,1);

do $$ begin
  alter table guide.shoes add constraint shoes_author_size_eu_range check (
    author_size_eu is null or (author_size_eu between 30 and 50 and author_size_eu * 2 = trunc(author_size_eu * 2))
  );
exception when duplicate_object then null; end $$;

do $$ begin
  alter table guide.shoes add constraint shoes_author_street_size_eu_range check (
    author_street_size_eu is null
    or (author_street_size_eu between 30 and 50 and author_street_size_eu * 2 = trunc(author_street_size_eu * 2))
  );
exception when duplicate_object then null; end $$;

do $$ begin
  alter table guide.shoes add constraint shoes_author_sizes_owned check (
    owned_by_author or (author_size_eu is null and author_street_size_eu is null)
  );
exception when duplicate_object then null; end $$;

alter table guide.gyms add column if not exists grading_difficulty smallint;

do $$ begin
  alter table guide.gyms add constraint gyms_grading_difficulty_range check (grading_difficulty between 1 and 5);
exception when duplicate_object then null; end $$;
