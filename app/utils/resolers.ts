import type { ResolerService, ResolerSummary } from '~/types/domain'

/** Services a workshop offers (guide.resolers.services), in display order. */
export const RESOLER_SERVICES: readonly ResolerService[] = [
  'half_sole',
  'full_sole',
  'rand',
  'toe_patch',
  'closure_repair',
  'stitching',
  'other',
]

/** Keeps only known services, in canonical order (the column is free text[] in the DB). */
export function toResolerServices(value: string[] | null | undefined): ResolerService[] {
  const present = new Set(value ?? [])
  return RESOLER_SERVICES.filter((service) => present.has(service))
}

export type ResolerSortKey = 'score' | 'price' | 'days'
export const RESOLER_SORT_KEYS: readonly ResolerSortKey[] = ['score', 'price', 'days']

/** Listing filters (all "must have"): mail first, then one per service. */
export const RESOLER_FILTER_KEYS = [
  'mail',
  'half_sole',
  'full_sole',
  'rand',
  'toe_patch',
  'closure_repair',
  'stitching',
] as const
export type ResolerFilterKey = (typeof RESOLER_FILTER_KEYS)[number]

/** Orders already-fetched resolers; missing values go last. Price and wait: lower first. */
export function sortResolers(items: ResolerSummary[], key: ResolerSortKey): ResolerSummary[] {
  const value = (r: ResolerSummary) =>
    key === 'score' ? r.authorScore : key === 'price' ? r.pricePerPair : r.turnaroundMin
  const ascending = key !== 'score'
  return [...items].sort((a, b) => {
    const va = value(a)
    const vb = value(b)
    if (va === null) return vb === null ? 0 : 1
    if (vb === null) return -1
    return ascending ? va - vb : vb - va
  })
}

export function filterResolers(items: ResolerSummary[], active: ResolerFilterKey[]) {
  return items.filter((r) =>
    active.every((key) =>
      key === 'mail' ? r.acceptsMail === true : r.services.includes(key),
    ),
  )
}

/** "7–10" or "7" when the range collapses; null without data. */
export function turnaroundRange(r: Pick<ResolerSummary, 'turnaroundMin' | 'turnaroundMax'>) {
  const min = r.turnaroundMin ?? r.turnaroundMax
  const max = r.turnaroundMax ?? r.turnaroundMin
  if (min === null || max === null) return null
  return min === max ? { text: String(min), count: max } : { text: `${min}–${max}`, count: max }
}
