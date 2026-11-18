import type { Locale, ShoeSummary } from '~/types/domain'
import { type GuideClient, one, pick } from './client'
import { type ListItemsOptions, fetchAuthorScores, fetchItems, num, toBase } from './items'

type ShoeDetail = {
  brand: string
  model: string
  fit: ShoeSummary['fit']
  profile: ShoeSummary['profile']
  asymmetry: ShoeSummary['asymmetry']
  closure: ShoeSummary['closure']
  rubber: string | null
  rubber_thickness_mm: number | null
  stiffness: number | null
  recommended_use: string[]
  price_min_eur: number | null
  price_max_eur: number | null
  price_checked_at: string | null
  levels: string[]
  is_affiliate: boolean | null
  affiliate_url: string | null
  affiliate_program: string | null
  owned_by_author: boolean
  author_size_eu: number | string | null
  author_street_size_eu: number | string | null
  author_size_note_es: string | null
  author_size_note_en: string | null
  updated_at: string | null
}

/** Most recent of several ISO timestamps (same format, so string order is time order). */
const latestDate = (...dates: (string | null | undefined)[]) =>
  dates.filter((d): d is string => !!d).sort().at(-1) ?? ''

/** Climbing shoes (comparator): one items query + one batched author-scores query. */
export async function listShoes(
  db: GuideClient,
  locale: Locale,
  options: ListItemsOptions = {},
): Promise<ShoeSummary[]> {
  const rows = await fetchItems(db, 'shoe', locale, options)
  const { overall, criteria } = await fetchAuthorScores(
    db,
    locale,
    rows.map((row) => row.id),
  )
  return rows.map((row) => {
    const detail = one(row.detail as ShoeDetail | null)
    const review = one(row.author_review)
    const owned = detail?.owned_by_author ?? false
    return {
      ...toBase(row, locale, overall),
      brand: detail?.brand ?? '',
      model: detail?.model ?? row.name,
      fit: detail?.fit ?? null,
      profile: detail?.profile ?? null,
      asymmetry: detail?.asymmetry ?? null,
      closure: detail?.closure ?? null,
      rubber: detail?.rubber ?? null,
      rubberThicknessMm: num(detail?.rubber_thickness_mm),
      stiffness: detail?.stiffness ?? null,
      recommendedUse: detail?.recommended_use ?? [],
      priceMin: num(detail?.price_min_eur),
      priceMax: num(detail?.price_max_eur),
      priceCheckedAt: detail?.price_checked_at ?? null,
      levels: detail?.levels ?? [],
      isAffiliate: detail?.is_affiliate === true,
      affiliateUrl: detail?.affiliate_url ?? null,
      affiliateProgram: detail?.affiliate_program ?? null,
      ownedByAuthor: owned,
      authorSizeEu: owned ? num(detail?.author_size_eu) : null,
      authorStreetSizeEu: owned ? num(detail?.author_street_size_eu) : null,
      authorSizeNote: owned
        ? pick(locale, detail?.author_size_note_es ?? null, detail?.author_size_note_en ?? null)
        : null,
      authorHeadline: owned && review ? pick(locale, review.headline_es, review.headline_en) : null,
      editedAt: latestDate(row.updated_at, detail?.updated_at, review?.updated_at),
      criteria: owned ? (criteria.get(row.id) ?? []) : [],
    }
  })
}
