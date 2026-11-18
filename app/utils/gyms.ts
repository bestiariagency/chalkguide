import type { GymSummary } from '~/types/domain'

export type GymSortKey = 'score' | 'price' | 'beginner'

/**
 * Orders already-fetched gyms (UI state only, values come from the views).
 * Missing values go last in every order.
 */
export function sortGyms(gyms: GymSummary[], key: GymSortKey): GymSummary[] {
  const value = (gym: GymSummary) =>
    key === 'score' ? gym.authorScore : key === 'price' ? gym.priceMonthly : gym.beginnerIndex
  const ascending = key === 'price'
  return [...gyms].sort((a, b) => {
    const va = value(a)
    const vb = value(b)
    if (va === null) return vb === null ? 0 : 1
    if (vb === null) return -1
    return ascending ? va - vb : vb - va
  })
}

export type GymListSortKey = 'price' | 'family' | 'variety'
export const GYM_LIST_SORT_KEYS: GymListSortKey[] = ['price', 'family', 'variety']

/** Listing order (README §9.9.2): day price ascending by default; family and variety descending. Gaps go last. */
export function sortGymsForList(gyms: GymSummary[], key: GymListSortKey): GymSummary[] {
  const value = (gym: GymSummary) =>
    key === 'price' ? gym.priceDay : key === 'family' ? gym.familyIndex : gym.variety
  return [...gyms].sort((a, b) => {
    const va = value(a)
    const vb = value(b)
    if (va === null) return vb === null ? 0 : 1
    if (vb === null) return -1
    return key === 'price' ? va - vb : vb - va
  })
}

/** Featured gyms first, then by author score: the home shows the top `count`. */
export function pickHomeGyms(gyms: GymSummary[], count = 3): GymSummary[] {
  return [...gyms]
    .sort(
      (a, b) =>
        Number(b.isFeatured) - Number(a.isFeatured) || (b.authorScore ?? 0) - (a.authorScore ?? 0),
    )
    .slice(0, count)
}

/** Most recent verification date among the given gyms (prices or item data). */
export function latestVerification(gyms: GymSummary[]): string | null {
  return (
    gyms
      .map((gym) => gym.pricesVerifiedAt ?? gym.verifiedAt)
      .filter((date): date is string => !!date)
      .sort()
      .at(-1) ?? null
  )
}

export function gymTypeKey(gym: GymSummary): string | null {
  if (gym.hasLead && gym.hasBoulder) return 'gyms.type.both'
  if (gym.hasLead) return 'gyms.type.lead'
  if (gym.hasBoulder) return 'gyms.type.boulder'
  return null
}

/** Listing filters (all "must have"): the mockup's four chips. */
export const GYM_FILTER_KEYS = ['lead', 'kids', 'noBelayTest', 'early'] as const
export type GymFilterKey = (typeof GYM_FILTER_KEYS)[number]

const EARLY_OPENING_MINUTES = 7 * 60

const FILTER_TESTS: Record<GymFilterKey, (gym: GymSummary) => boolean> = {
  lead: (gym) => gym.hasLead === true,
  kids: (gym) => gym.hasKidsArea === true,
  noBelayTest: (gym) => gym.belayTestRequired === false,
  early: (gym) => gym.opensAtMinutes !== null && gym.opensAtMinutes <= EARLY_OPENING_MINUTES,
}

export function filterGyms(gyms: GymSummary[], active: GymFilterKey[]): GymSummary[] {
  return gyms.filter((gym) => active.every((key) => FILTER_TESTS[key](gym)))
}

/** i18n keys (under `gyms.grading.*` / `gyms.style.*`) of the 5 positions of each descriptive scale. */
export const GYM_SCALE_WORDS = {
  grading: ['generous', 'fairlyGenerous', 'average', 'fairlyHard', 'hard'],
  style: ['veryTechnical', 'technical', 'mixed', 'dynamic', 'veryDynamic'],
} as const
export type GymScaleKind = keyof typeof GYM_SCALE_WORDS

/** Key of the word for a 1–5 value, or null (no data / out of range). */
export function gymScaleWordKey(kind: GymScaleKind, value: number | null): string | null {
  if (value === null || !Number.isInteger(value) || value < 1 || value > 5) return null
  return `gyms.${kind}.${GYM_SCALE_WORDS[kind][value - 1]}`
}
