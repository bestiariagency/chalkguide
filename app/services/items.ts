import type {
  AuthorScore,
  ItemBase,
  Locale,
  UserRatings,
  VisitType,
} from '~/types/domain'
import type { Json } from '~/types/database.types'
import { type GuideClient, one, pick, unwrap, unwrapMaybe } from './client'
import { MEDIA_COLUMNS, toMediaRef } from './media'

/**
 * Items (gyms, resolers, shoes). One query for items + detail + author review (embeds),
 * then one batched query per derived view (`.in('item_id', ids)`): no N+1.
 * Derived values (indices, averages) always come from the views, never from the client.
 */
type ItemCategory = 'gym' | 'resoler' | 'shoe'

const BASE_COLUMNS = `id, slug, name, summary_es, summary_en, is_featured, verified_at, has_en,
  seo_title_es, seo_title_en, seo_description_es, seo_description_en, noindex, updated_at,
  cover:media!items_cover_media_id_fkey(${MEDIA_COLUMNS}),
  author_review:author_reviews(visit_type, has_en, headline_es, headline_en, updated_at)`

const DETAIL_COLUMNS: Record<ItemCategory, string> = {
  gym: `detail:gyms!inner(district, metro_stations, has_lead, has_boulder, has_kids_area,
    belay_test_required, opening_hours, price_monthly_eur, max_height_m, prices_verified_at, price_day_eur,
    grading_difficulty, setting_dynamism)`,
  resoler: `detail:resolers!inner(district, price_per_pair_eur, price_rand_eur, turnaround_days_min,
    turnaround_days_max, accepts_mail, mail_notes_es, mail_notes_en, rubber_brands, services,
    prices_verified_at)`,
  shoe: `detail:shoes!inner(brand, model, fit, closure, stiffness, price_min_eur, price_max_eur,
    price_checked_at, levels, is_affiliate, affiliate_url, affiliate_program, owned_by_author,
    profile, asymmetry, rubber, rubber_thickness_mm, recommended_use, author_size_eu,
    author_street_size_eu, author_size_note_es, author_size_note_en, updated_at)`,
}

type ReviewEmbed = {
  visit_type: VisitType
  has_en: boolean | null
  headline_es: string | null
  headline_en: string | null
  updated_at: string | null
}

export type ItemRow = {
  id: string
  slug: string
  name: string
  summary_es: string | null
  summary_en: string | null
  is_featured: boolean
  verified_at: string | null
  has_en: boolean | null
  seo_title_es: string | null
  seo_title_en: string | null
  seo_description_es: string | null
  seo_description_en: string | null
  noindex: boolean
  updated_at: string
  cover: unknown
  author_review: ReviewEmbed | ReviewEmbed[] | null
  detail: unknown
}

export interface ListItemsOptions {
  /** Restrict to these slugs (detail page) or leave empty for the whole published list. */
  slug?: string
  /** Shoes: only models recommended for this level. */
  level?: 'beginner' | 'intermediate' | 'advanced'
}

export async function fetchItems(
  db: GuideClient,
  category: ItemCategory,
  locale: Locale,
  { slug, level }: ListItemsOptions = {},
): Promise<ItemRow[]> {
  let query = db
    .from('items')
    .select(`${BASE_COLUMNS}, ${DETAIL_COLUMNS[category]}`)
    .eq('category', category)
    .eq('published', true)
  if (locale === 'en') query = query.eq('has_en', true)
  if (slug) query = query.eq('slug', slug)
  if (level) query = query.contains('detail.levels', [level])
  const rows = unwrap(await query.order('name')) as unknown as ItemRow[]
  // D3 (guide.item_is_en_ready): in English the author review must also be translated.
  return locale === 'en'
    ? rows.filter((row) => {
        const review = one(row.author_review)
        return !review || review.has_en === true
      })
    : rows
}

/**
 * Author scores per item from the view (one row per criterion): overall average and the
 * criteria, in one batched query for the whole list.
 */
export async function fetchAuthorScores(db: GuideClient, locale: Locale, ids: string[]) {
  const overall = new Map<string, number>()
  const criteria = new Map<string, AuthorScore[]>()
  if (!ids.length) return { overall, criteria }
  const rows = unwrap(
    await db
      .from('item_author_scores')
      .select('item_id, criterion_key, name_es, name_en, score, avg_overall, sort_order')
      .in('item_id', ids)
      .order('sort_order'),
  )
  for (const row of rows) {
    if (!row.item_id) continue
    if (row.avg_overall !== null) overall.set(row.item_id, Number(row.avg_overall))
    if (row.criterion_key && row.score !== null) {
      const list = criteria.get(row.item_id) ?? []
      list.push({
        criterionKey: row.criterion_key,
        name: pick(locale, row.name_es, row.name_en) ?? row.name_es ?? '',
        score: Number(row.score),
      })
      criteria.set(row.item_id, list)
    }
  }
  return { overall, criteria }
}

export function toBase(row: ItemRow, locale: Locale, scores: Map<string, number>): ItemBase {
  const review = one(row.author_review)
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    summary: pick(locale, row.summary_es, row.summary_en),
    cover: toMediaRef(one(row.cover as Parameters<typeof toMediaRef>[0]), locale),
    isFeatured: row.is_featured,
    verifiedAt: row.verified_at,
    hasEn: row.has_en === true,
    seoTitle: pick(locale, row.seo_title_es, row.seo_title_en),
    seoDescription: pick(locale, row.seo_description_es, row.seo_description_en),
    noindex: row.noindex,
    updatedAt: row.updated_at,
    visitType: review?.visit_type ?? null,
    authorScore: scores.get(row.id) ?? null,
  }
}

/** avg_by_criterion is `{ criterion_key: avg }` (null below the minimum, like avg_overall). */
function toCriterionAverages(value: Json | null | undefined): Record<string, number> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}
  return Object.fromEntries(
    Object.entries(value).filter(([, v]) => typeof v === 'number'),
  ) as Record<string, number>
}

export const num = (value: number | string | null | undefined) =>
  value === null || value === undefined ? null : Number(value)

/** Author scores per criterion, already named in the right locale. */
export async function getAuthorScores(
  db: GuideClient,
  locale: Locale,
  itemId: string,
): Promise<AuthorScore[]> {
  const rows = unwrap(
    await db
      .from('item_author_scores')
      .select('criterion_key, name_es, name_en, score, sort_order')
      .eq('item_id', itemId)
      .order('sort_order'),
  )
  return rows
    .filter((row) => row.criterion_key && row.score !== null)
    .map((row) => ({
      criterionKey: row.criterion_key as string,
      name: pick(locale, row.name_es, row.name_en) ?? row.name_es ?? '',
      score: Number(row.score),
    }))
}

/** Readers' ratings: the view already hides averages below the minimum (≥ 3 reviews). */
export async function getUserRatings(db: GuideClient, itemId: string): Promise<UserRatings> {
  const row = unwrapMaybe(
    await db
      .from('item_user_ratings')
      .select('review_count, avg_overall, avg_by_criterion')
      .eq('item_id', itemId)
      .maybeSingle(),
  )
  return {
    reviewCount: row?.review_count ?? 0,
    avgOverall: num(row?.avg_overall),
    byCriterion: toCriterionAverages(row?.avg_by_criterion),
  }
}
