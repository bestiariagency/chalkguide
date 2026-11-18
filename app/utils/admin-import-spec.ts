import { RESOLER_SERVICE_HELP } from '~/utils/resoler-fields'
import type { ItemCategory } from '~/utils/item-spec'
import { SHOE_ASYMMETRY, SHOE_CLOSURE, SHOE_FIT, SHOE_LEVEL, SHOE_PROFILE, SHOE_STIFFNESS, SHOE_USE } from '~/utils/shoe-fields'

/**
 * Columns the item importer reads (F6.15b, D50; docs/design/admin/README.md §13.10 and audit §8). The keys are the ones
 * of the server whitelist and of the CSV export (D37). The server only gets DB values: the Spanish labels of the
 * template ("Cordones", "Sí", "En la media") are mapped here.
 */
export type ImportKind = 'text' | 'longtext' | 'int' | 'num' | 'bool' | 'date' | 'list' | 'enum' | 'enums' | 'photo' | 'photos'
type Option = readonly [value: string | number, label: string]

export interface ImportColumn {
  key: string
  kind: ImportKind
  options?: readonly Option[]
}

const text = (key: string): ImportColumn => ({ key, kind: 'text' })
const num = (key: string): ImportColumn => ({ key, kind: 'num' })
const int = (key: string): ImportColumn => ({ key, kind: 'int' })
const bool = (key: string): ImportColumn => ({ key, kind: 'bool' })
const date = (key: string): ImportColumn => ({ key, kind: 'date' })
const longtext = (key: string): ImportColumn => ({ key, kind: 'longtext' })
const enumOf = (key: string, options: readonly Option[], kind: 'enum' | 'enums' = 'enum'): ImportColumn => ({ key, kind, options })
const pairs = (list: readonly (readonly [string, string])[]): readonly Option[] => list

const VISIT: readonly Option[] = [['paid', 'Pagada'], ['paid', 'Comprados'], ['paid', 'Comprada'], ['invited', 'Invitada'], ['invited', 'Cedidos por la marca'], ['invited', 'Cedidas por la marca']]
const GRADING: readonly Option[] = [[1, 'Generosos'], [2, 'Algo generosos'], [3, 'En la media'], [4, 'Algo duros'], [5, 'Duros']]
const STYLE: readonly Option[] = [[1, 'Muy técnico'], [2, 'Técnico'], [3, 'Mixto'], [4, 'Dinámico'], [5, 'Muy dinámico']]

const COMMON: readonly ImportColumn[] = [
  text('name'), text('slug'), longtext('summary_es'), longtext('summary_en'), photo('cover'), bool('is_featured'), date('verified_at'), text('source'), text('source_url'),
  text('seo_title_es'), text('seo_title_en'), longtext('seo_description_es'), longtext('seo_description_en'), photo('og_image'), bool('noindex'), { key: 'gallery', kind: 'photos' },
]
function photo(key: string): ImportColumn {
  return { key, kind: 'photo' }
}

const REVIEW: readonly ImportColumn[] = [
  text('headline_es'), text('headline_en'), enumOf('visit_type', VISIT), date('visit_date'), longtext('disclosure_note_es'), longtext('disclosure_note_en'),
  longtext('review_text_es'), longtext('review_text_en'),
]

const GEO: readonly ImportColumn[] = [text('address'), text('city'), text('district'), text('postal_code'), num('lat'), num('lng'), text('website_url'), text('instagram_url'), text('phone')]

const GYM: readonly ImportColumn[] = [
  ...GEO, { key: 'metro_stations', kind: 'list' }, text('opening_hours_note_es'), text('opening_hours_note_en'),
  num('price_registration_eur'), num('price_day_eur'), num('price_10_pass_eur'), num('price_monthly_eur'), longtext('discounts_es'), longtext('discounts_en'), date('prices_verified_at'),
  num('surface_m2'), num('max_height_m'), int('routes_count'), int('autobelays_count'), int('kids_min_age'),
  bool('has_lead'), bool('has_boulder'), bool('has_training_area'), bool('belay_test_required'), bool('gear_rental'), bool('has_beginner_courses'), bool('has_cafe'), bool('serves_beer'), bool('has_kids_area'), bool('has_showers'), bool('has_wifi'),
  enumOf('grading_difficulty', GRADING), enumOf('setting_dynamism', STYLE),
]

const RESOLER: readonly ImportColumn[] = [
  ...GEO, enumOf('services', RESOLER_SERVICE_HELP.map(([value, label]) => [value, label] as const), 'enums'),
  num('price_per_pair_eur'), num('price_rand_eur'), int('turnaround_days_min'), int('turnaround_days_max'), { key: 'rubber_brands', kind: 'list' },
  date('prices_verified_at'), bool('accepts_mail'), longtext('mail_notes_es'), longtext('mail_notes_en'),
]

const SHOE: readonly ImportColumn[] = [
  text('brand'), text('model'), enumOf('fit', pairs(SHOE_FIT) ), enumOf('profile', pairs(SHOE_PROFILE)), enumOf('asymmetry', pairs(SHOE_ASYMMETRY)), enumOf('closure', pairs(SHOE_CLOSURE)),
  text('rubber'), num('rubber_thickness_mm'), enumOf('stiffness', SHOE_STIFFNESS), enumOf('recommended_use', pairs(SHOE_USE), 'enums'), enumOf('levels', pairs(SHOE_LEVEL), 'enums'),
  num('price_min_eur'), num('price_max_eur'), date('price_checked_at'), text('affiliate_url'), text('affiliate_program'), bool('owned_by_author'),
  num('author_size_eu'), num('author_street_size_eu'), text('author_size_note_es'), text('author_size_note_en'),
]

export const IMPORT_DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'] as const
/** Hours cell format: `10:00-14:00, 17:00-23:00` or `Cerrado`; closing at midnight is `24:00` (`00:00` as closing is read as `24:00`). */
const HOURS_KEYS = IMPORT_DAYS.map((day) => `opening_hours_${day}`)

export interface ImportSpec {
  category: ItemCategory
  /** Name of the sheet (and of the tab of the template) in the workbook. */
  sheet: string
  columns: ReadonlyMap<string, ImportColumn>
  /** Keys that only this type has: they tell a rocódromos file from a pies de gato one. */
  signature: readonly string[]
}

function spec(category: ItemCategory, sheet: string, detail: readonly ImportColumn[], signature: string[]): ImportSpec {
  const all = [...COMMON, ...REVIEW, ...detail]
  return { category, sheet, columns: new Map(all.map((c) => [c.key, c])), signature }
}

export const IMPORT_SPECS: Record<ItemCategory, ImportSpec> = {
  gym: spec('gym', 'Rocódromos', GYM, ['price_day_eur', 'has_boulder', 'metro_stations', 'opening_hours', ...HOURS_KEYS]),
  resoler: spec('resoler', 'Resoladores', RESOLER, ['price_per_pair_eur', 'services', 'rubber_brands', 'turnaround_days_min']),
  shoe: spec('shoe', 'Pies de gato', SHOE, ['brand', 'model', 'fit', 'closure', 'stiffness']),
}

/** Columns the export carries that are system data: ignored silently so an exported CSV can be uploaded again. */
const READ_ONLY = new Set(['id', 'item_id', 'category', 'published', 'published_at', 'created_at', 'updated_at', 'has_en', 'is_affiliate', 'hidden', 'status', 'reviews', 'user_reviews', 'user_reviews_count', 'reviews_count', 'avg_user_score', 'is_published'])
export const isReadOnlyKey = (key: string) => READ_ONLY.has(key) || /^(nota_autor_|detalle_|body_|user_|reviews_)/.test(key)

/** Keys with their own handling (not a plain column): opening hours per day, the JSON column of the export and `nota_<criterion>`. */
export const isHoursKey = (key: string) => HOURS_KEYS.includes(key)
export const isScoreKey = (key: string) => /^nota_[a-z0-9_]+$/.test(key) && !key.startsWith('nota_autor_')
export const scoreOf = (key: string) => key.slice('nota_'.length)
export const dayOf = (key: string) => key.slice('opening_hours_'.length)

/** Is this header a key the importer reads? */
export function isKnownKey(spec: ImportSpec, key: string): boolean {
  return spec.columns.has(key) || isHoursKey(key) || isScoreKey(key) || key === 'opening_hours'
}

/** Key to the closest known key (typos like `precio_desde`), or `undefined`. */
export function suggestKey(spec: ImportSpec, key: string): string | undefined {
  const pool = [...spec.columns.keys(), ...HOURS_KEYS]
  const distance = (a: string, b: string) => {
    const row = Array.from({ length: b.length + 1 }, (_, i) => i)
    for (let i = 1; i <= a.length; i++) {
      let prev = row[0]!
      row[0] = i
      for (let j = 1; j <= b.length; j++) {
        const tmp = row[j]!
        row[j] = Math.min(row[j]! + 1, row[j - 1]! + 1, prev + (a[i - 1] === b[j - 1] ? 0 : 1))
        prev = tmp
      }
    }
    return row[b.length]!
  }
  const best = pool.map((candidate) => [candidate, distance(key, candidate)] as const).sort((a, b) => a[1] - b[1])[0]
  return best && best[1] <= Math.max(2, Math.floor(key.length / 4)) ? best[0] : undefined
}
