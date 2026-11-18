/**
 * Reader photos in reviews (F6.11b, D31): limits, paths and error classification. Pure helpers;
 * Supabase calls live in `services/review-photos.ts`.
 */
export const REVIEW_PHOTO_MAX = 3
/** Size cap of the file the reader picks (it is re-encoded in the browser before uploading). */
export const REVIEW_PHOTO_INPUT_MAX_MB = 20
export const REVIEW_PHOTO_UPLOADS_BUCKET = 'review-photo-uploads'
export const REVIEW_PHOTO_PUBLIC_BUCKET = 'review-photos'
/**
 * Version of the rights text shown in the form (`reviews.photos.rights`). It must equal
 * `guide.review_photo_rights_version()`; when the text changes, both change together.
 */
export const REVIEW_PHOTO_RIGHTS_TEXT_VERSION = '2026-10-23'

export const REJECT_REASONS = ['not_own', 'identifiable_people', 'off_topic', 'low_quality', 'inappropriate'] as const
export type RejectReason = (typeof REJECT_REASONS)[number]
export const isRejectReason = (value: unknown): value is RejectReason => REJECT_REASONS.includes(value as RejectReason)

const HEIC = /\.(heic|heif)$/i
export const looksLikeHeic = (file: Pick<File, 'type' | 'name'>) => /heic|heif/i.test(file.type) || HEIC.test(file.name)

export type FileProblem = 'not_image' | 'too_big'

/** First check on a picked file; the real test is whether the browser can decode it. */
export function checkPhotoFile(file: Pick<File, 'type' | 'name' | 'size'>): FileProblem | null {
  if (!file.type.startsWith('image/') && !looksLikeHeic(file)) return 'not_image'
  if (file.size > REVIEW_PHOTO_INPUT_MAX_MB * 1024 * 1024) return 'too_big'
  return null
}

/** `<review_id>/<photo_id>.<ext>` in the private bucket (no user id: the admin sees the path). */
export const reviewPhotoUploadPath = (reviewId: string, photoId: string, ext: 'webp' | 'jpg') => `${reviewId}/${photoId}.${ext}`

export const newPhotoId = () => crypto.randomUUID().toLowerCase()

/** Public URL of an approved photo (`public_path` in the `review-photos` bucket; no listing). */
export const reviewPhotoPublicUrl = (supabaseUrl: string, path: string) => `${supabaseUrl.replace(/\/$/, '')}/storage/v1/object/public/${REVIEW_PHOTO_PUBLIC_BUCKET}/${path}`

export type PhotoErrorKind = 'rights_outdated' | 'rights_not_accepted' | 'photo_limit' | 'rate_limited' | 'forbidden' | 'generic'

/** Maps the backend contract errors (PT412, PT409, PT429, 42501, 22023, Storage 403) to a message key. */
export function photoErrorKind(error: unknown): PhotoErrorKind {
  const { code, message } = (error ?? {}) as { code?: string; message?: string }
  if (code === 'rights_outdated') return 'rights_outdated'
  if (code === 'PT412' || message === 'rights_not_accepted') return 'rights_not_accepted'
  if (code === 'PT409' || message === 'photo_limit') return 'photo_limit'
  if (code === 'PT429' || message === 'rate_limited') return 'rate_limited'
  if (code === '403' || code === '42501' || code === '22023') return 'forbidden'
  return 'generic'
}
