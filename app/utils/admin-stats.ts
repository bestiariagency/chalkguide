import type { ByCategory } from './admin-dashboard'
import type { StatsGrain } from './admin-stats-range'

/** `guide.admin_stats` (jsonb) parsed into a typed shape (README §16.8). Every number defaults to 0. */
export interface StatsBucket {
  /** First and last day (`YYYY-MM-DD`, Madrid) of the period, already cut by the range. */
  start: string
  end: string
  /** Period in progress or cut by the range. */
  partial: boolean
  subsIn: number
  subsOut: number
  /** Active subscribers at the end of the period. */
  subsTotal: number
  articles: number
  reviewsVisible: number
  reviewsHidden: number
}

export interface StatsTotals {
  from: string
  to: string
  subsIn: number
  subsOut: number
  subsTotalEnd: number
  articles: number
  reviewsVisible: number
  reviewsHidden: number
  itemsNew: ByCategory
}

export interface StatsData {
  range: 'custom' | '30d' | '12m'
  grain: StatsGrain
  from: string
  to: string
  generatedAt: string
  buckets: StatsBucket[]
  totals: StatsTotals
  /** `null`: the previous period starts before the 24-month cut («sin datos comparables»). */
  previous: StatsTotals | null
  /** Published at 00:00 Madrid of `from` and at the end of day `to`. Without them (older answer): today's total and total minus new. */
  itemsAtStart: ByCategory
  itemsAtEnd: ByCategory
  articlesTotal: number
}

const obj = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {})
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)
const str = (v: unknown) => (typeof v === 'string' ? v : '')
const byCategory = (v: unknown): ByCategory => ({ gym: num(obj(v).gym), resoler: num(obj(v).resoler), shoe: num(obj(v).shoe) })

function totals(raw: unknown): StatsTotals {
  const r = obj(raw)
  return {
    from: str(r.from),
    to: str(r.to),
    subsIn: num(r.subs_in),
    subsOut: num(r.subs_out),
    subsTotalEnd: num(r.subs_total_end),
    articles: num(r.articles_published),
    reviewsVisible: num(r.reviews_visible),
    reviewsHidden: num(r.reviews_hidden),
    itemsNew: byCategory(r.items_new_in_range),
  }
}

const GRAINS: StatsGrain[] = ['day', 'week', 'month']

/** Throws when the answer is not the contract (the page then shows the error block). */
export function parseStats(raw: unknown): StatsData {
  const r = obj(raw)
  const grain = GRAINS.find((g) => g === r.granularity)
  if (!grain || !Array.isArray(r.series) || !r.current_totals || !str(r.from) || !str(r.to)) throw new Error('admin_stats: unexpected answer')
  const published = byCategory(r.items_published)
  const atEnd = r.items_published_at_end ? byCategory(r.items_published_at_end) : published
  const itemsNew = byCategory(obj(r.current_totals).items_new_in_range)
  const atStart = r.items_published_at_start
    ? byCategory(r.items_published_at_start)
    : { gym: Math.max(0, atEnd.gym - itemsNew.gym), resoler: Math.max(0, atEnd.resoler - itemsNew.resoler), shoe: Math.max(0, atEnd.shoe - itemsNew.shoe) }
  return {
    range: r.range === '30d' ? '30d' : r.range === '12m' ? '12m' : 'custom',
    grain,
    from: str(r.from),
    to: str(r.to),
    generatedAt: str(r.generated_at),
    buckets: r.series.map((item) => {
      const b = obj(item)
      return {
        start: str(b.bucket_start),
        end: str(b.bucket_end),
        partial: b.partial === true,
        subsIn: num(b.subs_in),
        subsOut: num(b.subs_out),
        subsTotal: num(b.subs_total),
        articles: num(b.articles_published),
        reviewsVisible: num(b.reviews_visible),
        reviewsHidden: num(b.reviews_hidden),
      }
    }),
    totals: totals(r.current_totals),
    previous: r.previous ? totals(r.previous) : null,
    itemsAtStart: atStart,
    itemsAtEnd: atEnd,
    articlesTotal: num(r.articles_published_total),
  }
}

export const sumCategories = (by: ByCategory) => by.gym + by.resoler + by.shoe
