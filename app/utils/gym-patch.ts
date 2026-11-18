import { TRI_FIELDS, GYM_FIELDS, type GymForm } from '~/utils/gym-fields'
import type { ChangeEntry } from '~/utils/article-changes'
import { ITEM_META, checkNumber, describeItemChanges, changedFieldIds, wordsMeta, valueMeta, validateItem, type ItemErrors, type Shower } from '~/utils/item-patch'
import { WEEKDAYS, closingValue, isClosingTime, isOpeningTime, minutes } from '~/utils/opening-hours'

// Gym side of the item patch/validation/change-list machinery (see item-patch.ts for the shared part).

/** Field errors the database would reject. Keys are field ids (hours: `opening_hours.mon`). `taken` = slugs of other gyms. */
export function validateGym(form: GymForm, taken: ReadonlySet<string>): ItemErrors {
  const errors = validateItem(form, taken, 'rocódromo')
  for (const id of ['price_registration_eur', 'price_day_eur', 'price_10_pass_eur', 'price_monthly_eur'] as const) checkNumber(errors, id, form[id], { min: 0, max: 9999.99 })
  checkNumber(errors, 'surface_m2', form.surface_m2, { gt: 0, int: true })
  checkNumber(errors, 'max_height_m', form.max_height_m, { gt: 0, max: 999.9 })
  checkNumber(errors, 'routes_count', form.routes_count, { min: 0, int: true })
  checkNumber(errors, 'autobelays_count', form.autobelays_count, { min: 0, int: true })
  checkNumber(errors, 'kids_min_age', form.kids_min_age, { min: 0, max: 18, int: true })
  for (const day of WEEKDAYS) {
    const { closed, slots } = form.opening_hours[day]
    if (closed) continue
    for (const [open, close] of slots) {
      if (!isOpeningTime(open) || !isClosingTime(close)) errors[`opening_hours.${day}`] = 'Escribe las horas con el formato 07:00. Para cerrar a medianoche, escribe 24:00.'
      else if ((minutes(closingValue(close)) ?? 0) <= (minutes(open) ?? 0)) errors[`opening_hours.${day}`] = `La hora de cierre (${close}) debe ser posterior a la de apertura (${open}).`
    }
  }
  return errors
}

export const GYM_META = {
  ...ITEM_META,
  metro_stations: valueMeta('Paradas de metro'),
  opening_hours: valueMeta('Horario'),
  opening_hours_note_es: wordsMeta('Nota de horario', 'ES'),
  opening_hours_note_en: wordsMeta('Nota de horario', 'EN'),
  price_registration_eur: valueMeta('Matrícula (€)'),
  price_day_eur: valueMeta('Entrada de día (€)'),
  price_10_pass_eur: valueMeta('Bono 10 (€)'),
  price_monthly_eur: valueMeta('Cuota mensual (€)'),
  discounts_es: wordsMeta('Descuentos', 'ES'),
  discounts_en: wordsMeta('Descuentos', 'EN'),
  prices_verified_at: valueMeta('Precios verificados el'),
  surface_m2: valueMeta('Superficie (m²)'),
  max_height_m: valueMeta('Altura máxima (m)'),
  routes_count: valueMeta('Vías'),
  autobelays_count: valueMeta('Autobelays'),
  kids_min_age: valueMeta('Edad mínima de niños'),
  grading_difficulty: valueMeta('Grados'),
  setting_dynamism: valueMeta('Estilo'),
  ...Object.fromEntries(TRI_FIELDS.map(([id, label]) => [id, valueMeta(label)])),
}

const SCALE_ES = ['', 'Generosos', 'Algo generosos', 'En la media', 'Algo duros', 'Duros']
const SCALE_STYLE = ['', 'Muy técnico', 'Técnico', 'Mixto', 'Dinámico', 'Muy dinámico']
const DAY_ES: Record<string, string> = { mon: 'lun', tue: 'mar', wed: 'mié', thu: 'jue', fri: 'vie', sat: 'sáb', sun: 'dom' }

const showGym: Shower = (id, value, form) => {
  if (id === 'grading_difficulty' || id === 'setting_dynamism') return value === null ? 'Sin dato' : ((id === 'grading_difficulty' ? SCALE_ES : SCALE_STYLE)[value as number] ?? '')
  if (id === 'opening_hours') {
    const hours = (form as GymForm).opening_hours
    return WEEKDAYS.map((d) => `${DAY_ES[d]} ${hours[d].closed ? 'cerrado' : hours[d].slots.map((s) => s.join('–')).join(', ') || '—'}`).join(' · ')
  }
  return undefined
}

export const gymChangedIds = (current: GymForm, base: GymForm) => changedFieldIds(GYM_FIELDS, current, base)
export const describeGymChanges = (base: GymForm, current: GymForm, criteria: Map<string, string>): ChangeEntry[] => describeItemChanges(GYM_FIELDS, GYM_META, showGym, base, current, criteria)
