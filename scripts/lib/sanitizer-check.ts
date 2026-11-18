/**
 * Shared harness and fixtures of the sanitizer checks (`check-sanitizer*.ts`): the pass/fail counter and the
 * helpers over the real sanitizer output.
 */
import { sanitizeArticleHtml } from '../../shared/lib/sanitize/sanitize-article-html'
import { VIDEO_ALLOW, VIDEO_SANDBOX } from '../../app/utils/article-embeds'

export const SUPA = 'https://proj.supabase.co'
export const s = (html: string) => sanitizeArticleHtml(html, { supabaseUrl: SUPA })
export const VID = 'dQw4w9WgXcQ'
export const VALID = `https://www.youtube-nocookie.com/embed/${VID}`

let failed = 0
let total = 0
export function check(name: string, ok: boolean, detail = '') {
  total++
  if (!ok) {
    failed++
    console.error(`FAIL ${name} ${detail}`)
  }
}
/** Prints the tally and exits 1 when anything failed. */
export function report() {
  console.log(`${total - failed}/${total} checks OK`)
  if (failed) process.exit(1)
}

export const count = (html: string, re: RegExp) => (html.match(re) ?? []).length
export const noIframe = (html: string) => !/<iframe/i.test(html)
export const safe = (html: string) => !/<script|\son\w+=|javascript:|srcdoc/i.test(html)
export const iframe = (src: string, extra = '') => `<iframe src="${src}"${extra ? ' ' + extra : ''}></iframe>`
export const card = (href: string, attr: string, extra = '', inner = 'Sharma') => `<a href="${href}" data-item-card="${attr.replace(/"/g, '&quot;')}"${extra ? ' ' + extra : ''}>${inner}</a>`
export const LABELS = { kinds: { gym: 'Rocódromo', shoe: 'Pie de gato', resoler: 'Resolador' }, view: 'Ver ficha' } as const
/** Real output of the video node's renderHTML (no id attribute). */
export const v1 = `<iframe src="${VALID}" title="Vídeo incrustado" allow="${VIDEO_ALLOW}" loading="lazy" allowfullscreen="true" referrerpolicy="strict-origin-when-cross-origin" sandbox="${VIDEO_SANDBOX}"></iframe>`
/** Host/scheme in upper case are not normalised: the iframe is removed (never copied as-is). */
export const v18 = s(`<IFRAME SRC="https://WWW.YOUTUBE-NOCOOKIE.COM/embed/${VID}"></IFRAME>`)
