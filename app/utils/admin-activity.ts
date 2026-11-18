import { madridToIso, todayMadrid } from '~/utils/admin-madrid'

/**
 * Actividad (F6.18, docs/design/admin/actividad.html): the audit log of the panel. The server (`admin_activity_list`)
 * sanitizes labels and details of private tables, so nothing here has to hide personal data. This file holds the
 * contract (parse), the tabs, the period and the URL filters; the sentences live in `admin-activity-text.ts`.
 */
export type ActivityGroup = 'content' | 'pub' | 'mod' | 'exp' | 'sys'
export type ActivityTab = 'all' | ActivityGroup
export type ActivityActor = 'admin' | 'agent' | 'system' | 'person'

export const ACTIVITY_TABS: readonly { value: ActivityTab; slug: string; label: string }[] = [
  { value: 'all', slug: 'todo', label: 'Todo' },
  { value: 'content', slug: 'contenido', label: 'Contenido' },
  { value: 'pub', slug: 'publicaciones', label: 'Publicaciones' },
  { value: 'mod', slug: 'moderacion', label: 'Moderación' },
  { value: 'exp', slug: 'exportaciones', label: 'Exportaciones' },
  { value: 'sys', slug: 'sistema', label: 'Sistema' },
]
export const tabFromSlug = (slug: unknown): ActivityTab => ACTIVITY_TABS.find((t) => t.slug === slug)?.value ?? 'all'
export const tabSlug = (tab: ActivityTab) => ACTIVITY_TABS.find((t) => t.value === tab)?.slug ?? 'todo'

export interface ActivityTarget {
  route: string | null
  query: Record<string, string> | null
  exists: boolean
}
export interface ActivityRecord {
  id: number
  occurredAt: string
  action: string
  table: string
  entityId: string | null
  /** Never an email: the server nulls it for private tables. */
  label: string | null
  group: ActivityGroup
  actor: ActivityActor
  itemCategory: string | null
  changed: string[]
  details: Record<string, unknown>
  hasSnapshot: boolean
  target: ActivityTarget
}
export interface ActivityCursor {
  at: string
  id: number
}
export interface ActivityPage {
  entries: ActivityRecord[]
  next: ActivityCursor | null
  /** Per tab; they ignore the tab but respect period, search and the rest of the filters. */
  counts: Record<ActivityTab, number>
}

const GROUPS: readonly string[] = ['content', 'pub', 'mod', 'exp', 'sys']
const ACTORS: readonly string[] = ['admin', 'agent', 'system', 'person']
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)
const obj = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {})
const text = (v: unknown) => (typeof v === 'string' && v ? v : null)

function parseTarget(raw: unknown): ActivityTarget {
  const t = obj(raw)
  const query = obj(t.query)
  const pairs = Object.entries(query).filter((e): e is [string, string] => typeof e[1] === 'string')
  return { route: text(t.route), query: pairs.length ? Object.fromEntries(pairs) : null, exists: t.exists === true }
}

/** Validates the jsonb of `admin_activity_list` into a typed page. */
export function parseActivityPage(raw: unknown): ActivityPage {
  const r = obj(raw)
  const counts = obj(r.counts)
  const cursor = obj(r.next_cursor)
  return {
    entries: (Array.isArray(r.entries) ? r.entries : []).map((item): ActivityRecord => {
      const e = obj(item)
      const group = String(e.group)
      const actor = String(e.actor)
      return {
        id: num(e.id),
        occurredAt: String(e.occurred_at ?? ''),
        action: String(e.action ?? ''),
        table: String(e.entity_table ?? ''),
        entityId: text(e.entity_id),
        label: text(e.label),
        group: (GROUPS.includes(group) ? group : 'content') as ActivityGroup,
        actor: (ACTORS.includes(actor) ? actor : 'system') as ActivityActor,
        itemCategory: text(e.item_category),
        changed: Array.isArray(e.changed_columns) ? e.changed_columns.filter((c): c is string => typeof c === 'string') : [],
        details: obj(e.details),
        hasSnapshot: e.has_snapshot === true,
        target: parseTarget(e.target),
      }
    }),
    next: typeof cursor.occurred_at === 'string' ? { at: cursor.occurred_at, id: num(cursor.id) } : null,
    counts: { all: num(counts.all), content: num(counts.content), pub: num(counts.pub), mod: num(counts.mod), exp: num(counts.exp), sys: num(counts.sys) },
  }
}

// ---- Period and filters (URL: ?vista=&q=&periodo=&desde=&hasta=) ----

export type ActivityPeriod = '7' | '30' | '90' | '365' | 'all' | 'custom'
export const ACTIVITY_PERIODS: readonly { value: Exclude<ActivityPeriod, 'custom'>; slug: string | undefined; label: string }[] = [
  { value: '7', slug: '7', label: 'Últimos 7 días' },
  { value: '30', slug: undefined, label: 'Últimos 30 días' },
  { value: '90', slug: '90', label: 'Últimos 90 días' },
  { value: '365', slug: '365', label: 'Último año' },
  { value: 'all', slug: 'todo', label: 'Todo el registro' },
]
export const SEARCH_MIN = 2
export const SEARCH_MAX = 100
const DATE = /^\d{4}-\d{2}-\d{2}$/

export interface ActivityFilters {
  tab: ActivityTab
  search: string
  period: ActivityPeriod
  /** `YYYY-MM-DD`, only in `custom`. */
  from: string
  to: string
}

/** Reads the filters of the URL query; a reversed custom range drops `hasta` so the server never gets 22023. */
export function filtersFromQuery(get: (key: string) => string): ActivityFilters {
  const from = DATE.test(get('desde')) ? get('desde') : ''
  const rawTo = DATE.test(get('hasta')) ? get('hasta') : ''
  const to = from && rawTo && rawTo < from ? '' : rawTo
  const preset = ACTIVITY_PERIODS.find((p) => p.slug && p.slug === get('periodo'))
  return {
    tab: tabFromSlug(get('vista')),
    search: get('q').slice(0, SEARCH_MAX),
    period: from || to ? 'custom' : (preset?.value ?? '30'),
    from,
    to,
  }
}

/** The search only goes to the server with 2 to 100 characters (below that it would be a 22023). */
export const searchTerm = (search: string) => (search.trim().length >= SEARCH_MIN ? search.trim().slice(0, SEARCH_MAX) : undefined)
export const hasActivityFilters = (f: ActivityFilters) => !!searchTerm(f.search) || f.period !== '30'

function addDaysKey(key: string, days: number) {
  const d = new Date(`${key}T12:00:00Z`)
  d.setUTCDate(d.getUTCDate() + days)
  return d.toISOString().slice(0, 10)
}

/** `p_from` (included) and `p_to` (excluded) of the period, in Madrid time. Presets end now; a custom `hasta` counts whole. */
export function periodRange(f: ActivityFilters, today = todayMadrid()): { from?: string; to?: string } {
  if (f.period === 'custom') return { from: f.from ? madridToIso(f.from) : undefined, to: f.to ? madridToIso(addDaysKey(f.to, 1)) : undefined }
  if (f.period === 'all') return {}
  return { from: madridToIso(addDaysKey(today, -(Number(f.period) - 1))) }
}

export interface ActivityArgs {
  p_group?: string
  p_search?: string
  p_from?: string
  p_to?: string
  p_limit: number
  p_cursor_at?: string
  p_cursor_id?: number
}
export const ACTIVITY_PAGE_SIZE = 50

export function activityArgs(f: ActivityFilters, cursor?: ActivityCursor, today?: string): ActivityArgs {
  const { from, to } = periodRange(f, today)
  return {
    p_group: f.tab === 'all' ? undefined : f.tab,
    p_search: searchTerm(f.search),
    p_from: from,
    p_to: to,
    p_limit: ACTIVITY_PAGE_SIZE,
    p_cursor_at: cursor?.at,
    p_cursor_id: cursor?.id,
  }
}

export const periodLabel = (f: ActivityFilters) => {
  if (f.period !== 'custom') return ACTIVITY_PERIODS.find((p) => p.value === f.period)?.label ?? 'Últimos 30 días'
  const d = (key: string) => adminDate(key)
  return f.from && f.to ? `${d(f.from)} – ${d(f.to)}` : f.from ? `Desde el ${d(f.from)}` : `Hasta el ${d(f.to)}`
}

// ---- Day groups ----

export interface ActivityDay {
  key: string
  label: string
  entries: ActivityRecord[]
}

/** «Hoy», «Ayer», «2 oct» (with the year when it is not this one). Entries arrive newest first. */
export function groupByDay(entries: readonly ActivityRecord[], now = new Date()): ActivityDay[] {
  const today = dayKey(now)
  const yesterday = addDaysKey(today, -1)
  const days: ActivityDay[] = []
  for (const entry of entries) {
    const key = dayKey(entry.occurredAt)
    const last = days[days.length - 1]
    if (last?.key === key) last.entries.push(entry)
    else {
      const long = adminDate(key)
      const label = key === today ? 'Hoy' : key === yesterday ? 'Ayer' : key.slice(0, 4) === today.slice(0, 4) ? long.replace(/ \d{4}$/, '') : long
      days.push({ key, label, entries: [entry] })
    }
  }
  return days
}
