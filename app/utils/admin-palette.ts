import type { Component } from 'vue'
import { Download, FilePlus2, ImagePlus, Mountain, Newspaper, CalendarPlus, Upload, Search, ArrowRight, Clock } from 'lucide-vue-next'
import type { SearchGroup } from '~/composables/useAdminSearch'
import type { RecentItem } from './admin-recent'
import { kindInfo, scopeOfKind, SCOPES, type ResultChip, type SearchKind, type SearchScope } from './admin-search'
import { EXPORT_CONFIGS, EXPORT_TARGETS } from './admin-export'
import { GYM_INFO, RESOLER_INFO, SHOE_INFO } from './item-spec'

/** Options of the ⌘K palette (README §15.3): what is listed, in which order, for a given text and scope. */
export type OptionType = 'goto' | 'create' | 'recent' | 'result' | 'more' | 'open' | 'all' | 'title'

export interface PaletteOption {
  /** Unique within the palette (DOM id suffix). */
  id: string
  type: OptionType
  label: string
  icon?: Component
  sub?: string
  subItalic?: boolean
  chip?: ResultChip | null
  thumb?: { path: string; color: string | null }
  /** Destination (goto / create / recent / result / open): a panel path or `exportar:{target}`. */
  to?: string
  /** `more` and `all`: scope to switch to. */
  scope?: SearchScope
  /** What to remember in «Recientes» when it is opened. */
  recent?: { kind: SearchKind; id: string }
  /** Text highlighted inside `label` and `sub`. */
  mark?: string
}

export interface PaletteGroup {
  id: string
  label: string
  count?: number
  options: PaletteOption[]
}

export const foldText = (text: string) => text.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

interface Section {
  slug: string
  label: string
  icon: Component
}

/** Menu destinations plus exports, imports (stay as they were) and settings; grouped as the menu. */
function sectionGroups(): { label: string; items: Section[] }[] {
  const exports = EXPORT_TARGETS.map((target) => ({ slug: `exportar:${target}`, label: `Exportar ${EXPORT_CONFIGS[target].title.toLowerCase()}…`, icon: Download }))
  // Importing is for a computer (README §13.8): the entries go to the importer page.
  const imports = [GYM_INFO, SHOE_INFO, RESOLER_INFO].map((info) => ({ slug: `${info.route}/importar`, label: `Importar ${info.nouns}…`, icon: Upload }))
  return [...ADMIN_NAV, { label: 'Exportar', items: exports }, { label: 'Importar', items: imports }, { label: 'Cuenta', items: [ADMIN_SETTINGS] }].map((g) => ({ label: g.label ?? 'Inicio', items: g.items }))
}

const gotoOption = (s: Section): PaletteOption => ({ id: `goto-${s.slug}`, type: 'goto', label: s.label, icon: s.icon, to: s.slug })

const CREATE: PaletteOption[] = [
  { id: 'create-article', type: 'create', label: 'Nuevo artículo', icon: FilePlus2, to: 'articulos/nuevo' },
  { id: 'create-gym', type: 'create', label: 'Nuevo rocódromo', icon: Mountain, to: 'rocodromos/nuevo' },
  { id: 'create-news', type: 'create', label: 'Nueva noticia', icon: Newspaper, to: 'noticias?nuevo=1' },
  { id: 'create-event', type: 'create', label: 'Nuevo evento', icon: CalendarPlus, to: 'agenda?nuevo=1' },
  { id: 'create-media', type: 'create', label: 'Subir fotos', icon: ImagePlus, to: 'medios' },
]

export interface PaletteInput {
  term: string
  scope: SearchScope
  search: SearchGroup[]
  recents: RecentItem[]
  /** The answer for the current text already arrived. */
  answered: boolean
}

function contentGroups({ term, scope, search }: PaletteInput): PaletteGroup[] {
  const kinds = SCOPES.find((s) => s.value === scope)?.kinds
  return search
    .filter((g) => !kinds || kinds.includes(g.kind as never))
    .map((g) => {
      const info = kindInfo(g.kind)!
      const options: PaletteOption[] = g.rows.map((r) => ({
        id: `result-${r.kind}-${r.id}`, type: 'result', label: r.title, icon: info.icon, sub: r.sub, subItalic: r.subItalic, chip: r.chip, thumb: r.thumb, to: r.to, recent: { kind: r.kind, id: r.ref }, mark: term,
      }))
      if (g.total > g.rows.length) {
        options.push(
          scope === 'all'
            ? { id: `more-${g.kind}`, type: 'more', label: `Ver los ${g.total} de ${info.label}`, icon: ArrowRight, scope: scopeOfKind(g.kind as never) }
            : { id: `open-${g.kind}`, type: 'open', label: `Abrir «${term}» en ${info.label}`, icon: ArrowRight, to: `${adminPath(info.route)}?q=${encodeURIComponent(term)}` },
        )
      }
      return { id: `content-${g.kind}`, label: info.label, count: g.total, options }
    })
}

/** Groups in display order. Empty when there is nothing to list yet (the component paints the state). */
export function buildPaletteGroups(input: PaletteInput): PaletteGroup[] {
  const { term, scope } = input
  const needle = foldText(term)
  const sections = sectionGroups()
  if (term.length === 0) {
    const recents: PaletteGroup[] = input.recents.length
      ? [{ id: 'recent', label: 'Recientes', options: input.recents.map((r) => ({ id: `recent-${r.kind}-${r.id}`, type: 'recent', label: r.title, icon: kindInfo(r.kind)?.icon ?? Clock, sub: kindInfo(r.kind)?.noun, to: recentTarget(r), recent: { kind: r.kind, id: r.id } })) }]
      : []
    return [...recents, ...sections.map((g) => ({ id: `goto-${g.label}`, label: g.label, options: g.items.map(gotoOption) })), { id: 'create', label: 'Crear', options: CREATE }]
  }
  const all = sections.flatMap((g) => g.items).filter((s) => foldText(s.label).includes(needle))
  if (term.length < 2) return sections.map((g) => ({ id: `goto-${g.label}`, label: g.label, options: g.items.filter((s) => all.includes(s)).map(gotoOption) })).filter((g) => g.options.length)
  if (scope !== 'all') return contentGroups(input)
  const head = all.filter((s) => foldText(s.label).startsWith(needle)).slice(0, 3)
  const tail = all.filter((s) => !head.includes(s))
  const group = (id: string, items: Section[]): PaletteGroup[] => (items.length ? [{ id, label: 'Ir a', options: items.map(gotoOption) }] : [])
  return [...group('goto-head', head), ...contentGroups(input), ...group('goto-tail', tail)]
}

/** Actions under «Nada coincide»: widen to Todo (inside a scope) and create an article with that title. */
export function emptyActions(term: string, scope: SearchScope): PaletteGroup {
  const options: PaletteOption[] = []
  if (scope !== 'all') options.push({ id: 'all', type: 'all', label: 'Buscar en todo', icon: Search, scope: 'all' })
  options.push({ id: 'title', type: 'title', label: `Crear un artículo titulado «${term}»`, icon: FilePlus2, to: `articulos/nuevo?titulo=${encodeURIComponent(term)}` })
  return { id: 'empty-actions', label: 'Qué hacer', options }
}

export const flatOptions = (groups: PaletteGroup[]) => groups.flatMap((g) => g.options)

/** Route a «Recientes» entry opens (kept here, not in admin-recent: that file is in the entry graph through the sign-out cleanup). */
export function recentTarget(item: RecentItem): string {
  const route = kindInfo(item.kind)?.route ?? ''
  if (item.kind === 'event') return `${adminPath('agenda')}?evento=${item.id}`
  if (item.kind === 'news') return `${adminPath('noticias')}?noticia=${item.id}`
  if (item.kind === 'media') return `${adminPath('medios')}?medio=${item.id}`
  return adminPath(`${route}/${item.id}`)
}
