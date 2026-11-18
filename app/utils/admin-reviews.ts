import type { Database } from '~/types/database.types'

export type ReviewStatus = Database['guide']['Enums']['review_status']

/** Views of the inbox (docs/design/admin/opiniones.html): recent is the default (post-moderation, D9). */
export type ReviewView = 'recent' | 'photos' | 'low' | 'hidden' | 'all'

export const REVIEW_VIEWS: readonly { value: ReviewView; label: string }[] = [
  { value: 'recent', label: 'Recientes' },
  { value: 'photos', label: 'Fotos por revisar' },
  { value: 'low', label: 'Nota ≤ 2' },
  { value: 'hidden', label: 'Ocultas' },
  { value: 'all', label: 'Todas' },
]

export const REVIEW_RECENT_DAYS = 7
export const REVIEWS_PAGE_SIZE = 40
export const ALL_OPTION = 'all'

export const reviewViewOf = (value: unknown, fallback: ReviewView = 'recent'): ReviewView => REVIEW_VIEWS.find((v) => v.value === value)?.value ?? fallback

export const REVIEW_CATEGORIES = [
  { value: 'gym', label: 'Rocódromos', singular: 'Rocódromo', route: 'rocodromos' },
  { value: 'resoler', label: 'Resoladores', singular: 'Resolador', route: 'resoladores' },
  { value: 'shoe', label: 'Pies de gato', singular: 'Pie de gato', route: 'pies-de-gato' },
] as const

export const categoryOfReview = (category: string) => REVIEW_CATEGORIES.find((c) => c.value === category)

export type PhotoStatus = Database['guide']['Enums']['review_photo_status']

/** Reasons accepted by `moderate_review_photo` (the reader sees them, phrased by loro-lola). */
export const PHOTO_REJECT_REASONS = [
  { value: 'off_topic', label: 'Sin relación con la ficha o publicidad' },
  { value: 'identifiable_people', label: 'Se ve gente reconocible' },
  { value: 'low_quality', label: 'Borrosa o de mala calidad' },
  { value: 'not_own', label: 'No parece una foto del lector' },
  { value: 'inappropriate', label: 'Contenido inapropiado' },
] as const

export const photoReasonLabel = (reason: string | null) => PHOTO_REJECT_REASONS.find((r) => r.value === reason)?.label ?? 'Sin motivo'

/** One reader photo as the inbox lists it (`admin_list_user_reviews.photos`). */
export interface AdminReviewPhoto {
  id: string
  sortOrder: number
  status: PhotoStatus
  storagePath: string
  publicPath: string | null
  width: number
  height: number
  mime: string
  size: number
  rejectReason: string | null
  createdAt: string
}

export interface AdminReview {
  id: string
  itemId: string
  itemName: string
  category: string
  /** Public name ("Nombre I."): the panel never reads the email or the user id. */
  author: string
  overall: number
  body: string | null
  locale: 'es' | 'en'
  status: ReviewStatus
  createdAt: string
  editedAt: string | null
  /** Last edit or creation: "Nueva" and the date range work on it. */
  lastActivityAt: string
  /** The author's text changed after the last moderation (or was never moderated). */
  needsReview: boolean
  /** Reviews written by the same author (the user id itself is never read). */
  authorCount: number
  /** Scores per criterion; the ones of inactive criteria stay in the data but are shown dimmed (D29). */
  scores: { criterionId: string; name: string; score: number; active: boolean }[]
  /** Item average over visible reviews now / if this review's visibility were toggled. */
  itemAvg: number | null
  itemVisibleCount: number
  avgIfToggled: number | null
  countIfToggled: number
  photos: AdminReviewPhoto[]
  photoCount: number
  pendingPhotoCount: number
}

/** `guide.admin_reviews_summary()`: counts of the views, last visit and the menu badge. */
export interface ReviewsSummary {
  total: number
  recent7d: number
  lowScore: number
  hidden: number
  seenAt: string | null
  badge: number
  minForAverage: number
  /** Photos waiting for a decision / reviews that have at least one. */
  photosPending: number
  reviewsWithPendingPhotos: number
}

/** Reasons accepted by `admin_delete_user_review`; anything else is solved by hiding. */
export const DELETE_REASONS = [
  { value: 'erasure_request', label: 'Solicitud de supresión (RGPD)' },
  { value: 'illegal_content', label: 'Contenido ilegal' },
] as const

/** Item stats returned by the moderation and delete RPCs. */
export interface ReviewItemStats {
  itemVisibleCount: number
  itemAvgOverall: number | null
}

export interface ReviewFilters {
  view: ReviewView
  search: string
  category: string
  item: string
}

export interface ReviewItemOption {
  id: string
  name: string
  category: string
  reviewCount: number
}

/** Link to the item editor in the panel. */
export function reviewItemHref(review: Pick<AdminReview, 'itemId' | 'category'>): string | undefined {
  const route = categoryOfReview(review.category)?.route
  return route ? `/administrador/${route}/${review.itemId}` : undefined
}

/** True for activity after the last visit (or in the last 7 days when there was none). */
export function isNewReview(activityAt: string, seenAt: string | null, now = Date.now()): boolean {
  const since = seenAt ? new Date(seenAt).getTime() : now - REVIEW_RECENT_DAYS * 86_400_000
  return new Date(activityAt).getTime() > since
}

/** Cut-off ISO of the "Recientes" view. */
export const recentSince = (now = Date.now()) => new Date(now - REVIEW_RECENT_DAYS * 86_400_000).toISOString()

export function reviewError(e: unknown): string {
  const { code } = (e ?? {}) as { code?: string }
  if (code === '22023') return 'Elige un motivo válido para borrar la opinión.'
  if (code === 'P0002') return 'Esa opinión o foto ya no existe. Recarga la lista.'
  if (code === '42501') return 'Tu sesión no tiene permiso para moderar opiniones.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo.'
}

/**
 * Item figures of a row after the item's visible average changed (stats from the moderation RPC):
 * the "if toggled" values follow from them, so the box stays right without reloading the list.
 */
export function withItemStats(row: AdminReview, avg: number | null, count: number): AdminReview {
  const sum = (avg ?? 0) * count
  const toggledCount = row.status === 'visible' ? count - 1 : count + 1
  const toggledSum = row.status === 'visible' ? sum - row.overall : sum + row.overall
  return { ...row, itemAvg: avg, itemVisibleCount: count, countIfToggled: toggledCount, avgIfToggled: toggledCount > 0 ? Math.round((toggledSum / toggledCount) * 100) / 100 : null }
}

/** Oldest pending photo of a review: the "Fotos por revisar" queue goes oldest first. */
export const oldestPendingPhoto = (review: Pick<AdminReview, 'photos'>) =>
  review.photos.filter((p) => p.status === 'pending').reduce<string>((min, p) => (!min || p.createdAt < min ? p.createdAt : min), '')

/** Same review after one of its photos changed. */
export function withPhoto(review: AdminReview, photo: AdminReviewPhoto): AdminReview {
  const photos = review.photos.map((p) => (p.id === photo.id ? photo : p))
  return { ...review, photos, pendingPhotoCount: photos.filter((p) => p.status === 'pending').length }
}

export function photoError(e: unknown): string {
  const { code, message } = (e ?? {}) as { code?: string; message?: string }
  if (code === '22023') return 'La foto ya tiene ese estado. Recarga la lista.'
  if (code === 'P0002') return 'Esa foto ya no existe. Recarga la lista.'
  if (code === '42501') return 'Tu sesión no tiene permiso para moderar fotos.'
  if (message === 'original_missing') return 'El original de esa foto ya no existe, así que no se puede volver a publicar.'
  return 'No se ha podido completar la acción con la foto. Inténtalo de nuevo.'
}
