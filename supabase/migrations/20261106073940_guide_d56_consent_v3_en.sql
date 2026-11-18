-- D56: versión 3 del consentimiento de newsletter. Mismo texto es que la v2 + texto en.
-- Se hace por el camino de las guardas (site_settings_consent_version cierra la v2 e inserta la v3
-- en consent_texts). Las guardas no se tocan. Idempotente: solo actúa si la versión vigente es < 3.
update guide.site_settings
   set consent_version            = 3,
       newsletter_consent_text_es = 'Quiero recibir novedades de ChalkGuide por email. Puedo darme de baja cuando quiera.',
       newsletter_consent_text_en = 'I''d like to receive news from ChalkGuide by email. I can unsubscribe at any time.'
 where id = 1
   and consent_version < 3
   and not exists (select 1 from guide.consent_texts where version >= 3);
