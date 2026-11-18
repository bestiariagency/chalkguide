import type { ActivityRecord } from '~/utils/admin-activity'
import { exportInfo, exportNoun } from '~/utils/admin-activity-text'
import { EXPORT_CONFIGS, purposeLabel, type ExportConfig } from '~/utils/admin-export'
import { sourceLabel } from '~/utils/admin-subscribers'

/**
 * Detail drawer of an export entry (README §12.6, actividad.html): who, when, what, filters, columns, rows, format
 * and, for subscribers, the purpose. The log keeps the query, never the file or the data.
 */
export interface ExportDetail {
  what: string
  filters: string[]
  columns: string
  rows: string
  format: string
  personal: boolean
  purpose: string
}

const configOf = (module: string, category: string): ExportConfig | undefined =>
  Object.values(EXPORT_CONFIGS).find((c) => c.module === module && (module !== 'items' || c.category === category))

const list = (v: unknown): string[] => (Array.isArray(v) ? v.map(String) : typeof v === 'string' ? [v] : [])
const LOCALES: Record<string, string> = { es: 'español', en: 'inglés' }
const DATE_FIELDS: Record<string, string> = { consent: 'alta', confirmed: 'confirmación', unsubscribed: 'baja', published_at: 'publicación', created_at: 'creación', starts_at: 'inicio', verified_at: 'verificación', approved_at: 'aprobación' }
const SOURCES: Record<string, string> = { manual: 'manual', agent: 'agente' }
const plural = (n: number) => countOf(n, 'fila', 'filas')
const lower = (s: string) => s.charAt(0).toLowerCase() + s.slice(1)

/** The sanitized filters of the log as short phrases («Estado: activos»). Unknown keys are ignored. */
export function exportFilterLines(module: string, category: string, filters: Record<string, unknown>): string[] {
  const config = configOf(module, category)
  const lines: string[] = []
  const statuses = list(filters.statuses)
  if (statuses.length) lines.push(`Estado: ${statuses.map((s) => lower(config?.statuses.find((x) => x.value === s)?.label ?? s)).join(', ')}`)
  const sources = list(filters.sources)
  if (sources.length) lines.push(`Origen: ${sources.map((s) => lower(sourceLabel(s))).join(', ')}`)
  if (typeof filters.source === 'string') lines.push(`Origen: ${SOURCES[filters.source] ?? filters.source}`)
  if (typeof filters.locale === 'string') lines.push(`Idioma: ${LOCALES[filters.locale] ?? filters.locale}`)
  const versions = list(filters.consent_version)
  if (versions.length) lines.push(`Texto aceptado: ${versions.length > 1 ? 'versiones' : 'versión'} ${versions.join(', ')}`)
  if (typeof filters.has_en === 'boolean') lines.push(filters.has_en ? 'Con inglés' : 'Sin inglés')
  if (typeof filters.published === 'boolean') {
    const end = config?.feminine ? 'as' : 'os'
    lines.push(filters.published ? `Solo publicad${end}` : `Solo ocult${end}`)
  }
  if (filters.category_id) lines.push('Una categoría concreta')
  if (filters.item_id) lines.push('Una ficha concreta')
  const types = list(filters.event_types)
  if (types.length) lines.push(`Tipo: ${types.join(', ')}`)
  const field = typeof filters.date_field === 'string' ? (DATE_FIELDS[filters.date_field] ?? '') : ''
  const range = [filters.from ? `desde ${adminDate(String(filters.from).slice(0, 10))}` : '', filters.to ? `hasta ${adminDate(String(filters.to).slice(0, 10))}` : ''].filter(Boolean)
  if (range.length) lines.push(`Fecha${field ? ` de ${field}` : ''}: ${range.join(' ')}`)
  if (typeof filters.ids_count === 'number') lines.push(`Selección de ${plural(filters.ids_count)}`)
  if (filters.with_body === true) lines.push('Con el cuerpo completo')
  return lines
}

export function exportDetail(e: ActivityRecord): ExportDetail {
  const x = exportInfo(e)
  const config = configOf(x.module, x.category)
  return {
    what: config?.title ?? exportNoun(x),
    filters: exportFilterLines(x.module, x.category, x.filters),
    columns: x.columns.join(', '),
    rows: x.truncated ? `${plural(x.rows)} de ${fmtInt(x.total)} (se truncó)` : plural(x.rows),
    format: x.format,
    personal: x.personal,
    purpose: purposeLabel(x.purpose),
  }
}
