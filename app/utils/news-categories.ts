/** Categories with their own tone, ink and icon (README §18.14, the 8 real ones of `guide.news_categories`). Anything else is neutral. */
export const NEWS_CATEGORY_KEYS = [
  'competicion',
  'roca-vias',
  'material',
  'rocodromos',
  'seguridad',
  'acceso-entorno',
  'federaciones',
  'comunidad',
] as const
export type NewsCategoryKey = (typeof NEWS_CATEGORY_KEYS)[number] | 'none'

export function newsCategoryKey(slug: string | null | undefined): NewsCategoryKey {
  return NEWS_CATEGORY_KEYS.find((key) => key === slug) ?? 'none'
}

/** Sets `--tone` (tile) and `--tink` (ink of the label and of the glyph). The full class strings keep Tailwind able to see them. */
const TONE_CLASS: Record<NewsCategoryKey, string> = {
  competicion: '[--tone:var(--color-news-competicion)] [--tink:var(--color-news-competicion-ink)]',
  'roca-vias': '[--tone:var(--color-news-roca-vias)] [--tink:var(--color-news-roca-vias-ink)]',
  material: '[--tone:var(--color-news-material)] [--tink:var(--color-news-material-ink)]',
  rocodromos: '[--tone:var(--color-news-rocodromos)] [--tink:var(--color-news-rocodromos-ink)]',
  seguridad: '[--tone:var(--color-news-seguridad)] [--tink:var(--color-news-seguridad-ink)]',
  'acceso-entorno': '[--tone:var(--color-news-acceso-entorno)] [--tink:var(--color-news-acceso-entorno-ink)]',
  federaciones: '[--tone:var(--color-news-federaciones)] [--tink:var(--color-news-federaciones-ink)]',
  comunidad: '[--tone:var(--color-news-comunidad)] [--tink:var(--color-news-comunidad-ink)]',
  none: '[--tone:var(--color-news-none)] [--tink:var(--color-news-none-ink)]',
}

export const newsToneClass = (slug: string | null | undefined) => TONE_CLASS[newsCategoryKey(slug)]
