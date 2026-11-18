import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import {
  MEDIA_PAGE_SIZE,
  type AdminMediaItem,
  type MediaCounts,
  type MediaFilter,
  type MediaUsageRow,
} from '~/utils/admin-media-library'
import { guideSchema, ServiceError } from '../client'
import { uploadObject } from '../storage-upload'

type Client = SupabaseClient<Database>
type MediaRow = Database['guide']['Tables']['media']['Row']

/**
 * Media library. Reads and writes go through the `guide` RPCs (`search_media`, `media_stats`,
 * `media_usages`, `create_media`, `replace_media`, `delete_media`); texts are a plain update. The
 * server sets mime/size and checks the path `<media_id>/<version>-<slug>.<ext>`.
 */
interface PgError {
  message: string
  code?: string
  details?: string | null
}
const fail = (error: PgError): never => {
  throw new ServiceError(error.message, error.code, error.details ?? undefined)
}

export interface MediaQuery {
  search: string
  filter: MediaFilter
}

function toItem(row: Omit<MediaRow, 'has_en'> & { has_en?: boolean | null }, usageCount: number): AdminMediaItem {
  return {
    id: row.id,
    storage_path: row.storage_path,
    version: row.version,
    original_filename: row.original_filename,
    mime_type: row.mime_type,
    size_bytes: row.size_bytes,
    width: row.width,
    height: row.height,
    alt_es: row.alt_es,
    alt_en: row.alt_en,
    caption_es: row.caption_es,
    caption_en: row.caption_en,
    credit: row.credit,
    dominant_color: row.dominant_color,
    created_at: row.created_at,
    updated_at: row.updated_at,
    usage_count: usageCount,
  }
}

export async function fetchMediaPage(client: Client, query: MediaQuery, offset: number, limit = MEDIA_PAGE_SIZE): Promise<{ items: AdminMediaItem[]; total: number }> {
  const { data, error } = await guideSchema(client).rpc('search_media', {
    p_query: query.search.trim().slice(0, 100),
    p_filter: query.filter,
    p_limit: limit,
    p_offset: offset,
  })
  if (error) return fail(error)
  const rows = data ?? []
  return { items: rows.map((r) => toItem(r as unknown as MediaRow, r.usage_count)), total: rows[0]?.total_count ?? 0 }
}

/** One library row by id (deep link `?medio=`); `null` when it no longer exists. */
export async function fetchMediaById(client: Client, id: string): Promise<AdminMediaItem | null> {
  const { data, error } = await guideSchema(client).from('media').select('*').eq('id', id).maybeSingle()
  if (error) return fail(error)
  return data ? toItem(data as unknown as MediaRow, 0) : null
}

/** Counters of the header and the filters (they ignore the search and the active filter). */
export async function fetchMediaCounts(client: Client): Promise<MediaCounts> {
  const { data, error } = await guideSchema(client).rpc('media_stats')
  const s = data?.[0]
  if (error || !s) return fail(error ?? { message: 'media_stats empty' })
  return {
    total: s.total_count,
    inUse: s.in_use_count,
    unused: s.unused_count,
    missingAlt: s.missing_alt_count,
    missingEn: s.missing_en_count,
    rowsBytes: s.rows_bytes,
    storageBytes: s.storage_bytes,
    storageObjects: s.storage_objects,
  }
}

export async function fetchMediaUsage(client: Client, id: string): Promise<MediaUsageRow[]> {
  const { data, error } = await guideSchema(client).rpc('media_usages', { p_id: id })
  if (error) return fail(error)
  return data ?? []
}

export interface MediaPatch {
  alt_es: string | null
  alt_en: string | null
  caption_es: string | null
  caption_en: string | null
  credit: string | null
  /** Only sent when the author changed it (contract lists the five text columns; see report). */
  dominant_color?: string | null
}

/** Texts and credit; the file never changes here. */
export async function saveMedia(client: Client, id: string, patch: MediaPatch): Promise<void> {
  const { data, error } = await guideSchema(client).from('media').update(patch).eq('id', id).select('id')
  if (error) return fail(error)
  if (!data.length) throw new ServiceError('media not found', 'P0002')
}

export interface UploadFile {
  path: string
  blob: Blob
  mime: string
  onProgress: (fraction: number) => void
  signal?: AbortSignal
}

/** POST to the `media` bucket with real progress, no upsert. */
export async function uploadToStorage(client: Client, config: { baseUrl: string; apiKey: string }, file: UploadFile): Promise<void> {
  await uploadObject(client, config, { bucket: 'media', path: file.path, blob: file.blob, mime: file.mime, maxAge: 31536000, onProgress: file.onProgress, signal: file.signal })
}

export async function removeFromStorage(client: Client, paths: string[]): Promise<void> {
  if (!paths.length) return
  const { error } = await client.storage.from('media').remove(paths)
  if (error) throw new ServiceError(error.message)
}

export interface NewMedia {
  id: string
  storage_path: string
  original_filename: string
  width: number
  height: number
  dominant_color: string
}

/** Registers an object already in Storage (the server fills mime and size). The caller removes the object on failure. */
export async function createMedia(client: Client, row: NewMedia): Promise<AdminMediaItem> {
  const { data, error } = await guideSchema(client).rpc('create_media', {
    p_id: row.id,
    p_storage_path: row.storage_path,
    p_original_filename: row.original_filename,
    p_width: row.width,
    p_height: row.height,
    p_dominant_color: row.dominant_color,
  })
  const created = data?.[0]
  if (error || !created) return fail(error ?? { message: 'create_media empty' })
  return toItem(created, 0)
}

export interface ReplacedMedia {
  version: number
  storage_path: string
  previous_storage_path: string
  mime_type: string
  size_bytes: number
  updated_at: string
}

/** Points the row to the new object (version + 1 in the database) and returns the old path to delete. */
export async function replaceMedia(
  client: Client,
  id: string,
  expectedVersion: number,
  row: Omit<NewMedia, 'id'>,
): Promise<ReplacedMedia> {
  const { data, error } = await guideSchema(client).rpc('replace_media', {
    p_id: id,
    p_expected_version: expectedVersion,
    p_storage_path: row.storage_path,
    p_original_filename: row.original_filename,
    p_width: row.width,
    p_height: row.height,
    p_dominant_color: row.dominant_color,
  })
  const replaced = data?.[0]
  if (error || !replaced) return fail(error ?? { message: 'replace_media empty' })
  return replaced
}

/** The RPC refuses when the file is in use (23503, `detail` = number of uses); then the object is removed. */
export async function deleteMedia(client: Client, id: string, expectedVersion: number): Promise<void> {
  const { data, error } = await guideSchema(client).rpc('delete_media', { p_id: id, p_expected_version: expectedVersion })
  if (error) return fail(error)
  await removeFromStorage(client, [data]).catch(() => undefined)
}
