# /cookies · párrafo de YouTube (APROBADO por Xavi el 2026-10-15)

Estado: aprobado por Xavi (2026-10-15). Aún no está en la BD: se incorpora a la política de cookies en F7.4, antes del primer vídeo publicado. Destino: `guide.pages` (key `cookies`), campos `body_*_es` / `body_*_en`.
Contexto: en el repo la página `/cookies` es solo un placeholder ("Texto provisional. La política de
cookies se redactará en F7.4."), sin tono ni estructura previos. Se propone como sección propia con
`h2` dentro de la futura política. Cubre D15 (`docs/security/D26-video-facade-review.md`).

Puntos confirmados (SúperXavi, 2026-10-15):
- Dominio del reproductor: `www.youtube-nocookie.com` (`app/utils/article-embeds.ts`, `videoEmbedSrc`).
- Sin memoria de consentimiento propia (D14): el plugin no usa cookies ni almacenamiento. Prueba F20 de
  coneja-lucky: 0 peticiones a Google antes del clic, con y sin JS (pendiente la verificación final de leona-lia).
- Autoplay tras un clic aprobado por leona-lia: el botón es "Reproducir vídeo".

---

## ES

### Vídeos de YouTube

Algunos artículos incluyen vídeos de YouTube, un servicio de Google LLC. ChalkGuide no carga nada de
YouTube ni de Google mientras lees: ni el reproductor, ni la miniatura, ni scripts. El vídeo aparece
como un recuadro con el botón "Reproducir vídeo", y solo cuando lo pulsas se carga el reproductor
desde `youtube-nocookie.com`, un dominio de YouTube.

Al pulsarlo, YouTube recibe tu dirección IP y los datos técnicos habituales de tu navegador, y puede
guardar identificadores en el almacenamiento local de tu navegador o instalar cookies propias para
hacer funcionar el reproductor, medir su uso y, según tu cuenta y tus ajustes de Google, personalizar
lo que ves. Esos datos los trata Google como responsable, no ChalkGuide, y nosotros no los vemos ni
los guardamos. Si no pulsas el botón, nada de esto ocurre.

Si prefieres no cargar el reproductor, cada recuadro incluye un enlace "Ver en YouTube" que abre el
vídeo en youtube.com. Puedes borrar lo que YouTube haya guardado desde los ajustes de tu navegador.
Más información en la [política de privacidad de Google](https://policies.google.com/privacy).

## EN

### YouTube videos

Some articles include YouTube videos. YouTube is a service of Google LLC. ChalkGuide loads nothing
from YouTube or Google while you read: no player, no thumbnail, no scripts. The video appears as a
placeholder with a "Play video" button, and the player is only loaded from `youtube-nocookie.com`, a
YouTube domain, once you press it.

When you press it, YouTube receives your IP address and the usual technical data from your browser,
and may store identifiers in your browser's local storage or set its own cookies in order to run the
player, measure its use and, depending on your Google account and settings, personalise what you see.
Google, not ChalkGuide, is the controller of that data, and we neither see nor keep it. If you don't
press the button, none of this happens.

If you'd rather not load the player, each placeholder has a "Watch on YouTube" link that opens the
video on youtube.com. You can delete anything YouTube has stored from your browser settings. More
information in [Google's privacy policy](https://policies.google.com/privacy).
