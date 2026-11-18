/** Design system: a verified datum older than 6 months is shown as "old" (dashed badge). */
export const STALE_AFTER_MONTHS = 6

export function isStale(iso: string, now: Date = new Date()): boolean {
  const limit = new Date(now)
  limit.setMonth(limit.getMonth() - STALE_AFTER_MONTHS)
  return new Date(iso) < limit
}

/** Whole months elapsed since an ISO date (never negative). */
export function monthsSince(iso: string, now: Date = new Date()): number {
  const from = new Date(iso)
  let months = (now.getFullYear() - from.getFullYear()) * 12 + now.getMonth() - from.getMonth()
  if (now.getDate() < from.getDate()) months--
  return Math.max(0, months)
}
