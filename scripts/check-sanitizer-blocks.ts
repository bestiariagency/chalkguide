/**
 * Sanitizer checks for the editorial v2 blocks (D51, docs/security/D51-prose-sanitize-review.md).
 * Companion of `check-sanitizer.ts` (kept apart to stay under ~300 lines). Runs the real modules.
 * Usage: `npx tsx scripts/check-sanitizer-blocks.ts`. Exit code 1 when anything fails.
 */
import { sanitizeArticleHtml } from '../shared/lib/sanitize/sanitize-article-html'
import { addHeadingAnchors, renderAuthorNotes, renderTables } from '../app/utils/prose-blocks'
import { articleToc, bodyHeadings, extractHeadings } from '../app/utils/article-toc'

const SUPA = 'https://proj.supabase.co'
const s = (html: string) => sanitizeArticleHtml(html, { supabaseUrl: SUPA })
const safe = (html: string) => !/<script|\son\w+=|javascript:|srcdoc|<svg|<math|<xmp|<template|<style/i.test(html)
const count = (html: string, re: RegExp) => (html.match(re) ?? []).length
const IMG = `${SUPA}/storage/v1/object/public/media/a.png`

let failed = 0
let total = 0
function check(name: string, ok: boolean, detail = '') {
  total++
  if (!ok) {
    failed++
    console.error(`FAIL ${name} ${detail}`)
  }
}

// 1. Escaping of aria-label / author name / table label.
const evil = '"><img src=x onerror=alert(1)>'
const note = renderAuthorNotes('<aside data-note="author"><p>x</p></aside>', evil)
check('B1 note label', !note.includes('<img') && count(note, /aria-label="/g) === 1, note)
const tbl = renderTables('<table><tbody><tr><td>1</td></tr></tbody></table>', evil)
check('B1 table label', !tbl.includes('<img') && count(tbl, /aria-label="/g) === 1, tbl)
const anchors = addHeadingAnchors('<h2>Título</h2>', () => evil)
check('B1 anchor label', !anchors.includes('<img'), anchors)

// 2. Upper case and entities.
check('B2 case', safe(s('<SCRIPT>alert(1)</SCRIPT><A HREF="JAVASCRIPT:x">a</A><IMG SRC="x" ONERROR="y">')))
check('B2 entities', s('<a href="&#106;avascript:alert(1)">x</a>') === '<a>x</a>', s('<a href="&#106;avascript:alert(1)">x</a>'))
check('B2 figure width', s('<FIGURE data-width="WIDE" class="x" style="y"><figcaption>a</figcaption></FIGURE>') === '<figure data-width="column"><figcaption>a</figcaption></figure>')

// 3. Forged internal markers do not survive.
const forged = s('<p data-note-label="" class="table-wrap" role="region" tabindex="0" aria-label="x" data-anchor id="h">a</p><div class="num" data-video-facade="">b</div>')
check('B3 markers', !/data-note-label|class=|role=|tabindex|aria-label|data-anchor|id=|data-video-facade/.test(forged), forged)
check('B3 aside other', s('<aside data-note="evil">a</aside>') === '<div>a</div>' || !s('<aside data-note="evil">a</aside>').includes('<aside'))

// 4. Nesting and idempotency.
const nested = s('<table><tbody><tr><td><table><tbody><tr><td>x</td></tr></tbody></table></td></tr></tbody></table>')
check('B4 nested table', count(nested, /<table>/g) === 1 && count(nested, /<\/table>/g) === 1, nested)
check('B4 nested table flattened', !/<(tbody|tr|td)>.*<(tbody|tr|td)>.*<\/\1>.*<\/\1>/.test(nested.replace(/<\/(tbody|tr|td)>/g, '</$1>')) && count(nested, /<td>/g) === 1 && count(nested, /<tr>/g) === 1, nested)
check('B4 nested idempotent', s(nested) === nested && s(s(nested)) === s(nested), s(s(nested)))
const ent = '<p>&amp;lt;b&amp;gt; &lt;i&gt;</p><table><tbody><tr><td>a &amp;lt; b</td></tr></tbody></table>'
check('B4 entities idempotent', s(s(ent)) === s(ent) && s(ent).includes('&amp;lt;'), s(ent))
check('B4 render pairs', count(renderTables(nested, 'T'), /table-wrap/g) === 1)
const nestedAside = s('<aside data-note="author"><aside data-note="author">x</aside></aside>')
check('B4 nested aside', count(nestedAside, /<aside/g) === 1 && count(nestedAside, /<\/aside>/g) === 1, nestedAside)
const sample = '<h2>a</h2><p>x <a href="https://e.com">y</a></p><figure data-width="wide"><img src="' + IMG + '" alt="a" data-media-id="123e4567-e89b-12d3-a456-426614174000"><figcaption>c<small>d</small></figcaption></figure><blockquote><p>q</p></blockquote><aside data-note="author"><p>n</p></aside><table><thead><tr><th scope="col">h</th></tr></thead><tbody><tr><td>1</td></tr></tbody></table>'
check('B4 idempotent', s(s(sample)) === s(sample), s(sample))
check('B4 small only in figcaption', s('<p>a<small>b</small></p>') === '<p>ab</p>' && s('<figure><figcaption><small>b</small></figcaption></figure>').includes('<small>'))

// 5. Footer (no longer allowed) and deep blockquote.
check('B5 footer gone', !s('<blockquote><footer>x</footer></blockquote><footer>y</footer>').includes('<footer'))
check('B5 deep blockquote', safe(s('<blockquote>'.repeat(500) + 'x' + '</blockquote>'.repeat(500))))

// 6. mXSS.
for (const h of ['<math><mi><script>alert(1)</script></mi></math>', '<svg><style><img src=x onerror=alert(1)></style></svg>', '<xmp><img src=x onerror=alert(1)></xmp>', '<template><img src=x onerror=alert(1)></template>', '<![CDATA[<script>alert(1)</script>]]>', '<noscript><p title="</noscript><img src=x onerror=alert(1)>">']) {
  check(`B6 ${h.slice(0, 14)}`, safe(s(h)) && !/onerror/i.test(s(h)), s(h))
}

// 7. iframe inside blocks.
const VID = '<iframe src="https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"></iframe>'
for (const wrap of ['table><tbody><tr><td>%</td></tr></tbody></table', 'figure><figcaption>%</figcaption></figure', 'aside data-note="author">%</aside', 'blockquote>%</blockquote']) {
  const tag = wrap.split(/[ >]/)[0]!
  const out = s(`<${wrap.replace('%', VID)}>`)
  check(`B7 iframe in ${tag}`, safe(out) && count(out, /<iframe/g) <= 1 && !/<iframe[^>]*(?:onload|srcdoc)/.test(out), out)
}
check('B7 evil iframe', !s('<figure><iframe src="https://evil.com/x"></iframe></figure>').includes('<iframe'))

// 8. Images outside the bucket, srcset, picture.
check('B8 outside', !s('<figure><img src="https://evil.com/a.png"></figure>').includes('<img'))
check('B8 srcset', !/srcset/.test(s(`<img src="${IMG}" srcset="https://evil.com/a.png 2x">`)))
check('B8 picture', !/<picture|<source|evil/.test(s(`<picture><source srcset="https://evil.com/a.png"><img src="${IMG}"></picture>`)))
check('B8 sizes', !/sizes|style/.test(s(`<img src="${IMG}" sizes="100vw" style="x:y">`)))

// 9. Obfuscated hrefs.
for (const h of [' javascript:alert(1)', 'java\tscript:alert(1)', 'java\nscript:alert(1)', '&#x6A;avascript:alert(1)', 'jav&Tab;ascript:alert(1)', '\u0001javascript:alert(1)', 'data:text/html;base64,PHNjcmlwdD4=', 'JAVASCRIPT&colon;alert(1)']) {
  const out = s(`<a href="${h}">x</a>`)
  check(`B9 ${JSON.stringify(h).slice(0, 18)}`, !/javascript|data:|href=/i.test(out), out)
}

// 10. Reserved ids and 1000 equal titles.
const reserved = ['Newsletter', 'Keep reading', 'Article items', 'Article title', 'Site footer', 'Mobile menu', 'Contenido', 'Category list', 'Blog x', 'V 1']
const ids = bodyHeadings(reserved.map((t) => `<h2>${t}</h2>`).join('')).map((h) => h.id)
check('B10 reserved', ids.length === reserved.length && ids.every((id) => id.endsWith('-apartado')), ids.join())
const many = bodyHeadings('<h2>Igual</h2>'.repeat(1000)).map((h) => h.id)
check('B10 1000 equal', new Set(many).size === 1000)

// 11. O1: index and ids agree once the body is sanitized a single time.
const raw = '<h2>Uno</h2><p>a</p><H2 id="x" onclick="y">Uno</H2><h3>Dos</h3><script>alert(1)</script><h2>Uno</h2>'
const clean = s(raw)
const idsFromAnchors = [...addHeadingAnchors(clean).matchAll(/<h2 id="([^"]+)"/g)].map((m) => m[1])
check('B11 toc = ids', JSON.stringify(extractHeadings(clean).map((h) => h.id)) === JSON.stringify(idsFromAnchors), idsFromAnchors.join())
check('B11 clean idempotent for ids', JSON.stringify(bodyHeadings(s(clean))) === JSON.stringify(bodyHeadings(clean)))
check('B11 toc empty short', articleToc(clean).length === 0)

// 12. Table DoS: bounded cost, no RangeError.
const row = '<tr><td>1</td></tr>'
const huge = `<table><tbody>${row.repeat(120000)}</tbody></table>`
let t0 = Date.now()
let out = ''
try {
  out = renderTables(huge, 'T')
} catch (e) {
  check('B12 no throw', false, String(e))
}
check('B12 rows no num', !out.includes('class="num"') && out.includes('table-wrap') && Date.now() - t0 < 5000, `${Date.now() - t0}ms`)
const wide = `<table><tbody><tr>${'<td>1</td>'.repeat(50)}</tr></tbody></table>`
check('B12 columns no num', !renderTables(wide, 'T').includes('class="num"'))
check('B12 ok table', renderTables('<table><tbody><tr><td>1</td><td>a</td></tr><tr><td>2</td><td>b</td></tr></tbody></table>', 'T').includes('<td class="num">1'))
t0 = Date.now()
check('B12 sanitize big', s(huge).length > 0 && Date.now() - t0 < 10000, `${Date.now() - t0}ms`)

console.log(`${total - failed}/${total} blocks checks OK`)
if (failed) process.exit(1)
