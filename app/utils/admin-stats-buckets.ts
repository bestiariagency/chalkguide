import { statsCap, dayOfMonth, fmtDay, fmtDayLong, STATS_MONTHS_LONG, STATS_MONTHS_SHORT, weekdayOf } from './admin-stats-format'
import { keyAdd } from './admin-stats-range'
import type { StatsGrain } from './admin-stats-range'
import type { StatsBucket } from './admin-stats'

/** A period ready to draw: x-axis text, detail title and the note of a period in progress or cut (README §16.4). */
export interface BucketView extends StatsBucket {
  /** x-axis label; by day, `axisFirst` carries the month and shows on the first label and when the month changes. */
  axis: string
  axisFirst?: string
  month: string
  full: string
  note: string | null
}

function lastOfMonth(key: string): string {
  const y = Number(key.slice(0, 4))
  const m = Number(key.slice(5, 7))
  return `${key.slice(0, 8)}${new Date(Date.UTC(y, m, 0)).getUTCDate()}`
}

/** Natural first and last day of the period that holds `key`. */
function naturalSpan(key: string, grain: StatsGrain): [string, string] {
  if (grain === 'day') return [key, key]
  if (grain === 'week') {
    const monday = keyAdd(key, -((weekdayOf(key) + 6) % 7))
    return [monday, keyAdd(monday, 6)]
  }
  return [`${key.slice(0, 8)}01`, lastOfMonth(key)]
}

export function bucketViews(buckets: readonly StatsBucket[], grain: StatsGrain, today: string): BucketView[] {
  return buckets.map((b, i) => {
    const [first, last] = naturalSpan(b.start, grain)
    const live = b.partial && last > today
    const cut = b.partial && !live
    const day = dayOfMonth(b.start)
    const month = b.start.slice(0, 7)
    const mon = STATS_MONTHS_SHORT[Number(b.start.slice(5, 7)) - 1] ?? ''
    const span = `del ${dayOfMonth(b.start)} al ${dayOfMonth(b.end)}`
    const base = { ...b, month }
    if (grain === 'day') {
      return { ...base, axis: String(day), axisFirst: `${day} ${mon}`, full: fmtDayLong(b.start), note: b.partial ? 'hoy, en curso' : null }
    }
    if (grain === 'week') {
      return {
        ...base,
        axis: fmtDay(b.start, false),
        full: first === b.start && !cut ? `Semana del ${fmtDay(first)}` : `Del ${b.start.slice(0, 7) === b.end.slice(0, 7) ? dayOfMonth(b.start) : fmtDay(b.start, false)} al ${fmtDay(b.end)}`,
        note: live ? `en curso, ${span}` : cut ? 'semana recortada por el periodo' : null,
      }
    }
    const yy = b.start.slice(2, 4)
    return {
      ...base,
      axis: i === 0 || mon === 'ene' ? `${mon} ${yy}` : mon,
      full: `${statsCap(STATS_MONTHS_LONG[Number(b.start.slice(5, 7)) - 1] ?? '')} ${b.start.slice(0, 4)}`,
      note: live ? `en curso, hasta el ${dayOfMonth(b.end)}` : cut ? `recortado, ${span}` : null,
    }
  })
}
