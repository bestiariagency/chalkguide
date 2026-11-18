import type { FigureWidth } from '~~/shared/lib/sanitize/constants'

/** Minimum width (px) of a photo to go full bleed without visible loss (design §13.9). */
export const BLEED_MIN_WIDTH = 1600

/** "A sangre" only for landscape photos of at least 1.600 px; unknown size counts as not enough. */
export function canBleed(width: number | null | undefined, height: number | null | undefined): boolean {
  return !!width && !!height && width >= BLEED_MIN_WIDTH && width > height
}

export const FIGURE_WIDTH_LABELS: Record<FigureWidth, string> = { column: 'Columna', wide: 'Ancha', bleed: 'A sangre' }

/** Tables of the editor: limits of the design (§13.9). */
export const TABLE_MAX_COLUMNS = 5
export const TABLE_MAX_ROWS = 30
