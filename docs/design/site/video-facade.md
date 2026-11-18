# Fachada de vídeo "clic para cargar" (D26) · sitio público

Estado: **propuesta de buho-pixel, pendiente de Xavi** · 15.10.26
Mockup: [`pages/video-facade.html`](pages/video-facade.html) (reposo en contexto, hover, foco, cargando, cargado, sin JS, ámbito oscuro y 390). El mockup no contacta con Google: no usa fuentes de Google ni `i.ytimg.com`, y el reproductor está simulado.
Base: `UiProse` (`app/components/ui/Prose.vue`), tarjeta de ficha (`a[data-item-card]`, aprobada) y el iframe canónico de `docs/security/F6.4-2b-embeds-spec.md` (O1–O8, O13 opción a).

## 1 · Decisiones

| Tema | Decisión | Por qué |
| --- | --- | --- |
| Imagen | **Ninguna.** El marcador usa el fondo `photo-placeholder` del DS (degradado de pizarra con polvo de tiza), el mismo que llevan las portadas sin foto | No pedimos nada a `i.ytimg.com` y no hay que alojar miniaturas. Además el vídeo se reconoce como "hueco de medio" del sitio, no como un anuncio de YouTube |
| Título del vídeo | **Texto genérico.** Etiqueta mono `VÍDEO · YOUTUBE` y botón "Reproducir vídeo". No inventamos ni pedimos el título | El HTML solo guarda el ID. Para sacar el título haría falta oEmbed (otra llamada a Google) o un campo nuevo. Si más adelante el editor admite un **pie de vídeo** escrito por Xavi, irá como primera línea del `figcaption` (fuera de esta entrega) |
| Recordar la decisión | **Solo por vídeo, sin memoria.** Cada clic carga ese vídeo y nada más. No se guarda nada en el navegador | Es lo estándar y lo más simple. "Cargar siempre" obliga a guardar un consentimiento (localStorage), a poder retirarlo en `/cookies` y a explicarlo, y los artículos tendrán uno o dos vídeos como mucho. Si algún día hace falta, se añade una casilla "Recordar en este navegador" con su forma de revocarla |
| Aviso | **Una línea bajo el marco** (`figcaption`), siempre visible, enlazada a `/cookies` y con "Ver en YouTube" como salida | Fuera del marco se lee bien a 390 (dentro no cabe sin tapar el botón) y no compite con la acción. El botón lo referencia con `aria-describedby`, así que el lector de pantalla lo oye antes de pulsar |
| Objetivo táctil | **Todo el marco 16:9 es el botón**; la pastilla es solo la pista visual | El objetivo mide como poco 342 × 192 en 390. Funciona igual que la tarjeta de ficha, donde toda la tarjeta es el enlace |
| Autoplay tras el clic | **Pendiente de leona-lia** (§7). Recomiendo que un clic baste para reproducir | Si no se aprueba, el texto del botón pasa a "Cargar vídeo" para no prometer lo que no hace (§8) |

## 2 · Anatomía

```
figure[data-video-facade]                       ← bloque de prosa (margen superior del ritmo 1.1em)
├─ div[data-video-frame]  16:9, radio lg (12)   ← anfitrión; luego lleva el iframe
│  ├─ button[data-video-play]  (con JS)         ← photo-placeholder, ocupa todo el marco
│  │   └─ span.chrome-dark  (contenido oscuro)
│  │       ├─ etiqueta mono "VÍDEO · YOUTUBE"   arriba a la izquierda, 16 px (20 px desde md)
│  │       └─ pastilla accent-fill: ▶ "Reproducir vídeo"   centrada, alto 48
│  └─ a[data-video-nojs]  (sin JS)              ← mismo marco; pastilla ghost "Ver en YouTube ↗"
└─ figcaption  (aviso)                          ← 8 px debajo; escudo 14 + texto note meta + 2 enlaces
```

## 3 · Marcado

La genera una función pura **`renderVideoFacades(html, labels)`** que va en `app/utils/prose-video-facades.ts`. Se ejecuta **después** del saneador, en la misma cadena que `renderItemCards`: `renderVideoFacades(renderItemCards(wrapTables(sanitize(...))))`.
- Solo sustituye los `<iframe>` cuyo `src` cumpla `YOUTUBE_EMBED_SRC`. El ID sale de la regex y se vuelve a validar con `YOUTUBE_ID`.
- No arrastra ningún atributo del original. Todas las etiquetas i18n pasan por `escapeHtml`.
- Si el iframe no valida, se quita (nunca se deja un iframe sin fachada).
- `n` es el índice del vídeo en el cuerpo y sirve para que los `id` no se repitan. Nunca se usa `id="<videoId>"` (R1, DOM clobbering).

```html
<figure data-video-facade="{ID}">
  <div data-video-frame class="relative aspect-video w-full rounded-lg">
    <button type="button" data-video-play aria-describedby="cg-video-note-{n}"
      class="group photo-placeholder absolute inset-0 rounded-lg
             focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">
      <span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">
        <span class="label-mini absolute top-4 left-4 md:top-5 md:left-5">{labels.kicker}</span>
        <span class="inline-flex min-h-12 items-center gap-2.5 rounded-md bg-accent-fill px-5
                     text-body-sm font-medium text-on-accent
                     transition-[background-color,scale] duration-150 ease-standard
                     group-hover:bg-accent-hover group-active:scale-[.98]
                     motion-reduce:transition-none motion-reduce:group-active:scale-100">
          <svg …lucide play, fill="currentColor", 18px, aria-hidden="true"></svg>
          {labels.play}
        </span>
      </span>
    </button>
    <a data-video-nojs href="https://www.youtube.com/watch?v={ID}" rel="noopener"
      class="photo-placeholder absolute inset-0 rounded-lg
             focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent">
      <span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">
        <span class="label-mini absolute top-4 left-4 md:top-5 md:left-5">{labels.kicker}</span>
        <span class="inline-flex min-h-12 items-center gap-2 rounded-md border border-control px-5
                     text-body-sm font-medium text-foreground">
          {labels.watch} <svg …lucide external-link, 16px, aria-hidden="true"></svg>
        </span>
      </span>
    </a>
  </div>
  <figcaption id="cg-video-note-{n}" class="mt-2 flex gap-2 text-note text-meta">
    <svg …lucide shield, 14px, class="mt-0.5 flex-none", aria-hidden="true"></svg>
    <span>{labels.notice} <a href="{cookiesPath}">{labels.cookies}</a> ·
      <a href="https://www.youtube.com/watch?v={ID}" rel="noopener">{labels.watch}<span class="sr-only"> {labels.external}</span></a></span>
  </figcaption>
</figure>
```

Notas:
- **`chrome-dark` va en el `span` interior, no en el botón.** Así el contorno de foco se dibuja con el `accent` del ámbito de fuera: `#9A4A16` sobre papel (5.5:1). Si el ámbito pasara al botón, el contorno saldría `#E8923A` sobre papel (≈2.2:1) y no cumpliría AA. Hace falta `bg-transparent`, porque `.chrome-dark` pone `background-color` en `@layer base` y taparía el degradado (la utilidad gana).
- El foco se marca con `outline` y no con el `--ring` global, porque `photo-placeholder` ocupa `box-shadow`. Es la misma solución que en la tarjeta de ficha.
- `cookiesPath` se calcula con `localePath('cookies')` en `UiProse` (`/cookies` · `/en/cookies`) y llega a la función ya resuelto.
- Iconos: SVG de Lucide en línea (`play`, `external-link`, `shield`, `loader-circle`). No se pueden usar los componentes Vue porque el contenido va por `v-html`. Trazo 1.75; `play` va con relleno.

### Cambios en `UiProse` (`embeds`)
- Las reglas de `iframe` cambian porque ahora el iframe vive siempre dentro del marco: `[&_iframe]:absolute [&_iframe]:inset-0 [&_iframe]:size-full [&_iframe]:border-0 [&_iframe]:bg-transparent`. Salen `aspect-video`, `h-auto` y `bg-board`: el 16:9 lo pone el marco, y un fondo `board` haría un destello claro antes de que pinte el reproductor.
- Añadir `[&_a[data-video-nojs]]:no-underline`, porque la regla `[&_a]:underline` subrayaría la pastilla.
- Los dos enlaces del aviso heredan el estilo de enlace de la prosa (subrayado en `accent`, `underline-offset-4`). Se quedan así, pero con `text-foreground` para que destaquen dentro del texto `meta`.

## 4 · Sin JS (fallback)

`nuxt.config.ts` ya añade la clase `.js` a `<html>` con un script en línea. Hay que añadir a `main.css` (CSS de respaldo, con su comentario):

```css
/* CSS fallback: fachada de vídeo (D26). Sin JS no hay botón: el marco es un enlace a youtube.com. */
[data-video-play] { display: none; }
.js [data-video-play] { display: block; }
.js [data-video-nojs] { display: none; }
```

Sin JS el lector ve el mismo marco con la pastilla **ghost** "Ver en YouTube ↗", y el aviso sigue debajo. El enlace no se abre en una pestaña nueva (`target` no hace falta). Con JS, el "Ver en YouTube" del aviso también sirve de salida a quien no quiera incrustar nada.

## 5 · Comportamiento con JS

Un **delegado de clic** a nivel de documento en un plugin de cliente (`app/plugins/video-facade.client.ts`). Se registra antes de hidratar y vale para todas las instancias de `UiProse` y para la navegación entre páginas. Al pulsar `[data-video-play]` (con clic, Enter o Espacio; es un `button` nativo):

1. Lee `figure[data-video-facade]`, valida el ID con `YOUTUBE_ID` y, si no es válido, no hace nada.
2. Quita el botón y el enlace `nojs`. Al marco le añade `photo-placeholder overflow-hidden` y `aria-busy="true"`.
3. Inserta la capa de carga: `span.chrome-dark.bg-transparent.absolute.inset-0.flex.flex-col.items-center.justify-center.gap-3` con `loader-circle` de 28 px en `text-accent` y `animate-spin motion-reduce:animate-none`, más "Cargando vídeo…" en `text-note text-meta`.
4. Crea el iframe **con la API del DOM** (`createElement` + `setAttribute`, nunca `innerHTML`) y solo con las constantes de `article-embeds.ts`: `src = videoEmbedSrc(id)`, `title = VIDEO_TITLE[locale]`, `allow = VIDEO_ALLOW`, `referrerpolicy = VIDEO_REFERRER_POLICY`, `sandbox = VIDEO_SANDBOX`, `allowfullscreen`. El iframe va encima de la capa de carga y es transparente, así que el lector ve la rueda hasta que pinta el reproductor. Así no hace falta escuchar `load` para ocultarla.
5. En `load`, quita `aria-busy` del marco. El foco pasa al iframe en cuanto se inserta (`iframe.focus()`), y el siguiente Tab entra en el reproductor.
6. El `figcaption` no cambia, porque el aviso sigue siendo cierto. Los demás vídeos de la página no se cargan.

**Error.** Desde fuera no se detecta bien un fallo del reproductor (es de otro origen): si falla, YouTube o el navegador muestran su propio error dentro del marco. La salida que siempre queda es "Ver en YouTube", en el aviso. No hay estado de error propio.

**Antes de hidratar.** Al ser un plugin de cliente, la ventana sin respuesta es mínima. No hace falta `disabled`.

## 6 · Estados

| Estado | Visual | Motion |
| --- | --- | --- |
| Reposo | Marco `photo-placeholder` con radio 12, etiqueta `label-mini` (`meta` oscuro `#A19D94`) y pastilla `accent-fill` con `on-accent` | — |
| Hover (puntero) | Pastilla a `accent-hover`. Cursor `pointer` (regla global) | `background-color` 150 ms `ease-standard` |
| Foco (teclado) | Contorno de 2 px `accent` separado 2 px del marco. En claro es `#9A4A16`; en ámbito oscuro, `#E8923A` | Ninguno |
| Activo | Pastilla `scale(.98)` | 150 ms; sin escala con `prefers-reduced-motion` |
| Cargando | Rueda de 28 px en `accent` y "Cargando vídeo…" (texto visible, no solo el icono). `aria-busy` en el marco | Gira 0.8 s; con reduced-motion no gira y el texto se queda |
| Cargado | Iframe canónico a sangre en el marco | — |
| Sin JS | Pastilla ghost con borde `control` de 1 px y "Ver en YouTube ↗" | — |
| Deshabilitado / vacío | No aplica: si el ID no valida, no hay fachada | — |

## 7 · Para leona-lia (revisar antes de implementar)

1. **Ninguna petición a Google antes del clic.** En la pestaña Red de un artículo con vídeo no debe aparecer `youtube-nocookie.com`, `youtube.com`, `ytimg.com`, `googlevideo.com` ni `gstatic.com`. Tampoco con `rel="preconnect"`: no lo pongáis.
2. **El iframe ya no sale del `v-html`: lo crea el plugin.** Se construye solo con las constantes canónicas (O1–O4). El saneador no cambia y la salida guardada sigue siendo el iframe canónico, así que no cambian ni la idempotencia ni el re-parseo.
3. **Autoplay tras el clic (decisión).** (a) Iframe canónico tal cual: hacen falta dos clics, el nuestro y el del reproductor. (b) **Recomendada:** solo en el iframe que crea el plugin, `src = videoEmbedSrc(id) + '?autoplay=1'` y `allow = VIDEO_ALLOW + '; autoplay'`. El gesto del lector es explícito y lite-youtube hace lo mismo. Es una excepción a O1 y O2 que solo vive en cliente y deja el saneador intacto. En iOS puede seguir pidiendo un segundo toque, y eso es aceptable.
4. Los `href` a `https://www.youtube.com/watch?v={ID}` se construyen con el ID validado. Son navegación normal (el lector elige ir) y llevan `rel="noopener"`.
5. La CSP no cambia (`frame-src https://www.youtube-nocookie.com`, O12).

## 8 · Textos provisionales (para loro-lola)

Claves sugeridas en `blog.video.*` (es / en):

| Clave | ES | EN |
| --- | --- | --- |
| `kicker` | Vídeo · YouTube | Video · YouTube |
| `play` | Reproducir vídeo (si se aprueba §7.3b) · Cargar vídeo (si no) | Play video · Load video |
| `watch` | Ver en YouTube | Watch on YouTube |
| `external` | (abre youtube.com) | (opens youtube.com) |
| `notice` | Se carga desde YouTube (Google) solo si le das a reproducir. YouTube recibirá tu IP y puede guardar datos en tu navegador. | It loads from YouTube (Google) only if you press play. YouTube will receive your IP address and may store data in your browser. |
| `cookies` | Cookies | Cookies |
| `loading` | Cargando vídeo… | Loading video… |

Límites: `notice` en **2 líneas como máximo a 390** (≈ 150 caracteres con los enlaces) y `play` en ≤ 18 caracteres para que la pastilla no parta línea. La página `/cookies` (editorial) debe nombrar YouTube como tercero que **solo** se carga a petición del lector. Eso lo coordina loro-lola con Xavi, no es diseño.

## 9 · Responsive y modo oscuro

- **390:** el marco ocupa la columna (342 × 192). Pastilla 48 px de alto y etiqueta a 16 px de las esquinas. El aviso ocupa 2 líneas. Sin scroll horizontal.
- **768 / 1440:** el marco ocupa `max-w-read` (680 × 383) y la etiqueta pasa a 20 px de las esquinas. Lo demás no cambia.
- **Modo oscuro:** el sitio es solo claro en v1 (§9.4, D20). Aun así, la fachada funciona tal cual dentro de `.chrome-dark`. El marco ya es oscuro en los dos ámbitos (`--photo-*` no cambia), el contenido tiene su propio `.chrome-dark` y el foco y el aviso usan tokens semánticos que cambian con el ámbito. En oscuro, el aviso queda en `meta #A19D94` sobre `#0f0f0f` (7.4:1).

## 10 · Contraste (WCAG 2.x)

| Par | Ratio |
| --- | --- |
| `on-accent` sobre `accent-fill` (pastilla) | 7.9 |
| `on-accent` sobre `accent-hover` | 5.3 |
| Pastilla `accent-fill` frente al marco (`#1F1B18`), UI | ≈ 6.9 |
| Etiqueta `#A19D94` sobre la zona más clara del marco (`#3A2F27`) | ≈ 4.9 |
| Pastilla ghost: texto `#F0EDE8` sobre el marco / borde `#75716A`, UI | ≥ 11 / ≈ 3.4 |
| Aviso `meta` sobre papel | 6.2 |
| Foco `#9A4A16` sobre papel | 5.5 |

## 11 · Aceptación (lo que revisaré)

- Red vacía de dominios de Google hasta el clic (lo comprobaré en DevTools).
- Con teclado: Tab llega al marco y se ve el contorno; con Enter o Espacio carga el vídeo y el foco pasa al iframe. El lector de pantalla anuncia "Reproducir vídeo, botón" seguido del aviso.
- Sin JS (desactivado en DevTools), el enlace a youtube.com funciona.
- Con `prefers-reduced-motion`, ni escala ni giro.
- Sin CLS: la fachada y el iframe ocupan el mismo marco 16:9.
- Se ve bien a 1440, 768 y 390, con dos vídeos en el mismo artículo (cada uno carga por separado).
