import type { CalendarArticleRow, CalendarEventRow } from '~/services/admin/dashboard'

export type CalendarKind = 'pub' | 'sched' | 'rev' | 'agenda' | 'agenda-todo'
export interface CalendarItem {
  id: string
  kind: CalendarKind
  title: string
  /** Time (scheduled / agenda) or null. */
  time: string | null
  meta: string | null
  to: string
}

export interface CalendarDay {
  key: string
  day: number
  outside: boolean
  today: boolean
  /** Before today (the 2-week view paints it on `side`). */
  past?: boolean
  items: CalendarItem[]
}

/** Items per day key: articles (published, scheduled, published with changes) and agenda events. */
export function buildCalendarItems(
  articles: CalendarArticleRow[],
  events: CalendarEventRow[],
  revisedIds: ReadonlySet<string>,
): Map<string, CalendarItem[]> {
  const map = new Map<string, CalendarItem[]>()
  const push = (key: string, item: CalendarItem) => map.set(key, [...(map.get(key) ?? []), item])
  for (const a of articles) {
    const kind: CalendarKind = a.status === 'scheduled' ? 'sched' : revisedIds.has(a.id) ? 'rev' : 'pub'
    push(dayKey(a.published_at), {
      id: a.id,
      kind,
      title: a.title_es,
      time: kind === 'sched' ? hhmm(a.published_at) : null,
      meta: a.category,
      to: adminPath(`articulos/${a.id}`),
    })
  }
  for (const e of events) {
    push(dayKey(e.starts_at), {
      id: e.id,
      kind: e.status === 'draft' ? 'agenda-todo' : 'agenda',
      title: e.title_es,
      time: null,
      meta: e.location_text,
      to: adminPath('agenda'),
    })
  }
  return map
}

/** Month grid Monday to Sunday, 5 or 6 weeks. `month` is `YYYY-MM`. */
export function buildMonthGrid(month: string, today: string, items: Map<string, CalendarItem[]>): CalendarDay[] {
  const first = keyToDate(`${month}-01`)
  const lead = (first.getDay() + 6) % 7
  const daysInMonth = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
  const weeks = Math.ceil((lead + daysInMonth) / 7)
  const start = addDays(`${month}-01`, -lead)
  return Array.from({ length: weeks * 7 }, (_, i) => {
    const key = addDays(start, i)
    return { key, day: Number(key.slice(8)), outside: !key.startsWith(month), today: key === today, past: key < today, items: items.get(key) ?? [] }
  })
}

export type CalendarView = '2w' | 'month'
export const CALENDAR_VIEW_KEY = 'cg-admin-cal-view'

/** Monday (day key) of the week containing `key`. */
export function weekStart(key: string): string {
  return addDays(key, -((keyToDate(key).getDay() + 6) % 7))
}

/** Two weeks, Monday to Sunday, from `start` (a Monday). */
export function buildWeeksGrid(start: string, today: string, items: Map<string, CalendarItem[]>): CalendarDay[] {
  return Array.from({ length: 14 }, (_, i) => {
    const key = addDays(start, i)
    return { key, day: Number(key.slice(8)), outside: false, today: key === today, past: key < today, items: items.get(key) ?? [] }
  })
}

/** Date window [from, to) (day keys) the calendar needs: the visible range plus the 14-day list that starts at `listFrom`. */
export function calendarWindow(view: CalendarView, month: string, start: string, listFrom: string): { from: string; to: string } {
  const range =
    view === 'month'
      ? (() => {
          const grid = buildMonthGrid(month, listFrom, new Map())
          return { from: grid[0]!.key, to: addDays(grid[grid.length - 1]!.key, 1) }
        })()
      : { from: start, to: addDays(start, 14) }
  const listTo = addDays(listFrom, 14)
  return { from: range.from < listFrom ? range.from : listFrom, to: range.to > listTo ? range.to : listTo }
}

const short = (key: string, withYear: boolean) =>
  new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'short', ...(withYear ? { year: 'numeric' } : {}) }).format(keyToDate(key)).replace(/\./g, '')

/** "2–15 nov 2026", "30 nov – 13 dic 2026", "30 dic 2026 – 12 ene 2027". */
export function rangeTitle(start: string): string {
  const end = addDays(start, 13)
  const [a, b] = [keyToDate(start), keyToDate(end)]
  if (a.getFullYear() !== b.getFullYear()) return `${short(start, true)} – ${short(end, true)}`
  if (a.getMonth() !== b.getMonth()) return `${short(start, false)} – ${short(end, true)}`
  return `${a.getDate()}–${short(end, true)}`
}

/** "jue 5". */
export function weekdayDay(key: string): string {
  const name = new Intl.DateTimeFormat('es-ES', { weekday: 'short' }).format(keyToDate(key)).replace(/\./g, '')
  return `${name} ${Number(key.slice(8))}`
}

export function shiftMonth(month: string, delta: number): string {
  const d = keyToDate(`${month}-01`)
  d.setMonth(d.getMonth() + delta)
  return dateToKey(d).slice(0, 7)
}

/** The 14 days from `start` that have items (a day without anything is not listed). */
export function buildUpcoming(start: string, today: string, items: Map<string, CalendarItem[]>): CalendarDay[] {
  return Array.from({ length: 14 }, (_, i) => addDays(start, i))
    .filter((key) => items.has(key))
    .map((key) => ({ key, day: Number(key.slice(8)), outside: false, today: key === today, past: key < today, items: items.get(key) ?? [] }))
}
