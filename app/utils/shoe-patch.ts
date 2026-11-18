import type { ChangeEntry } from '~/utils/article-changes'
import { parseNumber } from '~/utils/item-fields'
import { ITEM_META, changedFieldIds, checkNumber, describeItemChanges, validateItem, valueMeta, wordsMeta, type ItemErrors, type Shower } from '~/utils/item-patch'
import { AFFILIATE_URL_MESSAGE } from '~/utils/check-violation'
import { OWNED_ONLY, SHOE_ASYMMETRY, SHOE_CLOSURE, SHOE_FIELDS, SHOE_FIT, SHOE_LEVEL, SHOE_NOTE_MAX, SHOE_PROFILE, SHOE_SIZE, SHOE_STIFFNESS, SHOE_USE, optionLabel, type ShoeForm } from '~/utils/shoe-fields'

/** Shoe side of the item validation and change list. */
export function validateShoe(form: ShoeForm, taken: ReadonlySet<string>, live = false): ItemErrors {
  const errors = validateItem(form, taken, 'pie de gato')
  const text = (id: 'brand' | 'model' | 'rubber' | 'affiliate_program', max: number) => {
    if (form[id].trim().length > max) errors[id] = `Máximo ${max} caracteres.`
  }
  // Empty is fine on a draft sheet (null in the database); a published one cannot lose them (publishing would fail).
  if (live && !form.brand.trim()) errors.brand = 'La ficha está publicada: la marca no puede quedar vacía.'
  if (live && !form.model.trim()) errors.model = 'La ficha está publicada: el modelo no puede quedar vacío.'
  text('brand', 60)
  text('model', 80)
  text('rubber', 80)
  text('affiliate_program', 80)
  checkNumber(errors, 'rubber_thickness_mm', form.rubber_thickness_mm, { gt: 0, max: 99.9 })
  checkNumber(errors, 'price_min_eur', form.price_min_eur, { min: 0, max: 9999.99 })
  checkNumber(errors, 'price_max_eur', form.price_max_eur, { min: 0, max: 9999.99 })
  const low = parseNumber(form.price_min_eur)
  const high = parseNumber(form.price_max_eur)
  if (!errors.price_max_eur && low !== null && high !== null && high < low) errors.price_max_eur = 'El precio máximo no puede ser menor que el mínimo.'
  const url = form.affiliate_url.trim()
  if (url && (!/^https:\/\/\S+$/.test(url) || url.length > 2048 || /["'<>]/.test(url) || !isUrl(url))) errors.affiliate_url = AFFILIATE_URL_MESSAGE
  if (!url && form.affiliate_program.trim()) errors.affiliate_program = 'Sin enlace no hay programa: vacíalo o pon el enlace.'
  if ((low !== null || high !== null) && !form.price_checked_at) {
    // The database refuses a price without date, so the price is held back from the autosave until the date is there.
    errors.price_checked_at = 'Si hay precio, pon la fecha en que lo verificaste («Verificar hoy»).'
    if (low !== null && !errors.price_min_eur) errors.price_min_eur = 'Falta la fecha del precio.'
    if (high !== null && !errors.price_max_eur) errors.price_max_eur = 'Falta la fecha del precio.'
  }
  if (form.owned_by_author) checkOwned(form, errors)
  return errors
}

const isUrl = (text: string) => {
  try {
    return new URL(text).hostname.includes('.')
  } catch {
    return false
  }
}

/** His sizes (30–50, half sizes, both or none) and the fit notes (140, English needs Spanish). */
function checkOwned(form: ShoeForm, errors: ItemErrors) {
  for (const id of ['author_size_eu', 'author_street_size_eu'] as const) {
    checkNumber(errors, id, form[id], { min: SHOE_SIZE.min, max: SHOE_SIZE.max })
    const n = parseNumber(form[id])
    if (!errors[id] && n !== null && n * 2 !== Math.trunc(n * 2)) errors[id] = 'Va de media en media talla (42, 42,5…).'
  }
  const size = form.author_size_eu.trim()
  const street = form.author_street_size_eu.trim()
  if (size && !street && !errors.author_street_size_eu) errors.author_street_size_eu = 'Falta la talla de calle: las dos o ninguna.'
  if (street && !size && !errors.author_size_eu) errors.author_size_eu = 'Falta la talla que usas: las dos o ninguna.'
  for (const id of ['author_size_note_es', 'author_size_note_en'] as const) if (form[id].trim().length > SHOE_NOTE_MAX) errors[id] = `Máximo ${SHOE_NOTE_MAX} caracteres.`
  if (form.author_size_note_en.trim() && !form.author_size_note_es.trim()) errors.author_size_note_en = 'La nota en inglés necesita la nota en español.'
}

export const SHOE_META = {
  ...ITEM_META,
  visit_type: valueMeta('Cómo los conseguí'),
  visit_date: valueMeta('Usándolos desde'),
  brand: wordsMeta('Marca'),
  model: wordsMeta('Modelo'),
  fit: valueMeta('Horma'),
  profile: valueMeta('Perfil'),
  asymmetry: valueMeta('Asimetría'),
  closure: valueMeta('Cierre'),
  rubber: wordsMeta('Goma'),
  rubber_thickness_mm: valueMeta('Grosor de la goma (mm)'),
  stiffness: valueMeta('Rigidez'),
  recommended_use: valueMeta('Uso recomendado'),
  levels: valueMeta('Nivel'),
  price_min_eur: valueMeta('Precio desde (€)'),
  price_max_eur: valueMeta('Precio hasta (€)'),
  price_checked_at: valueMeta('Precio verificado el'),
  affiliate_url: valueMeta('Enlace de afiliado'),
  affiliate_program: wordsMeta('Programa de afiliados'),
  owned_by_author: valueMeta('Los tengo y los he usado'),
  author_size_eu: valueMeta('Talla que uso (EU)'),
  author_street_size_eu: valueMeta('Talla de calle (EU)'),
  author_size_note_es: { label: 'Nota de ajuste', lang: 'ES' as const, kind: 'words' as const },
  author_size_note_en: { label: 'Nota de ajuste', lang: 'EN' as const, kind: 'words' as const },
}

const labels = (options: readonly (readonly [string, string])[], values: string[]) => values.map((v) => optionLabel(options, v)).join(', ') || 'Ninguno'

const showShoe: Shower = (id, value) => {
  switch (id) {
    case 'visit_type': return value === 'invited' ? 'Cedidos por la marca' : 'Comprados'
    case 'fit': return optionLabel(SHOE_FIT, String(value))
    case 'profile': return value ? optionLabel(SHOE_PROFILE, String(value)) : 'Sin dato'
    case 'asymmetry': return value ? optionLabel(SHOE_ASYMMETRY, String(value)) : 'Sin dato'
    case 'closure': return value ? optionLabel(SHOE_CLOSURE, String(value)) : 'Sin dato'
    case 'stiffness': return SHOE_STIFFNESS.find(([n]) => n === value)?.[1] ?? 'Sin dato'
    case 'recommended_use': return labels(SHOE_USE, value as string[])
    case 'levels': return labels(SHOE_LEVEL, value as string[])
    default: return undefined
  }
}

/** Ids of the sizes and notes are ignored in the change list while he does not own the model (they are not sent). */
const sentIds = (form: ShoeForm, ids: string[]) => (form.owned_by_author ? ids : ids.filter((id) => !(OWNED_ONLY as readonly string[]).includes(id)))

export const shoeChangedIds = (current: ShoeForm, base: ShoeForm) => sentIds(current, changedFieldIds(SHOE_FIELDS, current, base))
export const describeShoeChanges = (base: ShoeForm, current: ShoeForm, criteria: Map<string, string>): ChangeEntry[] =>
  describeItemChanges(SHOE_FIELDS, SHOE_META, showShoe, base, current, criteria).filter((entry) => sentIds(current, [entry.key]).length > 0)
