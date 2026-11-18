# D26 · Fachada de vídeo (clic para cargar) · revisión previa (leona-lia, 2026-10-15)

Spec de diseño: `docs/design/site/video-facade.md` (buho-pixel). **Veredicto previo: VIABLE con condiciones.**
Sin D1–D16 cumplidas y F1–F20 en verde, la revisión final queda vetada. Cierra O13 (opción a) de `F6.4-2b-embeds-spec.md`.

## Decisiones
- ID y clic: aprobados con D1–D6 y D11–D13. Sin JS: `<a href="https://www.youtube.com/watch?v=ID" rel="noopener">`, sin `target`.
- **Autoplay aprobado** (excepción a O1/O2 solo en cliente, D7–D9). Botón "Reproducir vídeo".
- Cero contacto con Google antes del clic: obligatorio (D10).

## Condiciones
- **D1** `renderVideoFacades(html, labels)` pura en `app/utils/prose-video-facades.ts`, sobre `renderItemCards(wrapTables(sanitize(...)))`. Busca `<iframe\b([^>]*)>\s*<\/iframe>`, saca `src` con el patrón `ATTR` de `prose-item-cards.ts`, exige `YOUTUBE_EMBED_SRC` y `YOUTUBE_ID`. Invariante: ningún `<iframe` en la salida. Solo literales fijos, ID validado y etiquetas con un `escapeHtml` común (extraído a util compartido). No copia atributos; nunca `id="<ID>"` ni `<h1-6`.
- **D2** `id` únicos: `blog/[slug].vue` parte el cuerpo en dos `UiProse`; prefijo con `useId()`, validado `/^[A-Za-z0-9_-]+$/` y escapado.
- **D3** Plugin `app/plugins/video-facade.client.ts`: un solo listener `click` en `document`; `event.target` debe ser `Element`; `closest('button[data-video-play]')` → `closest('figure[data-video-facade]')` dentro de una raíz `[data-prose]`; si no cuadra, `return` sin `preventDefault`/`stopPropagation`. Solo lee el ID. Idioma del `title` desde `nuxtApp.$i18n.locale` (≠ `en` → `es`).
- **D4** Revalidar `YOUTUBE_ID` en el plugin.
- **D5** Solo API del DOM: nada de `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write`/`createContextualFragment` (el mockup usa `insertAdjacentHTML`: no copiarlo). Capa de carga emitida por `renderVideoFacades` con `hidden`; el plugin solo quita `hidden`. Iframe con `createElement` + `setAttribute` de constantes.
- **D6** Si ya hay iframe, no hacer nada (uno por fachada).
- **D7** Iframe del plugin: exactamente `src = videoPlayerSrc(id)` (= `videoEmbedSrc(id) + '?autoplay=1'`), `title`, `allow = VIDEO_PLAYER_ALLOW` (= `VIDEO_ALLOW + '; autoplay'`), `referrerpolicy = VIDEO_REFERRER_POLICY`, `sandbox = VIDEO_SANDBOX`, `allowfullscreen`. Ningún otro parámetro (`mute`, `enablejsapi`, `origin`, `start`, `playlist`) ni atributo.
- **D8** Diff vacío en el saneador, `YOUTUBE_EMBED_SRC` y `article-embed-nodes.ts`.
- **D9** Cuando haya `Permissions-Policy`/CSP: permitir `autoplay` y `fullscreen` para `https://www.youtube-nocookie.com` + `frame-src` (anotado en `.ai/devops.md`).
- **D10** Antes del clic, nada hacia `youtube*`, `ytimg`, `googlevideo`, `gstatic`, `fonts.g*` (ni `preconnect`/`dns-prefetch`/`prefetch`/`preload`/`Link`, ni miniaturas, ni `<noscript><iframe>`). Enlace sin JS como `<a>` normal (no `NuxtLink`). Verificar en DevTools con y sin JS, artículo con dos vídeos.
- **D11** Iframe anidado en `p`/`li`/`h2`/`h3`/`blockquote`: preferido cerrar y reabrir el bloque o dejar solo "Ver en YouTube"; aceptable emitir y documentar (F15).
- **D12** Nunca vídeo dentro de enlace (R3); ningún `button` dentro de `a`.
- **D13** La salida de `renderVideoFacades` no se guarda, no se re-sanea ni va a email (en email: enlace `watch?v=`).
- **D14** Sin memoria de consentimiento (ni storage ni cookies).
- **D15** Antes del primer vídeo publicado, `/cookies` nombra YouTube como tercero que solo se carga a petición del lector (loro-lola + Xavi).
- **D16** Sin `v-html` nuevo; el plugin solo toca el DOM del marco.

## Casos (`scripts/check-sanitizer.ts`; `rv(x) = renderVideoFacades(renderItemCards(s(x)), LABELS)`, `VID = dQw4w9WgXcQ`)
| # | Entrada | Esperado |
|---|---|---|
| F1 | V1 | 1 `figure[data-video-facade="VID"]`, 0 `<iframe`, 1 `button[data-video-play]`, `a[data-video-nojs]` a `watch?v=VID` con `rel="noopener"`, sin `target` |
| F2 | V2–V21 | 0 `<iframe`, 0 `data-video-facade` |
| F3 | dos vídeos | 2 fachadas, ids de aviso distintos, `aria-describedby` correcto |
| F4 | cuerpo en 2 `UiProse` | ningún `id` repetido |
| F5 | `LABELS` hostiles | escapadas; 0 `on\w+=` |
| F6 | saneado alterado (`ID"><script>`, `onload`) | sin fachada, 0 `<iframe` |
| F7 | sin iframe | idéntico a `renderItemCards` |
| F8 | — | sin `id="VID"` ni `name=` |
| F9 | — | sin `<h[1-6]`; `headingOffset` no la altera |
| F10 | corpus V y C | nunca `<iframe` |
| F11 | ID con mayúsculas (V18) | sin fachada |
| F12 | — | `href` solo con `VID`; `cookiesPath` escapado |
| F13 | `videoPlayerSrc(VID)` | falla `YOUTUBE_EMBED_SRC`; `s()` lo elimina |
| F14 | — | `VIDEO_PLAYER_ALLOW === VIDEO_ALLOW + '; autoplay'`; sandbox sin prohibidos |
| F15 | iframe en `p`/`li`/`h2`/`blockquote` | sin script ni `on*`; D11 documentado |
| F16 | iframe dentro de `a` | sin fachada ni `button` en `a` |
| F17 | — | capa de carga con `hidden` y texto escapado |

Manuales/plugin: **F18** ID manipulado o de 10/12 → sin iframe; clic fuera de `[data-prose]` → nada; doble clic → un iframe. **F19** iframe con exactamente los 6 atributos de D7; `src` termina en `/embed/VID?autoplay=1`. **F20** Red sin Google antes del clic (con y sin JS); un clic reproduce en escritorio (iOS puede pedir dos); pantalla completa y "Ver en YouTube" funcionan. Si falla, no se añaden tokens: vuelve a leona-lia.

Para la verificación final: diffs de `prose-video-facades.ts`, plugin, `Prose.vue`, `article-embeds.ts`, `main.css`; diff vacío (D8); F1–F17 y batería previa en verde; F18–F20 manuales; D9 en `.ai/devops.md`.
Nota de SúperXavi: R6 y R7 de `F6.4-2b-embeds-spec.md` ya están aplicadas (check-sanitizer 118/118).

## Verificación final (leona-lia, 2026-10-15) · APROBADO
- D1–D7, D10–D14, D16 cumplidas. Regex `TOKEN` revisada: es segura porque la entrada es salida de
  `sanitize-html` (`<`, `>`, `"` escapados en texto y atributos) y `src` exige comillas dobles; un
  iframe dentro de `<a>` se descarta (D12 y R3); el barrido `LEFTOVER_IFRAME` garantiza 0 `<iframe`.
  Fachada solo con literales, ID validado, `escapeHtml` común (`app/utils/html-escape.ts`) y prefijo
  `useId()` filtrado. Plugin: un listener, cadena `closest` dentro de `[data-prose]`, revalida
  `YOUTUBE_ID`, uno por fachada, solo API del DOM, 6 atributos constantes, `?autoplay=1` sin más.
- D8: verificado leyendo el contenido (sin diff disponible); coincide con el saneador aprobado hoy.
- D9 anotado en `.ai/devops.md`. D11 aceptado (fachada donde estaba el iframe; F15).
- F1–F17 revisados en `scripts/check-sanitizer.ts` (161/161). F18–F20 en Chromium headless (Playwright)
  y prueba manual de Xavi.
- Pendiente, no bloqueante: F18 con ID manipulado en navegador (aceptado por revisión de código;
  prueba manual recomendada); D15 antes del primer vídeo publicado (borrador en `docs/copy/cookies-youtube.md`);
  D9 al activar CSP/Permissions-Policy.
