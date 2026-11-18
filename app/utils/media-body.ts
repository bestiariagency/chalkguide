import type { JSONContent } from '@tiptap/vue-3'

/**
 * Body images remember their `media` row (`data-media-id`) but also the storage path they had when
 * inserted. Replacing a file moves the row to a new path, so on load the `src` is rewritten with the
 * current one. Only the part after the bucket prefix changes; the sanitizer is not involved.
 */
const BUCKET = '/storage/v1/object/public/media/'
const UUID = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
const IMG_TAG = /<img\b[^>]*>/gi
const MEDIA_ID = new RegExp(`\\sdata-media-id=["'](${UUID})["']`, 'i')
const SRC_ATTR = /(\ssrc=["'])([^"']*)(["'])/i

export type MediaPaths = ReadonlyMap<string, string>

function swapPath(src: string, path: string): string {
  const at = src.indexOf(BUCKET)
  return at < 0 ? src : `${src.slice(0, at + BUCKET.length)}${path}`
}

export function mediaIdsInHtml(html: string | null | undefined): string[] {
  const ids = new Set<string>()
  for (const tag of html?.match(IMG_TAG) ?? []) {
    const id = MEDIA_ID.exec(tag)?.[1]
    if (id) ids.add(id.toLowerCase())
  }
  return [...ids]
}

export function rewriteHtmlMedia(html: string, paths: MediaPaths): string {
  if (!paths.size) return html
  return html.replace(IMG_TAG, (tag) => {
    const path = paths.get(MEDIA_ID.exec(tag)?.[1]?.toLowerCase() ?? '')
    return path ? tag.replace(SRC_ATTR, (_, open: string, src: string, close: string) => `${open}${swapPath(src, path)}${close}`) : tag
  })
}

export function mediaIdsInDoc(doc: unknown): string[] {
  const ids = new Set<string>()
  const walk = (node: JSONContent | undefined) => {
    if (!node) return
    const id = node.type === 'image' ? node.attrs?.mediaId : undefined
    if (typeof id === 'string' && id) ids.add(id.toLowerCase())
    node.content?.forEach(walk)
  }
  if (doc && typeof doc === 'object') walk(doc as JSONContent)
  return [...ids]
}

export function rewriteDocMedia<T>(doc: T, paths: MediaPaths): T {
  if (!paths.size || !doc || typeof doc !== 'object') return doc
  const walk = (node: JSONContent): JSONContent => {
    const next: JSONContent = node.content ? { ...node, content: node.content.map(walk) } : { ...node }
    const path = node.type === 'image' && typeof node.attrs?.mediaId === 'string' ? paths.get(node.attrs.mediaId.toLowerCase()) : undefined
    if (path && typeof node.attrs?.src === 'string') next.attrs = { ...node.attrs, src: swapPath(node.attrs.src, path) }
    return next
  }
  return walk(doc as JSONContent) as T
}
