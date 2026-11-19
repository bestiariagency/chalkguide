# Banner de cookies · textos es/en (D86)

Estado: redactado por loro-lola. Dirección A (barra de papel), sin X, botones Aceptar · Rechazar · Configurar, con Google y Meta nombrados (D86). Herramienta: `vanilla-cookieconsent` (D85). Claves de `docs/design/site/README.md` §16.8. Pendiente de volcar a `i18n/locales/es.json` y `en.json` (lo hace quien implemente; no se ha tocado i18n).

Límites de diseño: título ≤ 32; descripción + enlace ≤ 140 (recuento entre paréntesis); botones del banner ≤ 10; botones del panel ≤ 18.

Notas de voz: tuteo, primera persona de Xavi en el panel («Nunca subo tu email»), sin tono de miedo ni empujón a aceptar. «Rechazar» y «Aceptar» con el mismo peso. Sin promesas que no se cumplan: «Rechazar no cambia nada» es cierto porque el sitio funciona igual sin Google ni Meta.

---

## Banner (primera capa)

| Clave | ES | EN |
| --- | --- | --- |
| `cookies.banner.title` | Las cookies, a tu elección (26) | Cookies are your call (21) |
| `cookies.banner.description` | Con tu permiso, Google mide las visitas y Google y Meta muestran ChalkGuide en otras webs. Rechazar no cambia nada. (115; con el enlace, 135) | With your permission, Google measures visits and Google and Meta show ChalkGuide on other sites. Rejecting changes nothing. (123; with the link, 137) |
| `cookies.banner.policyLink` | Política de cookies (19) | Cookie policy (13) |
| `cookies.banner.accept` | Aceptar (7) | Accept (6) |
| `cookies.banner.reject` | Rechazar (8) | Reject (6) |
| `cookies.banner.settings` | Configurar (10) | Settings (8) |
| `cookies.banner.announce` (solo lector de pantalla) | Aviso de cookies. Puedes aceptar, rechazar o configurar. | Cookie notice. You can accept, reject or adjust settings. |
| `cookies.banner.revision` [D86] (sustituye a `description` cuando la política cambia y se vuelve a preguntar; el enlace se añade igual) | He cambiado las cookies o para qué las uso, así que te pregunto de nuevo. Rechazar no cambia nada. (98; con el enlace, 118) | I've changed the cookies I use or what they're for, so I'm asking again. Rejecting changes nothing. (99; with the link, 113) |

## Panel de preferencias (segunda capa)

| Clave | ES | EN |
| --- | --- | --- |
| `cookies.prefs.title` | Preferencias de cookies | Cookie preferences |
| `cookies.prefs.statusNone` | Todavía no has elegido. Hasta que lo hagas no se carga ninguna cookie de Google ni de Meta. | You haven't chosen yet. Until you do, no Google or Meta cookies are loaded. |
| `cookies.prefs.statusSaved` | Tu elección actual, guardada el {date}. | Your current choice, saved on {date}. |
| `cookies.prefs.intro` | Elige qué permites. Lo que no actives no se carga. Puedes cambiarlo cuando quieras desde «Preferencias de cookies», al pie de cada página. | Choose what to allow. Anything you don't switch on isn't loaded. You can change it whenever you like from "Cookie preferences" at the foot of every page. |
| `cookies.prefs.policyLink` | Política de cookies | Cookie policy |
| `cookies.prefs.close` | Cerrar sin guardar | Close without saving |
| `cookies.prefs.rejectAll` | Rechazar todo (13) | Reject all (10) |
| `cookies.prefs.acceptAll` | Aceptar todo (12) | Accept all (10) |
| `cookies.prefs.save` | Guardar selección (17) | Save selection (14) |
| `cookies.prefs.on` | Sí | On |
| `cookies.prefs.off` | No | Off |
| `cookies.prefs.alwaysOn` | Siempre activas | Always on |
| `cookies.prefs.details` | Qué guardan y de quién | What they store and who by |
| `cookies.prefs.videosNote` | Los vídeos de YouTube no dependen de esto: solo se cargan cuando pulsas «Reproducir vídeo». | YouTube videos don't depend on this: they only load when you press "Play video". |
| `cookies.prefs.saved` (solo lector de pantalla) | Preferencias de cookies guardadas. | Cookie preferences saved. |

## Categorías

| Clave | ES | EN |
| --- | --- | --- |
| `cookies.category.necessary.title` | Necesarias | Necessary |
| `cookies.category.necessary.description` | Guardan esta elección, tu preferencia de vista en Noticias si la cambias y, si inicias sesión con Google, tu sesión. Sin ellas la web no funciona. | They store this choice, your view preference in News if you change it and, if you sign in with Google, your session. The site doesn't work without them. |
| `cookies.category.analytics.title` | Analítica | Analytics |
| `cookies.category.analytics.description` | Google Analytics: qué páginas se leen y desde dónde llegan, para saber qué escribir. No sirve para anuncios. | Google Analytics: which pages are read and where readers come from, so I know what to write. It isn't used for ads. |
| `cookies.category.ads.title` | Publicidad y remarketing | Advertising and remarketing |
| `cookies.category.ads.description` | Google Ads y el píxel de Meta: recordar que has visitado ChalkGuide para enseñarte sus anuncios en otras webs y redes. Nunca subo tu email. | Google Ads and the Meta pixel: remembering that you visited ChalkGuide so its ads can be shown to you on other sites and networks. I never upload your email. |

## Tabla de cookies

| Clave | ES | EN |
| --- | --- | --- |
| `cookies.table.cookie` | Cookie | Cookie |
| `cookies.table.provider` | Proveedor | Provider |
| `cookies.table.purpose` | Finalidad | Purpose |
| `cookies.table.duration` | Duración | Duration |
| `cookies.purpose.consent` | Guarda tu elección de cookies | Stores your cookie choice |
| `cookies.purpose.session` | Mantiene tu sesión, solo si inicias sesión | Keeps you signed in, only if you sign in |
| `cookies.purpose.newsView` | Recuerda si prefieres ver las noticias en cuadrícula o en lista; solo si cambias la vista | Remembers whether you prefer to see the news as a grid or a list; only if you change the view |
| `cookies.purpose.ga` | Distingue visitas para medir qué se lee | Tells visits apart to measure what is read |
| `cookies.purpose.gcl` | Mide si un anuncio de Google ha llevado a una visita | Measures whether a Google ad led to a visit |
| `cookies.purpose.fbp` | Meta: reconoce tu navegador para listas de remarketing | Meta: recognises your browser for remarketing lists |

Duraciones: no son copy. Salen del escaneo real (lince-max y leona-lia). Hasta entonces, `Por confirmar` / `To be confirmed`.

## Pie y página `/cookies`

| Clave | ES | EN |
| --- | --- | --- |
| `footer.cookiePreferences` | Preferencias de cookies | Cookie preferences |
| `cookies.choice.title` | Tu elección | Your choice |
| `cookies.choice.savedOn` | Guardada el {date}. | Saved on {date}. |
| `cookies.choice.none` | Todavía no has elegido. Hasta que lo hagas no se carga ninguna cookie de Google ni de Meta. | You haven't chosen yet. Until you do, no Google or Meta cookies are loaded. |
| `cookies.choice.noJs` | Sin JavaScript no se carga ninguna cookie de Google ni de Meta, así que no hay nada que elegir. Para cambiar tus preferencias, activa JavaScript. | Without JavaScript no Google or Meta cookies are loaded, so there is nothing to choose. To change your preferences, turn JavaScript on. |
| `cookies.choice.change` | Cambiar preferencias | Change preferences |
| `cookies.choice.chooseNow` | Elegir ahora | Choose now |
| `cookies.choice.on` | Activada | On |
| `cookies.choice.off` | Desactivada | Off |

---

## Avisos para quien implemente

1. Todas las cifras de longitud están dentro de los límites de §16.8; la descripción con enlace queda en 135 (es) y 137 (en), con poco margen. Si un cambio de enlace o de palabra supera 140, avisar a loro-lola.
2. `cookies.banner.description` no incluye el enlace: se compone con `policyLink` al final, separado por un espacio.
3. `{date}` lo formatea el código con la configuración regional (es-ES / en-GB).
4. «Rechazar no cambia nada» solo es cierto mientras ningún contenido dependa de Google ni de Meta (vídeos, ya aparte por D26).

## Pendientes de Xavi

- [XAVI: confirmar que te encaja «Rechazar no cambia nada» en el banner.]
- [XAVI / leona-lia: confirmar las duraciones tras el escaneo y la caducidad de `cc_cookie`.]
