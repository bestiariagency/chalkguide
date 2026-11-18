import type { Locale, MediaRef } from '~/types/domain'
import { mediaIdsInHtml, rewriteHtmlMedia, type MediaPaths } from '~/utils/media-body'
import { pick, type GuideClient } from './client'

/** Columns of `media` needed to render an image (embed with an explicit FK name). */
export const MEDIA_COLUMNS = 'storage_path, alt_es, alt_en, width, height, credit, dominant_color'

interface MediaRow {
  storage_path: string
  alt_es: string | null
  alt_en: string | null
  width: number | null
  height: number | null
  credit?: string | null
  dominant_color?: string | null
}

export function toMediaRef(row: MediaRow | null, locale: Locale): MediaRef | null {
  if (!row) return null
  return {
    path: row.storage_path,
    alt: pick(locale, row.alt_es, row.alt_en),
    width: row.width,
    height: row.height,
    credit: row.credit ?? null,
    dominantColor: row.dominant_color ?? null,
  }
}

/** Public URL of an object in the `media` bucket (public bucket, no listing). */
export function mediaPublicUrl(supabaseUrl: string, path: string): string {
  return `${supabaseUrl.replace(/\/$/, '')}/storage/v1/object/public/media/${path}`
}

/** Current `storage_path` of each media id (replacing a file moves the row to a new path). */
export async function fetchMediaPaths(db: GuideClient, ids: string[]): Promise<MediaPaths> {
  if (!ids.length) return new Map()
  const { data, error } = await db.from('media').select('id, storage_path').in('id', ids)
  if (error) throw new Error(error.message)
  return new Map(data.map((row) => [row.id.toLowerCase(), row.storage_path]))
}

/**
 * Body HTML with the `src` of every `img[data-media-id]` pointing to the current object. Best effort:
 * if the lookup fails the page still renders with the stored `src`.
 */
export async function refreshBodyHtml(db: GuideClient, html: string): Promise<string> {
  const ids = mediaIdsInHtml(html)
  if (!ids.length) return html
  try {
    return rewriteHtmlMedia(html, await fetchMediaPaths(db, ids))
  } catch {
    return html
  }
}
