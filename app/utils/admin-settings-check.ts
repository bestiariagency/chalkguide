import { SETTING_AUTHOR_PHOTO, SETTING_TEXTS, SOCIAL_NETWORKS, SETTING_MIN_REVIEWS, SETTING_OG, socialId, type SettingTextKey, type SettingsForm } from '~/utils/admin-settings'
import { STATS_FIELD, statId, validateStats } from '~/utils/admin-author-stats'
import type { AdminMedia } from '~/utils/admin-media'

/** Same rule as `guide.social_links_valid` for one value: https, host with a dot, no spaces, `<>"'`, `\` or userinfo. */
const SOCIAL_URL = /^https:\/\/[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+([/?#][^\s<>"'\\]*)?$/
const EMAIL = /^[^\s@<>"']+@[^\s@<>"']+\.[^\s@<>"']+$/

/** Error text for one social URL, or '' when it is valid (an empty value removes the network). */
export function socialUrlError(value: string): string {
  const url = value.trim()
  if (!url) return ''
  if (!/^https:\/\//i.test(url)) return 'Falta https:// al principio.'
  if (url.length > 300) return 'Máximo 300 caracteres.'
  if (/[\s<>"'\\]/.test(url)) return 'No puede llevar espacios ni los signos < > " \' \\.'
  if (/^https:\/\/[^/?#]*@/.test(url)) return 'No puede llevar usuario ni contraseña.'
  return SOCIAL_URL.test(url) ? '' : 'Escribe una dirección completa, con dominio (por ejemplo, https://ejemplo.com/perfil).'
}

export const textLimitMessage = (key: SettingTextKey) => {
  const rule: { min?: number; max: number } = SETTING_TEXTS[key]
  return rule.min ? `Obligatorio, hasta ${rule.max} caracteres.` : `Máximo ${rule.max} caracteres.`
}

/** Client validation, same rules as the CHECKs; keyed by field id (`name` of the control). */
export function validateSettings(form: SettingsForm, og: AdminMedia | null, authorPhoto: AdminMedia | null = null): Record<string, string> {
  const errors: Record<string, string> = {}
  for (const key of Object.keys(SETTING_TEXTS) as SettingTextKey[]) {
    const rule: { min?: number; max: number } = SETTING_TEXTS[key]
    const value = form[key].trim()
    if (rule.min && !value) errors[key] = key === 'site_name' ? 'Escribe el nombre del sitio.' : 'El texto de consentimiento en español es obligatorio.'
    else if (value.length > rule.max) errors[key] = textLimitMessage(key)
  }
  if (!errors.contact_email && form.contact_email.trim() && !EMAIL.test(form.contact_email.trim())) errors.contact_email = 'Escribe un email válido.'
  for (const n of SOCIAL_NETWORKS) {
    const message = socialUrlError(form.social[n.key] ?? '')
    if (message) errors[socialId(n.key)] = message
  }
  const min = form.min_user_reviews_for_average.trim()
  if (!/^\d+$/.test(min) || Number(min) < 1 || Number(min) > 50) errors[SETTING_MIN_REVIEWS] = 'Escribe un número entero del 1 al 50.'
  if (form.default_og_media_id && og && (!og.alt_es?.trim() || !og.alt_en?.trim())) errors[SETTING_OG] = OG_ALT_MESSAGE
  if (form.author_photo_media_id && authorPhoto && (!authorPhoto.alt_es?.trim() || !authorPhoto.alt_en?.trim())) errors[SETTING_AUTHOR_PHOTO] = PHOTO_ALT_MESSAGE
  Object.assign(errors, validateStats(form.author_stats))
  return errors
}

export const PHOTO_ALT_MESSAGE = 'Esta foto no tiene texto alternativo en español e inglés. Añádelo en Medios o elige otra.'
export const OG_ALT_MESSAGE = 'Esta imagen no tiene texto alternativo en español e inglés. Añádelo en Medios o elige otra.'

/** Fields (with a text each) behind a CHECK refused by the database; `null` when the constraint is not a setting. */
export function settingsCheckErrors(constraint: string, form: SettingsForm): Record<string, string> | null {
  if (constraint === 'site_settings_social_links_valid') {
    const bad = SOCIAL_NETWORKS.filter((n) => socialUrlError(form.social[n.key] ?? ''))
    const first = SOCIAL_NETWORKS.find((n) => (form.social[n.key] ?? '').trim())
    const generic = 'Revisa este enlace: empieza por https://, lleva dominio y no tiene espacios ni comillas.'
    if (bad.length) return Object.fromEntries(bad.map((n) => [socialId(n.key), socialUrlError(form.social[n.key]!)]))
    return first ? { [socialId(first.key)]: generic } : null
  }
  if (constraint.includes(STATS_FIELD)) {
    const known = validateStats(form.author_stats)
    return Object.keys(known).length ? known : { [statId(0, 'value')]: 'Revisa las cifras: cada fila necesita la cifra y su etiqueta en español.' }
  }
  const column = /^site_settings_(.+?)(?:_length)?_check$/.exec(constraint)?.[1]
  if (column && column in SETTING_TEXTS) {
    return { [column]: column === 'contact_email' ? 'Máximo 254 caracteres.' : textLimitMessage(column as SettingTextKey) }
  }
  if (constraint.includes('min_user_reviews')) return { [SETTING_MIN_REVIEWS]: 'Escribe un número entero del 1 al 50.' }
  return null
}

export type SettingsFailure =
  | { kind: 'conflict'; keys: string[] }
  | { kind: 'check'; constraint: string }
  | { kind: 'og-alt' }
  | { kind: 'forbidden' }
  | { kind: 'other' }

/** Reads the error of `admin_update_settings`: PT409 conflict, 23514 check, PT422 missing alt, 42501 not admin. */
export function settingsFailure(error: unknown): SettingsFailure {
  const e = error as { code?: string; message?: string; detail?: string; details?: string } | null
  if (e?.code === 'PT409') {
    try {
      const parsed = JSON.parse(e.detail ?? e.details ?? '{}') as { keys?: unknown }
      return { kind: 'conflict', keys: Array.isArray(parsed.keys) ? parsed.keys.map(String) : [] }
    } catch {
      return { kind: 'conflict', keys: [] }
    }
  }
  if (e?.code === '23514') {
    const constraint = /\b(site_settings_[a-z0-9_]+)\b/.exec(e.message ?? '')?.[1]
    return constraint ? { kind: 'check', constraint } : { kind: 'other' }
  }
  if (e?.code === 'PT422') return { kind: 'og-alt' }
  if (e?.code === '42501') return { kind: 'forbidden' }
  return { kind: 'other' }
}

/** An error id counts as «touched» when its own field changed (the figures are one column: any row). */
export const errorIsChanged = (id: string, changed: readonly string[]) =>
  changed.includes(id) || (id.startsWith(`${STATS_FIELD}.`) && changed.includes(STATS_FIELD))

/** Changed fields blocked by an error, in the order of `changed` (the figures expand to their rows). */
export const blockingFields = (changed: readonly string[], errors: Record<string, string>): string[] =>
  changed.flatMap((id) => (id === STATS_FIELD ? Object.keys(errors).filter((k) => k.startsWith(`${STATS_FIELD}.`)) : errors[id] ? [id] : []))
