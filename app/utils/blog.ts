import type { ArticleSummary } from '~/types/domain'

const FEATURED_MAX = 5

/**
 * Blog index split: up to 5 featured (is_featured first, newest first; completed with the newest
 * of the rest) and the remaining ones as "Últimos". `articles` arrives newest first.
 */
export function splitBlogIndex(articles: ArticleSummary[]) {
  const marked = articles.filter((article) => article.isFeatured).slice(0, FEATURED_MAX)
  const ids = new Set(marked.map((article) => article.id))
  const fill = articles.filter((article) => !ids.has(article.id)).slice(0, FEATURED_MAX - marked.length)
  const featured = [...marked, ...fill]
  const used = new Set(featured.map((article) => article.id))
  return { featured, latest: articles.filter((article) => !used.has(article.id)) }
}

const L = 'md:col-start-1 md:col-span-8'
const R = 'md:col-start-9 md:col-span-4'

/**
 * Mosaic slots (md+) per number of featured cards: 12 columns x 6 fixed rows. Left = 8 cols,
 * right = 4; both columns always add up to 6 rows, so there are no gaps. Literal classes so
 * Tailwind sees them.
 * 5: 3+3 | 2+2+2 · 4: 3+3 | 3+3 · 3: 6 | 3+3 · 2: 6 | 6 · 1: 12 cols x 5 rows.
 */
const SLOTS: Record<number, { classes: string; narrow: boolean }[]> = {
  1: [{ classes: 'md:col-span-12 md:row-span-5', narrow: false }],
  2: [
    { classes: `${L} md:row-span-6`, narrow: false },
    { classes: `${R} md:row-span-6`, narrow: true },
  ],
  3: [
    { classes: `${L} md:row-span-6`, narrow: false },
    { classes: `${R} md:row-start-1 md:row-span-3`, narrow: true },
    { classes: `${R} md:row-start-4 md:row-span-3`, narrow: true },
  ],
  4: [
    { classes: `${L} md:row-start-1 md:row-span-3`, narrow: false },
    { classes: `${L} md:row-start-4 md:row-span-3`, narrow: false },
    { classes: `${R} md:row-start-1 md:row-span-3`, narrow: true },
    { classes: `${R} md:row-start-4 md:row-span-3`, narrow: true },
  ],
  5: [
    { classes: `${L} md:row-start-1 md:row-span-3`, narrow: false },
    { classes: `${L} md:row-start-4 md:row-span-3`, narrow: false },
    { classes: `${R} md:row-start-1 md:row-span-2`, narrow: true },
    { classes: `${R} md:row-start-3 md:row-span-2`, narrow: true },
    { classes: `${R} md:row-start-5 md:row-span-2`, narrow: true },
  ],
}

export function featuredSlot(count: number, index: number) {
  return SLOTS[Math.min(count, FEATURED_MAX)]?.[index] ?? { classes: '', narrow: false }
}
