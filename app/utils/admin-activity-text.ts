import type { ActivityRecord } from '~/utils/admin-activity'
import { adminPath } from '~/utils/admin'

/**
 * Sentences of the Actividad feed. Second person for the admin («Editaste…»), third for the agent, the system and
 * readers. The server already masks private labels/details, and nothing here prints emails or free search text.
 */
export interface ActivitySeg {
  t?: string
  b?: boolean
  /** The entity label: the row renders it as a link when the entity still exists. */
  label?: boolean
}

const ITEM_NOUN: Record<string, string> = { gym: 'un rocódromo', resoler: 'un resolador', shoe: 'un pie de gato' }
const ITEM_PLURAL: Record<string, string> = { gym: 'rocódromos', resoler: 'resoladores', shoe: 'pies de gato' }
const ITEM_ONE: Record<string, string> = { gym: 'rocódromo', resoler: 'resolador', shoe: 'pie de gato' }
const NOUN: Record<string, string> = {
  articles: 'un artículo',
  pages: 'una página',
  events: 'un evento',
  media: 'un medio',
  article_categories: 'una categoría',
  authors: 'un autor',
  author_reviews: 'una reseña',
  user_reviews: 'una opinión',
  user_review_photos: 'una foto de una opinión',
  subscribers: 'un suscriptor',
  criteria: 'un criterio de nota',
  item_categories: 'un tipo de ficha',
  site_settings: 'los ajustes',
  admins: 'un administrador',
  import_batches: 'una importación',
}
const ITEM_TABLES = new Set(['items', 'gyms', 'resolers', 'shoes'])
const nounOf = (e: ActivityRecord) => (ITEM_TABLES.has(e.table) ? (ITEM_NOUN[e.itemCategory ?? ''] ?? 'una ficha') : (NOUN[e.table] ?? 'un elemento'))

/** Between the sentence and the label: «Editaste una ficha: X», «Ocultaste una opinión en X», «una reseña de X». */
const LINK: Record<string, string> = { user_reviews: ' en ', user_review_photos: ' en ', author_reviews: ' de ' }

const VERBS: Record<string, [you: string, other: string]> = {
  insert: ['Creaste', 'creó'],
  update: ['Editaste', 'editó'],
  delete: ['Eliminaste', 'eliminó'],
  draft_publish: ['Publicaste los cambios de', 'publicó los cambios de'],
  draft_discard: ['Descartaste los cambios de', 'descartó los cambios de'],
  unpublish: ['Despublicaste', 'despublicó'],
}
const SUBJECT = { agent: 'El agente de novedades', system: 'El sistema', person: 'Un lector' } as const

const str = (v: unknown) => (typeof v === 'string' ? v : '')
const t = (text: string): ActivitySeg => ({ t: text })
const b = (text: string): ActivitySeg => ({ t: text, b: true })

/** Export entries: `entity_table` is `export_{module}` and the details carry the module. */
export interface ExportInfo {
  module: string
  category: string
  format: string
  rows: number
  total: number
  truncated: boolean
  personal: boolean
  purpose: string
  columns: string[]
  filters: Record<string, unknown>
}
export function exportInfo(e: ActivityRecord): ExportInfo {
  const d = e.details
  const filters = d.filters && typeof d.filters === 'object' && !Array.isArray(d.filters) ? (d.filters as Record<string, unknown>) : {}
  const rows = typeof d.row_count === 'number' ? d.row_count : 0
  return {
    module: str(d.module) || e.table.replace(/^export_/, ''),
    category: str(filters.category),
    format: str(d.format).toUpperCase(),
    rows,
    total: typeof d.total === 'number' ? d.total : rows,
    truncated: d.truncated === true,
    personal: d.personal_data === true,
    purpose: str(d.purpose),
    columns: Array.isArray(d.columns) ? d.columns.filter((c): c is string => typeof c === 'string') : [],
    filters,
  }
}

/** Plural noun of what was exported: «suscriptores», «rocódromos». */
export function exportNoun(info: Pick<ExportInfo, 'module' | 'category'>): string {
  if (info.module === 'items') return ITEM_PLURAL[info.category] ?? 'fichas'
  return { articles: 'artículos', user_reviews: 'opiniones', subscribers: 'suscriptores', events: 'eventos' }[info.module] ?? 'filas'
}

const REVIEW_STATE: Record<string, string> = { hidden: 'Ocultaste', visible: 'Volviste a mostrar' }

/** The sentence as segments; the row decides how to draw the label. */
export function activitySegments(e: ActivityRecord): ActivitySeg[] {
  const noun = nounOf(e)
  const link = [...(e.label ? [t(LINK[e.table] ?? ': '), { label: true } as ActivitySeg] : [])]
  const to = str(e.details.to)

  if (e.action === 'export') {
    const x = exportInfo(e)
    return [b(`Exportaste ${exportNoun(x)}`), t(` · ${countOf(x.rows, 'fila', 'filas')}${x.format ? ` · ${x.format}` : ''}`)]
  }
  if (e.action === 'import' || e.action === 'import_undo') {
    const category = str(e.details.category) || (e.itemCategory ?? '')
    const what = ITEM_PLURAL[category] ?? 'fichas'
    const rows = typeof e.details.rows === 'number' ? e.details.rows : 0
    return e.action === 'import' ? [t('Importaste '), b(countOf(rows, ITEM_ONE[category] ?? 'ficha', what))] : [b('Deshiciste una importación'), t(` de ${what}`)]
  }
  if (e.table === 'subscribers') {
    if (e.action === 'delete' || to === 'erased') {
      if (e.actor === 'admin') return [b('Suprimiste los datos'), t(' de un suscriptor')]
      if (e.actor === 'person') return [t('Un lector '), b('suprimió sus datos')]
      return [t(`${SUBJECT[e.actor as keyof typeof SUBJECT] ?? SUBJECT.system} `), b('suprimió los datos'), t(' de un suscriptor')]
    }
    if (to === 'unsubscribed') return [e.actor === 'admin' ? b('Diste de baja') : b('Un suscriptor se dio de baja'), ...(e.actor === 'admin' ? [t(' a un suscriptor')] : [])]
    if (e.action === 'insert') return [e.actor === 'person' ? b('Un lector se suscribió') : b('Se añadió un suscriptor')]
  }
  if ((e.table === 'user_reviews' || e.table === 'user_review_photos') && e.action === 'update' && REVIEW_STATE[to]) {
    return [b(`${REVIEW_STATE[to]} ${noun}`), ...link]
  }
  if (e.actor === 'system' && e.group === 'pub' && e.action === 'update' && e.table !== 'site_settings') return [b('Publicación automática'), ...(e.label ? [t(': '), { label: true } as ActivitySeg] : [t(` de ${noun}`)])]
  if (e.action === 'draft_publish' && e.actor === 'admin' && e.changed.length) {
    return [t('Publicaste '), b(countOf(e.changed.length, 'cambio', 'cambios')), t(' en '), ...(e.label ? [{ label: true } as ActivitySeg] : [t(noun)])]
  }

  const verb = VERBS[e.action]
  if (!verb) return [t('Cambio registrado'), ...(e.label ? [t(': '), { label: true } as ActivitySeg] : [])]
  if (e.actor === 'admin') return [b(verb[0]), t(` ${noun}`), ...link]
  const who = SUBJECT[e.actor as keyof typeof SUBJECT] ?? SUBJECT.system
  return [t(`${who} `), b(verb[1]), t(` ${noun}`), ...link]
}

// ---- Second line ----

const COLUMNS: Record<string, string> = {
  title_es: 'título', title_en: 'título (EN)', name: 'nombre', slug_es: 'enlace', slug_en: 'enlace (EN)', excerpt_es: 'resumen', excerpt_en: 'resumen (EN)',
  body_es: 'cuerpo', body_en: 'cuerpo (EN)', content_es: 'cuerpo', content_en: 'cuerpo (EN)', cover_media_id: 'portada', cover_alt_es: 'texto alternativo',
  category_id: 'categoría', status: 'estado', published: 'visibilidad', published_at: 'fecha de publicación', tags: 'etiquetas', description_es: 'descripción',
  description_en: 'descripción (EN)', address: 'dirección', city: 'ciudad', website: 'web', url: 'enlace', price_text: 'precio', starts_at: 'fecha de inicio', ends_at: 'fecha de fin',
  location_text: 'lugar', alt_es: 'texto alternativo', alt_en: 'texto alternativo (EN)', verified_at: 'fecha de verificación', sort_order: 'orden', name_es: 'nombre', name_en: 'nombre (EN)',
}
const IGNORED = new Set(['updated_at', 'created_at', 'search_es', 'search_en'])

/** «Título, portada y cuerpo»: known columns by name, the rest as a count. */
export function changedFields(columns: readonly string[]): string {
  const real = columns.filter((c) => !IGNORED.has(c))
  const names = [...new Set(real.map((c) => COLUMNS[c]).filter((n): n is string => !!n))]
  const rest = real.filter((c) => !COLUMNS[c]).length
  if (!names.length) return real.length ? countOf(real.length, 'campo', 'campos') : ''
  const shown = names.slice(0, 4)
  const more = names.length - shown.length + rest
  const text = more > 0
    ? `${shown.join(', ')} y ${countOf(more, 'campo más', 'campos más')}`
    : shown.length > 1 ? `${shown.slice(0, -1).join(', ')} y ${shown[shown.length - 1]}` : (shown[0] ?? '')
  return text.charAt(0).toUpperCase() + text.slice(1)
}

/** Lines under the sentence. Reasons come from the admin; user text never reaches here (the server whitelists it). */
export function activityMeta(e: ActivityRecord): string[] {
  if (e.action === 'export' || e.action === 'import' || e.action === 'import_undo') return []
  const lines: string[] = []
  const reason = str(e.details.reason)
  if (reason) lines.push(`Motivo: ${reason}`)
  if (e.action === 'update' || e.action === 'draft_publish') {
    const fields = changedFields(e.changed)
    if (fields) lines.push(fields)
  }
  return lines
}

// ---- Links ----

const BUILT = new Set(['articulos', 'paginas', 'rocodromos', 'resoladores', 'pies-de-gato', 'medios', 'agenda', 'opiniones', 'suscriptores', 'categorias', 'autores', 'criterios'])
const EXPORT_ROUTE: Record<string, string> = { articles: 'articulos', user_reviews: 'opiniones', subscribers: 'suscriptores', events: 'agenda' }
const ITEM_ROUTE: Record<string, string> = { gym: 'rocodromos', resoler: 'resoladores', shoe: 'pies-de-gato' }

/** Panel URL of the entity, or null: deleted (`exists = false`), no screen yet (Ajustes) or no useful destination. */
export function activityHref(e: ActivityRecord): string | null {
  if (e.action === 'export') {
    const x = exportInfo(e)
    const slug = x.module === 'items' ? ITEM_ROUTE[x.category] : EXPORT_ROUTE[x.module]
    return slug ? adminPath(slug) : null
  }
  const { route, query, exists } = e.target
  if (!exists || !route?.startsWith(`${adminPath('')}/`)) return null
  const [slug = ''] = route.slice(adminPath('').length + 1).split('/')
  if (!BUILT.has(slug)) return null
  const qs = query ? `?${new URLSearchParams(query).toString()}` : ''
  return `${route}${qs}`
}
