import type { ChangeEntry } from '~/utils/article-changes'
import { RESOLER_FIELDS, RESOLER_SERVICE_HELP, type ResolerForm } from '~/utils/resoler-fields'
import { ITEM_META, checkNumber, describeItemChanges, changedFieldIds, valueMeta, validateItem, type ItemErrors, type Shower } from '~/utils/item-patch'
import { parseNumber } from '~/utils/item-fields'

/** Resoler side of the item validation and change list. */
export function validateResoler(form: ResolerForm, taken: ReadonlySet<string>): ItemErrors {
  const errors = validateItem(form, taken, 'resolador')
  checkNumber(errors, 'price_per_pair_eur', form.price_per_pair_eur, { min: 0, max: 9999.99 })
  checkNumber(errors, 'price_rand_eur', form.price_rand_eur, { min: 0, max: 9999.99 })
  checkNumber(errors, 'turnaround_days_min', form.turnaround_days_min, { min: 0, max: 32767, int: true })
  checkNumber(errors, 'turnaround_days_max', form.turnaround_days_max, { min: 0, max: 32767, int: true })
  const min = parseNumber(form.turnaround_days_min)
  const max = parseNumber(form.turnaround_days_max)
  if (!errors.turnaround_days_max && min !== null && max !== null && max < min) errors.turnaround_days_max = `El plazo máximo (${max}) no puede ser menor que el mínimo (${min}).`
  return errors
}

export const RESOLER_META = {
  ...ITEM_META,
  services: valueMeta('Servicios'),
  price_per_pair_eur: valueMeta('Precio por par (€)'),
  price_rand_eur: valueMeta('Precio de rehacer rand (€)'),
  turnaround_days_min: valueMeta('Plazo mínimo (días)'),
  turnaround_days_max: valueMeta('Plazo máximo (días)'),
  rubber_brands: valueMeta('Marcas de goma'),
  prices_verified_at: valueMeta('Precios verificados el'),
  accepts_mail: valueMeta('Acepta envíos'),
  mail_notes_es: { label: 'Notas de envío', lang: 'ES' as const, kind: 'words' as const },
  mail_notes_en: { label: 'Notas de envío', lang: 'EN' as const, kind: 'words' as const },
}

const SERVICE_LABEL = new Map<string, string>(RESOLER_SERVICE_HELP.map(([key, label]) => [key, label]))

const showResoler: Shower = (id, value) => {
  if (id === 'services') return (value as string[]).map((s) => SERVICE_LABEL.get(s) ?? s).join(', ') || 'Ninguno'
  return undefined
}

export const resolerChangedIds = (current: ResolerForm, base: ResolerForm) => changedFieldIds(RESOLER_FIELDS, current, base)
export const describeResolerChanges = (base: ResolerForm, current: ResolerForm, criteria: Map<string, string>): ChangeEntry[] => describeItemChanges(RESOLER_FIELDS, RESOLER_META, showResoler, base, current, criteria)
