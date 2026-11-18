import type { GymSummary, Locale } from '~/types/domain'
import type { Json } from '~/types/database.types'
import { earliestOpening } from '~/utils/opening-hours'
import { type GuideClient, one, unwrap } from './client'
import { type ListItemsOptions, fetchAuthorScores, fetchItems, num, toBase } from './items'

/** Gyms listing: items + detail embed, then one batched query for the derived indices. */
export async function listGyms(
  db: GuideClient,
  locale: Locale,
  options: ListItemsOptions = {},
): Promise<GymSummary[]> {
  const rows = await fetchItems(db, 'gym', locale, options)
  const ids = rows.map((row) => row.id)
  const [{ overall: scores, criteria }, indices] = await Promise.all([
    fetchAuthorScores(db, locale, ids),
    ids.length
      ? db
          .from('gym_indices')
          .select('item_id, monthly_cost_2pw_eur, price_index, beginner_index, family_index')
          .in('item_id', ids)
          .then(unwrap)
      : Promise.resolve([]),
  ])
  const byItem = new Map(indices.map((row) => [row.item_id, row]))
  return rows.map((row) => {
    const detail = one(
      row.detail as {
        district: string | null
        metro_stations: string[]
        has_lead: boolean | null
        has_boulder: boolean | null
        has_kids_area: boolean | null
        belay_test_required: boolean | null
        opening_hours: Json
        price_monthly_eur: number | null
        max_height_m: number | string | null
        prices_verified_at: string | null
        price_day_eur: number | null
        grading_difficulty: number | null
        setting_dynamism: number | null
      } | null,
    )
    const index = byItem.get(row.id)
    return {
      ...toBase(row, locale, scores),
      district: detail?.district ?? null,
      metroStations: detail?.metro_stations ?? [],
      hasLead: detail?.has_lead ?? null,
      hasBoulder: detail?.has_boulder ?? null,
      hasKidsArea: detail?.has_kids_area ?? null,
      belayTestRequired: detail?.belay_test_required ?? null,
      opensAtMinutes: earliestOpening(detail?.opening_hours),
      priceMonthly: num(detail?.price_monthly_eur),
      maxHeightM: num(detail?.max_height_m),
      pricesVerifiedAt: detail?.prices_verified_at ?? null,
      monthlyCost2pw: num(index?.monthly_cost_2pw_eur),
      priceIndex: num(index?.price_index),
      beginnerIndex: num(index?.beginner_index),
      familyIndex: num(index?.family_index),
      priceDay: num(detail?.price_day_eur),
      variety: criteria.get(row.id)?.find((c) => c.criterionKey === 'variety')?.score ?? null,
      gradingDifficulty: detail?.grading_difficulty ?? null,
      settingDynamism: detail?.setting_dynamism ?? null,
    }
  })
}

/**
 * Whether the gym criterion `key` is active (RLS only shows active criteria to the public). The
 * listing hides the column of a criterion Xavi turned off (F6.10).
 */
export async function isGymCriterionActive(db: GuideClient, key: string): Promise<boolean> {
  const rows = unwrap(await db.from('criteria').select('id').eq('category', 'gym').eq('key', key).eq('is_active', true).limit(1))
  return rows.length > 0
}
