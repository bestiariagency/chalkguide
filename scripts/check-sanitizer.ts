/**
 * Sanitizer checks (F6.4 · 2b): regression battery of F6.4-editor-review.md + V1–V22 / C1–C12 of
 * docs/security/F6.4-2b-embeds-spec.md. Runs the real module. Usage: `npx tsx scripts/check-sanitizer.ts`.
 * Exit code 1 when anything fails.
 */
import { renderItemCards } from '../app/utils/prose-item-cards'
import { LABELS, SUPA, VALID, VID, card, check, iframe, noIframe, report, s, safe, v1, v18 } from './lib/sanitizer-check'
import { VIDEO_ALLOW, VIDEO_SANDBOX, VIDEO_TITLE, YOUTUBE_EMBED_SRC, parseItemCard } from '../app/utils/article-embeds'

// --- tiny attribute parser (tags of the sanitizer output are canonical: double-quoted) ------------
interface Tag { name: string; attrs: Record<string, string> }
function tags(html: string, name: string): Tag[] {
  const out: Tag[] = []
  for (const m of html.matchAll(new RegExp(`<${name}\\b([^>]*)>`, 'g'))) {
    const attrs: Record<string, string> = {}
    for (const a of m[1]!.matchAll(/([a-z-]+)(?:="([^"]*)")?/g)) attrs[a[1]!] = a[2] ?? ''
    out.push({ name, attrs })
  }
  return out
}
const OK_ATTRS = (title = VIDEO_TITLE.es) => ({
  src: VALID, title, allow: VIDEO_ALLOW, loading: 'lazy', allowfullscreen: '',
  referrerpolicy: 'strict-origin-when-cross-origin', sandbox: VIDEO_SANDBOX,
})
const sameAttrs = (a: Record<string, string>, b: Record<string, string>) =>
  JSON.stringify(Object.entries(a).sort()) === JSON.stringify(Object.entries(b).sort())

function isOkIframe(html: string, title = VIDEO_TITLE.es) {
  const t = tags(html, 'iframe')
  return t.length === 1 && sameAttrs(t[0]!.attrs, OK_ATTRS(title)) && /<iframe[^>]*><\/iframe>/.test(html) && html.replace(/<iframe[^>]*><\/iframe>/, '').trim() === ''
}

// Sandbox must not contain forbidden tokens (O3).
check('O3 sandbox tokens', !/top-navigation|forms|modals|downloads|storage-access|pointer-lock/.test(VIDEO_SANDBOX))

// --- V -----------------------------------------------------------------------------------------
check('V1', isOkIframe(s(v1)), s(v1))
check('V2', noIframe(s(iframe(`${VALID}?autoplay=1&mute=1`))))
check('V3', noIframe(s(`<iframe src="${VALID}&#63;autoplay=1"></iframe>`)))
for (const [n, u] of [['V4a', `${VALID}#t=10`], ['V4b', `${VALID}/`]] as const) check(n, noIframe(s(iframe(u))))
for (const [n, u] of [
  ['V5a', `https://www.youtube.com/embed/${VID}`],
  ['V5b', `http://www.youtube-nocookie.com/embed/${VID}`],
  ['V5c', `//www.youtube-nocookie.com/embed/${VID}`],
  ['V6a', `https://www.youtube-nocookie.com.evil.com/embed/${VID}`],
  ['V6b', `https://evil.com/?https://www.youtube-nocookie.com/embed/${VID}`],
  ['V6c', `https://www.youtube-nocookie.com@evil.com/embed/${VID}`],
  ['V7a', 'javascript:alert(1)'],
  ['V7b', 'data:text/html,<script>alert(1)</script>'],
  ['V7c', 'jav&#x09;ascript:alert(1)'],
  ['V7d', `/embed/${VID}`],
  ['V21a', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXc'],
  ['V21b', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQQ'],
  ['V21c', 'https://www.youtube-nocookie.com/embed/dQw4w9W.cQ'],
  ['V21d', 'https://www.youtube-nocookie.com/embed/dQw4w9W%2ecQ'],
  ['V21e', 'https://www.youtube-nocookie.com/embed/dQw4w9W%2FcQ'],
  ['V21f', 'https://www.youtube-nocookie.com/embed/..'],
]) {
  const out = s(iframe(u))
  check(n, noIframe(out) && safe(out), out)
}
check('V8a', noIframe(s('<iframe srcdoc="<script>alert(1)</script>"></iframe>')) && safe(s('<iframe srcdoc="<script>alert(1)</script>"></iframe>')))
check('V8b', noIframe(s('<iframe></iframe>')))
const v9 = s(iframe(VALID, 'srcdoc="<script>1</script>" onload="alert(1)" style="x:y" name="n" id="i" class="c" width="1" height="1" csp="x" data-x="1"'))
check('V9', isOkIframe(v9), v9)
check('V10', isOkIframe(s(iframe(VALID, 'allow="camera; microphone; geolocation; autoplay"'))))
check('V11a', isOkIframe(s(iframe(VALID, 'sandbox="allow-top-navigation allow-forms"'))))
check('V11b', isOkIframe(s(iframe(VALID))))
for (const p of ['unsafe-url', 'no-referrer']) check(`V12 ${p}`, isOkIframe(s(iframe(VALID, `referrerpolicy="${p}"`))))
check('V13', isOkIframe(s(iframe(VALID, 'loading="eager"'))))
check('V14a', isOkIframe(s(iframe(VALID, 'title="<img src=x onerror=alert(1)>"'))))
check('V14b', isOkIframe(s(iframe(VALID, 'title="libre"'))))
check('V14c', isOkIframe(s(iframe(VALID, 'title="Embedded video"')), VIDEO_TITLE.en))
const v15 = s(`<iframe src="${VALID}"><img src=x onerror=alert(1)><a href="javascript:1">x</a></iframe>`)
check('V15', isOkIframe(v15) && safe(v15), v15)
const v16 = s(`<iframe src="${VALID}">&lt;/iframe&gt;&lt;script&gt;alert(1)&lt;/script&gt;</iframe>`)
check('V16', isOkIframe(v16) && safe(v16), v16)
const v17 = s(`<iframe src="${VALID}"><p>texto</p>`)
check('V17', safe(v17) && s(v17) === v17 && tags(v17, 'iframe').length <= 1, v17)
// V18: host/scheme in upper case are not normalised (see `v18` in the harness).
check('V18', noIframe(v18) && !/WWW\.YOUTUBE/.test(v18), v18)
for (const [n, h] of [
  ['V19a', `<svg><iframe src="${VALID}"></iframe></svg>`],
  ['V19b', `<math><iframe src="${VALID}"></iframe></math>`],
  ['V19c', `<noscript><iframe src="${VALID}"></iframe></noscript>`],
  ['V19d', `<svg><style><iframe src="${VALID}"></style></svg>`],
]) {
  const out = s(h)
  check(n, safe(out) && !/<(svg|math|noscript|style)/i.test(out) && tags(out, 'iframe').every((t) => sameAttrs(t.attrs, OK_ATTRS())), out)
}
for (const t of ['embed', 'object', 'frame', 'frameset', 'video', 'audio', 'portal']) {
  const out = s(`<${t} src="${VALID}"></${t}>`)
  check(`V20 ${t}`, !new RegExp(`<${t}\\b`, 'i').test(out) && !out.includes('youtube'), out)
}
// V22: idempotent, and the editor's parseHTML (`iframe[src]` + YOUTUBE_EMBED_SRC) accepts the output.
const v22 = s(v1)
check('V22 idempotent', s(v22) === v22)
check('V22 reparse', tags(v22, 'iframe').length === 1 && YOUTUBE_EMBED_SRC.test(tags(v22, 'iframe')[0]!.attrs.src!))

// --- C -----------------------------------------------------------------------------------------
const C1 = card('/rocodromos/sharma-bcn', 'gym:sharma-bcn')
check('C1', s(C1) === C1, s(C1))
const C2 = card('/en/climbing-shoes/x', 'shoe:x')
check('C2', s(C2) === C2, s(C2))
for (const [href, attr] of [
  ['/rocodromos/x', 'shoe:x'], ['/rocodromos/y', 'gym:x'], ['/pies-de-gato/x', 'gym:x'],
  ['/resolar-pies-de-gato/x', 'gym:x'], ['/en/climbing-gyms/x', 'resoler:x'],
]) check(`C3 ${href} ${attr}`, s(card(href!, attr!)) === `<a href="${href}">Sharma</a>`, s(card(href!, attr!)))
for (const [n, href] of [
  ['C4a', 'https://evil.com/rocodromos/x'], ['C4b', '//evil.com/rocodromos/x'], ['C4c', '/rocodromos/x?utm=1'],
  ['C4d', '/rocodromos/x#a'], ['C4e', '/rocodromos/x/'], ['C4f', '/es/rocodromos/x'],
] as const) {
  const out = s(card(href, 'gym:x'))
  const t = tags(out, 'a')[0]
  check(n, !!t && !('data-item-card' in t.attrs), out)
}
check('C4 external rel', tags(s(card('https://evil.com/rocodromos/x', 'gym:x')), 'a')[0]!.attrs.rel === 'noopener')
const c5 = s(card('javascript:alert(1)', 'gym:x'))
check('C5', c5 === '<a>Sharma</a>', c5)
for (const attr of ['gym:X', 'gym:x ', 'gym:x\n', 'admin:x', 'gym:../x', 'gym:x"><img src=x onerror=alert(1)>', `gym:${'a'.repeat(121)}`]) {
  const out = s(card('/rocodromos/x', attr))
  check(`C6 ${JSON.stringify(attr).slice(0, 30)}`, !/data-item-card/.test(out) && safe(out), out)
}
check('R4 slug 120 ok', parseItemCard(`gym:${'a'.repeat(120)}`, `/rocodromos/${'a'.repeat(120)}`) !== null)
check('R4 slug 121 no', parseItemCard(`gym:${'a'.repeat(121)}`, `/rocodromos/${'a'.repeat(121)}`) === null)
const c7 = s(card('/rocodromos/x', 'gym:x', 'target="_blank" rel="opener" class="c" style="x:y" id="i" title="t" onclick="alert(1)"'))
check('C7', c7 === card('/rocodromos/x', 'gym:x'), c7)
check('C8', s('<a href="/rocodromos/x" DATA-ITEM-CARD="gym:x">Sharma</a>') === card('/rocodromos/x', 'gym:x'))
check('C9a', s('<p data-item-card="gym:x">t</p>') === '<p>t</p>')
check('C9b', !/data-item-card/.test(s(`<img src="${SUPA}/storage/v1/object/public/media/a.png" data-item-card="gym:x">`)))
const c10 = s(card('/rocodromos/x', 'gym:x', '', '<img src=x onerror=alert(1)><script>alert(1)</script>Sharma'))
check('C10', c10 === card('/rocodromos/x', 'gym:x'), c10)
const c11 = s(`<p>antes</p><a href="/rocodromos/x" data-item-card="gym:x"><iframe src="${VALID}"></iframe></a><p>despues</p>`)
check('C11', c11 === '<p>antes</p><p>despues</p>', c11)
check('C12 idempotent', s(s(C1)) === s(C1) && s(s(C2)) === s(C2))
// C12 reparse: the editor's parseHTML calls parseItemCard(data-item-card, href): must accept the output.
const out1 = tags(s(C1), 'a')[0]!.attrs
check('C12 reparse', parseItemCard(out1['data-item-card'], out1.href)?.slug === 'sharma-bcn')

// --- R6: nested <a> around a video (idempotent, no quadratic backtracking) -------------------------
const r6 = s(`<a href="/x"><a href="/y"><iframe src="${VALID}"></iframe></a></a>`)
check('R6 nested a idempotent', s(r6) === r6 && noIframe(r6) && safe(r6), r6)
const r6b = s(`<a href="/x">${'<a href="/y">'.repeat(2000)}t`)
check('R6 nested a many idempotent', s(r6b) === r6b)

// --- R5: renderItemCards over sanitized output ----------------------------------------------------
const rc = (html: string) => renderItemCards(s(html), LABELS)
const FIXED = /<\/?(?:a|span)\b[^<>]*>/g
const noStray = (out: string) => !/[<>]/.test(out.replace(FIXED, ''))
const rc1 = rc(card('/rocodromos/x', 'gym:x', '', 'Sharma'))
check('R5 card es', rc1.startsWith('<a data-item-card="gym:x" href="/rocodromos/x">') && rc1.includes('Rocódromo') && rc1.includes('Sharma') && rc1.includes('Ver ficha') && rc1.endsWith('</a>'), rc1)
const rc2 = rc(card('/en/climbing-shoes/x', 'shoe:x'))
check('R5 card en', rc2.includes('href="/en/climbing-shoes/x"') && rc2.includes('data-item-card="shoe:x"') && rc2.includes('Pie de gato'), rc2)
for (const [n, name] of [
  ['script', '&lt;script&gt;alert(1)&lt;/script&gt;'], ['dq', 'a"b'], ['sq', "a'b"], ['amp', 'a &amp;lt;b&amp;gt;'], ['mix', '&lt;img src=x onerror=alert(1)&gt;"\'&amp;'],
] as const) {
  const out = rc(card('/rocodromos/x', 'gym:x', '', name))
  check(`R5 name ${n}`, noStray(out) && !/<script|javascript:/i.test(out) && !/<script|<img/i.test(out), out)
}
const rcS = rc(card('/rocodromos/x', 'gym:x', '', '&lt;script&gt;'))
check('R5 script text escaped', rcS.includes('&#38;lt;script&#38;gt;') === false && rcS.includes('&#60;script&#62;') && !rcS.includes('<script'), rcS)
const plain = '<a href="/rocodromos/x">Sharma</a>'
check('R5 plain a untouched', rc(plain) === plain, rc(plain))
const ext = '<a href="https://evil.com/x" rel="noopener">x</a>'
check('R5 external a untouched', rc(ext) === ext, rc(ext))
const bad = '<a href="/rocodromos/x" data-item-card="shoe:x">Sharma</a>'
check('R5 invalid card as-is', renderItemCards(bad, LABELS) === bad)
const bad2 = '<a href="/x" data-item-card="admin:x">t</a>'
check('R5 invalid card as-is 2', renderItemCards(bad2, LABELS) === bad2)

// --- Regression battery (F6.4-editor-review.md) ----------------------------------------------------
for (const h of ['javascript:alert(1)', 'JaVaScRiPt:alert(1)', 'jav&#x09;ascript:alert(1)', 'data:text/html,x', 'vbscript:x', '//evil.com', '\\\\evil.com']) {
  check(`REG href ${h}`, s(`<a href="${h}">x</a>`) === '<a>x</a>', s(`<a href="${h}">x</a>`))
}
check('REG rel noopener', s('<a href="https://e.com" target="_blank">x</a>') === '<a href="https://e.com" rel="noopener">x</a>')
const okImg = `${SUPA}/storage/v1/object/public/media/a.png`
check('REG img ok', s(`<img src="${okImg}" alt="a">`).includes(okImg))
for (const src of [`${SUPA}/storage/v1/object/public/media/../../public/other/x.png`, `${SUPA}/storage/v1/object/public/media/%2e%2e/x`, 'https://evil.com/x.png', `${SUPA}/storage/v1/object/public/media/a\\b`]) {
  check(`REG img ${src.slice(-20)}`, s(`<img src="${src}">`) === '', s(`<img src="${src}">`))
}
const regImg = s(`<img src="${okImg}" srcset="x 1x" onerror="alert(1)" style="x:y" data-media-id="nope" width="10" height="abc">`)
check('REG img attrs', !/srcset|onerror|style|data-media-id|height/.test(regImg) && /width="10"/.test(regImg), regImg)
check('REG uuid kept', s(`<img src="${okImg}" data-media-id="123e4567-e89b-12d3-a456-426614174000">`).includes('data-media-id'))
for (const h of ['<svg><script>alert(1)</script></svg>', '<template><script>alert(1)</script></template>', '<noscript><p title="</noscript><img src=x onerror=alert(1)>"></noscript>', '<!--[if IE]><script>alert(1)</script><![endif]-->', '<script>alert(1)</script><style>x{}</style>']) {
  check(`REG ${h.slice(0, 20)}`, safe(s(h)) && !/<(svg|template|noscript|style)/i.test(s(h)), s(h))
}
check('REG basic', s('<p>a <strong>b</strong> <em>c</em></p><h2>t</h2><ul><li>x</li></ul>') === '<p>a <strong>b</strong> <em>c</em></p><h2>t</h2><ul><li>x</li></ul>')

report()
