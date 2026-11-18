import { CONTACT_FIELDS, GEO_FIELDS, ITEM_FIELDS, REVIEW_FIELDS, buildForm, buildSections, defField, type Columns, type FormOf, type ItemForm, type Sections } from '~/utils/item-fields'

/** Field catalogue of the resoler editor (F6.8): the shared item blocks plus services, prices, turnaround and mail. */

/** Services of the DB CHECK (guide.resolers.services) with the explanation shown next to each box. */
export const RESOLER_SERVICE_HELP = [
  ['half_sole', 'Media suela', 'Cambiar la goma de la mitad delantera, de la puntera al arco'],
  ['full_sole', 'Suela completa', 'Toda la suela, de puntera a talón'],
  ['rand', 'Rand', 'Rehacer el borde de goma que rodea la puntera'],
  ['toe_patch', 'Parche de puntera', 'Goma encima de la puntera, para los toe hooks'],
  ['closure_repair', 'Reparación de cierres', 'Velcros, cordones y hebillas'],
  ['stitching', 'Costuras', 'Volver a coser las costuras abiertas'],
  ['other', 'Otros', 'Explícalo en la reseña'],
] as const

export const RESOLER_FIELDS = [
  ...ITEM_FIELDS,
  ...GEO_FIELDS,
  ...CONTACT_FIELDS,
  defField('services', 'detail', 'list'),
  defField('price_per_pair_eur', 'detail', 'dec'),
  defField('price_rand_eur', 'detail', 'dec'),
  defField('turnaround_days_min', 'detail', 'int'),
  defField('turnaround_days_max', 'detail', 'int'),
  defField('rubber_brands', 'detail', 'list'),
  defField('prices_verified_at', 'detail', 'date'),
  defField('accepts_mail', 'detail', 'tri'),
  defField('mail_notes_es', 'detail', 'text'),
  defField('mail_notes_en', 'detail', 'text'),
  ...REVIEW_FIELDS,
] as const

export interface ResolerForm extends ItemForm, FormOf<typeof RESOLER_FIELDS> {}

export const resolerFromRows = (rows: { item: Columns; detail: Columns; review: Columns | null }, scores: Record<string, number>, gallery: string[]): ResolerForm => buildForm<ResolerForm>(RESOLER_FIELDS, rows, scores, gallery)

export const resolerSections = (form: ResolerForm, clean: (html: string) => string, skip: ReadonlySet<string> = new Set(), fallback?: Sections): Sections => buildSections(RESOLER_FIELDS, form, clean, skip, fallback)
