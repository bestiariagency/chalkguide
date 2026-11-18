import { YOUTUBE_EMBED_SRC, YOUTUBE_ID } from './article-embeds'
import { escapeHtml, htmlAttr } from './html-escape'

/**
 * Click-to-load video facade (D26). Runs AFTER the sanitizer, on `renderItemCards(...)`. Every canonical
 * `<iframe>` (src = `YOUTUBE_EMBED_SRC`) is replaced by a `figure[data-video-facade]` that asks nothing
 * from Google until the reader clicks; the client plugin (`video-facade.client.ts`) then builds the real
 * iframe with the DOM API. The markup is rebuilt only from fixed literals, the validated video ID and
 * escaped labels: no attribute of the original is carried over. Invariant: the output has no `<iframe`.
 * The output is render-only: never stored, re-sanitized or sent by email (there: `watch?v=` link).
 *
 * D11 (iframe nested in `p`/`li`/`h2`/`blockquote`): the facade is emitted where the iframe was. In a
 * `p` the HTML parser closes the paragraph before the `figure` (an empty `<p>` may remain); in `li`,
 * `blockquote` and headings the `figure` stays inside. It is not a security issue (no script, no
 * handlers; the plugin only reacts inside `[data-prose]`) and the editor's video node is a block
 * that does not produce those shapes. Accepted and covered by F15. An iframe inside an `<a>` gets no
 * facade (D12: no button inside a link): it is dropped.
 */
export interface VideoFacadeLabels {
  kicker: string
  play: string
  watch: string
  external: string
  notice: string
  cookies: string
  loading: string
  /** Localized path of `/cookies` (already resolved with `localePath`). */
  cookiesPath: string
  /** Prefix of the notice `id`s (from `useId()`): the body is split across several `UiProse`. */
  idPrefix: string
}

const TOKEN = /<a\b[^>]*>|<\/a\s*>|<iframe\b([^>]*)>\s*<\/iframe>/gi
const LEFTOVER_IFRAME = /<\/?iframe\b[^>]*>/gi

const FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent'
const SVG = (size: number, body: string, extra = '', fill = 'none') =>
  `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 24 24" fill="${fill}" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"${extra} aria-hidden="true">${body}</svg>`
const ICON_PLAY = SVG(18, '<polygon points="6 3 20 12 6 21 6 3"/>', '', 'currentColor')
const ICON_EXTERNAL = SVG(16, '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>')
const ICON_SHIELD = SVG(14, '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/>', ' class="mt-0.5 flex-none"')
const ICON_SPINNER = SVG(28, '<path d="M21 12a9 9 0 1 1-6.219-8.56"/>', ' class="animate-spin text-accent motion-reduce:animate-none"')

/** Only `[A-Za-z0-9_-]` survives (ids stay valid and unique per `UiProse`). */
const safePrefix = (prefix: string) => prefix.replace(/[^A-Za-z0-9_-]/g, '') || 'v'

function facade(id: string, n: number, l: Record<keyof VideoFacadeLabels, string>): string {
  const note = `cg-video-note-${l.idPrefix}-${n}`
  const watchUrl = `https://www.youtube.com/watch?v=${id}`
  const kicker = `<span class="label-mini absolute top-4 left-4 md:top-5 md:left-5">${l.kicker}</span>`
  return (
    `<figure data-video-facade="${id}">` +
    '<div data-video-frame class="relative aspect-video w-full rounded-lg">' +
    `<button type="button" data-video-play aria-describedby="${note}" class="group photo-placeholder absolute inset-0 rounded-lg ${FOCUS}">` +
    `<span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">${kicker}` +
    '<span class="inline-flex min-h-12 items-center gap-2.5 rounded-md bg-accent-fill px-5 text-body-sm font-medium text-on-accent transition-[background-color,scale] duration-150 ease-standard group-hover:bg-accent-hover group-active:scale-[.98] motion-reduce:transition-none motion-reduce:group-active:scale-100">' +
    `${ICON_PLAY}${l.play}</span></span></button>` +
    `<a data-video-nojs href="${watchUrl}" rel="noopener" class="photo-placeholder absolute inset-0 rounded-lg ${FOCUS}">` +
    `<span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">${kicker}` +
    `<span class="inline-flex min-h-12 items-center gap-2 rounded-md border border-control px-5 text-body-sm font-medium text-foreground">${l.watch} ${ICON_EXTERNAL}</span></span></a>` +
    // Loading layer: emitted hidden, the plugin only removes `hidden` (D5). No <img>, no remote asset.
    '<span data-video-loading hidden class="chrome-dark absolute inset-0 flex flex-col items-center justify-center gap-3 bg-transparent">' +
    `${ICON_SPINNER}<span class="text-note text-meta">${l.loading}</span></span>` +
    '</div>' +
    `<figcaption id="${note}" class="mt-2 flex gap-2 text-note text-meta">${ICON_SHIELD}` +
    `<span>${l.notice} <a href="${l.cookiesPath}" class="text-foreground">${l.cookies}</a> · ` +
    `<a href="${watchUrl}" rel="noopener" class="text-foreground">${l.watch}<span class="sr-only"> ${l.external}</span></a></span>` +
    '</figcaption></figure>'
  )
}

export function renderVideoFacades(html: string, labels: VideoFacadeLabels): string {
  if (!/<iframe/i.test(html)) return html
  const l = Object.fromEntries(
    Object.entries(labels).map(([key, value]) => [key, key === 'idPrefix' ? safePrefix(value) : escapeHtml(value)]),
  ) as Record<keyof VideoFacadeLabels, string>
  let inAnchor = false
  let n = 0
  const out = html.replace(TOKEN, (match: string, attrs: string | undefined) => {
    if (attrs === undefined) {
      inAnchor = !match.startsWith('</')
      return match
    }
    if (inAnchor) return ''
    const src = htmlAttr('src').exec(` ${attrs}`)?.[1]
    const id = YOUTUBE_EMBED_SRC.exec(src ?? '')?.[1]
    if (!id || !YOUTUBE_ID.test(id)) return ''
    return facade(id, n++, l)
  })
  return out.replace(LEFTOVER_IFRAME, '')
}
