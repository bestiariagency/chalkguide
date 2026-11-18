import { CONTACT_FIELDS, GEO_FIELDS, ITEM_FIELDS, REVIEW_FIELDS, buildForm, buildSections, defField, type Columns, type FormOf, type ItemForm, type Sections } from '~/utils/item-fields'

/** Field catalogue of the gym editor (F6.7): the shared item blocks plus what only gyms have. */

const tri = <const I extends string>(id: I) => defField(id, 'detail', 'tri')

export const TRI_FIELDS = [
  ['has_lead', 'Cuerda'],
  ['has_boulder', 'Bloque'],
  ['has_training_area', 'Zona de entrenamiento'],
  ['belay_test_required', 'Test de aseguramiento obligatorio'],
  ['gear_rental', 'Alquiler de material'],
  ['has_beginner_courses', 'Cursos de iniciación'],
  ['has_cafe', 'Cafetería'],
  ['serves_beer', 'Sirve cerveza'],
  ['has_kids_area', 'Zona infantil'],
  ['has_showers', 'Duchas'],
  ['has_wifi', 'Wifi'],
] as const

export const GYM_FIELDS = [
  ...ITEM_FIELDS,
  ...GEO_FIELDS,
  defField('metro_stations', 'detail', 'list'),
  defField('opening_hours', 'detail', 'hours'),
  defField('opening_hours_note_es', 'detail', 'text'),
  defField('opening_hours_note_en', 'detail', 'text'),
  ...CONTACT_FIELDS,
  defField('price_registration_eur', 'detail', 'dec'),
  defField('price_day_eur', 'detail', 'dec'),
  defField('price_10_pass_eur', 'detail', 'dec'),
  defField('price_monthly_eur', 'detail', 'dec'),
  defField('discounts_es', 'detail', 'text'),
  defField('discounts_en', 'detail', 'text'),
  defField('prices_verified_at', 'detail', 'date'),
  defField('surface_m2', 'detail', 'int'),
  defField('max_height_m', 'detail', 'dec'),
  defField('routes_count', 'detail', 'int'),
  defField('autobelays_count', 'detail', 'int'),
  defField('kids_min_age', 'detail', 'int'),
  defField('grading_difficulty', 'detail', 'scale'),
  defField('setting_dynamism', 'detail', 'scale'),
  tri('has_lead'),
  tri('has_boulder'),
  tri('has_training_area'),
  tri('belay_test_required'),
  tri('gear_rental'),
  tri('has_beginner_courses'),
  tri('has_cafe'),
  tri('serves_beer'),
  tri('has_kids_area'),
  tri('has_showers'),
  tri('has_wifi'),
  ...REVIEW_FIELDS,
] as const

export interface GymForm extends ItemForm, FormOf<typeof GYM_FIELDS> {}

/** Form from the stored rows (`item`, `detail`, `review` columns), the author scores and the gallery. */
export const formFromRows = (rows: { item: Columns; detail: Columns; review: Columns | null }, scores: Record<string, number>, gallery: string[]): GymForm => buildForm<GymForm>(GYM_FIELDS, rows, scores, gallery)

export const sectionsOf = (form: GymForm, clean: (html: string) => string, skip: ReadonlySet<string> = new Set(), fallback?: Sections): Sections => buildSections(GYM_FIELDS, form, clean, skip, fallback)
