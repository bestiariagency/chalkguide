import { statsSummary } from '~/utils/admin-author-stats'
import { SETTING_AUTHOR_PHOTO, SETTING_MIN_REVIEWS, SETTING_OG, SETTING_PREMOD, type SettingsLoaded, type SettingsRow } from '~/utils/admin-settings'

const LABELS: Record<string, string> = {
  site_name: 'Nombre del sitio',
  tagline: 'Lema',
  footer_text: 'Texto del pie',
  default_seo_title: 'Título SEO',
  default_seo_description: 'Descripción SEO',
  contact_email: 'Email de contacto público',
  newsletter_title: 'Título de la newsletter',
  newsletter_body: 'Texto de la newsletter',
  newsletter_consent_text: 'Consentimiento de la newsletter',
  social_links: 'Redes sociales',
  author_name: 'Nombre del autor',
  author_role: 'Rol del autor',
  author_lede: 'Frase de «Sobre mí»',
  author_bio: 'Bio corta',
  author_stats: '«En números»',
  [SETTING_AUTHOR_PHOTO]: 'Foto del autor',
  [SETTING_OG]: 'Imagen para redes (OG)',
  [SETTING_PREMOD]: 'Revisar antes de publicar',
  [SETTING_MIN_REVIEWS]: 'Opiniones mínimas para mostrar la media',
}

/** Human label of a settings column (`tagline_es` → «Lema ES»). */
export function settingsColumnLabel(column: string): string {
  if (LABELS[column]) return LABELS[column]
  const m = /^(.*)_(es|en)$/.exec(column)
  return m && LABELS[m[1]!] ? `${LABELS[m[1]!]} ${m[2]!.toUpperCase()}` : column
}

/** The server's value of a column as plain text, for the «otra versión» view of a conflict. */
export function settingsColumnValue(loaded: SettingsLoaded, column: string): string {
  const row = loaded.row as SettingsRow & Record<string, unknown>
  const value = row[column]
  if (column === SETTING_OG) return loaded.og?.original_filename ?? (value ? 'Otra imagen' : 'Sin imagen')
  if (column === SETTING_AUTHOR_PHOTO) return loaded.authorPhoto?.original_filename ?? (value ? 'Otra foto' : 'Sin foto')
  if (column === 'author_stats') return statsSummary(value)
  if (column === SETTING_PREMOD) return value ? 'Activado' : 'Desactivado'
  if (column === 'social_links') {
    const entries = value && typeof value === 'object' ? Object.entries(value as Record<string, unknown>) : []
    return entries.length ? entries.map(([k, v]) => `${k}: ${String(v)}`).join(' · ') : '(vacío)'
  }
  return value === null || value === undefined || value === '' ? '(vacío)' : String(value)
}
