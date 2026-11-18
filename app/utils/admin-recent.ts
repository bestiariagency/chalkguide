import type { SearchKind } from './admin-search'

/** «Recientes» of the ⌘K palette: the last items opened, kept on this device only (`localStorage`, README §15.3). */
export const RECENT_KEY = 'cg-admin-recent'
const MAX_RECENT = 5
const KINDS: readonly string[] = ['article', 'gym', 'resoler', 'shoe', 'page', 'event', 'news', 'media']

export interface RecentItem {
  kind: SearchKind
  /** Page: its `key`; the rest: the row id. */
  id: string
  title: string
  openedAt: number
}

export function readRecent(): RecentItem[] {
  try {
    const parsed: unknown = JSON.parse(readStorage(RECENT_KEY) ?? '[]')
    if (!Array.isArray(parsed)) return []
    return parsed
      .filter((r): r is RecentItem => !!r && typeof r === 'object' && KINDS.includes(r.kind) && typeof r.id === 'string' && typeof r.title === 'string')
      .slice(0, MAX_RECENT)
  } catch {
    return []
  }
}

export function pushRecent(item: Omit<RecentItem, 'openedAt'>): RecentItem[] {
  const next = [{ ...item, openedAt: Date.now() }, ...readRecent().filter((r) => !(r.kind === item.kind && r.id === item.id))].slice(0, MAX_RECENT)
  writeStorage(RECENT_KEY, JSON.stringify(next))
  return next
}

export const clearRecent = () => removeStorage(RECENT_KEY)
