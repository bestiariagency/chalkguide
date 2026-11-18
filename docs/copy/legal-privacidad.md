# /privacidad · borrador (F7.4)

> **Borrador: requiere revisión legal antes de publicar.** Redactado por loro-lola a partir de los hechos que Xavi ha confirmado y del modelo de datos (`docs/data-model.md`). No es asesoría legal ni se ha revisado por un profesional. Destino: `guide.pages` (key `privacy`), `body_*_es` / `body_*_en`.

Todo lo que dice `[PENDIENTE XAVI: …]` es un dato que solo Xavi puede aportar.

---

## ES

### Política de privacidad

**Quién trata tus datos**

El responsable es [PENDIENTE XAVI: nombre o razón social], NIF [PENDIENTE XAVI: NIF], con domicilio en [PENDIENTE XAVI: domicilio]. Contacto para cualquier cuestión de privacidad: [PENDIENTE XAVI: email].

**Qué datos trato, para qué y con qué base**

| Qué | Para qué | Base legal |
| --- | --- | --- |
| Email, idioma, fecha y origen del consentimiento, versión del texto aceptado, página donde te apuntaste | Enviarte la newsletter mensual y poder demostrar que la pediste | Tu consentimiento (art. 6.1.a RGPD) |
| Nombre y apellidos de tu cuenta de Google, email, identificador de usuario | Que puedas entrar y opinar. En las opiniones se publica tu nombre y la inicial del apellido (por ejemplo, Marta G.) | Ejecución del servicio que pides (art. 6.1.b) |
| Tus opiniones: notas por criterio, texto y fotos | Mostrarlas en la ficha y calcular la nota de lectores | Tu consentimiento al publicarlas y mi interés legítimo en moderarlas (art. 6.1.a y 6.1.f) |
| Lista de espera de Chalk app por rocódromo: usuario y rocódromo | Avisarte cuando se abra la pizarra | Tu consentimiento (art. 6.1.a) |
| Datos técnicos de las visitas (IP, navegador) | Servir la web y mantenerla segura | Interés legítimo (art. 6.1.f) |
| Medición propia de visitas (`guide.analytics_events`): página, idioma, clase de origen, móvil o escritorio, hora truncada a la hora en punto. Sin IP, sin navegador, sin identificadores, sin cookies [D86] | Saber qué páginas se leen y qué artículos llevan a la newsletter | No trata datos personales; no requiere base legal del RGPD ni consentimiento de cookies. [PENDIENTE revisión legal: confirmar] |
| Analítica de Google (Google Analytics 4): identificador de cookie, IP, dispositivo y navegador, páginas vistas [D86] | Saber qué páginas se leen y desde dónde llegan los lectores | Tu consentimiento (art. 6.1.a RGPD y art. 22.2 LSSI), solo si aceptas «Analítica» |
| Publicidad y remarketing (Google Ads y píxel de Meta): identificador de cookie, IP, dispositivo y navegador, páginas vistas, alta en la newsletter como evento (sin tu email) [D86] | Medir anuncios y mostrártelos en otras webs y redes si has visitado ChalkGuide | Tu consentimiento (art. 6.1.a RGPD y art. 22.2 LSSI), solo si aceptas «Publicidad y remarketing» |

**Cookies, medición y publicidad** [D86]

Detallo qué cookies hay y cuánto duran en la [política de cookies](/cookies). Aquí, lo que importa para tus datos:

- Hay una medición propia sin cookies que no guarda tu IP ni ningún identificador. Es siempre la misma, aceptes o no.
- Google Analytics, Google Ads y el píxel de Meta solo se activan si lo permites en el banner. Aceptar y rechazar están al mismo nivel. Entrar con Google para opinar **no** es consentir cookies ni la newsletter.
- **No subo tu email, ni ninguna lista de emails, a Google ni a Meta.** Las altas en la newsletter se miden como un evento sin datos personales. Tengo desactivada la «coincidencia avanzada» automática del píxel de Meta, que de otro modo podría recoger el email de un formulario. [PENDIENTE XAVI: comprobar que está desactivada en el Administrador de Eventos de Meta.]
- Puedes retirar el consentimiento cuando quieras desde «Preferencias de cookies», al pie de cada página; es tan fácil como darlo. Para no ver anuncios personalizados también puedes usar los ajustes de anuncios de [Google](https://myadcenter.google.com) y de [Meta](https://www.facebook.com/adpreferences).
- Los artículos sobre lesiones quedan fuera de las listas de remarketing.

**Newsletter**

Para apuntarte tienes que marcar una casilla, que viene desmarcada, y confirmar después tu dirección desde un email que te envío (doble confirmación). Guardo la fecha y el origen de tu consentimiento. No guardo tu IP ni los datos de tu navegador al apuntarte. Te das de baja con un clic desde cualquier carta. Entrar con Google **no** te suscribe a la newsletter: es un consentimiento distinto y solo se da con la casilla.

**Cuenta con Google**

Entras con Google para opinar. Lo que recibo de tu cuenta es lo necesario para identificarte y mostrar tu nombre con la inicial del apellido. No recibo tu contraseña. Google trata tus datos según su propia política.

**Opiniones de lectores**

Tu opinión se publica en el momento y la reviso después. Puedes editarla o borrarla cuando quieras. Si pides que se borre tu cuenta o tus datos, se suprimen también tus opiniones y fotos.

**Chalk app**

ChalkGuide comparte base de datos y cuentas de usuario con Chalk app, la aplicación para encontrar compañeros de escalada. La misma cuenta sirve en las dos. [PENDIENTE XAVI: confirmar que Chalk app tiene su propia política de privacidad y enlazarla; decidir si el mismo responsable trata los datos de ambas.]

**Quién más ve tus datos (encargados y terceros)**

- Supabase: base de datos, autenticación y almacenamiento de archivos. [PENDIENTE XAVI: región del proyecto y garantías de transferencia internacional.]
- Netlify: alojamiento de la web. Puede registrar datos técnicos de conexión.
- Brevo: envío de la newsletter. Recibe tu email y el estado de tu suscripción.
- Google: inicio de sesión y, solo si pulsas «Reproducir vídeo», el reproductor de YouTube (ver la [política de cookies](/cookies)). [D86] Además, solo si aceptas, Google Analytics 4 y Google Ads (Google actúa como responsable de esos datos). Google Search Console mide cómo aparece ChalkGuide en Google y no recibe datos tuyos.
- Meta: solo si aceptas «Publicidad y remarketing», el píxel de Meta (Meta actúa como responsable de esos datos). [D86]
- [D86] El banner de cookies se sirve desde ChalkGuide: ningún proveedor externo recibe tu IP al mostrarlo.

[D86] **Transferencias fuera del Espacio Económico Europeo.** Google y Meta son empresas con sede en EE. UU. (o con matriz allí), así que lo que reciban de ti si aceptas puede transferirse a ese país, con las garantías que ellas aplican [PENDIENTE leona-lia: entidad responsable en cada caso y garantía concreta, p. ej. marco de privacidad de datos UE-EE. UU.]. Si rechazas, esos envíos no ocurren. Lo mismo vale para Supabase, Netlify y Brevo según su ubicación [PENDIENTE XAVI: región de cada uno].

Con la excepción de lo que tú permitas a Google y Meta en el banner, no vendo tus datos ni los cedo para publicidad.

**Cuánto tiempo los conservo**

- Newsletter: mientras sigas suscrito. [PENDIENTE XAVI: qué se conserva tras la baja y durante cuánto tiempo, p. ej. prueba del consentimiento.]
- Cuenta y opiniones: [PENDIENTE XAVI: plazo].
- Registros de actividad: [PENDIENTE XAVI: plazo; el modelo propone 24 meses en el registro de auditoría del panel].
- [D86] Medición propia (`guide.analytics_events`): [PENDIENTE XAVI / jabali-javi: la spec propone 90 días para las filas brutas y 24 meses para los recuentos agregados, que no permiten identificar a nadie].
- [D86] Google Analytics 4: 2 meses en los datos de eventos [PENDIENTE: confirmar al configurar la propiedad]. Listas de remarketing: hasta 540 días en Google y 180 en Meta [PENDIENTE: confirmar al crearlas]. Cookies: según la [política de cookies](/cookies).
- [D86] Tu elección de cookies (`cc_cookie`): [PENDIENTE XAVI: duración; se propone renovarla a los 24 meses].
- Lista de espera de Chalk app: hasta que se abra la pizarra o pidas salir. [PENDIENTE XAVI: confirmar].

**Tus derechos**

Puedes acceder a tus datos, rectificarlos, suprimirlos, oponerte, pedir su limitación y su portabilidad, y retirar tu consentimiento en cualquier momento sin que afecte a lo anterior. [D86] Retirar el de cookies es tan fácil como darlo: «Preferencias de cookies», al pie de cada página. Escríbeme a [PENDIENTE XAVI: email]. Si crees que no he tratado bien tus datos, puedes reclamar ante la Agencia Española de Protección de Datos (aepd.es).

**Menores**

[PENDIENTE XAVI / revisión legal: edad mínima para opinar o suscribirse.]

**Cambios**

Si cambio esta política, lo diré aquí con la fecha de actualización.

## EN

### Privacy policy

**Who processes your data**

The controller is [PENDING XAVI: name or company name], tax ID [PENDING XAVI: tax ID], address [PENDING XAVI: address]. Contact for any privacy matter: [PENDING XAVI: email].

**What data I process, why and on what basis**

| What | Why | Legal basis |
| --- | --- | --- |
| Email, language, date and source of consent, version of the text accepted, page where you signed up | To send you the monthly newsletter and to be able to show you asked for it | Your consent (Art. 6(1)(a) GDPR) |
| Name and surname from your Google account, email, user ID | So you can sign in and leave reviews. Reviews show your first name and the initial of your surname (for example, Marta G.) | Performance of the service you ask for (Art. 6(1)(b)) |
| Your reviews: scores per criterion, text and photos | To show them on the listing and calculate the readers' score | Your consent when you publish them and my legitimate interest in moderating them (Art. 6(1)(a) and (f)) |
| Chalk app waiting list per gym: user and gym | To let you know when the board opens | Your consent (Art. 6(1)(a)) |
| Technical visit data (IP, browser) | To serve the site and keep it secure | Legitimate interest (Art. 6(1)(f)) |
| Own visit measurement (`guide.analytics_events`): page, language, kind of source, mobile or desktop, time truncated to the hour. No IP, no browser, no identifiers, no cookies [D86] | To know which pages are read and which articles lead to the newsletter | It does not process personal data; no GDPR legal basis or cookie consent needed. [PENDING legal review: confirm] |
| Google analytics (Google Analytics 4): cookie identifier, IP, device and browser, page views [D86] | To know which pages are read and where readers come from | Your consent (Art. 6(1)(a) GDPR and Art. 22.2 LSSI), only if you accept "Analytics" |
| Advertising and remarketing (Google Ads and Meta pixel): cookie identifier, IP, device and browser, page views, newsletter sign-up as an event (without your email) [D86] | To measure ads and show them to you on other sites and networks if you have visited ChalkGuide | Your consent (Art. 6(1)(a) GDPR and Art. 22.2 LSSI), only if you accept "Advertising and remarketing" |

**Cookies, measurement and advertising** [D86]

I list which cookies exist and how long they last in the [cookie policy](/en/cookies). Here, what matters for your data:

- There is an own measurement with no cookies that keeps neither your IP nor any identifier. It is always the same, whether you accept or not.
- Google Analytics, Google Ads and the Meta pixel only switch on if you allow them in the banner. Accepting and rejecting sit at the same level. Signing in with Google to leave a review is **not** consent to cookies or to the newsletter.
- **I do not upload your email, or any list of emails, to Google or Meta.** Newsletter sign-ups are measured as an event with no personal data. I have switched off the Meta pixel's automatic "advanced matching", which could otherwise pick up the email from a form. [PENDING XAVI: check it is switched off in Meta Events Manager.]
- You can withdraw consent whenever you like from "Cookie preferences" at the foot of every page; it is as easy as giving it. To avoid personalised ads you can also use the ad settings of [Google](https://myadcenter.google.com) and [Meta](https://www.facebook.com/adpreferences).
- Articles about injuries are kept out of remarketing lists.

**Newsletter**

To sign up you tick a box, which starts unticked, and then confirm your address from an email I send you (double opt-in). I keep the date and source of your consent. I do not keep your IP or browser details when you sign up. You can unsubscribe in one click from any letter. Signing in with Google does **not** subscribe you to the newsletter: that is a separate consent, given only through the box.

**Google account**

You sign in with Google to leave reviews. What I receive from your account is what is needed to identify you and to show your name with your surname initial. I never receive your password. Google processes your data under its own policy.

**Reader reviews**

Your review is published straight away and I check it afterwards. You can edit or delete it whenever you like. If you ask for your account or data to be deleted, your reviews and photos are deleted too.

**Chalk app**

ChalkGuide shares its database and user accounts with Chalk app, the app for finding climbing partners. The same account works on both. [PENDING XAVI: confirm that Chalk app has its own privacy policy and link to it; decide whether the same controller handles both.]

**Who else sees your data (processors and third parties)**

- Supabase: database, authentication and file storage. [PENDING XAVI: project region and international transfer safeguards.]
- Netlify: web hosting. It may log technical connection data.
- Brevo: sending the newsletter. It receives your email and subscription status.
- Google: sign-in and, only if you press "Play video", the YouTube player (see the [cookie policy](/en/cookies)). [D86] Also, only if you accept, Google Analytics 4 and Google Ads (Google acts as controller of that data). Google Search Console measures how ChalkGuide appears in Google and receives no data from you.
- Meta: only if you accept "Advertising and remarketing", the Meta pixel (Meta acts as controller of that data). [D86]
- [D86] The cookie banner is served from ChalkGuide: no outside provider receives your IP when it is shown.

[D86] **Transfers outside the European Economic Area.** Google and Meta are US-based companies (or have a US parent), so what they receive from you if you accept may be transferred to that country, under the safeguards they apply [PENDING leona-lia: controller entity in each case and the specific safeguard, e.g. EU-US Data Privacy Framework]. If you reject, those transfers do not happen. The same goes for Supabase, Netlify and Brevo depending on where they are located [PENDING XAVI: region of each].

Apart from what you allow Google and Meta in the banner, I do not sell your data or share it for advertising.

**How long I keep it**

- Newsletter: while you stay subscribed. [PENDING XAVI: what is kept after you unsubscribe and for how long, e.g. proof of consent.]
- Account and reviews: [PENDING XAVI: period].
- Activity logs: [PENDING XAVI: period; the data model proposes 24 months for the panel audit log].
- [D86] Own measurement (`guide.analytics_events`): [PENDING XAVI / jabali-javi: the spec proposes 90 days for raw rows and 24 months for aggregated counts, which cannot identify anyone].
- [D86] Google Analytics 4: 2 months for event data [PENDING: confirm when the property is set up]. Remarketing lists: up to 540 days at Google and 180 at Meta [PENDING: confirm when they are created]. Cookies: see the [cookie policy](/en/cookies).
- [D86] Your cookie choice (`cc_cookie`): [PENDING XAVI: duration; renewing it every 24 months is proposed].
- Chalk app waiting list: until the board opens or you ask to leave. [PENDING XAVI: confirm].

**Your rights**

You can access, correct and delete your data, object, ask for restriction and portability, and withdraw your consent at any time without affecting what happened before. [D86] Withdrawing cookie consent is as easy as giving it: "Cookie preferences", at the foot of every page. Write to me at [PENDING XAVI: email]. If you think I have mishandled your data, you can complain to the Spanish Data Protection Agency (aepd.es).

**Minors**

[PENDING XAVI / legal review: minimum age to review or subscribe.]

**Changes**

If I change this policy, I will say so here with the update date.

---

## Afirmaciones que Xavi debe confirmar

1. Todos los [PENDIENTE]: responsable, NIF, domicilio, email, región de Supabase, plazos de conservación, edad mínima, herramienta de analítica.
2. Que ChalkGuide no recibe de Google más que nombre, email e identificador (comprobar la configuración del proveedor en Supabase Auth).
3. Que al suscribirse no se guarda IP ni navegador (así consta en `subscribers`; revisar también lo que Brevo registre por su cuenta).
4. Que borrar la cuenta o pedir la supresión elimina también opiniones y fotos (hoy el panel solo borra por supresión RGPD o contenido ilegal, D30).
5. Que el mismo responsable trata Chalk app y ChalkGuide, y qué política enlaza.
6. Que las bases legales de la tabla son las que quieres defender: es el punto principal para la revisión legal.
7. Que no hay transferencia de datos a EE. UU. aparte de las inherentes a Google, Meta, Brevo, Netlify y Supabase, y qué garantías aplican. [D86]
8. [D86] Que la coincidencia avanzada automática de Meta está desactivada y que no se sube ningún email a Google ni a Meta (Customer Match fuera).
9. [D86] Que la medición propia trunca la hora y no guarda IP ni user agent, y sus plazos; y que la fila de la tabla dice lo que de verdad hace la base de datos (jabali-javi / leona-lia).
10. [D86] Que las listas de remarketing excluyen artículos sobre lesiones y que los plazos (GA4 2 meses; 540 / 180 días) son los configurados.
11. [D86] Que, con `vanilla-cookieconsent` autoalojado, ningún proveedor recibe la IP al mostrar el banner (y que no hay registro de consentimientos en servidor: decidir cómo se prueba el consentimiento, con leona-lia).
