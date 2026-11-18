import { countOf } from './admin-dashboard'

export type CriterionCategory = 'gym' | 'resoler' | 'shoe'

export const CRITERION_CATEGORIES: { value: CriterionCategory; label: string }[] = [
  { value: 'gym', label: 'Rocódromos' },
  { value: 'resoler', label: 'Resoladores' },
  { value: 'shoe', label: 'Pies de gato' },
]

export const criterionCategoryOf = (value: unknown): CriterionCategory =>
  CRITERION_CATEGORIES.find((c) => c.value === value)?.value ?? 'gym'
export const criterionCategoryLabel = (value: CriterionCategory) => CRITERION_CATEGORIES.find((c) => c.value === value)?.label ?? value

export interface AdminCriterion {
  id: string
  category: CriterionCategory
  key: string
  name_es: string
  name_en: string
  description_es: string | null
  description_en: string | null
  sort_order: number
  is_active: boolean
  used_in_formula: boolean
}

export interface CriterionUsage {
  author_items: number
  user_reviews: number
  draft_items: number
  used_by_index: boolean
  can_delete: boolean
}

/** A published item of the category with the author's score per criterion id (preview and "before → after"). */
export interface CriterionSample {
  id: string
  name: string
  scores: Record<string, number>
}

export const NO_USAGE: CriterionUsage = { author_items: 0, user_reviews: 0, draft_items: 0, used_by_index: false, can_delete: true }

/** Where a criterion of a gym counts besides the plain averages (README §7.1). */
export const CRITERION_EFFECTS: Record<string, { kind: 'index' | 'table'; title: string; detail: string; lock?: string }> = {
  beginner_friendly: {
    kind: 'index',
    title: 'Índice principiantes',
    detail: '50 % del índice principiantes.',
    lock: 'Entra en el índice principiantes (50 % de la fórmula). No se puede desactivar mientras la fórmula lo use: primero habría que cambiar el índice.',
  },
  family_friendly: {
    kind: 'index',
    title: 'Índice familiar',
    detail: '20 % del índice familiar.',
    lock: 'Entra en el índice familiar (20 % de la fórmula). No se puede desactivar mientras la fórmula lo use: primero habría que cambiar el índice.',
  },
  variety: { kind: 'table', title: 'Listado de rocódromos', detail: 'columna «Variedad» de las tarjetas del listado de rocódromos.' },
}
export const criterionEffect = (c: AdminCriterion) => (c.category === 'gym' ? CRITERION_EFFECTS[c.key] : undefined)

export const pluralItems = (n: number) => countOf(n, 'ficha', 'fichas')
export const noteCount = (u: CriterionUsage) => u.author_items + u.user_reviews

/** "5 fichas · 24 lectores" or "Sin notas". */
export function usageText(u: CriterionUsage): string {
  if (!noteCount(u) && !u.draft_items) return 'Sin notas'
  const parts = [u.author_items ? pluralItems(u.author_items) : '', u.user_reviews ? countOf(u.user_reviews, 'lector', 'lectores') : '']
  return parts.filter(Boolean).join(' · ') || 'Solo en borradores'
}

export const averageOf = (scores: Record<string, number>, ids: readonly string[]): number | null => {
  const values = ids.map((id) => scores[id]).filter((v): v is number => typeof v === 'number' && v > 0)
  return values.length ? values.reduce((a, b) => a + b, 0) / values.length : null
}
export const formatAverage = (value: number | null) => (value === null ? '–' : value.toFixed(1).replace('.', ','))

// --- Form ----------------------------------------------------------------------------------------

export interface CriterionForm {
  key: string
  name_es: string
  name_en: string
  description_es: string
  description_en: string
}
export type CriterionField = keyof CriterionForm
export type CriterionErrors = Partial<Record<CriterionField, string>>

export const MAX_NAME = 80
export const MAX_DESCRIPTION = 300
export const MAX_KEY = 40
const KEY_RE = /^[a-z][a-z0-9]*(_[a-z0-9]+)*$/

export const emptyCriterionForm = (): CriterionForm => ({ key: '', name_es: '', name_en: '', description_es: '', description_en: '' })

export const criterionToForm = (c: AdminCriterion): CriterionForm => ({
  key: c.key,
  name_es: c.name_es,
  name_en: c.name_en,
  description_es: c.description_es ?? '',
  description_en: c.description_en ?? '',
})

/** Key that follows the name: no accents, `a-z 0-9 _`, starts with a letter, max 40. */
export function criterionKeyFrom(name: string): string {
  return name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^[^a-z]+/, '')
    .slice(0, MAX_KEY)
    .replace(/_+$/, '')
}

/** First free `value_2`, `value_3`… for a taken key. */
export function nextFreeKey(key: string, taken: ReadonlySet<string>): string {
  for (let n = 2; n < 100; n++) {
    const candidate = `${key.slice(0, MAX_KEY - String(n).length - 1)}_${n}`
    if (!taken.has(candidate)) return candidate
  }
  return key
}

export function validateCriterion(form: CriterionForm, opts: { isNew: boolean; takenKeys: ReadonlySet<string>; categoryLabel: string }): CriterionErrors {
  const errors: CriterionErrors = {}
  const es = form.name_es.trim()
  if (!es) errors.name_es = 'Escribe el nombre en español.'
  else if (es.length > MAX_NAME) errors.name_es = `Máximo ${MAX_NAME} caracteres.`
  const en = form.name_en.trim()
  if (!en) errors.name_en = 'Escribe el nombre en inglés.'
  else if (en.length > MAX_NAME) errors.name_en = `Máximo ${MAX_NAME} caracteres.`
  if (form.description_es.trim().length > MAX_DESCRIPTION) errors.description_es = `Máximo ${MAX_DESCRIPTION} caracteres.`
  if (form.description_en.trim().length > MAX_DESCRIPTION) errors.description_en = `Máximo ${MAX_DESCRIPTION} caracteres.`
  if (opts.isNew) {
    if (!form.key) errors.key = 'Escribe la clave interna.'
    else if (form.key.length < 2 || form.key.length > MAX_KEY || !KEY_RE.test(form.key)) {
      errors.key = 'Solo minúsculas, números y guion bajo; empieza por letra (2 a 40 caracteres).'
    } else if (opts.takenKeys.has(form.key)) {
      errors.key = `Ya hay un criterio «${form.key}» en ${opts.categoryLabel}. Prueba «${nextFreeKey(form.key, opts.takenKeys)}» o cambia el nombre.`
    }
  }
  return errors
}

/** Insert payload (no `sort_order`: the database puts it last) or update payload (only editable columns). */
export function criterionPayload(form: CriterionForm) {
  const name_es = form.name_es.trim()
  return {
    name_es,
    name_en: form.name_en.trim(),
    description_es: form.description_es.trim() || null,
    description_en: form.description_en.trim() || null,
  }
}

// --- Errors --------------------------------------------------------------------------------------

export interface CriterionError {
  message: string
  field?: CriterionField
  /** The list is out of date: reload it. */
  reload?: boolean
}

const CHECK_FIELDS: [RegExp, CriterionField, string][] = [
  [/criteria_key_check/, 'key', 'La clave no es válida: minúsculas, números y guion bajo; empieza por letra (2 a 40).'],
  [/criteria_name_es_trimmed/, 'name_es', 'El nombre en español no puede empezar ni acabar con espacios.'],
  [/criteria_name_es_check/, 'name_es', `El nombre en español debe tener entre 1 y ${MAX_NAME} caracteres.`],
  [/criteria_name_en_trimmed/, 'name_en', 'El nombre en inglés no puede empezar ni acabar con espacios.'],
  [/criteria_name_en_check/, 'name_en', `El nombre en inglés debe tener entre 1 y ${MAX_NAME} caracteres.`],
  [/criteria_description_es_check/, 'description_es', `La ayuda en español debe tener entre 1 y ${MAX_DESCRIPTION} caracteres.`],
  [/criteria_description_en_check/, 'description_en', `La ayuda en inglés debe tener entre 1 y ${MAX_DESCRIPTION} caracteres.`],
]

/** Counts in the `criterion has scores` detail: "author_review_scores: 5, user_review_scores: 3, content_drafts: 1". */
function scoresDetail(detail: string): string {
  const n = (name: string) => Number(new RegExp(`${name}:\\s*(\\d+)`).exec(detail)?.[1] ?? 0)
  const parts = [
    n('author_review_scores') && `${n('author_review_scores')} de tus notas`,
    n('user_review_scores') && `${n('user_review_scores')} de lectores`,
    n('content_drafts') && countOf(n('content_drafts'), 'borrador', 'borradores'),
  ].filter(Boolean)
  return parts.length ? ` (${parts.join(', ')})` : ''
}

/** Spanish message (and field, if any) for a database/network error of the criteria screen. */
export function criterionError(error: unknown, categoryLabel = 'esta categoría'): CriterionError {
  const e = error as { code?: string; message?: string; details?: string | null; detail?: string | null } | null
  const code = e?.code
  const message = e?.message ?? ''
  const detail = e?.details ?? e?.detail ?? ''
  if (code === '23514') {
    const hit = CHECK_FIELDS.find(([re]) => re.test(message))
    return hit ? { field: hit[1], message: hit[2] } : { message: 'Algún dato no cumple las reglas del criterio (formato o longitud).' }
  }
  if (code === '23502') return { field: 'name_en', message: 'Falta el nombre en inglés.' }
  if (code === '23505') return { field: 'key', message: `Ya hay un criterio con esa clave en ${categoryLabel}. Prueba otra.` }
  if (code === '23503' && /criterion has scores/i.test(message)) {
    return { message: `No se puede eliminar: tiene notas guardadas${scoresDetail(detail)}. Desactivarlo lo saca de medias e índices y conserva las notas.`, reload: true }
  }
  if (code === '22023' && /immutable/i.test(message)) return { message: 'La clave no se puede cambiar una vez creada.' }
  if (code === '22023' && /index formula/i.test(message)) {
    return { message: 'Este criterio entra en la fórmula de un índice: no se puede desactivar ni eliminar mientras la use.', reload: true }
  }
  if (code === '22023' && /ids required|duplicate ids|belong to the category|every criterion/i.test(message)) {
    return { message: 'La lista de criterios ha cambiado (quizá en otra pestaña). Se ha recargado: vuelve a ordenarla.', reload: true }
  }
  if (code === 'P0002') return { message: 'La categoría o el criterio ya no existe. Se ha recargado la lista.', reload: true }
  if (code === '42501') return { message: 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.' }
  if (/fetch|network|failed to load/i.test(message)) return { message: 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.' }
  return { message: 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.' }
}
