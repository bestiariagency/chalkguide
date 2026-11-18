import type { Database } from '~/types/database.types'
import type { AdminMedia } from '~/utils/admin-media'
import { STATS_FIELD, statRowsFromJson, statsDiffer, statsPayload, type StatRow } from '~/utils/admin-author-stats'

export type SettingsRow = Database['guide']['Tables']['site_settings']['Row']

/** Text columns of the form: limits mirror the CHECKs of `guide.site_settings` (F6.17). */
export const SETTING_TEXTS = {
  site_name: { min: 1, max: 80 },
  tagline_es: { max: 200 },
  tagline_en: { max: 200 },
  footer_text_es: { max: 300 },
  footer_text_en: { max: 300 },
  default_seo_title_es: { max: 70 },
  default_seo_title_en: { max: 70 },
  default_seo_description_es: { max: 160 },
  default_seo_description_en: { max: 160 },
  contact_email: { max: 254 },
  newsletter_title_es: { max: 120 },
  newsletter_title_en: { max: 120 },
  newsletter_body_es: { max: 400 },
  newsletter_body_en: { max: 400 },
  newsletter_consent_text_es: { min: 1, max: 2000 },
  newsletter_consent_text_en: { max: 2000 },
  author_name: { max: 80 },
  author_role_es: { max: 80 },
  author_role_en: { max: 80 },
  author_lede_es: { max: 120 },
  author_lede_en: { max: 120 },
  author_bio_es: { max: 160 },
  author_bio_en: { max: 160 },
} as const
export type SettingTextKey = keyof typeof SETTING_TEXTS
export const SETTING_TEXT_KEYS = Object.keys(SETTING_TEXTS) as SettingTextKey[]

/** Networks offered in the form; any other key already in `social_links` is kept untouched. */
export const SOCIAL_NETWORKS = [
  { key: 'instagram', label: 'Instagram', placeholder: 'https://instagram.com/…' },
  { key: 'youtube', label: 'YouTube', placeholder: 'https://youtube.com/@…' },
  { key: 'tiktok', label: 'TikTok', placeholder: 'https://tiktok.com/@…' },
  { key: 'x', label: 'X', placeholder: 'https://x.com/…' },
  { key: 'facebook', label: 'Facebook', placeholder: 'https://facebook.com/…' },
] as const

export const SETTING_OG = 'default_og_media_id'
export const SETTING_AUTHOR_PHOTO = 'author_photo_media_id'
export const SETTING_PREMOD = 'user_reviews_premoderation'
export const SETTING_MIN_REVIEWS = 'min_user_reviews_for_average'
export const socialId = (network: string) => `social.${network}`

export type SettingsForm = Record<SettingTextKey, string> & {
  default_og_media_id: string | null
  author_photo_media_id: string | null
  /** Written figures of «En números» (max 2 rows; blank rows are dropped on save). */
  author_stats: StatRow[]
  user_reviews_premoderation: boolean
  /** Text field; validated as an integer 1–50. */
  min_user_reviews_for_average: string
  /** Network key → URL ('' = none). */
  social: Record<string, string>
}

/** What the screen loaded: the row, the open consent version and the OG image with its size. */
export interface SettingsLoaded {
  row: SettingsRow
  consent: { version: number; validFrom: string | null }
  og: AdminMedia | null
  authorPhoto: AdminMedia | null
  /** Published gyms and shoes (the calculated boxes of «En números»); null when they could not be counted. */
  calc: { gyms: number; shoes: number } | null
}

const socialOf = (row: SettingsRow): Record<string, string> => {
  const raw = row.social_links
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return {}
  return Object.fromEntries(Object.entries(raw).filter((e): e is [string, string] => typeof e[1] === 'string'))
}

export function settingsFormFromRow(row: SettingsRow): SettingsForm {
  const links = socialOf(row)
  const form = {
    default_og_media_id: row.default_og_media_id,
    author_photo_media_id: row.author_photo_media_id,
    author_stats: statRowsFromJson(row.author_stats),
    user_reviews_premoderation: row.user_reviews_premoderation,
    min_user_reviews_for_average: String(row.min_user_reviews_for_average),
    social: Object.fromEntries(SOCIAL_NETWORKS.map((n) => [n.key, links[n.key] ?? ''])),
  } as SettingsForm
  for (const key of SETTING_TEXT_KEYS) form[key] = row[key] ?? ''
  return form
}

/** `social_links` to send: unknown keys kept, known ones with a trimmed value, empty ones removed (`""` is not valid). */
export function socialPayload(form: SettingsForm, row: SettingsRow): Record<string, string> {
  const known = new Set<string>(SOCIAL_NETWORKS.map((n) => n.key))
  const out: Record<string, string> = {}
  for (const [key, value] of Object.entries(socialOf(row))) if (!known.has(key)) out[key] = value
  for (const [key, value] of Object.entries(form.social)) if (value.trim()) out[key] = value.trim()
  return out
}

/** Ids of the fields that differ from what is saved (the text columns compare trimmed: the database stores blanks as null). */
export function settingsChangedFields(form: SettingsForm, row: SettingsRow): string[] {
  const out: string[] = SETTING_TEXT_KEYS.filter((k) => form[k].trim() !== (row[k] ?? '').trim())
  if (form.default_og_media_id !== row.default_og_media_id) out.push(SETTING_OG)
  if (form.author_photo_media_id !== row.author_photo_media_id) out.push(SETTING_AUTHOR_PHOTO)
  if (statsDiffer(form.author_stats, row.author_stats)) out.push(STATS_FIELD)
  if (form.user_reviews_premoderation !== row.user_reviews_premoderation) out.push(SETTING_PREMOD)
  if (form.min_user_reviews_for_average.trim() !== String(row.min_user_reviews_for_average)) out.push(SETTING_MIN_REVIEWS)
  const saved = socialOf(row)
  for (const n of SOCIAL_NETWORKS) if (form.social[n.key]!.trim() !== (saved[n.key] ?? '')) out.push(socialId(n.key))
  return out
}

/** Column behind a field id (`social.x` → `social_links`, `author_stats.0.value` → `author_stats`). */
export const columnOf = (id: string) => (id.startsWith('social.') ? 'social_links' : id.startsWith(`${STATS_FIELD}.`) ? STATS_FIELD : id)

/** Arguments of `admin_update_settings`: new values and, for the same columns, the loaded ones (conflict detection). */
export function settingsPatch(form: SettingsForm, row: SettingsRow, ids: string[]) {
  const changes: Record<string, unknown> = {}
  const base: Record<string, unknown> = {}
  for (const column of new Set(ids.map(columnOf))) {
    if (column === 'social_links') {
      changes[column] = socialPayload(form, row)
      base[column] = row.social_links
    } else if (column === SETTING_MIN_REVIEWS) {
      changes[column] = Number(form.min_user_reviews_for_average)
      base[column] = row.min_user_reviews_for_average
    } else if (column === STATS_FIELD) {
      changes[column] = statsPayload(form.author_stats)
      base[column] = row.author_stats
    } else if (column === SETTING_OG || column === SETTING_AUTHOR_PHOTO || column === SETTING_PREMOD) {
      changes[column] = form[column]
      base[column] = row[column]
    } else {
      const key = column as SettingTextKey
      const required = 'min' in SETTING_TEXTS[key]
      changes[column] = form[key].trim() || (required ? '' : null)
      base[column] = row[key]
    }
  }
  return { changes, base }
}

/** Spanish names of the sections that hold the columns (conflict notice). */
export function settingsSections(columns: string[]): string[] {
  const names = new Set<string>()
  for (const c of columns) {
    if (c.startsWith('author_')) names.add('Autor del sitio')
    else if (c === 'site_name' || c.startsWith('tagline_') || c.startsWith('footer_text_')) names.add('General')
    else if (c.startsWith('default_')) names.add('SEO por defecto')
    else if (c === 'social_links' || c === 'contact_email') names.add('Redes y contacto')
    else if (c.startsWith('newsletter_')) names.add('Newsletter')
    else names.add('Opiniones')
  }
  return [...names]
}
