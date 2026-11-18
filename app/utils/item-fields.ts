import { EMPTY_DOC, emptyBody, isEmptyDoc, type ArticleBody } from '~/utils/article-editor'
import { WEEKDAYS, closingValue, type Weekday } from '~/utils/opening-hours'

/**
 * Field machinery shared by the item editors (F6.7 gyms, F6.8 resolers). The form keys ARE the
 * database column names, so one list drives reading rows, writing patches (direct save and draft
 * payload, D23) and the change list. Kinds decide how a form value maps to a column; numbers stay as
 * text in the form until saved. Each category composes its own list from the shared blocks below.
 */
export type Section = 'item' | 'detail' | 'review'

export interface DayHours {
  closed: boolean
  slots: [string, string][]
}
export type HoursForm = Record<Weekday, DayHours>

interface Kinds {
  text: string
  req: string
  int: string
  dec: string
  date: string
  bool: boolean
  tri: boolean | null
  scale: number | null
  media: string | null
  list: string[]
  hours: HoursForm
  /** Spanish body: never null. */
  body: ArticleBody
  /** English body: an empty document is stored as null. */
  bodyEn: ArticleBody
  visit: 'paid' | 'invited'
}
export type Kind = keyof Kinds

export interface Field {
  id: string
  section: Section
  kind: Kind
}

export const defField = <const I extends string, const K extends Kind>(id: I, section: Section, kind: K) => ({ id, section, kind }) as { id: I; section: Section; kind: K }

/** Fields every item has (table `items`). */
export const ITEM_FIELDS = [
  defField('name', 'item', 'req'),
  defField('slug', 'item', 'req'),
  defField('summary_es', 'item', 'text'),
  defField('summary_en', 'item', 'text'),
  defField('cover_media_id', 'item', 'media'),
  defField('is_featured', 'item', 'bool'),
  defField('verified_at', 'item', 'date'),
  defField('source', 'item', 'text'),
  defField('source_url', 'item', 'text'),
  defField('seo_title_es', 'item', 'text'),
  defField('seo_title_en', 'item', 'text'),
  defField('seo_description_es', 'item', 'text'),
  defField('seo_description_en', 'item', 'text'),
  defField('og_media_id', 'item', 'media'),
  defField('noindex', 'item', 'bool'),
] as const

/** Address block shared by gyms and resolers (their detail tables). */
export const GEO_FIELDS = [
  defField('address', 'detail', 'text'),
  defField('city', 'detail', 'req'),
  defField('district', 'detail', 'text'),
  defField('postal_code', 'detail', 'text'),
  defField('lat', 'detail', 'dec'),
  defField('lng', 'detail', 'dec'),
] as const

export const CONTACT_FIELDS = [
  defField('website_url', 'detail', 'text'),
  defField('instagram_url', 'detail', 'text'),
  defField('phone', 'detail', 'text'),
] as const

/** The author review (table `author_reviews`). */
export const REVIEW_FIELDS = [
  defField('visit_type', 'review', 'visit'),
  defField('visit_date', 'review', 'date'),
  defField('disclosure_note_es', 'review', 'text'),
  defField('disclosure_note_en', 'review', 'text'),
  defField('headline_es', 'review', 'text'),
  defField('headline_en', 'review', 'text'),
  defField('body_json_es', 'review', 'body'),
  defField('body_json_en', 'review', 'bodyEn'),
] as const

type FieldList = readonly { id: string; kind: Kind }[]
/** Form shape of a field list. */
export type FormOf<L extends FieldList> = { [F in L[number] as F['id']]: Kinds[F['kind']] }

export const COMMON_FIELDS = [...ITEM_FIELDS, ...GEO_FIELDS, ...CONTACT_FIELDS, ...REVIEW_FIELDS] as const
/** What every item form has: the shared panels (general, review, gallery, SEO) are typed with this. */
export interface ItemForm extends FormOf<typeof COMMON_FIELDS> {
  /** criterion id -> 1..5 (absent = "Sin nota"). */
  scores: Record<string, number>
  /** Gallery media ids in display order. */
  gallery: string[]
}

/** Database columns of a section (ready for `.update()` or a draft payload section). */
export type Columns = Record<string, unknown>
export interface Sections {
  item: Columns
  detail: Columns
  review: Columns
  scores: Record<string, number>
  gallery: string[]
}

export const emptyHours = (): HoursForm => Object.fromEntries(WEEKDAYS.map((d) => [d, { closed: false, slots: [] as [string, string][] }])) as HoursForm

function defaultFor(kind: Kind): unknown {
  switch (kind) {
    case 'bool': return false
    case 'tri':
    case 'scale':
    case 'media': return null
    case 'list': return []
    case 'hours': return emptyHours()
    case 'body':
    case 'bodyEn': return emptyBody()
    case 'visit': return 'paid'
    default: return ''
  }
}

/** A blank form for a field list (new fichas and rows that do not exist yet, e.g. the author review). */
export function blankForm<F extends ItemForm>(fields: readonly Field[]): F {
  const form: Record<string, unknown> = { scores: {}, gallery: [] }
  for (const field of fields) form[field.id] = defaultFor(field.kind)
  form.city = 'Barcelona'
  return form as unknown as F
}

const numText = (value: unknown) => (typeof value === 'number' ? String(value).replace('.', ',') : '')

function bodyFrom(json: unknown, html: unknown): ArticleBody {
  if (!json || typeof json !== 'object') return emptyBody()
  return { json: json as ArticleBody['json'], html: typeof html === 'string' ? html : '' }
}

function fromDb(field: Field, row: Columns): unknown {
  const value = row[field.id]
  switch (field.kind) {
    case 'text':
    case 'req':
    case 'date': return typeof value === 'string' ? value : ''
    case 'int':
    case 'dec': return numText(value)
    case 'bool': return value === true
    case 'tri': return typeof value === 'boolean' ? value : null
    case 'scale': return typeof value === 'number' ? value : null
    case 'media': return typeof value === 'string' ? value : null
    case 'list': return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : []
    case 'visit': return value === 'invited' ? 'invited' : 'paid'
    case 'body':
    case 'bodyEn': return bodyFrom(value, row[field.id.replace('json', 'html')])
    case 'hours': {
      const hours = emptyHours()
      const source = value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : {}
      for (const day of WEEKDAYS) {
        const slots = source[day]
        if (Array.isArray(slots)) hours[day].slots = slots.filter((s): s is [string, string] => Array.isArray(s) && typeof s[0] === 'string' && typeof s[1] === 'string').map((s) => [s[0], s[1]])
        // A day with no slots in a schedule that has other days is closed.
        hours[day].closed = !hours[day].slots.length && Object.keys(source).length > 0
      }
      return hours
    }
  }
}

/** Form from the stored rows (`item`, `detail`, `review` columns), the author scores and the gallery. */
export function buildForm<F extends ItemForm>(fields: readonly Field[], rows: { item: Columns; detail: Columns; review: Columns | null }, scores: Record<string, number>, gallery: string[]): F {
  const form = blankForm<F>(fields) as unknown as Record<string, unknown>
  for (const field of fields) form[field.id] = fromDb(field, rows[field.section] ?? {})
  return { ...(form as unknown as F), scores: { ...scores }, gallery: [...gallery] }
}

export const parseNumber = (value: string): number | null => {
  const text = value.trim().replace(',', '.')
  if (!text) return null
  const number = Number(text)
  return Number.isFinite(number) ? number : null
}

/** OpenStreetMap link for the typed coordinates; `null` unless both are valid (lat ±90, lng ±180). */
export function mapUrlOf(lat: string, lng: string): string | null {
  const la = parseNumber(lat)
  const ln = parseNumber(lng)
  if (la === null || ln === null || Math.abs(la) > 90 || Math.abs(ln) > 180) return null
  return `https://www.openstreetmap.org/?mlat=${la}&mlon=${ln}#map=17/${la}/${ln}`
}

const nullIfEmpty = (value: string) => value.trim() || null

export function fieldColumns(field: Field, value: unknown, clean: (html: string) => string): Columns {
  const id = field.id
  switch (field.kind) {
    case 'req': return { [id]: (value as string).trim() }
    case 'text':
    case 'date': return { [id]: nullIfEmpty(value as string) }
    case 'int':
    case 'dec': {
      const n = parseNumber(value as string)
      return { [id]: n }
    }
    case 'list': return { [id]: (value as string[]).map((v) => v.trim()).filter(Boolean) }
    case 'hours': {
      const hours = value as HoursForm
      const out: Record<string, [string, string][]> = {}
      for (const day of WEEKDAYS) if (!hours[day].closed && hours[day].slots.length) out[day] = hours[day].slots.map(([a, b]) => [a.trim(), closingValue(b)])
      return { [id]: out }
    }
    case 'body':
    case 'bodyEn': {
      const body = value as ArticleBody
      const html = id.replace('json', 'html')
      if (isEmptyDoc(body.json)) return field.kind === 'bodyEn' ? { [id]: null, [html]: null } : { [id]: EMPTY_DOC, [html]: '' }
      return { [id]: body.json, [html]: clean(body.html) }
    }
    default: return { [id]: value }
  }
}

/**
 * Database-shaped state of the form. Fields in `skip` (with errors) keep the value they have in
 * `fallback`, so a half-typed invalid value never reaches the database.
 */
export function buildSections(fields: readonly Field[], form: ItemForm, clean: (html: string) => string, skip: ReadonlySet<string> = new Set(), fallback?: Sections): Sections {
  const out: Sections = { item: {}, detail: {}, review: {}, scores: { ...form.scores }, gallery: [...form.gallery] }
  for (const field of fields) {
    const columns = fieldColumns(field, (form as unknown as Record<string, unknown>)[field.id], clean)
    const kept = skip.has(field.id) && fallback
    for (const [key, value] of Object.entries(columns)) out[field.section][key] = kept ? (fallback.item[key] ?? fallback.detail[key] ?? fallback.review[key] ?? null) : value
  }
  return out
}
