import { statsCap, fmtDay, fmtNum, monthName, monthYear, rangeText } from './admin-stats-format'
import { GRAIN_BY, GRAIN_NOUN, daysIn, keyAdd, statsCutoff } from './admin-stats-range'
import type { StatsData } from './admin-stats'

/** Subtitle under the title: exact range and grouping in one line (README §16.2). */
export function statsSubtitle(data: StatsData): string {
  const { from, to, grain, range } = data
  if (range === 'custom') {
    const days = daysIn(from, to)
    return `${rangeText(from, to)} · ${fmtNum(days)} ${days === 1 ? 'día' : 'días'} · ${GRAIN_BY[grain]}`
  }
  if (range === '12m' && grain === 'month') return `${statsCap(monthYear(from))} – ${monthYear(to)} · ${GRAIN_BY[grain]} · ${monthName(to)}, en curso`
  return `${rangeText(from, to)} · ${GRAIN_BY[grain]}`
}

/** «en 30 días» / «en 12 meses» / «en el periodo». */
export const statsPeriodText = (range: StatsData['range']) => (range === '30d' ? 'en 30 días' : range === '12m' ? 'en 12 meses' : 'en el periodo')

/** Note under the KPIs: which days the comparison uses, or why there is none. */
export function comparisonNote(data: StatsData, today: string): string {
  const days = daysIn(data.from, data.to)
  const prevFrom = keyAdd(data.from, -days)
  if (!data.previous) {
    return `Sin comparación: el periodo anterior empezaría el ${fmtDay(prevFrom)} y solo se guardan datos de los últimos 24 meses (desde el ${fmtDay(statsCutoff(today))}).`
  }
  return `Comparación con ${rangeText(prevFrom, keyAdd(data.from, -1))}, ${days === 1 ? 'el día' : `los ${fmtNum(days)} días`} justo antes.`
}

/** Column title of the table: «Mes», «Semana», «Día». */
export const grainColumn = (grain: StatsData['grain']) => statsCap(GRAIN_NOUN[grain][0])
