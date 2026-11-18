import type { Transformer } from 'sanitize-html'
import { isFigureWidth } from './constants'

/**
 * Editorial v2 blocks of the article allow-list (D47/D51, design §13.9): table, figure with caption
 * and width, figure caption and author note. Each tag keeps one closed
 * attribute at most; `class`, `style`, `id` and free attributes never survive. Used by
 * `sanitize-article-html.ts`.
 */
export const BLOCK_ALLOWED_TAGS = [
  'table', 'thead', 'tbody', 'tr', 'th', 'td', 'figure', 'figcaption', 'small', 'aside',
] as const

export const BLOCK_ALLOWED_ATTRIBUTES = {
  th: ['scope'],
  figure: ['data-width'],
  aside: ['data-note'],
} as const

const SCOPES = ['col', 'row']

/** Attribute values are rebuilt from closed lists: anything else falls back to a safe default. */
export const blockTransforms: Record<string, Transformer> = {
  th: (tagName, attribs) => ({ tagName, attribs: SCOPES.includes(attribs.scope ?? '') ? { scope: attribs.scope! } : ({} as Record<string, string>) }),
  figure: (tagName, attribs) => ({ tagName, attribs: { 'data-width': isFigureWidth(attribs['data-width']) ? attribs['data-width'] : 'column' } }),
  // A note that is not the author's loses its tag (the content stays as plain blocks): `div` is not allowed.
  aside: (tagName, attribs) =>
    attribs['data-note'] === 'author' ? { tagName, attribs: { 'data-note': 'author' } } : { tagName: 'div', attribs: {} as Record<string, string> },
}

const SCOPED = /<(\/?)(table|aside|figcaption|small|thead|tbody|tr|th|td)(?:\s[^>]*)?>/g
const TABLE_PARTS = new Set(['thead', 'tbody', 'tr', 'th', 'td'])

/**
 * Post-pass on sanitized output (tags are canonical): nested `table`/`aside` lose their tag (the
 * render pairs `<table>…</table>` without nesting) and `small` only lives inside `figcaption`;
 * a dropped tag keeps its content.
 */
export function dropStrayBlocks(html: string): string {
  const open = { table: 0, aside: 0, figcaption: 0, small: 0 }
  const kept: Record<string, boolean[]> = { table: [], aside: [], figcaption: [], small: [] }
  let flat = 0 // depth inside a dropped (nested) table: its rows and cells are flattened into the outer cell
  return html.replace(SCOPED, (tag, close: string, raw: string) => {
    if (TABLE_PARTS.has(raw)) return flat > 0 ? '' : tag
    const name = raw as keyof typeof open
    if (close) {
      const keep = kept[name]!.pop() ?? false
      if (keep) open[name]--
      else if (name === 'table') flat--
      return keep ? tag : ''
    }
    const keep = name === 'small' ? open.figcaption > 0 && open.small === 0 : open[name] === 0
    kept[name]!.push(keep)
    if (keep) open[name]++
    else if (name === 'table') flat++
    return keep ? tag : ''
  })
}
