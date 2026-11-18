import type { EventType, GuideEvent } from '~/types/domain'

export interface EventMonth {
  key: string
  /** First day of the month (local), for the board title. */
  date: Date
  events: GuideEvent[]
}

/** Groups events (already sorted by date) by month, keeping chronological order. */
export function groupEventsByMonth(events: GuideEvent[]): EventMonth[] {
  const months: EventMonth[] = []
  for (const event of events) {
    const key = monthKey(event.startsAt)
    let month = months.at(-1)
    if (month?.key !== key) {
      month = { key, date: parseMonthKey(key) ?? new Date(event.startsAt), events: [] }
      months.push(month)
    }
    month.events.push(event)
  }
  return months
}

/** Event types present in a list, in a stable display order. */
const TYPE_ORDER: EventType[] = ['competition', 'course', 'workshop', 'social', 'outing', 'other']
export function presentEventTypes(events: GuideEvent[]): EventType[] {
  const present = new Set(events.map((event) => event.type))
  return TYPE_ORDER.filter((type) => present.has(type))
}
