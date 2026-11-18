/**
 * Single date format of the panel: "5 sept 2026" (short month, with year). Accepts an instant
 * (ISO with time, shown in Madrid time) or a calendar date (`YYYY-MM-DD`, shown as is).
 * Relative times ("hace 2 h") live in `relativeUpdated`; everything else goes through here.
 */
const TZ = 'Europe/Madrid'
const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/

const clean = (text: string) => text.replace(/\./g, '')

export function adminDate(value: string): string {
  const dateOnly = DATE_ONLY.test(value)
  const date = new Date(dateOnly ? `${value}T12:00:00Z` : value)
  return clean(new Intl.DateTimeFormat('es-ES', { timeZone: dateOnly ? 'UTC' : TZ, day: 'numeric', month: 'short', year: 'numeric' }).format(date))
}

/** "5 sept 2026, 14:30" */
export function adminDateTime(value: string): string {
  const time = new Intl.DateTimeFormat('es-ES', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(value))
  return `${adminDate(value)}, ${time}`
}
