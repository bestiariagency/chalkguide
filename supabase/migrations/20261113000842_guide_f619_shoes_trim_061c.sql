-- F6.19 addendum backend (docs/security/F6.19-panel-review.md, observación 1). Idempotente.
-- U+061C (ARABIC LETTER MARK) se suma a la clase de extremos de marca y modelo de pies de gato. Se conservan los rangos
-- de 20261112225647. CHECK puro; draft_check_payload lo hereda. El panel ya lo recorta (app/utils/invisible-trim.ts).
-- Ninguna fila existente lo incumple (comprobado antes de aplicar).
alter table guide.shoes drop constraint if exists shoes_brand_trimmed;
alter table guide.shoes add constraint shoes_brand_trimmed check (
  brand !~ '^[[:space:]\u00A0\u00AD\u034F\u061C\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]|[[:space:]\u00A0\u00AD\u034F\u061C\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]$'
);
alter table guide.shoes drop constraint if exists shoes_model_trimmed;
alter table guide.shoes add constraint shoes_model_trimmed check (
  model !~ '^[[:space:]\u00A0\u00AD\u034F\u061C\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]|[[:space:]\u00A0\u00AD\u034F\u061C\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]$'
);
