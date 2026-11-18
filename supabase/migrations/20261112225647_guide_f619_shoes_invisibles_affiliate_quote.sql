-- F6.19 punto 7 (O4 de F6.9 y O3 opcional; docs/security/F6.19-panel-review.md). Idempotente.
-- O4: marca y modelo de pies de gato tampoco empiezan ni acaban por invisibles que seguían pasando: U+00AD, U+034F,
--     U+115F–1160, U+17B4–17B5, U+180B–180D, U+2066–2069, U+3164, U+FFA0 y etiquetas U+E0000–E007F. Se conservan los
--     rangos anteriores (20261022061659). CHECK puro; draft_check_payload lo hereda. Ninguna fila existente lo incumple.
-- O3: shoes_affiliate_url_check deja de admitir «'» (igual que el panel, que ya rechaza "'<>). Ninguna fila lo incumple.
alter table guide.shoes drop constraint if exists shoes_brand_trimmed;
alter table guide.shoes add constraint shoes_brand_trimmed check (
  brand !~ '^[[:space:]\u00A0\u00AD\u034F\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]|[[:space:]\u00A0\u00AD\u034F\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]$'
);
alter table guide.shoes drop constraint if exists shoes_model_trimmed;
alter table guide.shoes add constraint shoes_model_trimmed check (
  model !~ '^[[:space:]\u00A0\u00AD\u034F\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]|[[:space:]\u00A0\u00AD\u034F\u115F-\u1160\u1680\u17B4-\u17B5\u180B-\u180E\u2000-\u200F\u2028-\u202F\u205F-\u2064\u2066-\u2069\u3000\u3164\uFEFF\uFFA0\U000E0000-\U000E007F]$'
);

alter table guide.shoes drop constraint if exists shoes_affiliate_url_check;
alter table guide.shoes add constraint shoes_affiliate_url_check check (
  char_length(affiliate_url) <= 2048
  and affiliate_url ~ '^https://([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(:[0-9]{1,5})?([/?#][-A-Za-z0-9._~:/?#@!$&()*+,;=%]*)?$'
);
