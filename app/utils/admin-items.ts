import { BLOCKER_TEXT } from '~/utils/item-blockers'
import { altPublishMessage } from '~/utils/content-alt'
import { isFresh } from '~/utils/item-checklist'

/** Row of the items list (gyms, resolers): item + gym + counts. */
export interface AdminItemRow {
  id: string
  name: string
  slug: string
  published: boolean
  published_at: string | null
  is_featured: boolean
  has_en: boolean
  verified_at: string | null
  updated_at: string
  /** Barrio (gyms, resolers) or brand (shoes). */
  district: string | null
  city: string
  /** Has a cover (`cover_media_id`, the draft's one if it carries it). */
  has_cover: boolean
  /** Unpublished changes (0 = no draft). */
  changes: number
  reviews: number
}

export type ItemView = 'all' | 'published' | 'changes' | 'draft' | 'stale'

export const ITEM_VIEWS: { value: ItemView; label: string }[] = [
  { value: 'all', label: 'Todos' },
  { value: 'published', label: 'Publicadas' },
  { value: 'changes', label: 'Con cambios' },
  { value: 'draft', label: 'Borradores y ocultos' },
  { value: 'stale', label: 'Por verificar' },
]

/** Chip text for an item: feminine ("Publicada", "Oculta"); drafts keep the default. */
export const itemChipLabel = (status: AdminStatusKind) => (status === 'published' || status === 'revised' ? 'Publicada' : status === 'hidden' ? 'Oculta' : undefined)

export const needsVerification = (row: AdminItemRow) => !row.verified_at || !isFresh(row.verified_at)

export function matchesItemView(row: AdminItemRow, view: ItemView): boolean {
  switch (view) {
    case 'all': return true
    case 'published': return row.published
    case 'changes': return row.changes > 0
    case 'draft': return !row.published
    case 'stale': return needsVerification(row)
  }
}

export function countItemViews(rows: readonly AdminItemRow[]): Record<ItemView, number> {
  const counts = {} as Record<ItemView, number>
  for (const { value } of ITEM_VIEWS) counts[value] = rows.filter((row) => matchesItemView(row, value)).length
  return counts
}

/** "No se puede publicar: falta …" from the comma-separated codes of a 23514 `items_publish_ready` error. */
function publishBlockedMessage(detail: string): string {
  const parts = detail.split(',').map((c) => c.trim()).filter(Boolean).map((c) => BLOCKER_TEXT[c] ?? `un requisito pendiente (${c})`)
  return parts.length ? `No se puede publicar todavía. Falta: ${parts.join('; ')}.` : 'No se puede publicar todavía: faltan datos obligatorios de la ficha.'
}

/** Spanish message for a database/network error from the item services (`noun` = "rocódromo", "resolador"). */
export function itemErrorMessage(error: unknown, nameOf?: (id: string) => string | undefined, noun = 'rocódromo'): string {
  const alt = altPublishMessage(error, nameOf)
  if (alt) return alt
  const code = (error as { code?: string } | null)?.code
  const message = (error as { message?: string } | null)?.message ?? ''
  const detail = (error as { details?: string; detail?: string } | null)?.details ?? (error as { detail?: string } | null)?.detail ?? ''
  if (code === '23505' && /shoes_brand_model_key/.test(message)) return 'Ya existe un pie de gato con esa marca y ese modelo.'
  if (code === '23505') return `Ya existe un ${noun} con esa URL. Prueba con otra.`
  if (code === '23503' && /user reviews/i.test(message)) return 'La ficha tiene opiniones de usuarios y no se puede eliminar. Si está publicada, ocúltala.'
  if (code === '23503') return 'Falta un dato relacionado (una imagen o un criterio de nota) o hay datos que dependen de esta ficha.'
  if (code === 'PT423' && /delete/i.test(message)) return 'La ficha está publicada: ocúltala antes de eliminarla.'
  if (code === 'PT423') return 'La ficha está publicada: los cambios van al borrador. Recarga la página para continuar.'
  if (code === '22023' && /item not live/i.test(message)) return 'La ficha ya no está publicada. Recarga para ver su estado actual.'
  if (code === '22023' && /invalid section: scores/i.test(message) && /inactive criterion/i.test(detail)) return 'Esa nota es de un criterio desactivado y no se puede cambiar. Reactívalo en Criterios de nota para editarla.'
  if (code === '22023' && /invalid section: scores/i.test(message)) return 'Alguna nota usa un criterio que ya no es de esta categoría. Recarga la página y revisa las notas.'
  if (code === 'P0002') return 'La ficha ya no existe (quizá se eliminó en otra pestaña). Vuelve al listado.'
  if (code === '23514' && /items_publish_ready/i.test(message)) return publishBlockedMessage(detail)
  if (code === '23514' && /check violation:/i.test(message)) return 'Hay un campo que no cumple las reglas de la ficha: revisa los marcados en rojo.'
  if (code === '23514' || code === '22023' || code === '22P02' || code === '22007') return 'Algún dato no cumple las reglas de la ficha (formato, longitud o rango).'
  if (code === '42501') return 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.'
  if (code === 'PT409') return 'La ficha publicada ha cambiado mientras editabas (en otra pestaña o dispositivo). Recarga para ver la versión actual o publica tus cambios igualmente.'
  if (code === 'LIVE') return message
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}
