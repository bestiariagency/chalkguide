import type { AuthorStat, Locale } from '~/types/domain'

/** Trimmed text, or null when empty or only spaces (blank counts as missing). */
export function cleanText(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const text = value.trim()
  return text || null
}

/**
 * site_settings.author_stats: jsonb array of 0 to 2 `{value, label_es, label_en?}`.
 * Malformed entries and entries without value or label are dropped. A blank `label_en` counts as
 * missing: the Spanish label is used.
 */
export function parseAuthorStats(raw: unknown, locale: Locale): AuthorStat[] {
  if (!Array.isArray(raw)) return []
  const stats: AuthorStat[] = []
  for (const entry of raw.slice(0, 2)) {
    if (!entry || typeof entry !== 'object') continue
    const { value, label_es, label_en } = entry as Record<string, unknown>
    const figure = cleanText(typeof value === 'number' ? String(value) : value)
    const label = (locale === 'en' ? cleanText(label_en) : null) ?? cleanText(label_es)
    if (figure && label) stats.push({ value: figure, label })
  }
  return stats
}
