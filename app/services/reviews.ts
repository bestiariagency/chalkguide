import type { Locale, UserReview } from '~/types/domain'
import { listPublicReviewPhotos } from './review-photos'
import { type GuideClient, ServiceError, pick, unwrap, unwrapMaybe } from './client'

/**
 * Visible user reviews of an item, from guide.user_reviews_public (never `user_reviews`
 * directly: user_id is not readable). Texts are rendered interpolated, never with v-html.
 */
export async function listUserReviews(
  db: GuideClient,
  itemId: string,
  { limit = 20 }: { limit?: number } = {},
): Promise<UserReview[]> {
  const rows = unwrap(
    await db
      .from('user_reviews_public')
      .select('id, author_name, overall_score, body, locale, created_at, edited_at')
      .eq('item_id', itemId)
      .eq('status', 'visible')
      .order('created_at', { ascending: false })
      .limit(limit),
  )
  const photos = await listPublicReviewPhotos(db, rows.flatMap((row) => (row.id ? [row.id] : [])))
  return rows.map((row) => ({
    id: row.id ?? '',
    authorName: row.author_name ?? '',
    overall: row.overall_score ?? 0,
    body: row.body,
    locale: (row.locale ?? 'es') as Locale,
    createdAt: row.created_at ?? '',
    editedAt: row.edited_at,
    photos: photos.get(row.id ?? '') ?? [],
  }))
}

export interface ReviewCriterion {
  id: string
  name: string
  /** Help text shown while scoring (D29); null = nothing to show. */
  help: string | null
}

/** The signed-in user's own review of an item, with their score per criterion id. */
export interface MyReview {
  id: string
  /** Global score 1–5 (required). */
  overall: number
  body: string | null
  status: 'visible' | 'pending' | 'hidden'
  createdAt: string
  editedAt: string | null
  scores: Record<string, number>
}

/** Active criteria of a category, in display order (what the form must score). */
export async function listCriteria(
  db: GuideClient,
  locale: Locale,
  category: string,
): Promise<ReviewCriterion[]> {
  const rows = unwrap(
    await db
      .from('criteria')
      .select('id, name_es, name_en, description_es, description_en')
      .eq('category', category)
      .eq('is_active', true)
      .order('sort_order'),
  )
  return rows.map((row) => ({
    id: row.id,
    name: pick(locale, row.name_es, row.name_en) ?? row.name_es,
    help: pick(locale, row.description_es, row.description_en)?.trim() || null,
  }))
}

/** Own review (RLS lets the owner read it whatever its status). Null if there is none. */
export async function getMyReview(
  db: GuideClient,
  itemId: string,
  userId: string,
): Promise<MyReview | null> {
  const row = unwrapMaybe(
    await db
      .from('user_reviews')
      .select('id, overall_score, body, status, created_at, edited_at, user_review_scores(criterion_id, score)')
      .eq('item_id', itemId)
      .eq('user_id', userId)
      .maybeSingle(),
  )
  if (!row) return null
  return {
    id: row.id,
    overall: row.overall_score,
    body: row.body,
    status: row.status,
    createdAt: row.created_at,
    editedAt: row.edited_at,
    scores: Object.fromEntries(
      (row.user_review_scores ?? []).map((s) => [s.criterion_id, s.score]),
    ),
  }
}

export interface SubmitReviewInput {
  itemId: string
  /** Global score 1–5 (required). */
  overall: number
  /** { [criterionId]: 1..5 } with the criteria the user chose to score (all optional). */
  scores: Record<string, number>
  body: string
  locale: Locale
}

/** The RPC rejects with `rate_limited` (HTTP 429, PT429) after 5 new reviews in 24 h. */
export const isRateLimited = (error: unknown) =>
  error instanceof ServiceError && (error.message === 'rate_limited' || error.code === 'PT429')

/** Creates or edits the own review through the RPC (the only write path). */
export async function submitReview(db: GuideClient, input: SubmitReviewInput): Promise<string> {
  return unwrap(
    await db.rpc('submit_user_review', {
      p_item_id: input.itemId,
      p_overall: input.overall,
      p_scores: input.scores,
      p_body: input.body.trim() || undefined,
      p_locale: input.locale,
    }),
  )
}

/** Deletes the own review (RLS: owner or admin; scores go with it via ON DELETE CASCADE). */
export async function deleteMyReview(db: GuideClient, reviewId: string): Promise<void> {
  const { error } = await db.from('user_reviews').delete().eq('id', reviewId)
  if (error) throw new ServiceError(error.message, error.code)
}
