import type { ShoeSummary } from '~/types/domain'

export const SHOE_SORTS = ['price-asc', 'price-desc', 'name'] as const
export type ShoeSort = (typeof SHOE_SORTS)[number]

/** Query value (untrusted) → sort; cheapest first by default. */
export function parseSort(raw: unknown): ShoeSort {
  const value = Array.isArray(raw) ? raw[0] : raw
  return SHOE_SORTS.find((sort) => sort === value) ?? 'price-asc'
}

/** Order of the results grid. Models without price always go last when sorting by price. */
export function sortShoes(shoes: ShoeSummary[], sort: ShoeSort): ShoeSummary[] {
  if (sort === 'name') {
    return [...shoes].sort((a, b) => a.model.localeCompare(b.model) || a.brand.localeCompare(b.brand))
  }
  const cheapestFirst = sortShoesByPrice(shoes)
  if (sort === 'price-asc') return cheapestFirst
  const priced = cheapestFirst.filter((s) => (s.priceMin ?? s.priceMax) !== null)
  return [...priced.reverse(), ...cheapestFirst.filter((s) => (s.priceMin ?? s.priceMax) === null)]
}

/** How many models of the whole list carry each filter value (the chip counters). */
export function filterCounts(shoes: ShoeSummary[]): Record<ShoeListKey, Record<string, number>> {
  const count = (values: (readonly (string | null)[])[]) => {
    const result: Record<string, number> = {}
    for (const own of values) for (const value of new Set(own)) if (value) result[value] = (result[value] ?? 0) + 1
    return result
  }
  return {
    level: count(shoes.map((s) => s.levels)),
    profile: count(shoes.map((s) => [s.profile])),
    closure: count(shoes.map((s) => [s.closure])),
    stiffness: count(shoes.map((s) => [stiffnessGroup(s.stiffness)])),
    use: count(shoes.map((s) => s.recommendedUse)),
  }
}

/** Aggressiveness as 1–3 bars (flat → aggressive); 0 when unknown. */
export const aggressionLevel = (profile: ShoeSummary['profile']) =>
  profile === 'flat' ? 1 : profile === 'moderate' ? 2 : profile === 'aggressive' ? 3 : 0
