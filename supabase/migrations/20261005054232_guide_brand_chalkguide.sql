-- Marca: "ChalkGuide" en una palabra (decisión de Xavi, 2026-10-05). Nunca "Chalk Guide".
-- Cambia los defaults de site_settings y actualiza la fila existente. Re-ejecutable.
-- Si el texto de consentimiento cambia, se sube consent_version (prueba RGPD de qué texto se aceptó).

alter table guide.site_settings alter column site_name set default 'ChalkGuide';
alter table guide.site_settings alter column newsletter_consent_text_es
  set default 'Quiero recibir novedades de ChalkGuide por email. Puedo darme de baja cuando quiera.';

update guide.site_settings
set consent_version = consent_version + 1
where id = 1
  and (newsletter_consent_text_es like '%Chalk Guide%' or coalesce(newsletter_consent_text_en, '') like '%Chalk Guide%');

update guide.site_settings
set site_name                  = replace(site_name, 'Chalk Guide', 'ChalkGuide'),
    tagline_es                 = replace(tagline_es, 'Chalk Guide', 'ChalkGuide'),
    tagline_en                 = replace(tagline_en, 'Chalk Guide', 'ChalkGuide'),
    default_seo_title_es       = replace(default_seo_title_es, 'Chalk Guide', 'ChalkGuide'),
    default_seo_title_en       = replace(default_seo_title_en, 'Chalk Guide', 'ChalkGuide'),
    default_seo_description_es = replace(default_seo_description_es, 'Chalk Guide', 'ChalkGuide'),
    default_seo_description_en = replace(default_seo_description_en, 'Chalk Guide', 'ChalkGuide'),
    footer_text_es             = replace(footer_text_es, 'Chalk Guide', 'ChalkGuide'),
    footer_text_en             = replace(footer_text_en, 'Chalk Guide', 'ChalkGuide'),
    newsletter_title_es        = replace(newsletter_title_es, 'Chalk Guide', 'ChalkGuide'),
    newsletter_title_en        = replace(newsletter_title_en, 'Chalk Guide', 'ChalkGuide'),
    newsletter_body_es         = replace(newsletter_body_es, 'Chalk Guide', 'ChalkGuide'),
    newsletter_body_en         = replace(newsletter_body_en, 'Chalk Guide', 'ChalkGuide'),
    newsletter_consent_text_es = replace(newsletter_consent_text_es, 'Chalk Guide', 'ChalkGuide'),
    newsletter_consent_text_en = replace(newsletter_consent_text_en, 'Chalk Guide', 'ChalkGuide')
where id = 1;
