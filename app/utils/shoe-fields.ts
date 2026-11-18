import { COMMON_FIELDS, REVIEW_FIELDS, ITEM_FIELDS, blankForm, buildForm, buildSections, defField, parseNumber, type Columns, type FormOf, type ItemForm, type Sections } from '~/utils/item-fields'

/** Field catalogue of the shoe editor (F6.9): the shared item blocks plus the technical sheet, price, affiliate and the author's own data. */

type Pair = readonly [value: string, label: string]

/** Enums of the DB CHECKs (guide.shoes) with the Spanish label shown in the panel. */
export const SHOE_FIT: readonly Pair[] = [['unisex', 'Unisex'], ['women', 'Mujer'], ['men', 'Hombre'], ['kids', 'Niños']]
export const SHOE_FIT_DEFAULT = 'unisex'
export const SHOE_PROFILE: readonly Pair[] = [['flat', 'Plano'], ['moderate', 'Moderado'], ['aggressive', 'Agresivo']]
export const SHOE_ASYMMETRY: readonly Pair[] = [['none', 'Ninguna'], ['slight', 'Ligera'], ['moderate', 'Moderada'], ['strong', 'Fuerte']]
export const SHOE_CLOSURE: readonly Pair[] = [['lace', 'Cordones'], ['velcro', 'Velcro'], ['slipper', 'Slipper']]
export const SHOE_STIFFNESS: readonly (readonly [number, string])[] = [[1, 'Muy blanda'], [2, 'Blanda'], [3, 'Media'], [4, 'Rígida'], [5, 'Muy rígida']]
export const SHOE_USE: readonly Pair[] = [['gym', 'Rocódromo'], ['boulder', 'Bloque'], ['sport', 'Deportiva'], ['trad', 'Clásica'], ['multipitch', 'Vías largas'], ['training', 'Entrenamiento']]
export const SHOE_LEVEL: readonly Pair[] = [['beginner', 'Inicio'], ['intermediate', 'Intermedio'], ['advanced', 'Avanzado']]

export const SHOE_SIZE = { min: 30, max: 50, step: 0.5, start: 42 } as const
export const SHOE_NOTE_MAX = 140

export const SHOE_FIELDS = [
  ...ITEM_FIELDS,
  defField('brand', 'detail', 'text'),
  defField('model', 'detail', 'text'),
  defField('fit', 'detail', 'req'),
  defField('profile', 'detail', 'text'),
  defField('asymmetry', 'detail', 'text'),
  defField('closure', 'detail', 'text'),
  defField('rubber', 'detail', 'text'),
  defField('rubber_thickness_mm', 'detail', 'dec'),
  defField('stiffness', 'detail', 'scale'),
  defField('recommended_use', 'detail', 'list'),
  defField('levels', 'detail', 'list'),
  defField('price_min_eur', 'detail', 'dec'),
  defField('price_max_eur', 'detail', 'dec'),
  defField('price_checked_at', 'detail', 'date'),
  defField('affiliate_url', 'detail', 'text'),
  defField('affiliate_program', 'detail', 'text'),
  defField('owned_by_author', 'detail', 'bool'),
  defField('author_size_eu', 'detail', 'dec'),
  defField('author_street_size_eu', 'detail', 'dec'),
  defField('author_size_note_es', 'detail', 'text'),
  defField('author_size_note_en', 'detail', 'text'),
  ...REVIEW_FIELDS,
] as const

type ShoeOwn = FormOf<typeof SHOE_FIELDS>
export interface ShoeForm extends ItemForm, ShoeOwn {}

/** The author's own data (sizes and notes): the database only accepts them when he owns the model. */
export const OWNED_ONLY = ['author_size_eu', 'author_street_size_eu', 'author_size_note_es', 'author_size_note_en'] as const

export function shoeFromRows(rows: { item: Columns; detail: Columns; review: Columns | null }, scores: Record<string, number>, gallery: string[]): ShoeForm {
  // Address and contact fields do not exist for shoes: the shared validation reads them, so they stay blank.
  const form = { ...blankForm<ShoeForm>(COMMON_FIELDS), ...buildForm<ShoeForm>(SHOE_FIELDS, rows, scores, gallery) }
  // brand and model are null until the sheet is published (empty text); fit is never null.
  if (!SHOE_FIT.some(([value]) => value === form.fit)) form.fit = SHOE_FIT_DEFAULT
  return form
}

export function shoeSections(form: ShoeForm, clean: (html: string) => string, skip: ReadonlySet<string> = new Set(), fallback?: Sections): Sections {
  const out = buildSections(SHOE_FIELDS, form, clean, skip, fallback)
  if (!form.owned_by_author) for (const column of OWNED_ONLY) out.detail[column] = null
  // The database refuses invisible characters at the ends of brand and model (CHECK shoes_*_trimmed).
  for (const column of ['brand', 'model'] as const) if (typeof out.detail[column] === 'string') out.detail[column] = trimInvisible(out.detail[column])
  return out
}

/** Text of a size ("42,5") moved by `delta` pairs of half sizes, kept inside 30–50; an empty box starts at 42. */
export function stepSize(text: string, direction: 1 | -1): string {
  const current = parseNumber(text)
  const next = current === null ? SHOE_SIZE.start : Math.min(SHOE_SIZE.max, Math.max(SHOE_SIZE.min, Math.round((current + direction * SHOE_SIZE.step) * 2) / 2))
  return String(next).replace('.', ',')
}

/** Difference between the size he wears in the model and in the street ("−1", "+0,5", "0"); `null` unless both are valid. */
export function sizeDelta(size: string, street: string): string | null {
  const a = parseNumber(size)
  const b = parseNumber(street)
  if (a === null || b === null) return null
  const diff = Math.round((a - b) * 2) / 2
  const text = String(Math.abs(diff)).replace('.', ',')
  return diff === 0 ? '0' : `${diff < 0 ? '−' : '+'}${text}`
}

export const optionLabel = (options: readonly Pair[], value: string) => options.find(([v]) => v === value)?.[1] ?? value

/** Options of a segmented control or select from an enum catalogue. */
export const shoeOptions = (list: readonly Pair[]) => list.map(([value, label]) => ({ value, label }))
