import type { Json } from '~/types/database.types'
import { madridParts } from '~/utils/admin-madrid'
import { SOURCE_OPTIONS } from '~/utils/admin-subscribers'

/**
 * Export modal (F6.15, docs/design/admin/README.md §12): which listings export, what each one filters by and how the UI
 * state becomes the `p_filters` of `guide.admin_export` / `admin_export_count` (contract: docs/security/F6.15-export-audit.md).
 * The exported text of the modal lives in `app/components/admin/exports/` and in the labels of this file.
 */
export type ExportTarget = 'articles' | 'gym' | 'resoler' | 'shoe' | 'user_reviews' | 'subscribers' | 'events' | 'news'
export type ExportModule = 'articles' | 'items' | 'user_reviews' | 'subscribers' | 'events' | 'news'
export type ExportFormat = 'csv' | 'json'

export interface ExportField {
  key: string
  label: string
  kind: 'select' | 'date' | 'text'
  options?: readonly { value: string; label: string }[]
  /** Select without the «Todos» option (empty = first option). */
  required?: boolean
}
export interface ExportStatus {
  value: string
  label: string
  /** Part of the file name; empty for "Todos". */
  slug: string
}
export interface ExportConfig {
  module: ExportModule
  /** Sidebar/⌘K name. The modal says `Exportar {noun}`. */
  title: string
  /** Noun of the live summary: «1.284 suscriptores». */
  noun: string
  /** Singular of `noun`: «1 suscriptor». */
  nounOne: string
  /** Grammatical gender of `noun`: feminine («opiniones» → «publicadas»). Masculine when absent. */
  feminine?: boolean
  /** Sidebar route, for the ⌘K command. */
  route: string
  /** Name of the module in the file: `chalkguide-{file}-…`. */
  file: string
  category?: string
  statuses: readonly ExportStatus[]
  defaultStatus: string
  fields: readonly ExportField[]
  /** Fixed date column of the range (the field the "desde/hasta" refer to). */
  dateField?: string
  hasBody?: boolean
}

const YES_NO = (yes: string, no: string) => [{ value: 'true', label: yes }, { value: 'false', label: no }] as const
const EN_FIELD: ExportField = { key: 'has_en', label: 'Inglés', kind: 'select', options: YES_NO('Con inglés', 'Sin inglés') }
const range = (from: string, to: string): ExportField[] => [
  { key: 'from', label: from, kind: 'date' },
  { key: 'to', label: to, kind: 'date' },
]
const st = (value: string, label: string, slug = label.toLowerCase()): ExportStatus => ({ value, label, slug })
const ITEM_STATUSES = [st('all', 'Publicadas y ocultas', ''), st('published', 'Publicadas'), st('hidden', 'Ocultas')]

const itemConfig = (title: string, route: string, file: string, category: string, nounOne: string, noun: string): ExportConfig => ({
  module: 'items', title, noun, nounOne, route, file: `fichas-${file}`, category, statuses: ITEM_STATUSES, defaultStatus: 'all',
  fields: [EN_FIELD, ...range('Verificada desde', 'Verificada hasta')], dateField: 'verified_at', hasBody: true,
})

export const EXPORT_CONFIGS: Record<ExportTarget, ExportConfig> = {
  articles: {
    module: 'articles', title: 'Artículos', noun: 'artículos', nounOne: 'artículo', route: 'articulos', file: 'articulos',
    statuses: [st('all', 'Todos', ''), st('published', 'Publicados'), st('scheduled', 'Programados'), st('draft', 'Borradores')],
    defaultStatus: 'all',
    fields: [{ key: 'category_id', label: 'Categoría', kind: 'select' }, EN_FIELD, ...range('Publicado desde', 'Publicado hasta')],
    dateField: 'published_at', hasBody: true,
  },
  gym: itemConfig('Rocódromos', 'rocodromos', 'rocodromos', 'gym', 'rocódromo', 'rocódromos'),
  resoler: itemConfig('Resoladores', 'resoladores', 'resoladores', 'resoler', 'resolador', 'resoladores'),
  shoe: itemConfig('Pies de gato', 'pies-de-gato', 'pies-de-gato', 'shoe', 'pie de gato', 'pies de gato'),
  user_reviews: {
    module: 'user_reviews', feminine: true, title: 'Opiniones', noun: 'opiniones', nounOne: 'opinión', route: 'opiniones', file: 'opiniones',
    statuses: [st('visible', 'Visibles'), st('hidden', 'Ocultas'), st('all', 'Todas', '')],
    defaultStatus: 'visible',
    fields: [
      { key: 'category', label: 'Tipo de ficha', kind: 'select', options: [{ value: 'gym', label: 'Rocódromos' }, { value: 'resoler', label: 'Resoladores' }, { value: 'shoe', label: 'Pies de gato' }] },
      { key: 'locale', label: 'Idioma', kind: 'select', options: [{ value: 'es', label: 'Español' }, { value: 'en', label: 'Inglés' }] },
      ...range('Publicada desde', 'Publicada hasta'),
    ],
    dateField: 'created_at',
  },
  subscribers: {
    module: 'subscribers', title: 'Suscriptores', noun: 'suscriptores', nounOne: 'suscriptor', route: 'suscriptores', file: 'suscriptores',
    statuses: [st('active', 'Activos'), st('pending', 'Sin confirmar', 'sin-confirmar'), st('unsubscribed', 'Bajas'), st('all', 'Todos', '')],
    defaultStatus: 'active',
    fields: [
      { key: 'sources', label: 'Origen', kind: 'select', options: SOURCE_OPTIONS },
      { key: 'locale', label: 'Idioma', kind: 'select', options: [{ value: 'es', label: 'Español' }, { value: 'en', label: 'Inglés' }] },
      { key: 'consent_version', label: 'Texto aceptado (versión)', kind: 'text' },
      { key: 'date_field', label: 'Fecha de', kind: 'select', required: true, options: [{ value: 'consent', label: 'Alta' }, { value: 'confirmed', label: 'Confirmación' }, { value: 'unsubscribed', label: 'Baja' }] },
      ...range('Desde', 'Hasta'),
    ],
  },
  events: {
    module: 'events', title: 'Agenda', noun: 'eventos', nounOne: 'evento', route: 'agenda', file: 'agenda',
    statuses: [st('approved', 'Aprobados'), st('draft', 'Borradores'), st('cancelled', 'Cancelados'), st('rejected', 'Descartados'), st('all', 'Todos', '')],
    defaultStatus: 'approved',
    fields: [
      { key: 'source', label: 'Origen', kind: 'select', options: [{ value: 'manual', label: 'Manual' }, { value: 'agent', label: 'Agente' }] },
      ...range('Evento desde', 'Evento hasta'),
    ],
    dateField: 'starts_at',
  },
  news: {
    module: 'news', feminine: true, title: 'Noticias', noun: 'noticias', nounOne: 'noticia', route: 'noticias', file: 'noticias',
    statuses: [st('all', 'Todas', ''), st('published', 'Publicadas'), st('draft', 'Por revisar', 'por-revisar'), st('rejected', 'Rechazadas')],
    defaultStatus: 'all',
    fields: [
      { key: 'category_id', label: 'Categoría', kind: 'select' },
      { key: 'scopes', label: 'Alcance', kind: 'select', options: [{ value: 'cat', label: 'Cataluña' }, { value: 'es', label: 'España' }, { value: 'intl', label: 'Internacional' }] },
      { key: 'source', label: 'Origen', kind: 'select', options: [{ value: 'manual', label: 'Manual' }, { value: 'agent', label: 'Agente' }] },
      EN_FIELD,
      { key: 'date_field', label: 'Fecha de', kind: 'select', required: true, options: [{ value: 'published_at', label: 'Publicación' }, { value: 'created_at', label: 'Alta' }, { value: 'updated_at', label: 'Última edición' }] },
      ...range('Desde', 'Hasta'),
    ],
  },
}

/** Export targets in menu order (⌘K commands). */
export const EXPORT_TARGETS: readonly ExportTarget[] = ['articles', 'gym', 'resoler', 'shoe', 'user_reviews', 'subscribers', 'events', 'news']

/** What the user chose in the modal; strings only (lists are comma separated). */
export interface ExportDraft {
  status: string
  values: Record<string, string>
}
export interface ExportInitial extends Partial<ExportDraft> {
  /** «Con los filtros de la vista {vista}». */
  viewLabel?: string
}

export const PURPOSES = [
  { value: 'backup', label: 'Copia de seguridad' },
  { value: 'send_tool', label: 'Pasar a otra herramienta de envío' },
  { value: 'data_request', label: 'Responder a una petición, acceso o portabilidad' },
  { value: 'audit', label: 'Revisión o auditoría' },
  { value: 'other', label: 'Otro' },
] as const
export const purposeLabel = (value: string | null | undefined) => PURPOSES.find((p) => p.value === value)?.label ?? value ?? ''

export const SUBSCRIBER_PRESETS = {
  min: ['email', 'locale', 'status', 'consent_at', 'confirmed_at'],
  proof: ['email', 'locale', 'status', 'consent_at', 'confirmed_at', 'id', 'consent_source', 'consent_version', 'consent_page', 'unsubscribed_at', 'unsubscribe_source', 'created_at'],
} as const

const SUBSCRIBER_STATUSES: Record<string, string[]> = {
  active: ['active'],
  pending: ['pending', 'expired'],
  unsubscribed: ['unsubscribed', 'bounced'],
  all: ['pending', 'active', 'unsubscribed', 'bounced', 'expired'],
}
const csvList = (text: string | undefined) => (text ?? '').split(',').map((s) => s.trim()).filter(Boolean)

export interface ExportOptions {
  format: ExportFormat
  withBody?: boolean
  /** Subscribers: `min` (default) or `proof`. */
  preset?: 'min' | 'proof'
  purpose?: string
}

/** `p_filters` of the RPCs. Unknown keys are rejected by the server (22023), so every key is explicit and per module. */
export function buildFilters(config: ExportConfig, draft: ExportDraft, options: ExportOptions): Record<string, Json> {
  const { module } = config
  const v = draft.values
  const f: Record<string, Json> = {}
  const all = draft.status === 'all'
  if (module === 'items') {
    f.category = config.category ?? null
    if (!all) f.published = draft.status === 'published'
  } else if (module === 'subscribers') {
    f.statuses = SUBSCRIBER_STATUSES[draft.status] ?? SUBSCRIBER_STATUSES.active ?? []
    f.columns = options.preset ?? 'min'
    if (options.purpose) f.purpose = options.purpose
  } else if (module === 'user_reviews') {
    f.statuses = all ? ['pending', 'visible', 'hidden'] : [draft.status]
  } else if (!all) {
    f.statuses = [draft.status]
  }
  const text = (key: string) => v[key]?.trim()
  if ((module === 'articles' || module === 'news') && text('category_id')) f.category_id = text('category_id') ?? null
  if (module === 'user_reviews' && text('category')) f.category = text('category') ?? null
  if ((module === 'user_reviews' || module === 'events') && text('item_id')) f.item_id = text('item_id') ?? null
  if ((module === 'articles' || module === 'items' || module === 'news') && text('has_en')) f.has_en = text('has_en') === 'true'
  if ((module === 'user_reviews' || module === 'subscribers') && text('locale')) f.locale = text('locale') ?? null
  if ((module === 'events' || module === 'news') && text('source')) f.source = text('source') ?? null
  if (module === 'news') {
    if (text('scopes')) f.scopes = csvList(v.scopes)
    if (csvList(v.ids).length) f.ids = csvList(v.ids)
  }
  if (module === 'subscribers') {
    if (csvList(v.sources).length) f.sources = csvList(v.sources)
    const versions = csvList(v.consent_version).map(Number).filter((n) => Number.isInteger(n) && n >= 0)
    if (versions.length) f.consent_version = versions
  }
  const dateField = module === 'subscribers' ? text('date_field') || 'consent' : module === 'news' ? text('date_field') || 'published_at' : config.dateField
  if (dateField && (text('from') || text('to'))) f.date_field = dateField
  if (text('from')) f.from = text('from') ?? null
  if (text('to')) f.to = text('to') ?? null
  if (config.hasBody && options.format === 'json' && options.withBody) f.with_body = true
  return f
}

/** `chalkguide-{módulo}[-{estado}]-AAAA-MM-DD-HHMM.ext`, Barcelona time. */
export function exportFileName(config: ExportConfig, status: string, format: ExportFormat, at: Date = new Date()): string {
  const { date, time } = madridParts(at)
  const slug = config.statuses.find((s) => s.value === status)?.slug
  return ['chalkguide', config.file, slug, date, time.replace(':', '')].filter(Boolean).join('-') + `.${format}`
}

export interface ExportCount {
  total: number
  rowCount: number
  truncated: boolean
  columns: string[]
}
export interface ExportResult {
  export: { module: string; format: string; columns: string[]; row_count: number; total: number; truncated: boolean }
  rows: Record<string, unknown>[]
}
export interface RecentExport {
  id: number
  occurredAt: string
  format: string
  rowCount: number
  purpose: string | null
}

const obj = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {})
const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [])
export function parseExportCount(raw: unknown): ExportCount {
  const r = obj(raw)
  return { total: Number(r.total) || 0, rowCount: Number(r.row_count) || 0, truncated: r.truncated === true, columns: strings(r.columns) }
}
export function parseRecentExport(raw: unknown): RecentExport | null {
  const r = obj(Array.isArray(raw) ? raw[0] : undefined)
  if (r.id === undefined) return null
  return { id: Number(r.id), occurredAt: String(r.occurred_at ?? ''), format: String(r.format ?? ''), rowCount: Number(r.row_count) || 0, purpose: typeof r.purpose === 'string' ? r.purpose : null }
}
