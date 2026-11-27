import type { Database } from '~/types/database.types'
import { fullDay, madridToIso, shortDay, agoLabel } from '~/utils/admin-madrid'
import { RELATED_ORIGINS, RELATED_VIAS, type ConsentPurpose, type RelatedStatus, type SubscriberRelated } from '~/utils/admin-subscribers-related'

/**
 * Suscriptores (F6.14, D35): types, labels and pure rules of the screen. Everything the panel shows comes from the
 * RPCs `admin_*_subscriber(s)`; the table itself is not readable (42501). Dates in Europe/Madrid.
 */
export type SubscriberStatus = Database['guide']['Enums']['subscriber_status']
export type SubscriberView = 'active' | 'pending' | 'unsubscribed' | 'all'
export type SubscriberDateField = 'consent' | 'confirmed' | 'unsubscribed'
export type SubscriberLocale = Database['guide']['Enums']['locale']

/** Flip to `true` in F4.6 (confirmation emails + provider): the banner goes away and the default view is Activos. */
export const SENDING_CONNECTED = false

export interface Subscriber {
  id: string
  email: string
  status: SubscriberStatus
  locale: SubscriberLocale
  source: string
  version: number
  consentAt: string
  confirmedAt: string | null
  unsubscribedAt: string | null
  unsubscribeSource: string | null
  unsubscribeReason: string | null
  hasAccount: boolean
  expiresAt: string | null
  anonymizeAt: string | null
  /** D66: related-products consent, independent of `status`. */
  related: SubscriberRelated
}

export interface SubscriberList {
  total: number
  tabCounts: Record<SubscriberView, number>
  sourceCounts: Record<string, number>
  versionCounts: Record<string, number>
  relatedCounts: Record<RelatedStatus, number>
  rows: Subscriber[]
}

export interface SubscribersSummary {
  active: number
  active30d: number
  pending: number
  expired: number
  unsubscribed: number
  unsubscribed30d: number
  signups30d: number
  signups30dConfirmed: number
  confirmRate: number | null
  erased: number
}

export interface SubscriberEvent {
  at: string
  event: string
  source: string | null
  version: number | null
  locale: string | null
  page: string | null
  actor: string | null
  reason: string | null
  purpose: ConsentPurpose
}

export interface ConsentText {
  es: string | null
  en: string | null
  preserved: boolean
  validFrom: string | null
  validTo: string | null
}

export interface SubscriberDetail {
  subscriber: Subscriber & { consentPage: string | null }
  events: SubscriberEvent[]
  texts: Record<number, ConsentText>
  relatedTexts: Record<number, ConsentText>
}

// Views --------------------------------------------------------------------------------------------
export const SUBSCRIBER_VIEWS: readonly { value: SubscriberView; slug: string; label: string }[] = [
  { value: 'active', slug: 'activos', label: 'Activos' },
  { value: 'pending', slug: 'sin-confirmar', label: 'Sin confirmar' },
  { value: 'unsubscribed', slug: 'bajas', label: 'Bajas' },
  { value: 'all', slug: 'todos', label: 'Todos' },
]
export const viewFromSlug = (slug: unknown): SubscriberView | undefined => SUBSCRIBER_VIEWS.find((v) => v.slug === slug)?.value
export const viewSlug = (view: SubscriberView) => SUBSCRIBER_VIEWS.find((v) => v.value === view)?.slug ?? 'activos'
export const defaultSubscriberView = (): SubscriberView => (SENDING_CONNECTED ? 'active' : 'pending')

export function viewNote(view: SubscriberView): string {
  if (view === 'active') return 'Reciben la newsletter. Solo cuentan los que confirmaron el email (doble opt-in).'
  if (view === 'pending') {
    return SENDING_CONNECTED
      ? 'Se suscribieron pero no han confirmado: no reciben nada. Caducan a los 7 días sin confirmar y a los 30 se anonimizan solos.'
      : 'Se suscribieron pero no han confirmado: no reciben nada. Mientras no haya proveedor no caducan.'
  }
  if (view === 'unsubscribed') return 'No reciben nada. Se guarda la prueba de que se respetó su baja. Desde el panel no se puede volver a suscribir a nadie.'
  return 'Todos los estados. Los registros suprimidos (RGPD) no salen aquí: solo cuentan en el resumen.'
}

// Labels -------------------------------------------------------------------------------------------
export const SOURCE_OPTIONS: readonly { value: string; label: string }[] = [
  { value: 'footer', label: 'Pie de página' },
  { value: 'home', label: 'Inicio' },
  { value: 'item_page', label: 'Ficha' },
  { value: 'article', label: 'Artículo' },
  { value: 'article_mid', label: 'Artículo · a mitad' },
  { value: 'article_end', label: 'Artículo · al final' },
  { value: 'popup', label: 'Ventana emergente' },
  { value: 'newsletter_page', label: 'Página de newsletter' },
  { value: 'noticias', label: 'Noticias' },
]
export const sourceLabel = (source: string) =>
  source === 'admin_import' ? 'Importado' : (SOURCE_OPTIONS.find((s) => s.value === source)?.label ?? RELATED_ORIGINS[source] ?? source)

const VIAS: Record<string, string> = { link: 'Enlace del email', brevo: 'Proveedor de email', complaint: 'Queja de spam', admin: 'Desde el panel', user: 'Desde su cuenta', ...RELATED_VIAS }
export const viaLabel = (via: string | null) => (via ? (VIAS[via] ?? via) : '—')

export const UNSUBSCRIBE_REASONS = [
  { value: 'request', label: 'Me lo pidió (email, mensaje o en persona)' },
  { value: 'wrong', label: 'Email erróneo o de prueba' },
  { value: 'abuse', label: 'Alta que no hizo esa persona' },
  { value: 'other', label: 'Otro' },
] as const
export const ERASE_REASONS = [
  { value: 'request', label: 'Lo pidió la persona' },
  { value: 'wrong', label: 'Email de prueba o erróneo' },
  { value: 'other', label: 'Otro' },
] as const
const REASON_SHORT: Record<string, string> = { request: 'Me lo pidió', wrong: 'Email erróneo o de prueba', abuse: 'Lo hizo otra persona, no el titular', other: 'Otro' }
export const reasonShort = (reason: string | null) => (reason ? (REASON_SHORT[reason] ?? reason) : null)

export const localeName = (locale: string) => (locale === 'en' ? 'Inglés' : 'Español')

/** Only these can be unsubscribed (`admin_unsubscribe_subscribers`): not expired, not already unsubscribed. */
export const canUnsubscribe = (s: Pick<Subscriber, 'status'>) => s.status === 'pending' || s.status === 'active' || s.status === 'bounced'

// Dates ---------------------------------------------------------------------------------------------- (generic formatters: `admin-madrid`)
/** "Esperando" column: how long and, when it applies, when it expires or is anonymized. */
export function waitingOf(s: Subscriber): { main: string; note: string } {
  const main = agoLabel(s.consentAt)
  if (s.status === 'expired') return { main, note: s.anonymizeAt ? `se anonimiza el ${shortDay(s.anonymizeAt)}` : '' }
  if (!SENDING_CONNECTED) return { main, note: 'no caduca' }
  return { main, note: s.expiresAt ? `caduca el ${shortDay(s.expiresAt)}` : '' }
}

export function lastChangeOf(s: Subscriber): string {
  if (s.unsubscribedAt) return `Baja · ${shortDay(s.unsubscribedAt)}`
  if (s.confirmedAt) return `Confirmó · ${shortDay(s.confirmedAt)}`
  return `Alta · ${shortDay(s.consentAt)}`
}

// Filters (all of them live in the URL) -------------------------------------------------------------
export const DATE_FIELDS: readonly { value: SubscriberDateField; slug: string; label: string }[] = [
  { value: 'consent', slug: 'alta', label: 'Alta' },
  { value: 'confirmed', slug: 'confirmacion', label: 'Confirmación' },
  { value: 'unsubscribed', slug: 'baja', label: 'Baja' },
]
export const dateFieldFromSlug = (slug: unknown): SubscriberDateField => DATE_FIELDS.find((d) => d.slug === slug)?.value ?? 'consent'
export const dateFieldSlug = (field: SubscriberDateField) => DATE_FIELDS.find((d) => d.value === field)?.slug ?? 'alta'

export interface SubscriberFilters {
  search: string
  sources: string[]
  locale: SubscriberLocale | ''
  dateField: SubscriberDateField
  from: string
  to: string
  versions: number[]
  statuses: SubscriberStatus[]
  /** D66 «Afines» filter (`afines=` in the URL). */
  related: RelatedStatus[]
}
export const STATUS_FILTERS: readonly { value: SubscriberStatus; label: string }[] = [
  { value: 'active', label: 'Activo' },
  { value: 'pending', label: 'Sin confirmar' },
  { value: 'expired', label: 'Caducado' },
  { value: 'unsubscribed', label: 'Baja' },
  { value: 'bounced', label: 'Rebotado' },
]

export const emptySubscriberFilters = (): SubscriberFilters => ({ search: '', sources: [], locale: '', dateField: 'consent', from: '', to: '', versions: [], statuses: [], related: [] })
export const hasSubscriberFilters = (f: SubscriberFilters) => !!(f.search.trim() || f.sources.length || f.locale || f.from || f.to || f.versions.length || f.statuses.length || f.related.length)
/** Filters without the search: what "Quitar filtros" and the chips remove. */
export const hasFilterChips = (f: SubscriberFilters) => !!(f.sources.length || f.locale || f.from || f.to || f.versions.length || f.statuses.length || f.related.length)

/** Table column → RPC sort (whitelist of the RPC). Without a sort the order is the newest signup first. */
export function subscriberSort(sort: { id: string; desc: boolean } | null): string {
  return sort?.id === 'consent' && !sort.desc ? 'consent_at_asc' : 'consent_at_desc'
}

const nextDay = (date: string) => {
  const [y = 0, m = 1, d = 1] = date.split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d + 1)).toISOString().slice(0, 10)
}

export function listArgs(view: SubscriberView, f: SubscriberFilters, sort: { id: string; desc: boolean } | null, page: number, pageSize: number) {
  return {
    p_view: view,
    p_query: f.search.trim() || undefined,
    p_sources: f.sources.length ? f.sources : undefined,
    p_locale: f.locale || undefined,
    p_date_field: f.dateField,
    // The range is inclusive of the last day: [desde 00:00, día siguiente a "hasta" 00:00) in Madrid.
    p_from: f.from ? madridToIso(f.from) : undefined,
    p_to: f.to ? madridToIso(nextDay(f.to)) : undefined,
    p_versions: f.versions.length ? f.versions : undefined,
    p_statuses: view === 'all' && f.statuses.length ? f.statuses : undefined,
    p_sort: subscriberSort(sort),
    p_limit: pageSize,
    p_offset: page * pageSize,
    p_related: f.related.length ? f.related : undefined,
  }
}

export function dateChipLabel(f: SubscriberFilters): string {
  const field = DATE_FIELDS.find((d) => d.value === f.dateField)?.label ?? 'Alta'
  const text = (iso: string) => fullDay(madridToIso(iso))
  if (f.from && f.to) return `${field}: ${text(f.from)} – ${text(f.to)}`
  if (f.from) return `${field} desde el ${text(f.from)}`
  if (f.to) return `${field} hasta el ${text(f.to)}`
  return ''
}

// Summary --------------------------------------------------------------------------------------------
export interface SummaryCell {
  key: string
  title: string
  value: number | null
  hint: string
}
export function summaryCells(s: SubscribersSummary | undefined): SummaryCell[] {
  const count = (n: number | undefined) => n ?? null
  const rate = s?.confirmRate
  const erased = s ? `${s.erased} ${s.erased === 1 ? 'suprimido' : 'suprimidos'}` : ''
  const signupsHint = !s
    ? '—'
    : !SENDING_CONNECTED && s.signups30dConfirmed === 0
      ? `${s.signups30d ? 'ninguna confirmada' : 'sin altas'} · ${erased}`
      : `${rate == null ? 'sin altas' : `${String(rate).replace('.', ',')} % confirman`} · ${erased}`
  return [
    { key: 'active', title: 'Activos', value: count(s?.active), hint: s ? `+${s.active30d} en 30 días` : '—' },
    {
      key: 'pending',
      title: 'Sin confirmar',
      value: s ? s.pending + s.expired : null,
      hint: !s ? '—' : SENDING_CONNECTED ? `${s.expired} ${s.expired === 1 ? 'caducado' : 'caducados'}` : 'aún sin email de confirmación',
    },
    { key: 'unsubscribed', title: 'Bajas', value: s ? s.unsubscribed : null, hint: s ? `${s.unsubscribed30d} en 30 días` : '—' },
    { key: 'signups', title: 'Altas en 30 días', value: count(s?.signups30d), hint: signupsHint },
  ]
}
