import type { Locale, ResolerSummary } from '~/types/domain'
import type { ResolerDetail } from '~/types/resoler-detail'
import { type GuideClient, one, pick, unwrapMaybe } from './client'
import { type ListItemsOptions, fetchAuthorScores, fetchItems, num, toBase } from './items'
import { getItemExtras } from './item-detail'
import { toResolerServices } from '~/utils/resolers'

type ResolerRow = {
  district: string | null
  price_per_pair_eur: number | null
  price_rand_eur: number | null
  turnaround_days_min: number | null
  turnaround_days_max: number | null
  accepts_mail: boolean | null
  mail_notes_es: string | null
  mail_notes_en: string | null
  rubber_brands: string[]
  services: string[]
  prices_verified_at: string | null
}

export async function listResolers(
  db: GuideClient,
  locale: Locale,
  options: ListItemsOptions = {},
): Promise<ResolerSummary[]> {
  const rows = await fetchItems(db, 'resoler', locale, options)
  const { overall } = await fetchAuthorScores(
    db,
    locale,
    rows.map((row) => row.id),
  )
  return rows.map((row) => {
    const detail = one(row.detail as ResolerRow | null)
    return {
      ...toBase(row, locale, overall),
      district: detail?.district ?? null,
      pricePerPair: num(detail?.price_per_pair_eur),
      priceRand: num(detail?.price_rand_eur),
      turnaroundMin: detail?.turnaround_days_min ?? null,
      turnaroundMax: detail?.turnaround_days_max ?? null,
      acceptsMail: detail?.accepts_mail ?? null,
      mailNotes: detail ? pick(locale, detail.mail_notes_es, detail.mail_notes_en) : null,
      rubberBrands: detail?.rubber_brands ?? [],
      services: toResolerServices(detail?.services),
      pricesVerifiedAt: detail?.prices_verified_at ?? null,
    }
  })
}

/** Resoler page extras: contact data + author review, gallery and related articles. */
export async function getResolerDetail(
  db: GuideClient,
  locale: Locale,
  itemId: string,
): Promise<ResolerDetail<string> | null> {
  const [row, extras] = await Promise.all([
    db
      .from('resolers')
      .select('address, city, postal_code, website_url')
      .eq('item_id', itemId)
      .maybeSingle()
      .then(unwrapMaybe),
    getItemExtras(db, locale, itemId),
  ])
  if (!row) return null
  return {
    address: row.address,
    city: row.city,
    postalCode: row.postal_code,
    websiteUrl: row.website_url,
    ...extras,
  }
}
