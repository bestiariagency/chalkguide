const TZ = 'Europe/Madrid'
const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)
const asObject = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {})

export interface ActivityEntry {
  id: number
  occurredAt: string
  action: string
  table: string
  label: string | null
  changedCount: number
  /** `export` entries: what was exported (module from `export_{module}`, details from the log). */
  exported?: { module: string; format: string; rows: number }
}

export interface ByCategory {
  gym: number
  resoler: number
  shoe: number
}

const optNum = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : null)
function byCategory(v: unknown): ByCategory | null {
  const o = asObject(v)
  return 'gym' in o || 'resoler' in o || 'shoe' in o ? { gym: num(o.gym), resoler: num(o.resoler), shoe: num(o.shoe) } : null
}

export interface DashboardStats {
  articles: { published: number; scheduled: number; draft: number }
  subscribers: { active: number; pending: number; total: number; new30: number; newPrev30: number; unsub30: number }
  reviews: { pending: number; hidden: number; last30: number }
  itemsStale: number
  eventsDrafts: number
  mediaWithoutAlt: number
  /** Optional fields of the stats (D55): `null` when the backend does not send them, so the row drops that part. */
  eventsDraftsNextAt: string | null
  itemsStaleByCategory: ByCategory | null
  reviewPhotosPending: number | null
  itemsImportedUnpublished: number | null
  itemsImportedByCategory: ByCategory | null
  userReviewsLowSince: number | null
  mediaWithoutAltInUse: number | null
  eventsDraftsDuplicates: number | null
  itemsPublished: number | null
  itemsPublishedByCategory: ByCategory | null
  itemsTotalByCategory: ByCategory | null
  /** Nightly review-photo cleanup (F6.19): HTTP status of its last call and when it was checked; `null` = never checked or expired. */
  cleanupLastStatus: number | null
  cleanupCheckedAt: string | null
  nextScheduled: { id: string; title: string; publishedAt: string }[]
  activity: ActivityEntry[]
}

/** Tables whose label can be personal data (emails, reader names/text): never shown. */
const EXPORTED: Record<string, [one: string, many: string]> = {
  articles: ['artículo', 'artículos'],
  items: ['ficha', 'fichas'],
  user_reviews: ['opinión', 'opiniones'],
  subscribers: ['suscriptor', 'suscriptores'],
  events: ['evento', 'eventos'],
}
function exportedOf(table: string, details: Record<string, unknown>): ActivityEntry['exported'] {
  return { module: table.replace(/^export_/, ''), format: typeof details.format === 'string' ? details.format.toUpperCase() : '', rows: num(details.row_count) }
}

/** Validates the jsonb of `admin_dashboard_stats()` into a typed shape (defaults to 0 / empty). */
export function parseDashboardStats(raw: unknown): DashboardStats {
  const r = asObject(raw)
  const by = asObject(r.articles_by_status)
  const list = (v: unknown) => (Array.isArray(v) ? v.map(asObject) : [])
  return {
    articles: { published: num(by.published), scheduled: num(by.scheduled), draft: num(by.draft) },
    subscribers: {
      active: num(r.subscribers_active),
      pending: num(r.subscribers_pending),
      total: num(r.subscribers_total),
      new30: num(r.subscribers_new_30d),
      newPrev30: num(r.subscribers_new_prev_30d),
      unsub30: num(r.unsubscribed_30d),
    },
    reviews: { pending: num(r.user_reviews_pending), hidden: num(r.user_reviews_hidden), last30: num(r.user_reviews_30d) },
    itemsStale: num(r.items_stale),
    eventsDrafts: num(r.events_drafts),
    mediaWithoutAlt: num(r.media_without_alt),
    eventsDraftsNextAt: typeof r.events_drafts_next_at === 'string' ? r.events_drafts_next_at : null,
    itemsStaleByCategory: byCategory(r.items_stale_by_category),
    reviewPhotosPending: optNum(r.review_photos_pending),
    itemsImportedUnpublished: optNum(r.items_imported_unpublished),
    itemsImportedByCategory: byCategory(r.items_imported_unpublished_by_category),
    userReviewsLowSince: optNum(r.user_reviews_low_since),
    mediaWithoutAltInUse: optNum(r.media_without_alt_in_use),
    eventsDraftsDuplicates: optNum(r.events_drafts_duplicates),
    itemsPublished: optNum(r.items_published),
    itemsPublishedByCategory: byCategory(r.items_published_by_category),
    itemsTotalByCategory: byCategory(r.items_total_by_category),
    cleanupLastStatus: optNum(r.cleanup_last_status),
    cleanupCheckedAt: typeof r.cleanup_checked_at === 'string' ? r.cleanup_checked_at : null,
    nextScheduled: list(r.articles_scheduled_next).map((a) => ({
      id: String(a.id),
      title: String(a.title_es ?? ''),
      publishedAt: String(a.published_at ?? ''),
    })),
    activity: list(r.recent_activity).map((a) => {
      const table = String(a.entity_table ?? '')
      return {
        id: num(a.id),
        occurredAt: String(a.occurred_at ?? ''),
        action: String(a.action ?? ''),
        table,
        label: typeof a.entity_label === 'string' ? a.entity_label : null,
        changedCount: Array.isArray(a.changed_columns) ? a.changed_columns.length : 0,
        exported: a.action === 'export' ? exportedOf(table, asObject(a.details)) : undefined,
      }
    }),
  }
}

/** "+62", "−4", "0". */
export function signed(n: number): string {
  return n > 0 ? `+${n}` : n < 0 ? `−${Math.abs(n)}` : '0'
}

export function fmtInt(n: number): string {
  return new Intl.NumberFormat('es-ES').format(n)
}

/** «1 fila» / «3 filas» (number formatted es-ES). */
export const countOf = (n: number, one: string, many: string) => `${fmtInt(n)} ${n === 1 ? one : many}`

/** `YYYY-MM-DD` of an instant in Madrid time. */
export function dayKey(value: string | Date): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(typeof value === 'string' ? new Date(value) : value)
}

export const keyToDate = (key: string) => new Date(`${key}T12:00:00`)
export const dateToKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

export function addDays(key: string, days: number): string {
  const d = keyToDate(key)
  d.setDate(d.getDate() + days)
  return dateToKey(d)
}

export function hhmm(iso: string): string {
  return new Intl.DateTimeFormat('es-ES', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(iso))
}

export function formatDayLong(key: string): string {
  const text = new Intl.DateTimeFormat('es-ES', { weekday: 'long', day: 'numeric', month: 'long' }).format(keyToDate(key))
  return text.charAt(0).toUpperCase() + text.slice(1)
}

export function shortDate(iso: string): string {
  return adminDate(iso)
}

export function monthTitle(month: string): string {
  const text = new Intl.DateTimeFormat('es-ES', { month: 'long', year: 'numeric' }).format(keyToDate(`${month}-01`)).replace(' de ', ' ')
  return text.charAt(0).toUpperCase() + text.slice(1)
}

export function greeting(now = new Date()): string {
  const h = now.getHours()
  return h < 6 ? 'Buenas noches' : h < 13 ? 'Buenos días' : h < 21 ? 'Buenas tardes' : 'Buenas noches'
}

/** Polyline points for a 120x28 sparkline. */
export function sparkPoints(values: number[]): string {
  if (values.length < 2) return ''
  const max = Math.max(...values)
  const min = Math.min(...values)
  const span = max - min || 1
  return values.map((v, i) => `${Math.round((i / (values.length - 1)) * 120)},${Math.round(25 - ((v - min) / span) * 22)}`).join(' ')
}

const ENTITY: Record<string, string> = {
  articles: 'un artículo',
  pages: 'una página',
  items: 'una ficha',
  events: 'un evento',
  media: 'un medio',
  article_categories: 'una categoría',
  authors: 'un autor',
  user_reviews: 'una opinión',
  subscribers: 'un suscriptor',
}

/** Where an activity entry leads. */
export function activityLink(table: string): string | null {
  const slug: Record<string, string> = {
    articles: 'articulos',
    article_categories: 'categorias',
    authors: 'autores',
    pages: 'paginas',
    events: 'agenda',
    media: 'medios',
    user_reviews: 'opiniones',
    subscribers: 'suscriptores',
    items: 'rocodromos',
    export_articles: 'articulos',
    export_items: 'rocodromos',
    export_user_reviews: 'opiniones',
    export_subscribers: 'suscriptores',
    export_events: 'agenda',
  }
  return slug[table] ? adminPath(slug[table]) : null
}

/** Human sentence for an activity row; no personal data (private tables carry no label). */
export function activityText(entry: ActivityEntry): { lead: string; label: string | null } {
  const what = ENTITY[entry.table] ?? 'un elemento'
  const verbs: Record<string, string> = {
    insert: `Creaste ${what}`,
    update: `Editaste ${what}`,
    delete: `Borraste ${what}`,
    draft_publish: `Publicaste los cambios de ${what}`,
    draft_discard: `Descartaste los cambios de ${what}`,
    unpublish: `Despublicaste ${what}`,
    export: 'Hiciste una exportación',
    import: 'Hiciste una importación',
    import_undo: 'Deshiciste una importación',
  }
  const x = entry.exported
  if (x) {
    const [one, many] = EXPORTED[x.module] ?? ['fila', 'filas']
    return { lead: `Exportaste ${countOf(x.rows, one, many)}${x.format ? ` · ${x.format}` : ''}`, label: null }
  }
  return { lead: verbs[entry.action] ?? 'Cambio registrado', label: entry.label }
}
