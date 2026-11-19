import type { Component } from 'vue'
import { Calendar, File, FileText, Footprints, Image, Mountain, Newspaper, Wrench } from 'lucide-vue-next'
import type { SearchRow } from '~/services/admin/search'
import { GYM_INFO, RESOLER_INFO, SHOE_INFO } from './item-spec'

/** Content search of the ⌘K palette (README §15): kinds, scopes, highlight and one view model per result row. */
export type SearchKind = 'article' | 'gym' | 'resoler' | 'shoe' | 'page' | 'event' | 'news' | 'media'
export type SearchScope = 'all' | 'article' | 'items' | 'page' | 'event' | 'news' | 'media'

export const MIN_QUERY = 2
export const GROUP_LIMIT = 4
export const SCOPE_LIMIT = 20

/** Fixed group order (muscle memory). */
export const KINDS: { kind: SearchKind; label: string; noun: string; icon: Component; route: string }[] = [
  { kind: 'article', label: 'Artículos', noun: 'Artículo', icon: FileText, route: 'articulos' },
  { kind: 'gym', label: GYM_INFO.title, noun: 'Rocódromo', icon: Mountain, route: GYM_INFO.route },
  { kind: 'resoler', label: RESOLER_INFO.title, noun: 'Resolador', icon: Wrench, route: RESOLER_INFO.route },
  { kind: 'shoe', label: SHOE_INFO.title, noun: 'Pie de gato', icon: Footprints, route: SHOE_INFO.route },
  { kind: 'page', label: 'Páginas', noun: 'Página', icon: File, route: 'paginas' },
  { kind: 'event', label: 'Agenda', noun: 'Evento', icon: Calendar, route: 'agenda' },
  { kind: 'news', label: 'Noticias', noun: 'Noticia', icon: Newspaper, route: 'noticias' },
  { kind: 'media', label: 'Medios', noun: 'Foto', icon: Image, route: 'medios' },
]

export const SCOPES: { value: SearchScope; label: string; kinds: SearchKind[] | null }[] = [
  { value: 'all', label: 'Todo', kinds: null },
  { value: 'article', label: 'Artículos', kinds: ['article'] },
  { value: 'items', label: 'Fichas', kinds: ['gym', 'resoler', 'shoe'] },
  { value: 'page', label: 'Páginas', kinds: ['page'] },
  { value: 'event', label: 'Agenda', kinds: ['event'] },
  { value: 'news', label: 'Noticias', kinds: ['news'] },
  { value: 'media', label: 'Medios', kinds: ['media'] },
]

export const kindInfo = (kind: string) => KINDS.find((k) => k.kind === kind)

/** Label of the scope a kind belongs to («Rocódromos» → «Fichas»). */
export const scopeOfKind = (kind: SearchKind): SearchScope => SCOPES.find((s) => s.kinds?.includes(kind) && s.value !== 'all')?.value ?? 'all'

export interface MarkedPart {
  text: string
  mark: boolean
}

const fold = (text: string) => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/**
 * Splits `text` around the matches of `query` ignoring case and accents. The result is plain text parts: the template renders
 * them with interpolation and wraps the marked ones in `<mark>` (never as HTML).
 */
export function markParts(text: string, query: string): MarkedPart[] {
  const needle = fold(query.trim())
  if (!needle || !text) return [{ text, mark: false }]
  let folded = ''
  const origin: number[] = []
  Array.from(text).forEach((char, index) => {
    const piece = fold(char)
    for (let k = 0; k < piece.length; k++) origin.push(index)
    folded += piece
  })
  const chars = Array.from(text)
  const parts: MarkedPart[] = []
  let from = 0
  for (let at = folded.indexOf(needle); at !== -1; at = folded.indexOf(needle, at + needle.length)) {
    const start = origin[at]!
    const end = (origin[at + needle.length - 1] ?? chars.length - 1) + 1
    if (start < from) continue
    if (start > from) parts.push({ text: chars.slice(from, start).join(''), mark: false })
    parts.push({ text: chars.slice(start, end).join(''), mark: true })
    from = end
  }
  if (from < chars.length) parts.push({ text: chars.slice(from).join(''), mark: false })
  return parts.length ? parts : [{ text, mark: false }]
}

export interface ResultChip {
  label: string
  tone: string
}

export interface ResultRow {
  id: string
  /** Id for «Recientes» (pages: their `key`). */
  ref: string
  kind: SearchKind
  title: string
  /** Secondary line; italic when it is a body fragment. */
  sub: string
  subItalic: boolean
  chip: ResultChip | null
  to: string
  /** Media only. */
  thumb?: { path: string; color: string | null }
}

const obj = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {})
const str = (v: unknown) => (typeof v === 'string' ? v : '')
const bool = (v: unknown) => v === true
const WARN = 'bg-adm-warn-soft text-adm-warn'
const REV = 'bg-adm-st-rev-bg text-adm-st-rev'
const NEUTRAL = 'bg-adm-subtle text-adm-meta'

const FIELD_NOTE: Record<string, string> = {
  slug: 'coincide en la URL', slug_es: 'coincide en la URL', slug_en: 'coincide en la URL',
  excerpt_es: 'coincide en la entradilla', excerpt_en: 'coincide en la entradilla',
  summary_es: 'coincide en el resumen', summary_en: 'coincide en el resumen',
  insight_es: 'coincide en el aporte', insight_en: 'coincide en el aporte', source_name: 'coincide en el medio',
  address: 'coincide en la dirección', metro_stations: 'coincide en el metro',
  caption_es: 'coincide en el pie de foto', caption_en: 'coincide en el pie de foto', credit: 'coincide en el crédito', alt_en: 'coincide en el texto alternativo en inglés',
}

const money = (min: unknown, max: unknown) => {
  const [a, b] = [Number(min), Number(max)]
  if (!Number.isFinite(a) || a <= 0) return ''
  return Number.isFinite(b) && b > a ? `${a}–${b} €` : `${a} €`
}

function chipOf(row: SearchRow, d: Record<string, unknown>): ResultChip | null {
  const tone = (kind: AdminStatusKind) => ADMIN_STATUS[kind]
  switch (row.kind) {
    case 'article':
      if (row.status === 'published' && bool(d.has_draft)) return { label: 'Con cambios', tone: REV }
      return row.status === 'published' ? { label: 'Publicado', tone: tone('published').tone } : row.status === 'scheduled' ? { label: 'Programado', tone: tone('scheduled').tone } : { label: 'Borrador', tone: tone('draft').tone }
    case 'gym':
    case 'resoler':
    case 'shoe': {
      if (!bool(d.published)) return { label: 'Sin publicar', tone: tone('draft').tone }
      if (bool(d.has_draft)) return { label: 'Con cambios', tone: REV }
      const verified = str(d.verified_at)
      return !verified || !isFresh(verified) ? { label: 'Sin verificar', tone: WARN } : { label: 'Publicada', tone: tone('published').tone }
    }
    case 'page':
      return !bool(d.published) ? { label: 'Sin publicar', tone: tone('draft').tone } : bool(d.has_draft) ? { label: 'Con cambios', tone: REV } : { label: 'Publicada', tone: tone('published').tone }
    case 'event':
      return row.status === 'draft' ? { label: 'Por aprobar', tone: WARN } : row.status === 'cancelled' ? { label: 'Cancelado', tone: NEUTRAL } : { label: 'Aprobado', tone: tone('published').tone }
    case 'news':
      return row.status === 'draft' ? { label: 'Por revisar', tone: WARN } : { label: 'Publicada', tone: tone('published').tone }
    case 'media':
      return bool(d.missing_alt) ? { label: 'Sin alt', tone: WARN } : null
    default:
      return null
  }
}

function subOf(row: SearchRow, d: Record<string, unknown>): string {
  const join = (parts: string[]) => parts.filter(Boolean).join(' · ')
  switch (row.kind) {
    case 'article': {
      const when = str(d.published_at) ? adminDate(str(d.published_at)) : str(d.updated_at) ? `editado ${relativeUpdated(str(d.updated_at))}` : ''
      return join([str(d.category_name_es), when])
    }
    case 'gym': {
      const verified = str(d.verified_at)
      return join(['Rocódromo', str(d.district), verified ? `verificado ${adminDate(verified)}` : ''])
    }
    case 'resoler': {
      const [lo, hi] = [Number(d.turnaround_days_min), Number(d.turnaround_days_max)]
      const wait = lo > 0 ? (hi > lo ? `${lo}–${hi} días` : `${lo} días`) : ''
      return join(['Resolador', str(d.district), wait])
    }
    case 'shoe':
      return join(['Pie de gato', str(d.brand), money(d.price_min_eur, d.price_max_eur), bool(d.is_affiliate) ? 'afiliado' : ''])
    case 'page':
      return join([str(d.slug_es) ? `/${str(d.slug_es)}` : '', str(d.revised_on) ? `revisada ${adminDate(str(d.revised_on))}` : ''])
    case 'event': {
      const date = str(d.starts_at) ? adminDate(str(d.starts_at)) : ''
      return join([date, str(d.location_text) || str(d.item_name), d.source === 'agent' ? 'del agente' : ''])
    }
    case 'news': {
      const date = str(d.published_at) ? adminDate(str(d.published_at)) : ''
      return join([date, str(d.category_label_es), str(d.source_name), bool(d.has_insight) ? 'con aporte' : ''])
    }
    case 'media': {
      const uses = Number(d.usage_count) || 0
      return join([str(d.alt_es) ? `«${str(d.alt_es)}»` : 'Sin texto alternativo', uses ? `en uso en ${uses} ${uses === 1 ? 'sitio' : 'sitios'}` : 'sin usar'])
    }
    default:
      return ''
  }
}

const destination = (row: SearchRow): string => {
  const route = kindInfo(row.kind)?.route ?? ''
  if (row.kind === 'page') return adminPath(`paginas/${row.key}`)
  if (row.kind === 'event') return `${adminPath('agenda')}?evento=${row.id}`
  if (row.kind === 'news') return `${adminPath('noticias')}?noticia=${row.id}`
  if (row.kind === 'media') return `${adminPath('medios')}?medio=${row.id}`
  return adminPath(`${route}/${row.id}`)
}

/** One server row into what the palette paints. Text stays plain: the snippet is a decoded plain string. */
export function toResultRow(row: SearchRow): ResultRow {
  const d = obj(row.data)
  const body = row.matched_field === 'body_es' || row.matched_field === 'body_en'
  const english = row.matched_field === 'title_en' && str(d.title_en)
  let sub = subOf(row, d)
  let subItalic = false
  if (body) {
    sub = row.snippet ? `en el texto: «${row.snippet}»` : 'coincide en el texto'
    subItalic = true
  } else if (english) sub = `EN: ${str(d.title_en)}`
  else if (FIELD_NOTE[row.matched_field]) sub = FIELD_NOTE[row.matched_field]!
  return {
    id: row.id,
    ref: row.kind === 'page' ? row.key : row.id,
    kind: row.kind as SearchKind,
    title: row.title,
    sub,
    subItalic,
    chip: chipOf(row, d),
    to: destination(row),
    thumb: row.kind === 'media' ? { path: str(d.storage_path) || row.key, color: str(d.dominant_color) || null } : undefined,
  }
}
