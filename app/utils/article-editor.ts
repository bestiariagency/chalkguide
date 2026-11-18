import { mergeAttributes, type Extensions, type JSONContent } from '@tiptap/core'
import Image from '@tiptap/extension-image'
import Placeholder from '@tiptap/extension-placeholder'
import StarterKit from '@tiptap/starter-kit'
import { ItemCard, VideoEmbed } from './article-embed-nodes'
import { inMediaBucket, mediaBucketPrefix } from '~~/shared/lib/sanitize/constants'
import { AuthorNote, EditorTable, EditorTableCell, EditorTableHeader, EditorTableRow, ImageFigure } from './article-editor-nodes'
import type { EmbedLocale } from './article-embeds'

/** Image of the body: a node that remembers which `media` row it came from (`attrs.mediaId`). */
export const MediaImage = Image.extend({
  // Same gate as the sanitizer: only the project's public bucket, no path tricks.
  parseHTML() {
    return [
      {
        tag: 'img[src]',
        getAttrs: (element) => {
          const src = (element as HTMLElement).getAttribute('src') ?? ''
          const prefix = mediaBucketPrefix(String(tryUseNuxtApp()?.$config.public.supabase?.url ?? ''))
          return inMediaBucket(src, prefix) ? null : false
        },
      },
    ]
  },
  addAttributes() {
    return {
      ...this.parent?.(),
      mediaId: {
        default: null,
        parseHTML: (element: HTMLElement) => element.getAttribute('data-media-id'),
        renderHTML: (attrs: { mediaId?: string | null }) => (attrs.mediaId ? { 'data-media-id': attrs.mediaId } : {}),
      },
      width: { default: null },
      height: { default: null },
    }
  },
  renderHTML({ HTMLAttributes }) {
    return ['img', mergeAttributes(this.options.HTMLAttributes, HTMLAttributes, { loading: 'lazy' })]
  },
})

/**
 * Nodes and marks the article body may contain; they match the sanitizer allow-list
 * (`shared/lib/sanitize/sanitize-article-html.ts`, blocks in `article-editor-nodes.ts`), except the video and item-card embeds (see `article-embed-nodes.ts`). Headings h2/h3 only (the title is the h1).
 * `textOnly` (legal pages) leaves out image, video and item card; `extra` adds editor-only extensions.
 */
export function articleExtensions(placeholder: string, locale: EmbedLocale = 'es', options: { textOnly?: boolean; extra?: Extensions } = {}): Extensions {
  const embeds = options.textOnly
    ? []
    : [
        MediaImage.configure({ inline: false, allowBase64: false }),
        ImageFigure,
        EditorTable,
        EditorTableRow,
        EditorTableHeader,
        EditorTableCell,
        AuthorNote,
        VideoEmbed.configure({ locale }),
        ItemCard.configure({ locale }),
      ]
  return [
    StarterKit.configure({
      heading: { levels: [2, 3] },
      code: false,
      codeBlock: false,
      horizontalRule: false,
      strike: false,
      underline: false,
      link: {
        openOnClick: false,
        autolink: true,
        protocols: ['http', 'https', 'mailto'],
        HTMLAttributes: { rel: 'noopener', target: null },
      },
    }),
    ...embeds,
    Placeholder.configure({ placeholder }),
    ...(options.extra ?? []),
  ]
}

export const EMPTY_DOC: JSONContent = { type: 'doc', content: [] }

/** Body as the form keeps it: the Tiptap document (source of truth) and its HTML (sanitised on save). */
export interface ArticleBody {
  json: JSONContent
  html: string
}

export const emptyBody = (): ArticleBody => ({ json: structuredClone(EMPTY_DOC), html: '' })

/** True when the document has no text and no image (an empty paragraph counts as empty). */
export function isEmptyDoc(doc: JSONContent | null | undefined): boolean {
  if (!doc?.content?.length) return true
  return doc.content.every((node) => {
    if (node.type === 'paragraph' || node.type === 'heading') return !node.content?.length
    return false
  })
}

/** Visible words in the HTML (rough, for the "980 palabras · 4 min" hint). */
export function countWords(html: string): number {
  const text = html.replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').trim()
  return text ? text.split(/\s+/).length : 0
}

/** Same rule as the DB trigger: 200 words per minute, at least 1 when there is text. */
export const readingMinutes = (words: number) => (words ? Math.max(1, Math.ceil(words / 200)) : 0)

/** Normalises a user-typed link: adds https:// to bare domains; returns null when it is not http(s)/mailto. */
export function normalizeLinkUrl(raw: string): string | null {
  const value = raw.trim()
  if (!value) return null
  if (/^(https?:\/\/|mailto:)\S+$/i.test(value)) return value
  if (/^[\w-]+(\.[\w-]+)+(\/\S*)?$/.test(value)) return `https://${value}`
  return null
}
