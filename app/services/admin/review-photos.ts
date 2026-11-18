import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { processReviewPhoto } from '~/utils/review-photo-image'
import { REVIEW_PHOTO_PUBLIC_BUCKET, REVIEW_PHOTO_UPLOADS_BUCKET } from '~/utils/review-photos'
import { guideSchema, ServiceError, unwrap } from '../client'
import { removeObjects, uploadObject, type StorageConfig } from '../storage-upload'

type Client = SupabaseClient<Database>
type Moderated = { public_path: string | null; previous_public_path: string | null; status: string }

const SIGNED_URL_SECONDS = 3600
/** Cache of the public copy: short on purpose, so a retired photo stops being served soon (leona-lia). */
const PUBLIC_MAX_AGE = 3600

/** Signed URLs for objects of the private bucket (the admin can read them): path -> url. */
export async function signOriginals(client: Client, paths: string[]): Promise<Map<string, string>> {
  const urls = new Map<string, string>()
  if (!paths.length) return urls
  const { data } = await client.storage.from(REVIEW_PHOTO_UPLOADS_BUCKET).createSignedUrls(paths, SIGNED_URL_SECONDS)
  for (const entry of data ?? []) if (entry.path && entry.signedUrl) urls.set(entry.path, entry.signedUrl)
  return urls
}

export interface ApprovedPhoto {
  publicPath: string
  width: number
  height: number
}

/**
 * Approve = download the original, re-encode it in a canvas (always: the reader's bytes never go to
 * the public bucket, and EXIF/GPS are dropped), upload the copy as `<uuid>.<webp|jpg>`, record it
 * with `moderate_review_photo` and delete the private original. If recording fails the copy is removed.
 */
export async function approvePhoto(client: Client, config: StorageConfig, photo: { id: string; storagePath: string }): Promise<ApprovedPhoto> {
  const { data: original, error } = await client.storage.from(REVIEW_PHOTO_UPLOADS_BUCKET).download(photo.storagePath)
  if (error || !original) throw new ServiceError('original_missing', 'original_missing')
  const copy = await processReviewPhoto(original)
  const publicPath = `${crypto.randomUUID().toLowerCase()}.${copy.ext}`
  await uploadObject(client, config, { bucket: REVIEW_PHOTO_PUBLIC_BUCKET, path: publicPath, blob: copy.blob, mime: copy.mime, maxAge: PUBLIC_MAX_AGE })
  const { error: rpcError } = await guideSchema(client).rpc('moderate_review_photo', {
    p_id: photo.id,
    p_status: 'approved',
    p_public_path: publicPath,
    p_width: copy.width,
    p_height: copy.height,
  })
  if (rpcError) {
    await removeObjects(client, REVIEW_PHOTO_PUBLIC_BUCKET, [publicPath]).catch(() => undefined)
    throw new ServiceError(rpcError.message, rpcError.code)
  }
  await removeObjects(client, REVIEW_PHOTO_UPLOADS_BUCKET, [photo.storagePath]).catch(() => undefined)
  return { publicPath, width: copy.width, height: copy.height }
}

/** Reject (or retire an approved one): the reason is mandatory; the public copy, if any, is deleted. */
export async function rejectPhoto(client: Client, id: string, reason: string): Promise<void> {
  const result = unwrap(await guideSchema(client).rpc('moderate_review_photo', { p_id: id, p_status: 'rejected', p_reject_reason: reason })) as unknown as Moderated
  if (result.previous_public_path) await removeObjects(client, REVIEW_PHOTO_PUBLIC_BUCKET, [result.previous_public_path]).catch(() => undefined)
}
