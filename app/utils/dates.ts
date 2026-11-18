/** Date helpers. Dates are ISO in the DB; formatting is per locale in the UI. */
export function startOfToday(): Date {
  const now = new Date()
  return new Date(now.getFullYear(), now.getMonth(), now.getDate())
}

export function startOfNextMonth(from: Date): Date {
  return new Date(from.getFullYear(), from.getMonth() + 1, 1)
}

const TIME_ZONE = 'Europe/Madrid'

/** Site locale codes → full language tags (nuxt.config `language`): en is en-GB, not en-US. */
export function intlLocale(locale: string): string {
  return locale === 'en' ? 'en-GB' : locale === 'es' ? 'es-ES' : locale
}

/** "1 sept 2026" / "1 Sept 2026": short month in text for price dates. */
export const SHORT_MONTH_DATE: Intl.DateTimeFormatOptions = {
  day: 'numeric',
  month: 'short',
  year: 'numeric',
}

export function formatDate(
  iso: string,
  locale: string,
  options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'long', year: 'numeric' },
): string {
  return new Intl.DateTimeFormat(intlLocale(locale), { timeZone: TIME_ZONE, ...options }).format(new Date(iso))
}

/** "SÁB 10" / "SAT 10" for the chalkboard. */
export function formatBoardDay(iso: string, locale: string): string {
  const date = new Date(iso)
  const weekday = new Intl.DateTimeFormat(intlLocale(locale), { timeZone: TIME_ZONE, weekday: 'short' })
    .format(date)
    .replace('.', '')
  const day = new Intl.DateTimeFormat(intlLocale(locale), { timeZone: TIME_ZONE, day: 'numeric' }).format(date)
  return `${weekday} ${day}`.toUpperCase()
}

export function formatMonthName(date: Date, locale: string): string {
  const name = new Intl.DateTimeFormat(intlLocale(locale), { timeZone: TIME_ZONE, month: 'long' }).format(date)
  return name.charAt(0).toUpperCase() + name.slice(1)
}

/** "Lunes–viernes", "Sábado y domingo": weekday labels for a group of days (0 = Monday). */
export function formatWeekdayGroup(indices: number[], locale: string): string {
  const name = (i: number) =>
    new Intl.DateTimeFormat(intlLocale(locale), { timeZone: 'UTC', weekday: 'long' }).format(
      new Date(Date.UTC(2024, 0, 1 + i)), // 2024-01-01 is a Monday
    )
  const first = indices[0]
  const last = indices.at(-1)
  if (first === undefined || last === undefined) return ''
  const label =
    indices.length >= 3
      ? `${name(first)}–${name(last)}`
      : new Intl.ListFormat(intlLocale(locale), { type: 'conjunction' }).format(indices.map(name))
  return label.charAt(0).toUpperCase() + label.slice(1)
}

/** "21.09.26": compact numeric date in mono text (blog lists, article byline). */
export function formatShortDate(iso: string, locale: string): string {
  return formatDate(iso, locale, { day: '2-digit', month: '2-digit', year: '2-digit' }).replaceAll(
    '/',
    '.',
  )
}

/** "19:00" in the site time zone. */
export function formatTime(iso: string, locale: string): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: TIME_ZONE,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(new Date(iso))
}

/** "2026-10" for the month an ISO instant falls in (site time zone). */
export function monthKey(iso: string): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TIME_ZONE, year: 'numeric', month: '2-digit' }).format(
    new Date(iso),
  )
}

/** Parses "aaaa-mm" (month 01–12) into its first day at local midnight; null if invalid. */
export function parseMonthKey(key: string): Date | null {
  const match = /^(\d{4})-(0[1-9]|1[0-2])$/.exec(key)
  return match ? new Date(Number(match[1]), Number(match[2]) - 1, 1) : null
}

export function toMonthKey(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
}

export function addMonths(date: Date, months: number): Date {
  return new Date(date.getFullYear(), date.getMonth() + months, 1)
}

/** "octubre de 2026" / "October 2026". */
export function formatMonthYear(date: Date, locale: string): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    timeZone: TIME_ZONE,
    month: 'long',
    year: 'numeric',
  }).format(new Date(date.getFullYear(), date.getMonth(), 15))
}

/** Agenda months reachable by URL: from `back` months ago to `ahead` months ahead (README §6). */
export function isMonthInRange(month: Date, back = 12, ahead = 12): boolean {
  const now = startOfToday()
  const first = addMonths(new Date(now.getFullYear(), now.getMonth(), 1), -back)
  const last = addMonths(new Date(now.getFullYear(), now.getMonth(), 1), ahead)
  return month >= first && month <= last
}
