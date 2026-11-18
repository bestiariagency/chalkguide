/**
 * Table of contents of an article (editorial v2, §13.5). Pure and SSR-safe: reads the sanitized
 * body HTML, so the index renders on the server. Shown only with >= 800 words and >= 3 H2.
 */
export const TOC_MIN_WORDS = 800
export const TOC_MIN_HEADINGS = 3

export interface TocHeading {
  id: string
  text: string
}

const stripTags = (html: string) =>
  html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim()

/** URL-safe anchor from a heading text (accents and punctuation removed). */
export function slugifyHeading(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60)
}

/** Ids the page already uses (or could confuse): a heading never takes them (DOM clobbering, duplicates). */
const RESERVED_IDS = new Set([
  'newsletter', 'main', 'main-content', 'content', 'contenido', 'top', '__nuxt', '__layout',
  'keep-reading', 'article-items', 'article-title', 'site-footer', 'mobile-menu', 'category-list',
])
/** `blog-*` (page ids) and `v-1…` (video player ids) are reserved by prefix. */
const isReservedId = (id: string) => RESERVED_IDS.has(id) || id.startsWith('blog-') || /^v-\d/.test(id)

export interface BodyHeading extends TocHeading {
  level: 2 | 3
}

/**
 * Every H2 and H3 of the body in document order, with ids made by this code from the text (never
 * from the HTML) and unique across both levels. The server render (<UiProse>) and the index share
 * it, so anchors and index links always match.
 */
export function bodyHeadings(html: string): BodyHeading[] {
  const used = new Map<string, number>()
  const headings: BodyHeading[] = []
  for (const match of html.matchAll(/<h([23])(?:\s[^>]*)?>([\s\S]*?)<\/h\1>/gi)) {
    const text = stripTags(match[2] ?? '')
    let base = slugifyHeading(text) || 'apartado'
    if (isReservedId(base)) base = `${base}-apartado`
    // A suffixed id can collide with a real slug ("a-2"): keep counting until it is free.
    let count = (used.get(base) ?? 0) + 1
    let id = count > 1 ? `${base}-${count}` : base
    while (used.has(id)) id = `${base}-${++count}`
    used.set(base, count)
    used.set(id, 1)
    headings.push({ level: match[1] === '2' ? 2 : 3, id, text })
  }
  return headings
}

/** The H2 of the body (what the index lists), empty ones too, to match the DOM. */
export function extractHeadings(html: string): TocHeading[] {
  return bodyHeadings(html)
    .filter((heading) => heading.level === 2)
    .map(({ id, text }) => ({ id, text }))
}

export function countBodyWords(html: string): number {
  const text = stripTags(html)
  return text ? text.split(' ').length : 0
}

/** The index is worth it only for long articles with structure. */
export function articleToc(html: string): TocHeading[] {
  const headings = extractHeadings(html).filter((heading) => heading.text)
  return headings.length >= TOC_MIN_HEADINGS && countBodyWords(html) >= TOC_MIN_WORDS ? headings : []
}
