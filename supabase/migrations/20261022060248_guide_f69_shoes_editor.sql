-- F6.9: pies de gato en el panel. Endurece los CHECK de guide.shoes (afiliado, precio con fecha, marca/modelo).
-- Todos son expresiones puras: draft_check_payload los evalúa al guardar el borrador (23514 'check violation: <nombre>').

-- 1. URL de afiliado: https, host con dominio (sin userinfo "tienda.com@otro.com"), puerto opcional y ruta solo con
--    caracteres de URL RFC 3986 (sin espacios, controles, comillas, <, >, \ ni Unicode invisible). ≤ 2048.
alter table guide.shoes drop constraint if exists shoes_affiliate_url_check;
alter table guide.shoes add constraint shoes_affiliate_url_check check (
  char_length(affiliate_url) <= 2048
  and affiliate_url ~ '^https://([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}(:[0-9]{1,5})?([/?#][-A-Za-z0-9._~:/?#@!$&''()*+,;=%]*)?$'
);

-- 2. Programa de afiliado solo con enlace (la marca se deriva de affiliate_url vía is_affiliate) y no en blanco.
alter table guide.shoes drop constraint if exists shoes_affiliate_program_needs_url;
alter table guide.shoes add constraint shoes_affiliate_program_needs_url check (
  affiliate_program is null or (affiliate_url is not null and btrim(affiliate_program) <> '')
);

-- 3. Todo precio lleva su fecha (conventions: precios con fecha de verificación).
alter table guide.shoes drop constraint if exists shoes_price_dated;
alter table guide.shoes add constraint shoes_price_dated check (
  (price_min_eur is null and price_max_eur is null) or price_checked_at is not null
);

-- 4. Marca y modelo sin espacios en los extremos: el unique (lower(brand), lower(model)) no se esquiva con " Scarpa".
alter table guide.shoes drop constraint if exists shoes_brand_trimmed;
alter table guide.shoes add constraint shoes_brand_trimmed check (brand = btrim(brand));
alter table guide.shoes drop constraint if exists shoes_model_trimmed;
alter table guide.shoes add constraint shoes_model_trimmed check (model = btrim(model));
