import type { StatsBucket } from './admin-stats'
import type { BucketView } from './admin-stats-buckets'
import { fmtNum } from './admin-stats-format'

/** What each card draws: one entry per series, used by the legend, the hover detail and «Ver como tabla». */
export type SwatchKind = 'line' | 'acc' | 'muted' | 'hidden' | 'base' | 'partial'
export interface StatsCol {
  label: string
  swatch: SwatchKind
  value: (b: StatsBucket) => number
}
/** Hover / touch / keyboard detail of one period. */
export interface PlotTip {
  title: string
  note: string | null
  rows: { swatch: SwatchKind; label: string; value: string }[]
}
export type StatsCardId = 'subs' | 'articles' | 'reviews'

export const STATS_COLS: Record<StatsCardId, StatsCol[]> = {
  subs: [
    { label: 'Total activos', swatch: 'line', value: (b) => b.subsTotal },
    { label: 'Altas', swatch: 'acc', value: (b) => b.subsIn },
    { label: 'Bajas', swatch: 'muted', value: (b) => b.subsOut },
  ],
  articles: [{ label: 'Publicados', swatch: 'acc', value: (b) => b.articles }],
  reviews: [
    { label: 'Visibles', swatch: 'acc', value: (b) => b.reviewsVisible },
    { label: 'Ocultas', swatch: 'hidden', value: (b) => b.reviewsHidden },
  ],
}

/** Only the first graph of the card has a title in the table and the detail: subs also has a second (altas y bajas). */
export const STATS_TITLES: Record<StatsCardId, string> = { subs: 'Suscriptores', articles: 'Artículos publicados', reviews: 'Opiniones' }

/** The card has nothing to draw when its whole series is 0 (no axes at 0). */
export const statsCardEmpty = (id: StatsCardId, buckets: readonly StatsBucket[]) =>
  buckets.every((b) => STATS_COLS[id].every((c) => c.value(b) === 0))

export function statsTip(id: StatsCardId, b: BucketView): PlotTip {
  return { title: b.full, note: b.note, rows: STATS_COLS[id].map((c) => ({ swatch: c.swatch, label: c.label, value: fmtNum(c.value(b)) })) }
}

/** What a screen reader hears when the keyboard lands on a period. */
export const statsAnnounce = (id: StatsCardId, b: BucketView) =>
  `${b.full}${b.note ? `, ${b.note}` : ''}: ${STATS_COLS[id].map((c) => `${c.label} ${fmtNum(c.value(b))}`).join(', ')}`
