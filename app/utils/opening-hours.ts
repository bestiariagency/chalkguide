import type { Json } from '~/types/database.types'

/** guide.gyms.opening_hours: `{ "mon": [["10:00","23:00"]], ... }` (docs/data-model.md). */
export const WEEKDAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const
export type Weekday = (typeof WEEKDAYS)[number]
export type OpeningHours = Partial<Record<Weekday, [string, string][]>>

const TIME = /^(\d{1,2}):(\d{2})$/

const OPENING = /^([01]?\d|2[0-3]):[0-5]\d$/
const CLOSING = /^(([01]?\d|2[0-3]):[0-5]\d|24:00)$/

export function minutes(time: string): number | null {
  const match = TIME.exec(time)
  return match ? Number(match[1]) * 60 + Number(match[2]) : null
}

/** Valid opening time (`H:MM`/`HH:MM`, 00:00–23:59). */
export const isOpeningTime = (time: string) => OPENING.test(time)

/** Valid closing time: as an opening time, plus `24:00` (midnight). */
export const isClosingTime = (time: string) => CLOSING.test(time)

/** Closing time as stored: trimmed, and midnight written `00:00` becomes `24:00`. */
export function closingValue(time: string): string {
  const t = time.trim()
  return /^0?0:00$/.test(t) ? '24:00' : t
}

/** Validates the jsonb defensively: anything unexpected is ignored, never thrown. */
export function parseOpeningHours(value: Json | null | undefined): OpeningHours {
  const result: OpeningHours = {}
  if (!value || typeof value !== 'object' || Array.isArray(value)) return result
  for (const day of WEEKDAYS) {
    const slots = value[day]
    if (!Array.isArray(slots)) continue
    const valid = slots.filter(
      (slot): slot is [string, string] =>
        Array.isArray(slot) &&
        typeof slot[0] === 'string' &&
        typeof slot[1] === 'string' &&
        minutes(slot[0]) !== null &&
        minutes(slot[1]) !== null,
    )
    if (valid.length) result[day] = valid
  }
  return result
}

/** Earliest opening time of the week (minutes since 00:00), or null without schedule. */
export function earliestOpening(value: Json | null | undefined): number | null {
  const starts = Object.values(parseOpeningHours(value)).flatMap((slots) =>
    slots.map(([open]) => minutes(open)),
  )
  const valid = starts.filter((m): m is number => m !== null)
  return valid.length ? Math.min(...valid) : null
}

export interface HoursRow {
  days: Weekday[]
  slots: string
}

/** Groups consecutive days with identical hours ("mon–fri 07:00–23:30"). */
export function groupHours(hours: OpeningHours): HoursRow[] {
  const rows: HoursRow[] = []
  for (const day of WEEKDAYS) {
    const slots = hours[day]
    if (!slots) continue
    const label = slots.map(([open, close]) => `${open}–${close}`).join(' · ')
    const last = rows.at(-1)
    if (last && last.slots === label) last.days.push(day)
    else rows.push({ days: [day], slots: label })
  }
  return rows
}
