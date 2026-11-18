import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { ReviewPhoto } from '~/types/domain'
import { REVIEW_PHOTO_UPLOADS_BUCKET, reviewPhotoPublicUrl, type RejectReason, isRejectReason } from '~/utils/review-photos'
import { type GuideClient, guideSchema, ServiceError, unwrap } from './client'
import { removeObjects, uploadObject, type StorageConfig } from './storage-upload'

type Client = SupabaseClient<Database>

/** Approved photos of several reviews, from `user_review_photos_public` (no user data), by review id. */
export async function listPublicReviewPhotos(db: GuideClient, reviewIds: string[]): Promise<Map<string, ReviewPhoto[]>> {
  const byReview = new Map<string, ReviewPhoto[]>()
  if (!reviewIds.length) return byReview
  const rows = unwrap(await db.from('user_review_photos_public').select('id, review_id, sort_order, width, height, public_path').in('review_id', reviewIds).order('sort_order'))
  for (const row of rows) {
    if (!row.id || !row.review_id || !row.public_path) continue
    const list = byReview.get(row.review_id) ?? []
    list.push({ id: row.id, path: row.public_path, width: row.width ?? 0, height: row.height ?? 0 })
    byReview.set(row.review_id, list)
  }
  return byReview
}

/** The reader's own photo, any status. `src` is a public URL (approved) or a signed one (pending); null for rejected. */
export interface MyReviewPhoto {
  id: string
  status: 'pending' | 'approved' | 'rejected'
  rejectReason: RejectReason | null
  storagePath: string
  src: string | null
  width: number
  height: number
}

const SIGNED_URL_SECONDS = 3600

/** Own photos in slot order. Pending ones are in a private bucket: they get a signed URL. */
export async function listMyReviewPhotos(client: Client, supabaseUrl: string, reviewId: string): Promise<MyReviewPhoto[]> {
  const rows = unwrap(
    await guideSchema(client).from('user_review_photos').select('id, status, reject_reason, storage_path, public_path, width, height').eq('review_id', reviewId).order('sort_order'),
  )
  const pending = rows.filter((r) => r.status === 'pending').map((r) => r.storage_path)
  const signed = new Map<string, string>()
  if (pending.length) {
    const { data } = await client.storage.from(REVIEW_PHOTO_UPLOADS_BUCKET).createSignedUrls(pending, SIGNED_URL_SECONDS)
    for (const entry of data ?? []) if (entry.path && entry.signedUrl) signed.set(entry.path, entry.signedUrl)
  }
  return rows.map((r) => ({
    id: r.id,
    status: r.status,
    rejectReason: isRejectReason(r.reject_reason) ? r.reject_reason : null,
    storagePath: r.storage_path,
    src: r.status === 'approved' && r.public_path ? reviewPhotoPublicUrl(supabaseUrl, r.public_path) : (signed.get(r.storage_path) ?? null),
    width: r.width,
    height: r.height,
  }))
}

/** Current version of the rights text; the form must send it back with the accepted checkbox. */
export async function getRightsVersion(client: Client): Promise<string> {
  return unwrap(await guideSchema(client).rpc('review_photo_rights_version'))
}

export interface UploadReviewPhoto {
  reviewId: string
  photoId: string
  path: string
  blob: Blob
  mime: string
  width: number
  height: number
  rightsVersion: string
  onProgress: (fraction: number) => void
}

/**
 * Upload to the private bucket, then register the row. If registering fails the object is removed
 * (best effort; the daily cleanup catches what is left). Rejects with the original error.
 */
export async function uploadReviewPhoto(client: Client, config: StorageConfig, input: UploadReviewPhoto): Promise<void> {
  await uploadObject(client, config, { bucket: REVIEW_PHOTO_UPLOADS_BUCKET, path: input.path, blob: input.blob, mime: input.mime, maxAge: 3600, onProgress: input.onProgress })
  const { error } = await guideSchema(client).rpc('register_review_photo', {
    p_review_id: input.reviewId,
    p_photo_id: input.photoId,
    p_storage_path: input.path,
    p_width: input.width,
    p_height: input.height,
    p_rights_accepted: true,
    p_rights_version: input.rightsVersion,
  })
  if (error) {
    await removeObjects(client, REVIEW_PHOTO_UPLOADS_BUCKET, [input.path]).catch(() => undefined)
    throw new ServiceError(error.message, error.code)
  }
}

/** Deletes the row, then its private object (the public copy of an approved one is the panel's to clean). */
export async function deleteReviewPhoto(client: Client, id: string): Promise<void> {
  const result = unwrap(await guideSchema(client).rpc('delete_review_photo', { p_id: id })) as { storage_path?: string | null }
  if (result.storage_path) await removeObjects(client, REVIEW_PHOTO_UPLOADS_BUCKET, [result.storage_path]).catch(() => undefined)
}
