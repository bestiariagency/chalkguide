import { altPublishMessage } from '~/utils/content-alt'
import type { Database } from '~/types/database.types'

type ArticleStatus = Database['guide']['Enums']['article_status']

/** Row of the articles list: article + category name + unpublished-changes count. */
export interface AdminArticleRow {
  id: string
  title_es: string
  title_en: string | null
  slug_es: string
  slug_en: string | null
  status: ArticleStatus
  published_at: string | null
  updated_at: string
  is_featured: boolean
  has_en: boolean
  category_id: string
  /** Null = signed by the site author. */
  author_id: string | null
  category_name: string
  category_color: string | null
  /** Number of unpublished changes (0 = no row in `content_drafts`). */
  changes: number
}

/** Value of the authors filter for «signed by the site author» (no `author_id`). */
export const SITE_AUTHOR_FILTER = 'site'

/** Author option of the editor (guide.authors, by sort_order). */
export interface AdminAuthorOption {
  id: string
  name: string
}

export interface AdminCategoryOption {
  id: string
  name: string
  /** `#rrggbb` or null. */
  color: string | null
}

/** What the badge shows: a scheduled article whose date has passed is live, so "published". */
export type ArticleDisplay = 'draft' | 'scheduled' | 'published'

export function articleDisplay(row: Pick<AdminArticleRow, 'status' | 'published_at'>, now = Date.now()): ArticleDisplay {
  if (row.status === 'draft') return 'draft'
  return row.published_at && new Date(row.published_at).getTime() > now ? 'scheduled' : 'published'
}

/** Live = visible on the site (mirrors `guide.article_is_live`). Live articles are edited via drafts, not here. */
export function isArticleLive(row: Pick<AdminArticleRow, 'status' | 'published_at'>, now = Date.now()): boolean {
  return articleDisplay(row, now) === 'published'
}

export type ArticleView = 'all' | 'published' | 'changes' | 'scheduled' | 'draft' | 'no-en'

export const ARTICLE_VIEWS: { value: ArticleView; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'published', label: 'Publicados' },
  { value: 'changes', label: 'Con cambios' },
  { value: 'scheduled', label: 'Programados' },
  { value: 'draft', label: 'Borradores' },
  { value: 'no-en', label: 'Sin EN' },
]

export function matchesView(row: AdminArticleRow, view: ArticleView, now = Date.now()): boolean {
  switch (view) {
    case 'all': return true
    case 'published': return articleDisplay(row, now) === 'published'
    case 'changes': return row.changes > 0
    case 'scheduled': return articleDisplay(row, now) === 'scheduled'
    case 'draft': return row.status === 'draft'
    case 'no-en': return !row.has_en
  }
}

export function countByView(rows: readonly AdminArticleRow[], now = Date.now()): Record<ArticleView, number> {
  const counts = {} as Record<ArticleView, number>
  for (const { value } of ARTICLE_VIEWS) counts[value] = rows.filter((row) => matchesView(row, value, now)).length
  return counts
}

/** Number of unpublished changes in a draft payload: columns of the `article` section + related items. */
export function draftChangeCount(payload: unknown): number {
  if (!payload || typeof payload !== 'object') return 1
  const record = payload as Record<string, unknown>
  const section = record.article
  const columns = section && typeof section === 'object' ? Object.keys(section).length : 0
  return Math.max(1, columns + ('item_ids' in record ? 1 : 0))
}

const MAX_SLUG = 120

/** First free `base`, `base-2`, `base-3`… (max 120 chars, the DB limit). */
export function uniqueSlug(base: string, taken: ReadonlySet<string>): string {
  const clean = base.slice(0, MAX_SLUG).replace(/-+$/, '') || 'articulo'
  if (!taken.has(clean)) return clean
  for (let n = 2; ; n++) {
    const suffix = `-${n}`
    const candidate = `${clean.slice(0, MAX_SLUG - suffix.length).replace(/-+$/, '')}${suffix}`
    if (!taken.has(candidate)) return candidate
  }
}

/** Spanish message for a database/network error from the articles services. */
export function articleErrorMessage(error: unknown, nameOf?: (id: string) => string | undefined): string {
  const alt = altPublishMessage(error, nameOf)
  if (alt) return alt
  const code = (error as { code?: string } | null)?.code
  const message = (error as { message?: string } | null)?.message ?? ''
  if (code === '23505') return 'Ya existe un artículo con esa dirección (slug). Prueba con otra.'
  if (code === '23503' || code === '23001') return 'Falta una categoría válida o hay datos que dependen de este artículo.'
  if (code === '23514' && /check violation:/i.test(message)) return 'Hay un campo que no cumple las reglas del artículo: revisa los marcados en rojo.'
  if (code === '23514') return 'Algún dato no cumple las reglas del artículo (longitud o formato).'
  if (code === '42501') return 'No tienes permiso para hacer esto. Vuelve a entrar al panel.'
  // PT423: the database refuses direct edits of a live article (server clock); LIVE: our own pre-check.
  if (code === 'PT423' || code === 'LIVE') return message && code === 'LIVE' ? message : 'El artículo ya está publicado: se edita con borrador de cambios.'
  if (code === 'PT409') return 'El borrador cambió mientras lo mirabas. Recarga e inténtalo de nuevo.'
  if (code === '22023') return 'Este artículo no tiene cambios que descartar o ya está en otro estado.'
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}

const TZ = 'Europe/Madrid'

/** Offset (ms) of Barcelona from UTC at the given instant. */
function barcelonaOffset(date: Date): number {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', { timeZone: TZ, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' })
      .formatToParts(date).map((x) => [x.type, x.value]),
  )
  return Date.UTC(+p.year!, +p.month! - 1, +p.day!, +p.hour!, +p.minute!, +p.second!) - Math.floor(date.getTime() / 1000) * 1000
}
/** ISO date -> `datetime-local` value ("YYYY-MM-DDTHH:mm") in Barcelona time. */
export function toBarcelonaInput(iso: string): string {
  const date = new Date(iso)
  return new Date(date.getTime() + barcelonaOffset(date)).toISOString().slice(0, 16)
}
/** `datetime-local` value typed as Barcelona time -> ISO (UTC). Invalid input gives NaN date. */
export function fromBarcelonaInput(value: string): Date {
  const guess = new Date(`${value}:00Z`)
  return new Date(guess.getTime() - barcelonaOffset(new Date(guess.getTime() - barcelonaOffset(guess))))
}

/** "hace 4 min", "ayer", "hace 3 sem": relative for the last weeks, a short date after that. */
export function relativeUpdated(iso: string, now = Date.now()): string {
  const seconds = Math.round((new Date(iso).getTime() - now) / 1000)
  const abs = Math.abs(seconds)
  const rtf = new Intl.RelativeTimeFormat('es-ES', { numeric: 'auto', style: 'short' })
  if (abs < 60) return 'ahora'
  if (abs < 3600) return rtf.format(Math.round(seconds / 60), 'minute')
  if (abs < 86_400) return rtf.format(Math.round(seconds / 3600), 'hour')
  if (abs < 86_400 * 28) return rtf.format(Math.round(seconds / 86_400), 'day')
  return adminDate(iso)
}

/** Publication column: "—" for drafts, "14 oct 2026 · 08:00" when scheduled, "8 oct 2026" when live. */
export function publicationLabel(row: Pick<AdminArticleRow, 'status' | 'published_at'>, now = Date.now()): string {
  if (!row.published_at || row.status === 'draft') return '—'
  const date = new Date(row.published_at)
  if (articleDisplay(row, now) === 'scheduled') {
    const day = adminDate(row.published_at)
    const time = new Intl.DateTimeFormat('es-ES', { timeZone: TZ, hour: '2-digit', minute: '2-digit' }).format(date)
    return `${day} · ${time}`
  }
  return adminDate(row.published_at)
}

/** Status for `AdminStatusChip`. */
export function chipStatus(row: AdminArticleRow, now = Date.now()): 'draft' | 'scheduled' | 'published' | 'revised' {
  const display = articleDisplay(row, now)
  return display === 'published' && row.changes > 0 ? 'revised' : display
}

/** `datetime-local` value (Barcelona time) for the next 08:00 `days` days after today, or the next Monday. */
export function scheduleSlot(kind: 'tomorrow' | 'monday', now = Date.now()): string {
  const today = toBarcelonaInput(new Date(now).toISOString()).slice(0, 10)
  const base = new Date(`${today}T00:00:00Z`)
  const add = kind === 'tomorrow' ? 1 : ((8 - base.getUTCDay()) % 7 || 7)
  base.setUTCDate(base.getUTCDate() + add)
  return `${base.toISOString().slice(0, 10)}T08:00`
}
