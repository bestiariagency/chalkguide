import type { AdminEvent } from './admin-events'

// Dates (always Europe/Madrid, like the site and the database) -----------------------------------
const TZ = 'Europe/Madrid'
const WEEKDAYS = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb']
export const MONTHS_SHORT = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic']
export const MONTHS_LONG = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const partsFormat = new Intl.DateTimeFormat('en-CA', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })

export interface MadridParts {
  /** `YYYY-MM-DD`. */
  date: string
  /** `HH:mm`. */
  time: string
  year: number
  month: number
  day: number
  /** 0 = domingo. */
  weekday: number
}

export function madridParts(iso: string | Date): MadridParts {
  const map: Record<string, string> = {}
  for (const part of partsFormat.formatToParts(typeof iso === 'string' ? new Date(iso) : iso)) map[part.type] = part.value
  const year = Number(map.year)
  const month = Number(map.month)
  const day = Number(map.day)
  return {
    date: `${map.year}-${map.month}-${map.day}`,
    time: `${map.hour}:${map.minute}`,
    year,
    month,
    day,
    weekday: new Date(Date.UTC(year, month - 1, day)).getUTCDay(),
  }
}

/** `YYYY-MM-DD` + `HH:mm` in Madrid → ISO (UTC). Two passes settle the daylight-saving offset. */
export function madridToIso(date: string, time = '00:00'): string {
  const [y = 0, m = 1, d = 1] = date.split('-').map(Number)
  const [h = 0, mi = 0] = time.split(':').map(Number)
  const guess = Date.UTC(y, m - 1, d, h, mi)
  const offsetAt = (t: number) => {
    const p = madridParts(new Date(t))
    return Date.UTC(p.year, p.month - 1, p.day, Number(p.time.slice(0, 2)), Number(p.time.slice(3))) - t
  }
  const first = guess - offsetAt(guess)
  return new Date(guess - offsetAt(first)).toISOString()
}

export const todayMadrid = () => madridParts(new Date()).date

/** `vie 23 oct`. */
export function dayLabel(iso: string): string {
  const p = madridParts(iso)
  return `${WEEKDAYS[p.weekday]} ${p.day} ${MONTHS_SHORT[p.month - 1]}`
}

/** `18:00–21:00`, `Todo el día` (or the span of days when it covers several). */
export function timeLabel(e: Pick<AdminEvent, 'startsAt' | 'endsAt' | 'allDay'>): string {
  const start = madridParts(e.startsAt)
  const end = e.endsAt ? madridParts(e.endsAt) : null
  const sameDay = !end || end.date === start.date
  if (e.allDay) return sameDay ? 'Todo el día' : `Todo el día · hasta el ${end.day} ${MONTHS_SHORT[end.month - 1]}`
  if (!end) return start.time
  return sameDay ? `${start.time}–${end.time}` : `${start.time} → ${end.day} ${MONTHS_SHORT[end.month - 1]} ${end.time}`
}

/** `Noviembre 2026`: key and label of the month rows of the tables. */
export function monthGroup(iso: string): { key: string; label: string } {
  const p = madridParts(iso)
  const name = MONTHS_LONG[p.month - 1] ?? ''
  return { key: p.date.slice(0, 7), label: `${name.charAt(0).toUpperCase()}${name.slice(1)} ${p.year}` }
}

/** Day block of lists and previews: weekday, number and month (`hoy` replaces the weekday). */
export function dateBlock(iso: string): { weekday: string; day: number; month: string; today: boolean } {
  const p = madridParts(iso)
  const today = p.date === todayMadrid()
  return { weekday: today ? 'hoy' : (WEEKDAYS[p.weekday] ?? ''), day: p.day, month: MONTHS_SHORT[p.month - 1] ?? '', today }
}

/** Same rule as `guide.event_is_past` (used while editing, before the row exists). */
export function isPastEvent(startsAt: string, endsAt: string | null, allDay: boolean): boolean {
  if (endsAt && !allDay) return new Date(endsAt).getTime() < Date.now()
  return madridParts(endsAt ?? startsAt).date < todayMadrid()
}

export const monthPath = (iso: string) => `/agenda/${madridParts(iso).date.slice(0, 7)}`

// Short formats ----------------------------------------------------------------------------------
export function shortDay(iso: string): string {
  const p = madridParts(iso)
  return `${p.day} ${MONTHS_SHORT[p.month - 1]}`
}
export function fullDay(iso: string): string {
  return `${shortDay(iso)} ${madridParts(iso).year}`
}
export function fullDateTime(iso: string): string {
  return `${fullDay(iso)}, ${madridParts(iso).time}`
}
/** `hoy`, `hace 1 día`, `hace 3 días` (calendar days in Madrid). */
export function agoLabel(iso: string): string {
  const a = madridParts(iso)
  const b = madridParts(new Date())
  const days = Math.round((Date.UTC(b.year, b.month - 1, b.day) - Date.UTC(a.year, a.month - 1, a.day)) / 86_400_000)
  return days <= 0 ? 'hoy' : `hace ${days} ${days === 1 ? 'día' : 'días'}`
}
