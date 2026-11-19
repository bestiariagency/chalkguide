# /cookies · borrador (F7.4)

> **Borrador: requiere revisión legal antes de publicar.** Redactado por loro-lola. No es asesoría legal ni se ha revisado por un profesional. Destino: `guide.pages` (key `cookies`), `body_*_es` / `body_*_en`. La sección «Vídeos de YouTube» es el párrafo **aprobado por Xavi el 2026-10-15** (`docs/copy/cookies-youtube.md`), incorporado sin cambios. Lo marcado `[D86]` es nuevo o cambiado por la decisión del banner de consentimiento (GA4, Google Ads, píxel de Meta); los textos del banner viven en `docs/copy/cookies-banner.md`.

---

## ES

### Política de cookies

**Qué son**

Las cookies y el almacenamiento local son pequeños archivos o datos que una web guarda en tu navegador. Algunos son imprescindibles para que funcione algo que has pedido; otros sirven para medir o para mostrar publicidad.

**Qué uso en ChalkGuide** [D86]

Para leer ChalkGuide no hace falta aceptar nada: si rechazas, la web funciona igual. Hay dos capas.

1. **Sin cookies y sin pedirte nada.** Cuento las visitas con un sistema propio que no usa cookies ni almacenamiento en tu navegador y no guarda tu IP, tu navegador ni ningún identificador tuyo (más abajo, «Medición propia»). Además uso Google Search Console, que mide cómo aparece ChalkGuide en Google y no instala nada en tu navegador.
2. **Solo con tu permiso.** Al entrar te pregunto si permites la analítica de Google y la publicidad de Google y Meta. Hasta que elijas, no se carga nada de Google ni de Meta. Aceptar y rechazar están al mismo nivel, desplazarte por la página no cuenta como aceptar y puedes cambiar de idea cuando quieras.

| Qué | Proveedor | Para qué | Cuándo | Duración |
| --- | --- | --- | --- | --- |
| `cc_cookie` [D86] | ChalkGuide | Guardar tu elección de cookies | Al elegir | [D86] 365 días si aceptas y 182 días si rechazas. Pasado ese plazo, te vuelvo a preguntar |
| Sesión de Supabase (cookie o almacenamiento local) | Supabase | Mantenerte conectado si entras con Google para opinar | Solo si inicias sesión | [PENDIENTE XAVI: duración real; comprobarla en la configuración de Supabase Auth] |
| `cg_news_view` | ChalkGuide | Recordar si prefieres ver las noticias en cuadrícula o en lista | Solo si cambias la vista | 1 año |
| Idioma | ChalkGuide | Recordar si prefieres español o inglés | [PENDIENTE XAVI: confirmar si la web guarda esta preferencia y cómo, p. ej. cookie de `@nuxtjs/i18n`] | [PENDIENTE XAVI] |
| `_ga`, `_ga_<id>` [D86] | Google (Google Analytics 4) | Distinguir visitas para saber qué páginas se leen y desde dónde llegan | Solo si aceptas «Analítica» | [PENDIENTE: confirmar en el escaneo; Google indica 2 años por defecto] |
| `_gcl_*` [D86] | Google (Google Ads) | Medir si un anuncio de Google ha llevado a una visita | Solo si aceptas «Publicidad y remarketing» | [PENDIENTE: confirmar en el escaneo; Google indica 90 días por defecto] |
| `_fbp` [D86] | Meta (píxel de Meta) | Reconocer tu navegador para crear listas de remarketing | Solo si aceptas «Publicidad y remarketing» | [PENDIENTE: confirmar en el escaneo; Meta indica 90 días por defecto] |
| `_fbc` [D86] | Meta (píxel de Meta) | Guardar de qué anuncio de Meta vienes, si llegas desde uno, para medir si ha llevado a una visita | Solo si aceptas «Publicidad y remarketing» y llegas desde un anuncio de Meta | [PENDIENTE: confirmar en el escaneo; Meta indica 90 días por defecto] |

Las cuatro primeras filas de la tabla (`cc_cookie`, sesión, `cg_news_view`, idioma) son técnicas: no requieren tu consentimiento, pero te las cuento. Las cuatro últimas solo existen si las aceptas.

**Qué hace cada categoría que pide permiso** [D86]

- **Analítica.** Google Analytics 4 me dice qué páginas se leen y desde dónde llegan los lectores, para decidir qué escribir. No lo uso para anuncios. Los datos se conservan en Google dos meses (el mínimo que permite) y no activo las señales de Google ni envío datos tuyos como el email.
- **Publicidad y remarketing.** La etiqueta de Google Ads y el píxel de Meta recuerdan que has visitado ChalkGuide para mostrarte sus anuncios en otras webs y redes. Con ellos se miden también las altas en la newsletter, **sin enviar nunca tu email ni ningún dato que te identifique**. Tengo desactivada la «coincidencia avanzada» automática del píxel de Meta, que de otro modo podría recoger el email que escribes en un formulario. Si aceptas, entras en listas de remarketing que se conservan hasta 540 días en Google y 180 en Meta [PENDIENTE: confirmar los plazos al crear las listas]. Los artículos sobre lesiones quedan fuera de esas listas.
- **Google Consent Mode.** Uso Consent Mode v2 en modo básico: los cuatro permisos de Google (`analytics_storage`, `ad_storage`, `ad_user_data`, `ad_personalization`) parten en «denegado» y no se carga ningún script de Google ni de Meta hasta que aceptas. «Analítica» activa solo el primero; «Publicidad y remarketing» activa los otros tres a la vez.

**Medición propia, sin cookies** [D86]

Cada página vista y algunas acciones (por ejemplo, un clic en un enlace de afiliado o llegar a la newsletter) se anotan en una tabla propia, `guide.analytics_events`. Ahí guardo qué página, en qué idioma, de qué clase de origen viene la visita (buscador, redes, directo…) y si es móvil o escritorio, con la hora **truncada a la hora en punto**. No guardo tu IP, ni tu navegador, ni ningún identificador de sesión, de dispositivo o de usuario, ni uso cookies. Por eso no puedo saber cuántas personas distintas hay: solo cuántas páginas se leen. Esta medición no necesita tu permiso y no depende del banner. [PENDIENTE XAVI / jabali-javi: confirmar que la hora se trunca al guardar y el plazo de conservación; la spec propone 90 días para los datos brutos y 24 meses para los recuentos agregados.]

**Quién recibe datos y adónde van** [D86]

Google y Meta reciben tu dirección IP, datos técnicos de tu navegador y lo que hagas en ChalkGuide **solo si aceptas**, y los tratan como responsables según sus propias políticas ([Google](https://policies.google.com/privacy), [Meta](https://www.facebook.com/privacy/policy)). Son empresas con sede en EE. UU. (o con matriz allí), así que esos datos pueden transferirse fuera del Espacio Económico Europeo. [PENDIENTE leona-lia: confirmar qué entidad es responsable en cada caso y qué garantía de transferencia aplica (marco de privacidad de datos UE-EE. UU. u otra).] El banner de cookies se sirve desde ChalkGuide, no desde un tercero: no se contacta con Google ni con Meta antes de que elijas.

La newsletter no usa cookies: el alta se hace con un formulario y la confirmación, por email.

**Vídeos de YouTube**

Algunos artículos incluyen vídeos de YouTube, un servicio de Google LLC. ChalkGuide no carga nada de YouTube ni de Google mientras lees: ni el reproductor, ni la miniatura, ni scripts. El vídeo aparece como un recuadro con el botón «Reproducir vídeo», y solo cuando lo pulsas se carga el reproductor desde `youtube-nocookie.com`, un dominio de YouTube.

Al pulsarlo, YouTube recibe tu dirección IP y los datos técnicos habituales de tu navegador, y puede guardar identificadores en el almacenamiento local de tu navegador o instalar cookies propias para hacer funcionar el reproductor, medir su uso y, según tu cuenta y tus ajustes de Google, personalizar lo que ves. Esos datos los trata Google como responsable, no ChalkGuide, y nosotros no los vemos ni los guardamos. Si no pulsas el botón, nada de esto ocurre.

Si prefieres no cargar el reproductor, cada recuadro incluye un enlace «Ver en YouTube» que abre el vídeo en youtube.com. Puedes borrar lo que YouTube haya guardado desde los ajustes de tu navegador. Más información en la [política de privacidad de Google](https://policies.google.com/privacy).

Los vídeos no dependen del banner: aceptar o rechazar cookies no los carga ni los bloquea. [D86]

**Cómo cambiar o retirar tu elección** [D86]

[Aquí va el bloque «Tu elección» (`id="preferencias"`), con tu estado actual y el botón para cambiarla.] Desde el enlace «Preferencias de cookies», al pie de cada página, puedes cambiar tu elección o retirarla cuando quieras; retirarla es tan fácil como darla. Al retirarla dejan de enviarse datos a Google y a Meta y se borran las cookies `_ga*`, `_gcl_*`, `_fbp` y `_fbc` de este sitio. Para oponerte a los anuncios personalizados también puedes usar los ajustes de anuncios de [Google](https://myadcenter.google.com) y de [Meta](https://www.facebook.com/adpreferences). Fecha de la última actualización de esta política: [PENDIENTE XAVI: fecha al publicar].

También puedes borrar o bloquear cookies y almacenamiento local desde los ajustes de tu navegador. Si bloqueas el de la sesión, no podrás entrar para opinar.

**Cambios**

Si cambio las herramientas que uso o sus cookies, actualizaré esta página y volveré a preguntarte si hace falta. [D86]

## EN

### Cookie policy

**What they are**

Cookies and local storage are small files or pieces of data that a website saves in your browser. Some are essential for something you have asked for; others are used to measure or to show advertising.

**What I use on ChalkGuide** [D86]

You do not need to accept anything to read ChalkGuide: if you reject, the site works the same. There are two layers.

1. **No cookies, and nothing asked of you.** I count visits with my own system, which uses no cookies or storage in your browser and does not keep your IP, your browser or any identifier of yours (see "Own measurement" below). I also use Google Search Console, which measures how ChalkGuide appears in Google and installs nothing in your browser.
2. **Only with your permission.** When you arrive I ask whether you allow Google analytics and Google and Meta advertising. Until you choose, nothing from Google or Meta is loaded. Accepting and rejecting sit at the same level, scrolling the page does not count as accepting, and you can change your mind whenever you like.

| What | Provider | Purpose | When | Duration |
| --- | --- | --- | --- | --- |
| `cc_cookie` [D86] | ChalkGuide | To store your cookie choice | When you choose | [D86] 365 days if you accept and 182 days if you reject. After that I ask you again |
| Supabase session (cookie or local storage) | Supabase | To keep you signed in if you sign in with Google to leave a review | Only if you sign in | [PENDING XAVI: actual duration; check in the Supabase Auth settings] |
| `cg_news_view` | ChalkGuide | To remember whether you prefer to see the news as a grid or as a list | Only if you change the view | 1 year |
| Language | ChalkGuide | To remember whether you prefer Spanish or English | [PENDING XAVI: confirm whether the site stores this preference and how, e.g. an `@nuxtjs/i18n` cookie] | [PENDING XAVI] |
| `_ga`, `_ga_<id>` [D86] | Google (Google Analytics 4) | To tell visits apart so I know which pages are read and where readers come from | Only if you accept "Analytics" | [PENDING: confirm in the scan; Google states 2 years by default] |
| `_gcl_*` [D86] | Google (Google Ads) | To measure whether a Google ad led to a visit | Only if you accept "Advertising and remarketing" | [PENDING: confirm in the scan; Google states 90 days by default] |
| `_fbp` [D86] | Meta (Meta pixel) | To recognise your browser for remarketing lists | Only if you accept "Advertising and remarketing" | [PENDING: confirm in the scan; Meta states 90 days by default] |
| `_fbc` [D86] | Meta (Meta pixel) | To store which Meta ad you came from, if you arrive from one, to measure whether it led to a visit | Only if you accept "Advertising and remarketing" and arrive from a Meta ad | [PENDING: confirm in the scan; Meta states 90 days by default] |

The first four rows (`cc_cookie`, session, `cg_news_view`, language) are technical: they do not need your consent, but I tell you about them. The last four exist only if you accept them.

**What each category that asks for permission does** [D86]

- **Analytics.** Google Analytics 4 tells me which pages are read and where readers come from, so I can decide what to write. I do not use it for ads. Google keeps the data for two months (the minimum it allows), and I do not switch on Google signals or send your data such as your email.
- **Advertising and remarketing.** The Google Ads tag and the Meta pixel remember that you visited ChalkGuide so their ads can be shown to you on other sites and networks. They also measure newsletter sign-ups, **without ever sending your email or any data that identifies you**. I have switched off the Meta pixel's automatic "advanced matching", which could otherwise pick up the email you type into a form. If you accept, you join remarketing lists kept for up to 540 days at Google and 180 at Meta [PENDING: confirm the periods when the lists are created]. Articles about injuries are kept out of those lists.
- **Google Consent Mode.** I use Consent Mode v2 in basic mode: Google's four permissions (`analytics_storage`, `ad_storage`, `ad_user_data`, `ad_personalization`) start as "denied", and no Google or Meta script is loaded until you accept. "Analytics" switches on only the first; "Advertising and remarketing" switches on the other three together.

**Own measurement, no cookies** [D86]

Every page view and a few actions (for example, a click on an affiliate link or reaching the newsletter) are noted in a table of my own, `guide.analytics_events`. It stores which page, in which language, what kind of source the visit comes from (search engine, social, direct…) and whether it is mobile or desktop, with the time **truncated to the hour**. I do not keep your IP, your browser, or any session, device or user identifier, and I use no cookies. That is why I cannot tell how many different people there are: only how many pages are read. This measurement does not need your permission and does not depend on the banner. [PENDING XAVI / jabali-javi: confirm that the time is truncated when stored and the retention period; the spec proposes 90 days for raw data and 24 months for aggregated counts.]

**Who receives data and where it goes** [D86]

Google and Meta receive your IP address, technical data from your browser and what you do on ChalkGuide **only if you accept**, and they process it as controllers under their own policies ([Google](https://policies.google.com/privacy), [Meta](https://www.facebook.com/privacy/policy)). They are US-based companies (or have a US parent), so that data may be transferred outside the European Economic Area. [PENDING leona-lia: confirm which entity is the controller in each case and what transfer safeguard applies (EU-US Data Privacy Framework or other).] The cookie banner is served from ChalkGuide, not from a third party: neither Google nor Meta is contacted before you choose.

The newsletter does not use cookies: sign-up is a form and the confirmation is by email.

**YouTube videos**

Some articles include YouTube videos. YouTube is a service of Google LLC. ChalkGuide loads nothing from YouTube or Google while you read: no player, no thumbnail, no scripts. The video appears as a placeholder with a "Play video" button, and the player is only loaded from `youtube-nocookie.com`, a YouTube domain, once you press it.

When you press it, YouTube receives your IP address and the usual technical data from your browser, and may store identifiers in your browser's local storage or set its own cookies in order to run the player, measure its use and, depending on your Google account and settings, personalise what you see. Google, not ChalkGuide, is the controller of that data, and we neither see nor keep it. If you don't press the button, none of this happens.

If you'd rather not load the player, each placeholder has a "Watch on YouTube" link that opens the video on youtube.com. You can delete anything YouTube has stored from your browser settings. More information in [Google's privacy policy](https://policies.google.com/privacy).

Videos do not depend on the banner: accepting or rejecting cookies neither loads nor blocks them. [D86]

**How to change or withdraw your choice** [D86]

[The "Your choice" block (`id="preferences"`) goes here, with your current status and the button to change it.] From the "Cookie preferences" link at the foot of every page you can change or withdraw your choice whenever you like; withdrawing is as easy as giving. When you withdraw, no more data is sent to Google or Meta and the `_ga*`, `_gcl_*`, `_fbp` and `_fbc` cookies are deleted from this site. To object to personalised ads you can also use the ad settings of [Google](https://myadcenter.google.com) and [Meta](https://www.facebook.com/adpreferences). Date this policy was last updated: [PENDING XAVI: date at publication].

You can also delete or block cookies and local storage from your browser settings. If you block the session data, you will not be able to sign in to leave a review.

**Changes**

If I change the tools I use or their cookies, I will update this page and ask you again if needed. [D86]

---

## Afirmaciones que Xavi debe confirmar

1. [D86] Ya hay banner: «no hay banner porque solo hay lo imprescindible» queda retirado. La frase «rechazar no cambia nada» es cierta mientras ningún contenido dependa de Google o Meta (los vídeos van aparte, D26).
2. Qué guarda de verdad la sesión de Supabase en el navegador (cookie o almacenamiento local) y cuánto dura. Comprobarlo en el navegador, no suponerlo.
3. Si el idioma se recuerda y cómo.
4. Que el formulario de newsletter no deja ninguna cookie (el alta no guarda nada en el navegador).
5. [D86] Duraciones reales de `cc_cookie`, `_ga*`, `_gcl_*`, `_fbp`, `_fbc`: salen del escaneo, no de lo que dicen los proveedores por defecto.
6. [D86] Que la coincidencia avanzada automática de Meta está desactivada en el Administrador de Eventos (lo hace Xavi; comprobarlo) y que no se sube ningún email a Google ni a Meta.
7. [D86] Que el recuento propio (`guide.analytics_events`) trunca la hora y no guarda IP ni user agent, y su plazo de conservación (jabali-javi / leona-lia).
8. [D86] Que las listas de remarketing excluyen los artículos sobre lesiones y que los plazos (540 / 180 días) son los que se configuran.
9. Que el sitio no carga ningún otro tercero (fuentes, mapas, imágenes externas) que pueda guardar datos. Pendiente la verificación final de leona-lia sobre el vídeo (0 peticiones a Google antes del clic) y sobre 0 peticiones a Google y Meta antes de elegir.
10. [D86] Transferencias a EE. UU. y entidad responsable de Google y Meta (leona-lia).
