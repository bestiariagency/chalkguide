import type { GuideEvent } from '~/types/domain'
import { formatDate, intlLocale } from './dates'

export interface EventDay {
  /** "7" or "5–6" (several days). */
  day: string
  /** "SÁB" or "Sáb y dom" (several days). */
  weekday: string
  /** "NOV" (start month). */
  month: string
  multi: boolean
}

const part = (iso: string, locale: string, options: Intl.DateTimeFormatOptions) =>
  formatDate(iso, locale, options).replace('.', '')

/** Day, weekday and month of an event for the poster tile (README §13.7), Madrid time. */
export function eventDay(event: Pick<GuideEvent, 'startsAt' | 'endsAt'>, locale: string): EventDay {
  const { startsAt, endsAt } = event
  const month = part(startsAt, locale, { month: 'short' }).toUpperCase()
  const startDay = part(startsAt, locale, { day: 'numeric' })
  const startWeekday = part(startsAt, locale, { weekday: 'short' })
  const sameDay = !endsAt || formatDate(startsAt, locale) === formatDate(endsAt, locale)
  if (!endsAt || sameDay) return { day: startDay, weekday: startWeekday.toUpperCase(), month, multi: false }

  const endDay = part(endsAt, locale, { day: 'numeric' })
  const endWeekday = part(endsAt, locale, { weekday: 'short' })
  const consecutive = new Date(endsAt).getTime() - new Date(startsAt).getTime() < 2 * 86_400_000
  const cap = (text: string) => text.charAt(0).toUpperCase() + text.slice(1)
  const weekday = consecutive
    ? new Intl.ListFormat(intlLocale(locale), { type: 'conjunction' }).format([cap(startWeekday), endWeekday])
    : `${cap(startWeekday)}–${endWeekday}`
  return { day: `${startDay}–${endDay}`, weekday, month, multi: true }
}
