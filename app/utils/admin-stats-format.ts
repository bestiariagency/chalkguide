/** Date and number text of Estadísticas (docs/design/admin/README.md §16). Dates are `YYYY-MM-DD` day keys (Madrid). */
export const STATS_MONTHS_SHORT = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic']
export const STATS_MONTHS_LONG = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const WEEKDAYS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']

const grouped = new Intl.NumberFormat('es-ES', { useGrouping: 'always' })
/** `1.284`: es-ES does not group four digits by default, the panel always does. */
export const fmtNum = (n: number) => grouped.format(n)

export const statsCap = (text: string) => text.charAt(0).toUpperCase() + text.slice(1)

const parts = (key: string) => ({ y: Number(key.slice(0, 4)), m: Number(key.slice(5, 7)) - 1, d: Number(key.slice(8, 10)) })

/** "6 nov 2026" (or "6 nov" without year). */
export function fmtDay(key: string, year = true): string {
  const { y, m, d } = parts(key)
  return `${d} ${STATS_MONTHS_SHORT[m]}${year ? ` ${y}` : ''}`
}

export const dayOfMonth = (key: string) => parts(key).d
export const weekdayOf = (key: string) => new Date(Date.UTC(parts(key).y, parts(key).m, parts(key).d)).getUTCDay()

/** "Viernes 6 de noviembre de 2026". */
export function fmtDayLong(key: string): string {
  const { y, m, d } = parts(key)
  return `${statsCap(WEEKDAYS[weekdayOf(key)] ?? '')} ${d} de ${STATS_MONTHS_LONG[m]} de ${y}`
}

/** "1 mar – 15 jun 2026"; the year shows on both ends only when they differ. */
export function rangeText(from: string, to: string): string {
  if (from === to) return fmtDay(from)
  return parts(from).y === parts(to).y ? `${fmtDay(from, false)} – ${fmtDay(to)}` : `${fmtDay(from)} – ${fmtDay(to)}`
}

/** "Dic 2025" / "nov 2026". */
export const monthYear = (key: string) => `${STATS_MONTHS_SHORT[parts(key).m]} ${parts(key).y}`
export const monthName = (key: string) => STATS_MONTHS_LONG[parts(key).m] ?? ''
