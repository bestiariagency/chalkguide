import { blockDiff, wordDiff } from '~/utils/text-diff'
import { blocksOf, type ChangeEntry } from '~/utils/article-changes'
import { SEO_LIMITS } from '~/utils/admin-form'
import { fieldColumns, parseNumber, type Columns, type Field, type ItemForm, type Sections } from '~/utils/item-fields'

/** What goes to the database (direct save) or into a draft payload (D23): only the sections that differ. */
export interface ItemPatch {
  item?: Columns
  detail?: Columns
  author_review?: Columns
  scores?: Record<string, number>
  gallery?: string[]
}

const same = (a: unknown, b: unknown) => JSON.stringify(a) === JSON.stringify(b)

function diffColumns(now: Columns, base: Columns): Columns | undefined {
  const out: Columns = {}
  for (const key of Object.keys(now)) if (!same(now[key], base[key] ?? null)) out[key] = now[key]
  return Object.keys(out).length ? out : undefined
}

/** Columns of `now` that differ from `base`, section by section. Empty object = nothing to send. */
export function diffSections(now: Sections, base: Sections): ItemPatch {
  const patch: ItemPatch = {}
  const item = diffColumns(now.item, base.item)
  const detail = diffColumns(now.detail, base.detail)
  const review = diffColumns(now.review, base.review)
  if (item) patch.item = item
  if (detail) patch.detail = detail
  if (review) patch.author_review = review
  if (!same(now.scores, base.scores)) patch.scores = now.scores
  if (!same(now.gallery, base.gallery)) patch.gallery = now.gallery
  return patch
}
export const patchSize = (patch: ItemPatch) => Object.keys(patch).length

// --- Validation ------------------------------------------------------------------------------

export type ItemErrors = Partial<Record<string, string>>
const URL = /^https?:\/\/\S+$/
const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/

/** Checks one typed number (comma or dot decimals) against a rule; sets `errors[id]` when it fails. */
export function checkNumber(errors: ItemErrors, id: string, raw: string, rule: { min?: number; max?: number; gt?: number; int?: boolean }) {
  const text = raw.trim()
  if (!text) return
  const n = parseNumber(text)
  if (n === null) return void (errors[id] = 'Escribe un número.')
  const shown = (value: number) => String(value).replace('.', ',')
  if (rule.int && !Number.isInteger(n)) errors[id] = 'Debe ser un número entero.'
  else if (rule.gt !== undefined && n <= rule.gt) errors[id] = `Debe ser mayor que ${shown(rule.gt)}.`
  else if (rule.min !== undefined && n < rule.min) errors[id] = `Mínimo ${shown(rule.min)}.`
  else if (rule.max !== undefined && n > rule.max) errors[id] = `Máximo ${shown(rule.max)}.`
}

type TextId = 'name' | 'summary_es' | 'summary_en' | 'source' | 'phone' | 'headline_es' | 'headline_en' | 'disclosure_note_es' | 'disclosure_note_en'

/** Errors of the fields every item has (the database would reject them). `taken` = slugs of the other items of the category. */
export function validateItem(form: ItemForm, taken: ReadonlySet<string>, noun: string): ItemErrors {
  const errors: ItemErrors = {}
  const len = (id: TextId, max: number) => {
    if (form[id].trim().length > max) errors[id] = `Máximo ${max} caracteres.`
  }
  if (!form.name.trim()) errors.name = 'Escribe el nombre.'
  len('name', 120)
  if (!form.slug) errors.slug = 'Falta la URL.'
  else if (form.slug.length > 120 || !SLUG.test(form.slug)) errors.slug = 'La URL solo admite minúsculas, números y guiones.'
  else if (taken.has(form.slug)) errors.slug = `Ya existe otro ${noun} con esta URL.`
  if (!form.city.trim()) errors.city = 'Escribe la ciudad.'
  len('summary_es', 400)
  len('summary_en', 400)
  len('source', 200)
  len('phone', 30)
  len('headline_es', 200)
  len('headline_en', 200)
  len('disclosure_note_es', 500)
  len('disclosure_note_en', 500)
  for (const id of ['source_url', 'website_url', 'instagram_url'] as const) {
    if (form[id].trim() && !URL.test(form[id].trim())) errors[id] = 'Debe empezar por http:// o https://.'
  }
  for (const id of ['seo_title_es', 'seo_title_en'] as const) if (form[id].length > SEO_LIMITS.title.max) errors[id] = `Máximo ${SEO_LIMITS.title.max} caracteres.`
  for (const id of ['seo_description_es', 'seo_description_en'] as const) if (form[id].length > SEO_LIMITS.description.max) errors[id] = `Máximo ${SEO_LIMITS.description.max} caracteres.`
  if (form.postal_code.trim() && !/^\d{5}$/.test(form.postal_code.trim())) errors.postal_code = 'El código postal tiene 5 cifras.'
  checkNumber(errors, 'lat', form.lat, { min: -90, max: 90 })
  checkNumber(errors, 'lng', form.lng, { min: -180, max: 180 })
  return errors
}

/** Field ids behind the error keys (`opening_hours.mon` -> `opening_hours`). */
export const errorFieldIds = (errors: ItemErrors) => new Set(Object.keys(errors).map((key) => key.split('.')[0]!))

// --- Change list (D23) -----------------------------------------------------------------------

export interface FieldMeta { label: string; lang?: 'ES' | 'EN'; kind: ChangeEntry['kind'] }
export const wordsMeta = (label: string, lang?: 'ES' | 'EN'): FieldMeta => ({ label, lang, kind: 'words' })
export const valueMeta = (label: string, lang?: 'ES' | 'EN'): FieldMeta => ({ label, lang, kind: 'value' })

/** Labels of the fields every item has. */
export const ITEM_META: Record<string, FieldMeta> = {
  name: wordsMeta('Nombre'),
  slug: valueMeta('URL'),
  summary_es: wordsMeta('Resumen', 'ES'),
  summary_en: wordsMeta('Resumen', 'EN'),
  cover_media_id: { label: 'Portada', kind: 'media' },
  og_media_id: { label: 'Imagen para compartir', kind: 'media' },
  is_featured: valueMeta('Destacada'),
  verified_at: valueMeta('Datos verificados el'),
  source: wordsMeta('Fuente'),
  source_url: valueMeta('URL de la fuente'),
  seo_title_es: wordsMeta('Título SEO', 'ES'),
  seo_title_en: wordsMeta('Título SEO', 'EN'),
  seo_description_es: wordsMeta('Descripción SEO', 'ES'),
  seo_description_en: wordsMeta('Descripción SEO', 'EN'),
  noindex: valueMeta('No indexar'),
  address: wordsMeta('Dirección'),
  city: wordsMeta('Ciudad'),
  district: wordsMeta('Barrio o municipio'),
  postal_code: valueMeta('Código postal'),
  lat: valueMeta('Latitud'),
  lng: valueMeta('Longitud'),
  website_url: valueMeta('Web'),
  instagram_url: valueMeta('Instagram'),
  phone: valueMeta('Teléfono'),
  visit_type: valueMeta('Tipo de visita'),
  visit_date: valueMeta('Fecha de visita'),
  disclosure_note_es: wordsMeta('Nota de transparencia', 'ES'),
  disclosure_note_en: wordsMeta('Nota de transparencia', 'EN'),
  headline_es: wordsMeta('Veredicto', 'ES'),
  headline_en: wordsMeta('Veredicto', 'EN'),
  body_json_es: { label: 'Reseña', lang: 'ES', kind: 'body' },
  body_json_en: { label: 'Reseña', lang: 'EN', kind: 'body' },
  scores: valueMeta('Notas por criterio'),
  gallery: valueMeta('Galería'),
}

const identity = (html: string) => html
const blocksOfJson = (json: unknown) => blocksOf(json as Parameters<typeof blocksOf>[0])
const record = (form: ItemForm) => form as unknown as Record<string, unknown>

/** How a category shows its own values in the change list (`undefined` = use the default). */
export type Shower = (id: string, value: unknown, form: ItemForm) => string | undefined

function show(id: string, form: ItemForm, criteria: Map<string, string>, own: Shower): string {
  if (id === 'scores') {
    const parts = Object.entries(form.scores).map(([c, n]) => `${criteria.get(c) ?? 'Criterio'} ${n}`)
    return parts.length ? parts.join(' · ') : 'Sin notas'
  }
  if (id === 'gallery') return `${form.gallery.length} ${form.gallery.length === 1 ? 'foto' : 'fotos'}`
  const value = record(form)[id]
  const special = own(id, value, form)
  if (special !== undefined) return special
  if (typeof value === 'boolean') return value ? 'Sí' : 'No'
  if (value === null) return 'No lo sé'
  if (id === 'visit_type') return value === 'invited' ? 'Invitada' : 'Pagada'
  if (Array.isArray(value)) return value.join(', ') || 'Vacío'
  return typeof value === 'string' ? value.trim() || 'Vacío' : ''
}

/** Ids of the groups (field ids, `scores`, `gallery`) that differ between two forms. */
export function changedFieldIds(fields: readonly Field[], current: ItemForm, base: ItemForm): string[] {
  const ids: string[] = []
  for (const field of fields) {
    const read = (form: ItemForm) => {
      const value = record(form)[field.id]
      return field.kind === 'body' || field.kind === 'bodyEn' ? (value as { json: unknown }).json : fieldColumns(field, value, identity)
    }
    const a = read(current)
    const b = read(base)
    const bodyEmpty = (x: unknown) => field.kind.startsWith('body') && blocksOfJson(x).length === 0
    if (!same(a, b) && !(bodyEmpty(a) && bodyEmpty(b))) ids.push(field.id)
  }
  if (!same(current.scores, base.scores)) ids.push('scores')
  if (!same(current.gallery, base.gallery)) ids.push('gallery')
  return ids
}

export function describeItemChanges(fields: readonly Field[], meta: Record<string, FieldMeta>, own: Shower, base: ItemForm, current: ItemForm, criteria: Map<string, string>): ChangeEntry[] {
  return changedFieldIds(fields, current, base).map((key) => {
    const info = meta[key] ?? valueMeta(key)
    const entry: ChangeEntry = { key, label: info.label, lang: info.lang, kind: info.kind }
    const text = (form: ItemForm) => show(key, form, criteria, own)
    if (info.kind === 'media') entry.mediaIds = { before: (record(base)[key] as string | null) ?? null, after: (record(current)[key] as string | null) ?? null }
    else if (info.kind === 'body') {
      const get = (form: ItemForm) => (record(form)[key] as { json: Parameters<typeof blocksOf>[0] }).json
      entry.blocks = blockDiff(blocksOf(get(base)), blocksOf(get(current)))
    } else if (info.kind === 'value') entry.values = { before: text(base), after: text(current) }
    else entry.words = wordDiff(text(base) === 'Vacío' ? '' : text(base), text(current) === 'Vacío' ? '' : text(current))
    return entry
  })
}

/** "Revertir": copies the published value of one group back into the form. */
export function revertField(form: ItemForm, base: ItemForm, key: string): void {
  const plain = <T>(v: T): T => JSON.parse(JSON.stringify(v)) as T
  record(form)[key] = plain(record(base)[key])
}

// --- Stored draft ----------------------------------------------------------------------------

const objectOf = (value: unknown): Record<string, unknown> => (value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : {})

/** A stored draft payload as a patch (unknown keys are dropped). */
export function patchOf(payload: unknown): ItemPatch {
  const p = objectOf(payload)
  const patch: ItemPatch = {}
  if (Object.keys(objectOf(p.item)).length) patch.item = objectOf(p.item)
  if (Object.keys(objectOf(p.detail)).length) patch.detail = objectOf(p.detail)
  if (Object.keys(objectOf(p.author_review)).length) patch.author_review = objectOf(p.author_review)
  if (p.scores) patch.scores = objectOf(p.scores) as Record<string, number>
  if (Array.isArray(p.gallery)) patch.gallery = p.gallery.filter((v): v is string => typeof v === 'string')
  return patch
}

/** Number of unpublished changes a stored draft holds (one per column, plus scores and gallery). */
export function draftChanges(payload: unknown): number {
  const p = patchOf(payload)
  return Math.max(1, Object.keys(p.item ?? {}).length + Object.keys(p.detail ?? {}).length + Object.keys(p.author_review ?? {}).length + (p.scores ? 1 : 0) + (p.gallery ? 1 : 0))
}
