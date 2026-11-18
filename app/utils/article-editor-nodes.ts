import { Node, type NodeViewRenderer } from '@tiptap/core'
import { Table, TableCell, TableHeader, TableRow } from '@tiptap/extension-table'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import EditorFigureView from '~/components/admin/editor/nodes/FigureView.vue'
import EditorNoteView from '~/components/admin/editor/nodes/NoteView.vue'
import { UUID, inMediaBucket, isFigureWidth, mediaBucketPrefix } from '~~/shared/lib/sanitize/constants'

/**
 * Editorial v2 blocks of the body (§13.9): table, image with caption and width, author note. Their
 * HTML is exactly what the article sanitizer allows (`shared/lib/sanitize/sanitize-article-blocks.ts`).
 */

type AttrDefs = Record<string, { default?: unknown; [key: string]: unknown }>

/** Cell attributes (colspan, rowspan, colwidth) stay in the model for the table plugin but are never written to HTML: no merged or sized cells. */
const quiet = (defs: AttrDefs | undefined): AttrDefs =>
  Object.fromEntries(Object.entries(defs ?? {}).map(([key, def]) => [key, { ...def, renderHTML: () => ({}) }]))

export const EditorTable = Table.configure({ resizable: false })
export const EditorTableRow = TableRow
export const EditorTableCell = TableCell.extend({
  addAttributes() {
    return quiet(this.parent?.() as AttrDefs | undefined)
  },
})
/** Header cells carry the only attribute the sanitizer lets through a table: `scope="col"`. */
export const EditorTableHeader = TableHeader.extend({
  addAttributes() {
    return { ...quiet(this.parent?.() as AttrDefs | undefined), scope: { default: 'col', parseHTML: () => 'col', renderHTML: () => ({ scope: 'col' }) } }
  },
})

/** `<figure data-width><img><figcaption>caption<small>credit</small></figcaption></figure>`; the alt comes from Media. */
export const ImageFigure: Node = Node.create({
  name: 'imageFigure',
  group: 'block',
  atom: true,
  draggable: true,
  selectable: true,
  addAttributes: () => ({
    src: { default: null },
    alt: { default: '' },
    mediaId: { default: null },
    width: { default: null },
    height: { default: null },
    widthMode: { default: 'column' },
    caption: { default: '' },
    credit: { default: '' },
  }),
  parseHTML: () => [
    {
      tag: 'figure',
      priority: 1100,
      getAttrs: (element) => {
        const el = element as HTMLElement
        const img = el.querySelector('img')
        if (!img) return false
        const src = img.getAttribute('src') ?? ''
        // Only photos from the project's public bucket with a Media id (the sanitizer drops the rest anyway).
        const prefix = mediaBucketPrefix(String(tryUseNuxtApp()?.$config.public.supabase?.url ?? ''))
        if (!inMediaBucket(src, prefix) || !UUID.test(img.getAttribute('data-media-id') ?? '')) return false
        const figcaption = el.querySelector('figcaption')
        const small = figcaption?.querySelector('small') ?? null
        const caption = [...(figcaption?.childNodes ?? [])].filter((node) => node !== small).map((node) => node.textContent ?? '').join('').trim()
        const mode = el.getAttribute('data-width')
        const size = (name: string) => Number(img.getAttribute(name)) || null
        return {
          src: img.getAttribute('src'),
          alt: img.getAttribute('alt') ?? '',
          mediaId: img.getAttribute('data-media-id'),
          width: size('width'),
          height: size('height'),
          widthMode: isFigureWidth(mode) ? mode : 'column',
          caption,
          credit: small?.textContent?.trim() ?? '',
        }
      },
    },
  ],
  renderHTML({ node }) {
    const { src, alt, mediaId, width, height, widthMode, caption, credit } = node.attrs
    if (!src) return ['p']
    const image = ['img', { src, alt: alt ?? '', loading: 'lazy', ...(mediaId ? { 'data-media-id': mediaId } : {}), ...(width ? { width } : {}), ...(height ? { height } : {}) }]
    const text = [...(caption ? [String(caption)] : []), ...(credit ? [['small', String(credit)]] : [])]
    return ['figure', { 'data-width': isFigureWidth(widthMode) ? widthMode : 'column' }, image, ...(text.length ? [['figcaption', ...text]] : [])] as never
  },
  addNodeView: (): NodeViewRenderer => VueNodeViewRenderer(EditorFigureView),
})

/** `<aside data-note="author">` with paragraphs and lists; the "Nota de {name}" label is drawn by the node view and the site, never stored. */
export const AuthorNote: Node = Node.create({
  name: 'authorNote',
  group: 'block',
  content: '(paragraph | bulletList)+',
  defining: true,
  parseHTML: () => [{ tag: 'aside[data-note="author"]' }],
  renderHTML: () => ['aside', { 'data-note': 'author' }, 0],
  addNodeView: (): NodeViewRenderer => VueNodeViewRenderer(EditorNoteView),
})
