/**
 * Light, dependency-free parts of the article sanitizer contract (media bucket, figure widths).
 * Safe to import anywhere (panel editor, public utils): it does not pull in `sanitize-html`.
 */

/** Public prefix of the `media` bucket; `null` when no project URL is known (then no image is allowed). */
export function mediaBucketPrefix(supabaseUrl: string | undefined): string | null {
  const base = supabaseUrl?.trim().replace(/\/+$/, '')
  return base ? `${base}/storage/v1/object/public/media/` : null
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** Under the bucket prefix and without path tricks (`..`, `\`, encoded dots or slashes) to escape it. */
export function inMediaBucket(src: string, prefix: string | null): boolean {
  return !!prefix && src.startsWith(prefix) && !/\.\.|\\|%2e|%2f|%5c/i.test(src.slice(prefix.length))
}

export const FIGURE_WIDTHS = ['column', 'wide', 'bleed'] as const
export type FigureWidth = (typeof FIGURE_WIDTHS)[number]

export const isFigureWidth = (value: unknown): value is FigureWidth => FIGURE_WIDTHS.includes(value as FigureWidth)
