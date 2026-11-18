import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ALL_OPTION, type AdminReviewPhoto, recentSince, REVIEWS_PAGE_SIZE, type AdminReview, type ReviewFilters, type ReviewItemOption, type ReviewItemStats, type ReviewsSummary, type ReviewStatus } from '~/utils/admin-reviews'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>
type Row = Database['guide']['Functions']['admin_list_user_reviews']['Returns'][number]
type RawScore = { criterion_id: string; name_es: string; score: number; is_active: boolean }

/**
 * Everything goes through the admin RPCs of F6.11: the panel never reads `user_id` or the email;
 * `author_name` is the public "Nombre I." and `author_review_count` is computed in the database.
 */
type RawPhoto = { id: string; sort_order: number; status: AdminReviewPhoto['status']; storage_path: string; public_path: string | null; width: number; height: number; mime_type: string; size_bytes: number; reject_reason: string | null; created_at: string }

function toPhoto(p: RawPhoto): AdminReviewPhoto {
  return { id: p.id, sortOrder: p.sort_order, status: p.status, storagePath: p.storage_path, publicPath: p.public_path, width: p.width, height: p.height, mime: p.mime_type, size: p.size_bytes, rejectReason: p.reject_reason, createdAt: p.created_at }
}

function toReview(row: Row): AdminReview {
  const scores = (row.scores as unknown as RawScore[] | null) ?? []
  return {
    id: row.id,
    itemId: row.item_id,
    itemName: row.item_name,
    category: row.category,
    author: row.author_name,
    overall: row.overall_score,
    body: row.body,
    locale: row.locale,
    status: row.status,
    createdAt: row.created_at,
    editedAt: row.edited_at,
    lastActivityAt: row.last_activity_at,
    needsReview: row.needs_review,
    authorCount: row.author_review_count,
    scores: scores.map((s) => ({ criterionId: s.criterion_id, name: s.name_es, score: s.score, active: s.is_active })),
    itemAvg: row.item_avg_overall,
    itemVisibleCount: row.item_visible_count,
    avgIfToggled: row.item_avg_if_toggled,
    countIfToggled: row.item_count_if_toggled,
    photos: ((row.photos as unknown as RawPhoto[] | null) ?? []).map(toPhoto),
    photoCount: row.photo_count,
    pendingPhotoCount: row.pending_photo_count,
  }
}

export interface ReviewsPage {
  rows: AdminReview[]
  total: number
}

/** One page of the inbox, newest activity first. */
export async function fetchReviews(client: Client, { view, search, category, item }: ReviewFilters, offset: number): Promise<ReviewsPage> {
  const rows = unwrap(
    await guideSchema(client).rpc('admin_list_user_reviews', {
      p_category: category !== ALL_OPTION ? category : undefined,
      p_item_id: item !== ALL_OPTION ? item : undefined,
      p_query: search.trim() || undefined,
      p_from: view === 'recent' ? recentSince() : undefined,
      p_max_overall: view === 'low' ? 2 : undefined,
      p_status: view === 'hidden' ? 'hidden' : undefined,
      p_has_pending_photos: view === 'photos' ? true : undefined,
      p_limit: REVIEWS_PAGE_SIZE,
      p_offset: offset,
    }),
  )
  return { rows: rows.map(toReview), total: rows[0]?.total_count ?? 0 }
}

/** Counts of the views, last visit and menu badge in a single call. */
export async function fetchReviewsSummary(client: Client): Promise<ReviewsSummary> {
  const s = unwrap(await guideSchema(client).rpc('admin_reviews_summary')) as Record<string, number | boolean | string | null>
  const num = (key: string) => Number(s[key] ?? 0)
  return {
    total: num('total'),
    recent7d: num('recent_7d'),
    lowScore: num('low_score'),
    hidden: num('hidden'),
    seenAt: (s.seen_at as string | null) ?? null,
    badge: num('badge'),
    minForAverage: num('min_for_average') || 3,
    photosPending: num('photos_pending'),
    reviewsWithPendingPhotos: num('reviews_with_pending_photos'),
  }
}

/** Items that have reviews, for the "Ficha" filter. */
export async function fetchReviewItemOptions(client: Client): Promise<ReviewItemOption[]> {
  const rows = unwrap(await guideSchema(client).rpc('admin_review_items'))
  return rows.map((r) => ({ id: r.item_id, name: r.name, category: r.category, reviewCount: r.review_count }))
}

function toStats(raw: unknown): ReviewItemStats {
  const s = raw as Record<string, number | null>
  return { itemVisibleCount: Number(s.item_visible_count ?? 0), itemAvgOverall: s.item_avg_overall ?? null }
}

/**
 * Hide or show. `visible` over an already visible review means "revisada" (stored, no log entry).
 * Returns the item's averages after the change.
 */
export async function moderateReview(client: Client, id: string, status: Extract<ReviewStatus, 'visible' | 'hidden'>): Promise<ReviewItemStats> {
  return toStats(unwrap(await guideSchema(client).rpc('moderate_user_review', { p_id: id, p_status: status })))
}

/** Erasure (RGPD) or illegal content only; logged with the reason, without personal data. */
export async function deleteReview(client: Client, id: string, reason: string): Promise<ReviewItemStats> {
  return toStats(unwrap(await guideSchema(client).rpc('admin_delete_user_review', { p_id: id, p_reason: reason })))
}

/** D24: stores "now" as the last visit and returns the PREVIOUS one (null = never). */
export async function markReviewsSeen(client: Client): Promise<string | null> {
  return unwrap(await guideSchema(client).rpc('mark_reviews_seen')) ?? null
}
