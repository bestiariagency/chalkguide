import { listEvents } from '~/services/events'

/** Approved events in the next `days` days (agenda hub, §6: ~60 days). */
export function useUpcomingEvents(days = 60) {
  const start = startOfToday()
  const end = new Date(start.getTime() + days * 86_400_000)
  return useGuideData(`events:upcoming:${start.toISOString().slice(0, 10)}:${days}`, (db, locale) =>
    listEvents(db, locale, { from: start.toISOString(), to: end.toISOString() }),
  )
}

/** Approved events of one calendar month (agenda `/agenda/aaaa-mm`). */
export function useEventsOfMonth(month: MaybeRefOrGetter<Date>) {
  const range = () => {
    const start = toValue(month)
    return { from: start.toISOString(), to: addMonths(start, 1).toISOString() }
  }
  return useGuideData(
    () => `events:month-of:${toMonthKey(toValue(month))}`,
    (db, locale) => listEvents(db, locale, { ...range(), limit: 100 }),
  )
}

/** Next approved events from today (home carousel picks the first one that is not cancelled). */
export function useNextEvents() {
  const start = startOfToday()
  return useGuideData(`events:next:${start.toISOString().slice(0, 10)}`, (db, locale) =>
    listEvents(db, locale, { from: start.toISOString(), limit: 5 }),
  )
}
