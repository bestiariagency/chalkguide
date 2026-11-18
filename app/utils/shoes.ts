import type { ShoeSummary } from '~/types/domain'

/** Home glance: the most recently edited models, any level (newest first). */
export function pickLatestShoes(shoes: ShoeSummary[], count = 4): ShoeSummary[] {
  return [...shoes]
    .sort((a, b) => Date.parse(b.editedAt) - Date.parse(a.editedAt))
    .slice(0, count)
}

/** House rule: at most 3 models side by side. */
export const MAX_COMPARE = 3
export const PRICE_STEP = 5

export const SHOE_PROFILES = ['flat', 'moderate', 'aggressive'] as const
export const SHOE_CLOSURES = ['velcro', 'lace', 'slipper'] as const
export const STIFFNESS_GROUPS = ['soft', 'medium', 'stiff'] as const
export const SHOE_LEVELS = ['beginner', 'intermediate', 'advanced'] as const
export const SHOE_USES = ['gym', 'boulder', 'sport', 'trad', 'multipitch', 'training'] as const
export type StiffnessGroup = (typeof STIFFNESS_GROUPS)[number]

export interface ShoeFilters {
  profile: string[]
  closure: string[]
  stiffness: StiffnessGroup[]
  use: string[]
  level: string[]
  owned: boolean
  /** Price range in € (the full bounds mean "no price filter"). */
  min: number
  max: number
}

export type ShoeListKey = 'level' | 'profile' | 'closure' | 'stiffness' | 'use'
export type ShoeFilterOptions = Record<ShoeListKey, string[]>

/** 1–2 soft, 3 medium, 4–5 stiff. */
export function stiffnessGroup(stiffness: number | null): StiffnessGroup | null {
  if (stiffness === null) return null
  return stiffness <= 2 ? 'soft' : stiffness === 3 ? 'medium' : 'stiff'
}

/** Price bounds of the whole list, rounded to the slider step. */
export function priceBounds(shoes: ShoeSummary[]) {
  const prices = shoes.flatMap((s) => [s.priceMin, s.priceMax]).filter((p): p is number => p !== null)
  if (!prices.length) return { min: 0, max: 0 }
  return {
    min: Math.floor(Math.min(...prices) / PRICE_STEP) * PRICE_STEP,
    max: Math.ceil(Math.max(...prices) / PRICE_STEP) * PRICE_STEP,
  }
}

/** Only the values that exist in the data are offered as filters (known order). */
export function filterOptions(shoes: ShoeSummary[]): ShoeFilterOptions {
  const present = (known: readonly string[], values: (string | null)[]) =>
    known.filter((key) => values.includes(key))
  return {
    level: present(SHOE_LEVELS, shoes.flatMap((s) => s.levels)),
    profile: present(SHOE_PROFILES, shoes.map((s) => s.profile)),
    closure: present(SHOE_CLOSURES, shoes.map((s) => s.closure)),
    stiffness: present(STIFFNESS_GROUPS, shoes.map((s) => stiffnessGroup(s.stiffness))),
    use: present(SHOE_USES, shoes.flatMap((s) => s.recommendedUse)),
  }
}

export function filterShoes(
  shoes: ShoeSummary[],
  f: ShoeFilters,
  bounds: { min: number; max: number },
): ShoeSummary[] {
  const priced = f.min > bounds.min || f.max < bounds.max
  return shoes.filter((s) => {
    if (f.profile.length && !(s.profile && f.profile.includes(s.profile))) return false
    if (f.closure.length && !(s.closure && f.closure.includes(s.closure))) return false
    const group = stiffnessGroup(s.stiffness)
    if (f.stiffness.length && !(group && f.stiffness.includes(group))) return false
    if (f.use.length && !s.recommendedUse.some((use) => f.use.includes(use))) return false
    if (f.level.length && !s.levels.some((level) => f.level.includes(level))) return false
    if (f.owned && !s.ownedByAuthor) return false
    if (priced) {
      const low = s.priceMin ?? s.priceMax
      const high = s.priceMax ?? s.priceMin
      if (low === null || high === null || high < f.min || low > f.max) return false
    }
    return true
  })
}

/** Cheapest first (comparator order); models without price go last. */
export function sortShoesByPrice(shoes: ShoeSummary[]): ShoeSummary[] {
  const price = (s: ShoeSummary) => s.priceMin ?? s.priceMax
  return [...shoes].sort((a, b) => {
    const pa = price(a)
    const pb = price(b)
    if (pa === null) return pb === null ? 0 : 1
    if (pb === null) return -1
    return pa - pb
  })
}

/** Most recent price check among the given models. */
export function latestPriceCheck(shoes: ShoeSummary[]): string | null {
  return (
    shoes
      .map((s) => s.priceCheckedAt)
      .filter((date): date is string => !!date)
      .sort()
      .at(-1) ?? null
  )
}

/** Affiliate URLs come from the DB: only http(s) is ever rendered as a link. */
export const isHttpUrl = (url: string | null): url is string => !!url && /^https?:\/\//i.test(url)

/** Query-string values are untrusted: keep only known values. */
export function parseList<T extends string>(raw: unknown, allowed: readonly T[]): T[] {
  const text = Array.isArray(raw) ? raw[0] : raw
  if (typeof text !== 'string') return []
  const wanted = text.split(',')
  return allowed.filter((key) => wanted.includes(key))
}

/** Text the comparator search looks into: brand, model and rubber (README §9.9.1). */
export const shoeSearchFields = (s: ShoeSummary) => [s.brand, s.model, s.rubber]

/** Brand + model alphabetical (the adder's list order). */
export function sortShoesByName(shoes: ShoeSummary[]): ShoeSummary[] {
  return [...shoes].sort((a, b) => `${a.brand} ${a.model}`.localeCompare(`${b.brand} ${b.model}`))
}

/** Rows of the side-by-side view, in order. `long` ones stack by model on narrow screens. */
export const COMPARE_FIELDS = [
  { key: 'price', long: false },
  { key: 'profile', long: false },
  { key: 'asymmetry', long: false },
  { key: 'closure', long: false },
  { key: 'rubber', long: false },
  { key: 'stiffness', long: false },
  { key: 'use', long: false },
  { key: 'level', long: false },
  { key: 'author', long: false },
  { key: 'size', long: false },
  { key: 'learned', long: true },
  { key: 'buy', long: true },
] as const
export type CompareField = (typeof COMPARE_FIELDS)[number]['key']

/** EU size with at most one decimal ("39,5", "41"). */
export function formatSize(value: number | null, locale: string): string | null {
  if (value === null) return null
  return new Intl.NumberFormat(locale, { maximumFractionDigits: 1 }).format(value)
}

/** Author size minus street size with a real minus sign ("−1,5", "+1", "0"); computed, never stored. */
export function formatSizeDifference(
  authorSize: number | null,
  streetSize: number | null,
  locale: string,
): string | null {
  if (authorSize === null || streetSize === null) return null
  const diff = Math.round((authorSize - streetSize) * 10) / 10
  return new Intl.NumberFormat(locale, { maximumFractionDigits: 1, signDisplay: 'exceptZero' })
    .format(diff)
    .replace('-', '−')
}

/** Both sizes exist: the strip / comparator row can show them. */
export const hasSizes = (s: Pick<ShoeSummary, 'authorSizeEu' | 'authorStreetSizeEu'>) =>
  s.authorSizeEu !== null && s.authorStreetSizeEu !== null

/** Same level / profile first, then the closest price; never the model itself. */
export function pickAlternatives(shoe: ShoeSummary, all: ShoeSummary[], count = 3): ShoeSummary[] {
  const price = (s: ShoeSummary) => s.priceMin ?? s.priceMax
  const distance = (s: ShoeSummary) => {
    const a = price(shoe)
    const b = price(s)
    return a === null || b === null ? Infinity : Math.abs(a - b)
  }
  const score = (s: ShoeSummary) =>
    Number(s.levels.some((level) => shoe.levels.includes(level))) * 2 +
    Number(!!s.profile && s.profile === shoe.profile)
  return all
    .filter((s) => s.id !== shoe.id)
    .sort((a, b) => score(b) - score(a) || distance(a) - distance(b))
    .slice(0, count)
}
