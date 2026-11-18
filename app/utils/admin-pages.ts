import { localizedRoutes } from '~~/i18n/localized-routes'
import type { Database } from '~/types/database.types'
import type { AdminStatusKind } from '~/utils/admin-status'
import { altPublishMessage } from '~/utils/content-alt'

/** The five fixed pages of the site (D34): the key set is closed, nothing is created, duplicated or deleted. */
export type PageKey = 'about' | 'transparency' | 'legal_notice' | 'privacy' | 'cookies'

export interface PageDef {
  key: PageKey
  /** Name in the panel (the stored title can be edited). */
  label: string
  /** Legal pages: no unpublishing, text only, always noindex, share image of Ajustes, "Última actualización". */
  legal: boolean
  group: 'about' | 'legal'
  routeEs: string
  routeEn: string
  /** `seo.<name>` of the default description of this page (site copy, es/en). */
  descriptionKey: string
  /** Where the site links to it (explains why unpublishing is rarely a good idea). */
  links: string[]
}

const route = (name: 'about' | 'transparency' | 'privacy' | 'cookies' | 'legal-notice') => localizedRoutes[name]

export const PAGE_DEFS: Record<PageKey, PageDef> = {
  about: {
    key: 'about', label: 'Sobre mí', legal: false, group: 'about', routeEs: route('about').es, routeEn: `/en${route('about').en}`, descriptionKey: 'aboutDescription',
    links: ['Pie del sitio', 'Firma y tarjeta de autor de cada artículo'],
  },
  transparency: {
    key: 'transparency', label: 'Transparencia', legal: false, group: 'about', routeEs: route('transparency').es, routeEn: `/en${route('transparency').en}`, descriptionKey: 'transparencyDescription',
    links: ['Leyenda y fichas de rocódromo', 'Reseñas del autor', 'Enlaces de afiliado de pies de gato', 'Cabecera de artículos con visita invitada o afiliado', 'Sobre mí'],
  },
  legal_notice: {
    key: 'legal_notice', label: 'Aviso legal', legal: true, group: 'legal', routeEs: route('legal-notice').es, routeEn: `/en${route('legal-notice').en}`, descriptionKey: 'legalNoticeDescription',
    links: ['Pie del sitio'],
  },
  privacy: {
    key: 'privacy', label: 'Política de privacidad', legal: true, group: 'legal', routeEs: route('privacy').es, routeEn: `/en${route('privacy').en}`, descriptionKey: 'privacyDescription',
    links: ['Pie del sitio', 'Casilla de consentimiento de la newsletter', 'Formulario de opiniones'],
  },
  cookies: {
    key: 'cookies', label: 'Política de cookies', legal: true, group: 'legal', routeEs: route('cookies').es, routeEn: `/en${route('cookies').en}`, descriptionKey: 'cookiesDescription',
    links: ['Pie del sitio', 'Aviso de vídeos de YouTube (cuando haya)'],
  },
}

/** Fixed order of the list: the two author pages, then the legal ones. */
export const PAGE_ORDER: PageKey[] = ['about', 'transparency', 'legal_notice', 'privacy', 'cookies']
export const PAGE_GROUPS: { id: PageDef['group']; label: string }[] = [
  { id: 'about', label: 'Sobre ChalkGuide' },
  { id: 'legal', label: 'Legales' },
]

export const isPageKey = (value: unknown): value is PageKey => typeof value === 'string' && value in PAGE_DEFS

export const LEGAL_NO_UNPUBLISH = 'Las páginas legales no se despublican: se corrigen con cambios.'
/** Real delay between "Publicar" and the site showing it (ISR of 10 min, osset-op). */
export const PAGE_DELAY = 'Se verá en el sitio en unos minutos (hasta 10 min).'

type ListRow = Database['guide']['Functions']['admin_pages_list']['Returns'][number]

/** Row of the list: the RPC row plus whether the Spanish body is empty. */
export interface AdminPageRow extends ListRow {
  empty: boolean
  /** The Spanish body still has `[XAVI: …]` or "Texto provisional" marks. */
  provisional: boolean
}

export interface PageChip {
  status: AdminStatusKind
  label: string
  changes: number
}

export function pageChip(row: Pick<AdminPageRow, 'published' | 'draft_changes' | 'empty'>): PageChip {
  if (row.published) return { status: row.draft_changes > 0 ? 'revised' : 'published', label: 'Publicada', changes: row.draft_changes }
  return { status: 'draft', label: row.empty ? 'Sin contenido' : 'Borrador', changes: 0 }
}

/** What the "Buscadores" column says. */
export function pageIndexing(def: PageDef, row: Pick<AdminPageRow, 'published' | 'noindex'>): { text: string; hidden: boolean } {
  if (def.legal) return { text: 'Nunca (legal)', hidden: true }
  if (!row.published) return { text: 'No, sin publicar', hidden: false }
  return row.noindex ? { text: 'No (No indexar)', hidden: true } : { text: 'Sí', hidden: false }
}

/** Small amber note under the route while the text is still a placeholder (D34). */
export function pageNote(row: Pick<AdminPageRow, 'published' | 'empty' | 'provisional'>): string {
  if (row.published) return ''
  if (row.provisional) return 'Texto provisional'
  return row.empty ? 'Sin texto todavía' : ''
}

const FULL_DATE = new Intl.DateTimeFormat('es-ES', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })

/** `2026-10-24` → "24 de octubre de 2026" (what the reader sees under the title). */
export function revisedLabel(date: string): string {
  return FULL_DATE.format(new Date(`${date}T00:00:00Z`))
}

/** Today in Barcelona as `YYYY-MM-DD` (the database's `current_date` for "Hoy"). */
export function todayIso(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Madrid' }).format(now)
}

const msg = (error: unknown) => (error as { message?: string } | null)?.message ?? ''
const codeOf = (error: unknown) => (error as { code?: string } | null)?.code

/** Spanish message for a database/network error from the pages services (PT423, PT409, PT422, 23514, 42501, 22023). */
export function pageErrorMessage(error: unknown, nameOf?: (id: string) => string | undefined): string {
  const alt = altPublishMessage(error, nameOf)
  if (alt) return alt
  const code = codeOf(error)
  const message = msg(error)
  if (/legal_page_cannot_unpublish/.test(message)) return LEGAL_NO_UNPUBLISH
  if (code === 'PT423' && /pending draft/i.test(message)) return 'Esta página tiene un borrador de cambios sin publicar: publícalo o descártalo primero.'
  if (code === 'PT423' || code === 'LIVE') return 'La página ya está publicada: se edita con borrador de cambios.'
  if (code === 'PT409') return 'Lo publicado cambió mientras editabas. Recarga e inténtalo de nuevo.'
  if (code === '23514' && /pages_legal_text_only/.test(message)) return 'Las páginas legales solo admiten texto, títulos, listas y enlaces: quita imágenes, vídeos y fichas.'
  if (code === '23514' && /pages_legal_fixed/.test(message)) return 'Las páginas legales no se indexan ni llevan imagen propia para compartir.'
  if (code === '23514' && /revised_on/.test(message)) return 'La fecha de última actualización no puede ser futura.'
  if (code === '23514' && /check violation:/i.test(message)) return 'Hay un campo que no cumple las reglas de la página: revisa los marcados en rojo.'
  if (code === '23514') return 'Algún dato no cumple las reglas de la página (longitud o formato).'
  if (code === '42501') return 'No tienes permiso para hacer esto. Vuelve a entrar al panel.'
  if (code === '22023' && /column not allowed/i.test(message)) return 'Se ha intentado guardar un campo que no se puede cambiar desde aquí.'
  if (code === '22023' && /page not live/i.test(message)) return 'La página no está publicada, así que no hay nada que despublicar.'
  if (code === '22023') return 'Esta página no tiene cambios que descartar o está en otro estado.'
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}
