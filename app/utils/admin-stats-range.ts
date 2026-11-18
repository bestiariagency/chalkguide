import { dayOfMonth, fmtDay } from './admin-stats-format'

/**
 * Period, grouping and custom range of Estadísticas (README §16.2, §16.10, D61). The view lives in the URL
 * (`?periodo=30d|12m|personalizado&agrupar=dia|semana|mes&desde=&hasta=`); an invalid URL falls back to the default.
 */
export type StatsPeriod = '30d' | '12m' | 'custom'
export type StatsGrain = 'day' | 'week' | 'month'
export interface StatsView {
  period: StatsPeriod
  grain: StatsGrain
  from?: string
  to?: string
}

export const DEFAULT_VIEW: StatsView = { period: '12m', grain: 'month' }
export const GRAIN_LABEL: Record<StatsGrain, string> = { day: 'Día', week: 'Semana', month: 'Mes' }
export const GRAIN_BY: Record<StatsGrain, string> = { day: 'por día', week: 'por semana', month: 'por mes' }
export const GRAIN_NOUN: Record<StatsGrain, [string, string]> = { day: ['día', 'días'], week: ['semana', 'semanas'], month: ['mes', 'meses'] }
export const GRAIN_QUERY: Record<StatsGrain, string> = { day: 'dia', week: 'semana', month: 'mes' }
const PERIOD_QUERY: Record<StatsPeriod, string> = { '30d': '30d', '12m': '12m', custom: 'personalizado' }

/** With 62 days or less: day or week; with more: week or month (the server enforces the same). */
export const SHORT_RANGE_DAYS = 62
const WEEK_RANGE_DAYS = 183

const pad = (n: number) => String(n).padStart(2, '0')
const utc = (key: string) => Date.UTC(Number(key.slice(0, 4)), Number(key.slice(5, 7)) - 1, Number(key.slice(8, 10)))

export const keyAdd = (key: string, days: number) => new Date(utc(key) + days * 86_400_000).toISOString().slice(0, 10)
export const keyDiff = (from: string, to: string) => Math.round((utc(to) - utc(from)) / 86_400_000)
export const daysIn = (from: string, to: string) => keyDiff(from, to) + 1

export function isDayKey(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(utc(value)) && keyAdd(value, 0) === value
}

/** First day with data: today minus 24 months, plus one day (activity_log is purged at 24 months). */
export function statsCutoff(today: string): string {
  const y = Number(today.slice(0, 4)) - 2
  const m = Number(today.slice(5, 7))
  const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate()
  return keyAdd(`${y}-${pad(m)}-${pad(Math.min(dayOfMonth(today), lastDay))}`, 1)
}

export function allowedGrains(period: StatsPeriod, days: number): StatsGrain[] {
  if (period === '30d') return ['day', 'week']
  if (period === '12m') return ['week', 'month']
  return days <= SHORT_RANGE_DAYS ? ['day', 'week'] : ['week', 'month']
}

export function defaultGrain(period: StatsPeriod, days = 0): StatsGrain {
  if (period === '30d') return 'day'
  if (period === '12m') return 'month'
  return days <= SHORT_RANGE_DAYS ? 'day' : days <= WEEK_RANGE_DAYS ? 'week' : 'month'
}

export interface RangeIssue {
  field: 'from' | 'to' | 'both'
  message: string
}

/** Why a custom range cannot be applied (README §16.10), or `null`. Empty strings mean «sin rellenar». */
export function rangeIssue(from: string, to: string, today: string, cutoff: string): RangeIssue | null {
  if (!isDayKey(from)) return { field: 'from', message: 'Indica la fecha de inicio.' }
  if (!isDayKey(to)) return { field: 'to', message: 'Indica la fecha de fin.' }
  if (from > today) return { field: 'from', message: `La fecha de inicio no puede ser posterior a hoy (${fmtDay(today)}).` }
  if (to > today) return { field: 'to', message: `La fecha de fin no puede ser posterior a hoy (${fmtDay(today)}).` }
  if (from > to) return { field: 'both', message: 'La fecha de inicio es posterior a la de fin. Cámbialas de orden.' }
  if (from < cutoff) return { field: 'from', message: `Solo hay datos de los últimos 24 meses: la fecha de inicio debe ser el ${fmtDay(cutoff)} o posterior.` }
  return null
}

const GRAINS = Object.keys(GRAIN_QUERY) as StatsGrain[]
const grainFromQuery = (value: string) => GRAINS.find((g) => GRAIN_QUERY[g] === value)

/** Reads the URL; anything invalid gives the default (12 months by month), without an error message. */
export function viewFromQuery(get: (key: string) => string, today: string): StatsView {
  const period = get('periodo')
  const asked = grainFromQuery(get('agrupar'))
  if (period === PERIOD_QUERY.custom) {
    const [from, to] = [get('desde'), get('hasta')]
    if (rangeIssue(from, to, today, statsCutoff(today))) return DEFAULT_VIEW
    const days = daysIn(from, to)
    const grain = asked && allowedGrains('custom', days).includes(asked) ? asked : defaultGrain('custom', days)
    return { period: 'custom', grain, from, to }
  }
  const kind: StatsPeriod = period === '30d' ? '30d' : '12m'
  return { period: kind, grain: asked && allowedGrains(kind, 0).includes(asked) ? asked : defaultGrain(kind) }
}

export function viewToQuery(view: StatsView): Record<string, string | undefined> {
  return {
    periodo: PERIOD_QUERY[view.period],
    agrupar: GRAIN_QUERY[view.grain],
    desde: view.period === 'custom' ? view.from : undefined,
    hasta: view.period === 'custom' ? view.to : undefined,
  }
}

/** Arguments of `guide.admin_stats`. */
export function viewToArgs(view: StatsView): { p_range?: string; p_granularity: string; p_from?: string; p_to?: string } {
  return view.period === 'custom'
    ? { p_granularity: view.grain, p_from: view.from, p_to: view.to }
    : { p_range: view.period, p_granularity: view.grain }
}
