/**
 * Sanitizer checks of the video facades (D26). Companion of `check-sanitizer.ts` (kept apart to stay under
 * ~300 lines). Runs the real modules. Usage: `npx tsx scripts/check-sanitizer-facades.ts`. Exit code 1 when anything fails.
 */
import { renderItemCards } from '../app/utils/prose-item-cards'
import { renderVideoFacades, type VideoFacadeLabels } from '../app/utils/prose-video-facades'
import { VIDEO_ALLOW, VIDEO_PLAYER_ALLOW, YOUTUBE_EMBED_SRC, videoPlayerSrc } from '../app/utils/article-embeds'
import { LABELS, VALID, VID, check, count, iframe, noIframe, report, s, safe, v1, v18 } from './lib/sanitizer-check'

// --- F: video facades (D26) ------------------------------------------------------------------------
const VL: VideoFacadeLabels = {
  kicker: 'Vídeo · YouTube', play: 'Reproducir vídeo', watch: 'Ver en YouTube', external: '(abre youtube.com)',
  notice: 'Se carga desde YouTube', cookies: 'Cookies', loading: 'Cargando vídeo…', cookiesPath: '/cookies', idPrefix: 'v-0',
}
const rv = (html: string, labels: VideoFacadeLabels = VL) => renderVideoFacades(renderItemCards(s(html), LABELS), labels)
const f1 = rv(v1)
check('F1', count(f1, /<figure data-video-facade="dQw4w9WgXcQ">/g) === 1 && noIframe(f1) && count(f1, /<button type="button" data-video-play /g) === 1
  && /<a data-video-nojs href="https:\/\/www\.youtube\.com\/watch\?v=dQw4w9WgXcQ" rel="noopener"/.test(f1) && !/target=/.test(f1), f1)
const hostile: string[] = [
  iframe(`${VALID}?autoplay=1&mute=1`), iframe(`https://www.youtube.com/embed/${VID}`), iframe(`http://www.youtube-nocookie.com/embed/${VID}`),
  iframe(`https://www.youtube-nocookie.com.evil.com/embed/${VID}`), iframe('javascript:alert(1)'), iframe('https://www.youtube-nocookie.com/embed/dQw4w9WgXc'),
  iframe('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQQ'), '<iframe srcdoc="<script>1</script>"></iframe>', '<iframe></iframe>',
  `<IFRAME SRC="https://WWW.YOUTUBE-NOCOOKIE.COM/embed/${VID}"></IFRAME>`,
]
// The sanitizer unwraps these to the canonical iframe: a facade is right, but never an iframe.
const unwrapped = [`<svg><iframe src="${VALID}"></iframe></svg>`, `<noscript><iframe src="${VALID}"></iframe></noscript>`, `<iframe src="${VALID}">`]
for (const [i, h] of unwrapped.entries()) check(`F10 unwrapped ${i}`, noIframe(rv(h)) && safe(rv(h)), rv(h))
for (const [i, h] of hostile.entries()) {
  const out = rv(h)
  check(`F2 ${i}`, noIframe(out) && !/data-video-facade/.test(out) && safe(out), out)
}
const two = rv(v1 + v1)
const noteIds = [...two.matchAll(/<figcaption id="([^"]+)"/g)].map((m) => m[1]!)
const describedBy = [...two.matchAll(/aria-describedby="([^"]+)"/g)].map((m) => m[1]!)
check('F3', count(two, /<figure data-video-facade/g) === 2 && noteIds.length === 2 && noteIds[0] !== noteIds[1] && JSON.stringify(noteIds) === JSON.stringify(describedBy), two)
const ids = (h: string) => [...h.matchAll(/\sid="([^"]*)"/g)].map((m) => m[1]!)
const split = [...ids(rv(v1)), ...ids(rv(v1, { ...VL, idPrefix: 'v-1' }))]
check('F4', split.length === 2 && new Set(split).size === 2, split.join())
const HOSTILE = '"><script>alert(1)</script><img src=x onerror=alert(1)>\'&'
const f5 = rv(v1, { ...VL, kicker: HOSTILE, play: HOSTILE, watch: HOSTILE, external: HOSTILE, notice: HOSTILE, cookies: HOSTILE, loading: HOSTILE, cookiesPath: HOSTILE, idPrefix: HOSTILE })
check('F5', !/<script|<img|<\/script/i.test(f5) && !f5.includes(HOSTILE) && f5.includes('&#60;script&#62;') && count(f5, /<figure/g) === 1, f5)
for (const [i, evil] of [`ID"><script>alert(1)</script>`, 'onload="x"'].entries()) {
  const out = renderVideoFacades(`<iframe src="https://www.youtube-nocookie.com/embed/${evil}" ${i ? 'onload="x"' : ''}></iframe>`, VL)
  check(`F6 ${i}`, noIframe(out) && !/data-video-facade/i.test(out), out)
}
const noVideo = '<p>hola</p><a href="/rocodromos/x" data-item-card="gym:x">Sharma</a>'
check('F7', rv(noVideo) === renderItemCards(s(noVideo), LABELS))
check('F8', !/\sid="dQw4w9WgXcQ"|\sname=/.test(f1), f1)
check('F9', !/<h[1-6]/i.test(f1) && f1.replace(/<(\/?)h([1-6])(?=[\s>])/gi, '') === f1)
for (const h of hostile) check(`F10 ${h.slice(0, 24)}`, noIframe(rv(h)))
check('F11', noIframe(v18) && !/data-video-facade/.test(rv(v18)))
check('F12', [...f1.matchAll(/href="([^"]*)"/g)].every((m) => m[1] === `https://www.youtube.com/watch?v=${VID}` || m[1] === '/cookies'), f1)
check('F13', !YOUTUBE_EMBED_SRC.test(videoPlayerSrc(VID)) && noIframe(s(iframe(videoPlayerSrc(VID)))), videoPlayerSrc(VID))
check('F14', VIDEO_PLAYER_ALLOW === `${VIDEO_ALLOW}; autoplay` && videoPlayerSrc(VID) === `${VALID}?autoplay=1` && !/autoplay/.test(VIDEO_ALLOW))
// F15 / D11: the facade is emitted where the iframe was; no script or handlers whatever the container.
for (const c of ['p', 'li', 'h2', 'blockquote']) {
  const out = rv(`<${c}>antes<iframe src="${VALID}"></iframe>despues</${c}>`)
  check(`F15 ${c}`, noIframe(out) && safe(out) && count(out, /<figure data-video-facade/g) === 1, out)
}
// F16: iframe inside a link gets no facade and no button inside `a`.
const f16 = renderVideoFacades(`<a href="/x">t<iframe src="${VALID}"></iframe></a>`, VL)
check('F16', noIframe(f16) && !/<button/.test(f16) && !/data-video-facade/.test(f16), f16)
const f17 = rv(v1, { ...VL, loading: '<b>"x"</b>' })
check('F17', /<span data-video-loading hidden /.test(f17) && f17.includes('&#60;b&#62;&#34;x&#34;&#60;/b&#62;') && !f17.includes('<b>'), f17)
check('F17 no remote', !/ytimg|googlevideo|gstatic|fonts\.g|<img|<link|<noscript|preconnect/i.test(f1.replace(/https:\/\/www\.youtube\.com\/watch\?v=/g, '')), f1)

report()
