import type { Database } from '~/types/database.types'

type ArticleStatus = Database['guide']['Enums']['article_status']

/** Category row of the panel with its article counters. */
export interface AdminCategory {
  id: string
  name_es: string
  name_en: string | null
  slug_es: string
  slug_en: string | null
  description_es: string | null
  description_en: string | null
  color: string | null
  sort_order: number
  has_en: boolean
}

/** Minimal article of a category (ordering list; no bodies). */
export interface AdminCategoryArticle {
  id: string
  title_es: string
  status: ArticleStatus
  published_at: string | null
  category_id: string
  sort_order: number
  is_featured: boolean
}

export interface CategoryCounts {
  total: number
  /** Live now (published, or scheduled with a past date). */
  published: number
  scheduled: number
  draft: number
}

export function articleCounts(articles: readonly AdminCategoryArticle[], now = Date.now()): CategoryCounts {
  const counts: CategoryCounts = { total: articles.length, published: 0, scheduled: 0, draft: 0 }
  for (const article of articles) {
    const display = articleDisplay(article, now)
    if (display === 'published') counts.published++
    else if (display === 'scheduled') counts.scheduled++
    else counts.draft++
  }
  return counts
}

export const pluralArticles = (n: number) => `${n} ${n === 1 ? 'artículo' : 'artículos'}`

/** "2 publicados", "1 programado", "3 borradores" (singular/plural agree). */
export function statusSummary(counts: CategoryCounts): string {
  const part = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`
  return [
    part(counts.published, 'publicado', 'publicados'),
    part(counts.scheduled, 'programado', 'programados'),
    part(counts.draft, 'borrador', 'borradores'),
  ].join(', ')
}

/** "4 artículos (2 publicados)" as the design's delete dialog. */
export function countsSummary(counts: CategoryCounts): string {
  if (!counts.total) return 'sin artículos'
  const live = counts.published ? ` (${counts.published} ${counts.published === 1 ? 'publicado' : 'publicados'})` : ''
  return `${pluralArticles(counts.total)}${live}`
}

/** Colours of the design (categorias.html); free hex is also allowed. */
export const CATEGORY_COLORS = ['#E07A5F', '#3D5A80', '#81B29A', '#F2CC8F', '#6D597A', '#B56576'] as const

const HEX = /^#[0-9a-f]{6}$/i
export const isCategoryColor = (value: string) => HEX.test(value)

export interface CategoryForm {
  name_es: string
  name_en: string
  slug_es: string
  slug_en: string
  description_es: string
  description_en: string
  color: string
}

export const emptyCategoryForm = (): CategoryForm => ({
  name_es: '', name_en: '', slug_es: '', slug_en: '', description_es: '', description_en: '', color: CATEGORY_COLORS[0],
})

export function categoryToForm(category: AdminCategory): CategoryForm {
  return {
    name_es: category.name_es,
    name_en: category.name_en ?? '',
    slug_es: category.slug_es,
    slug_en: category.slug_en ?? '',
    description_es: category.description_es ?? '',
    description_en: category.description_en ?? '',
    color: category.color ?? '',
  }
}

export type CategoryField = keyof CategoryForm
export type CategoryErrors = Partial<Record<CategoryField, string>>

const MAX_NAME = 80
const MAX_DESCRIPTION = 160

/** Mirrors the table checks, including `article_categories_en_coherent` (EN name and slug go together). */
export function validateCategory(form: CategoryForm): CategoryErrors {
  const errors: CategoryErrors = {}
  if (!form.name_es.trim()) errors.name_es = 'Escribe el nombre en español.'
  else if (form.name_es.trim().length > MAX_NAME) errors.name_es = `Máximo ${MAX_NAME} caracteres.`
  if (!form.slug_es) errors.slug_es = 'Escribe la URL en español.'
  if (form.name_en.trim().length > MAX_NAME) errors.name_en = `Máximo ${MAX_NAME} caracteres.`
  const hasName = !!form.name_en.trim()
  const hasSlug = !!form.slug_en
  if (hasName && !hasSlug) errors.slug_en = 'Si hay nombre en inglés, falta su URL.'
  if (hasSlug && !hasName) errors.name_en = 'Si hay URL en inglés, falta su nombre.'
  if (form.description_es.length > MAX_DESCRIPTION) errors.description_es = `Máximo ${MAX_DESCRIPTION} caracteres.`
  if (form.description_en.length > MAX_DESCRIPTION) errors.description_en = `Máximo ${MAX_DESCRIPTION} caracteres.`
  if (form.color && !isCategoryColor(form.color)) errors.color = 'Usa el formato #rrggbb, por ejemplo #81B29A.'
  return errors
}

/** Empty strings become null (the DB checks reject empty text). */
export function formToPayload(form: CategoryForm) {
  const text = (value: string) => value.trim() || null
  return {
    name_es: form.name_es.trim(),
    name_en: text(form.name_en),
    slug_es: form.slug_es,
    slug_en: form.slug_en || null,
    description_es: text(form.description_es),
    description_en: text(form.description_en),
    color: form.color ? form.color.toLowerCase() : null,
  }
}

/** Slugs already used by other categories, per language (the DB enforces unique). */
export function takenCategorySlugs(categories: readonly AdminCategory[], excludeId?: string) {
  const es = new Set<string>()
  const en = new Set<string>()
  for (const category of categories) {
    if (category.id === excludeId) continue
    es.add(category.slug_es)
    if (category.slug_en) en.add(category.slug_en)
  }
  return { es, en }
}

/** Delete refused because articles or pending drafts still use the category and no target was given. */
export const isTargetRequiredError = (error: unknown) =>
  (error as { code?: string } | null)?.code === '22023' && /target required/i.test((error as { message?: string }).message ?? '')

/** Spanish message for a database/network error of the categories screen. */
export function categoryErrorMessage(error: unknown): string {
  const code = (error as { code?: string } | null)?.code
  const message = (error as { message?: string } | null)?.message ?? ''
  if (code === '23505') return 'Ya hay una categoría con esa URL. Prueba con otra.'
  if (code === '23514') return 'Algún dato no cumple las reglas (longitud, color o nombre y URL en inglés juntos).'
  if (code === '42501') return 'No tienes permiso para hacer esto. Vuelve a entrar al panel.'
  if (code === 'P0002') return 'La categoría ya no existe (quizá la eliminaron en otra pestaña). Lista recargada.'
  if (code === '22023') {
    if (/target required/i.test(message)) return 'Esta categoría la usan artículos o borradores de cambios pendientes. Elige a qué categoría moverlos.'
    if (/target must differ/i.test(message)) return 'El destino tiene que ser una categoría distinta de la que eliminas.'
    if (/target category not found/i.test(message)) return 'La categoría de destino ya no existe. Lista recargada: elige otra.'
    if (/last category/i.test(message)) return 'No se puede eliminar la última categoría, aunque esté vacía. Crea otra antes.'
    if (/ids required|duplicate ids|unknown category|must include every|must belong/i.test(message)) {
      return 'La lista ha cambiado en otra pestaña. Se muestra el orden actual.'
    }
    return 'La lista o el destino ya no son válidos; puede que hayan cambiado en otra pestaña. Lista recargada: inténtalo de nuevo.'
  }
  if (code === '23503') return 'Hay artículos que dependen de esta categoría. Muévelos a otra antes de eliminarla.'
  if (code === 'PT423') return 'Hay artículos publicados que solo se editan con borrador de cambios. Recarga e inténtalo de nuevo.'
  if (code === 'PT409') return 'Los datos cambiaron mientras los mirabas. Recarga e inténtalo de nuevo.'
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}
