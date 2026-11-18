/**
 * Shared shell of the article (editorial v2, §13.2): below 1100 px everything sits on the 640 px
 * reading axis (16 px margins at 390); from 1100 a 240 px rail + 48 px gutter + 640 px column.
 * Literal strings so Tailwind generates them.
 */
export const articleShell =
  'mx-auto w-full max-w-[calc(var(--container-prose)+2rem)] px-4 min-[1100px]:max-w-page min-[1100px]:px-6'
export const articleGrid =
  'grid min-[1100px]:grid-cols-[240px_minmax(0,var(--container-prose))] min-[1100px]:gap-x-12'

/** Cover photos at or above this width/height ratio span the page; below it the header splits (§13.5). */
export const WIDE_COVER_RATIO = 1.3
