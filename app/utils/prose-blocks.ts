import { bodyHeadings } from './article-toc'
import { TABLE_MAX_COLUMNS, TABLE_MAX_ROWS } from './article-figure'
import { escapeHtml } from './html-escape'

/**
 * Render of the editorial blocks (§13.5) over HTML that is ALREADY sanitized: tags are canonical and
 * carry no `class`/`id`, so these string transforms are safe and the classes below are ours. The
 * sanitizer is the only gate for author HTML; nothing here reads an id or class from it.
 */
const ANCHOR_CLASS =
  'ml-2 inline-flex min-h-11 min-w-11 items-center justify-center align-middle font-mono text-base text-accent no-underline opacity-0 transition-opacity duration-150 focus-visible:opacity-100 group-hover/h2:opacity-100 max-lg:hidden'
const HEADING_CLASS = 'group/h2 scroll-mt-[72px]'

/**
 * Gives every H2 and H3 an id made from its text (shared with the index, see `bodyHeadings`) and,
 * with `anchorLabel`, a `#` link in each H2. Unique by construction; a source `id` cannot exist here.
 */
export function addHeadingAnchors(html: string, anchorLabel?: (title: string) => string): string {
  const headings = bodyHeadings(html)
  let index = 0
  return html.replace(/<h([23])>([\s\S]*?)<\/h\1>/gi, (match, level: string, inner: string) => {
    const heading = headings[index++]
    if (!heading) return match
    const anchor =
      anchorLabel && level === '2'
        ? `<a href="#${heading.id}" data-anchor="" class="${ANCHOR_CLASS}" aria-label="${escapeHtml(anchorLabel(heading.text))}">#</a>`
        : ''
    const klass = level === '2' ? ` class="${HEADING_CLASS}"` : ' class="scroll-mt-[72px]"'
    return `<h${level} id="${heading.id}"${klass}>${inner}${anchor}</h${level}>`
  })
}

const NUMERIC_CELL = /^[+\-−–]?\d[\d.,\s]*(?:\s?(?:€|%|\$|£|min|h|km|m|kg|g|cm|mm|días|dias|d|x|×))?(?:\/\S{1,8})?$/i
const cellText = (inner: string) => inner.replace(/<[^>]*>/g, '').replace(/&nbsp;/g, ' ').trim()

/** Columns whose body cells are all figures get `class="num"` (right aligned, mono): detected at render, not stored. */
function markNumericColumns(table: string): string {
  const rows: RegExpMatchArray[][] = []
  let columns = 0
  for (const row of table.matchAll(/<tr>([\s\S]*?)<\/tr>/gi)) {
    // Beyond twice the editor's limits nothing is detected (cost bound; the editor never produces this).
    if (rows.length >= TABLE_MAX_ROWS * 2) return table
    const cells = [...(row[1] ?? '').matchAll(/<(td|th)(\s[^>]*)?>([\s\S]*?)<\/\1>/gi)]
    if (cells.length > TABLE_MAX_COLUMNS * 2) return table
    columns = Math.max(columns, cells.length)
    rows.push(cells)
  }
  const body = rows.map((cells) => cells.filter((cell) => cell[1] === 'td')).filter((cells) => cells.length)
  const numeric = new Set<number>()
  for (let col = 0; col < columns; col++) {
    const texts = body.map((cells) => cells[col]).filter((cell) => cell !== undefined).map((cell) => cellText(cell![3] ?? ''))
    if (texts.length && texts.every((text) => NUMERIC_CELL.test(text))) numeric.add(col)
  }
  if (!numeric.size) return table
  return table.replace(/<tr>([\s\S]*?)<\/tr>/gi, (_, inner: string) => {
    let col = 0
    const cells = inner.replace(/<(td|th)(\s[^>]*)?>/gi, (cell, tag: string, attrs = '') => (numeric.has(col++) ? `<${tag}${attrs} class="num">` : cell))
    return `<tr>${cells}</tr>`
  })
}

/** Each table in its own scroll region (focusable, named) with figure columns detected. */
export function renderTables(html: string, regionLabel: string): string {
  const label = escapeHtml(regionLabel)
  return html.replace(
    /<table>[\s\S]*?<\/table>/gi,
    (table) => `<div class="table-wrap" role="region" tabindex="0" aria-label="${label}">${markNumericColumns(table)}</div>`,
  )
}

/**
 * Author note: a decorative Caveat label ("Nota de Xavi") and an `aria-label` on the `aside`.
 * The name is plain text, escaped here; `null` falls back to the generic label.
 */
export function renderAuthorNotes(html: string, label: string): string {
  const text = escapeHtml(label)
  return html.replace(/<aside data-note="author">/g, `<aside data-note="author" aria-label="${text}"><p data-note-label="" aria-hidden="true">${text}</p>`)
}
