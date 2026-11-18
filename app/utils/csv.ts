import { madridParts } from '~/utils/admin-madrid'

/**
 * CSV for Excel / Numbers (docs/design/admin/README.md §12.4): UTF-8 with BOM, `;` separator, CRLF, RFC 4180 quotes,
 * decimals with a comma, `sí`/`no`, dates in Barcelona time, lists joined with ` | `. Pure functions, no I/O.
 */
export const CSV_BOM = '﻿'
const SEPARATOR = ';'

/** Object columns that become one column per key: `scores` -> `nota_<key>`. */
const FLATTEN_PREFIX: Record<string, string> = { scores: 'nota_', author_scores: 'nota_autor_', details: 'detalle_' }
const ISO_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/
/** A spreadsheet may run a cell as a formula when it starts with one of these, also after spaces or invisible characters. */
const FORMULA_START = /^(?:[\t\r\n]|[\s\p{Cc}\p{Cf}]*[=+\-@＝＋－＠])/u

type Row = Record<string, unknown>

/** Text cells that could run as a formula get a leading `'` (leona-lia: CSV injection). Numbers are never touched. */
export function neutralizeFormula(text: string): string {
  return FORMULA_START.test(text) ? `'${text}` : text
}

function formatText(value: string): string {
  if (!ISO_TIMESTAMP.test(value) || Number.isNaN(Date.parse(value))) return value
  const { date, time } = madridParts(value)
  return `${date} ${time}`
}

/** One cell as the text that goes in the file (before quoting). */
export function cellText(value: unknown): string {
  if (value === null || value === undefined) return ''
  if (typeof value === 'number') return String(value).replace('.', ',')
  if (typeof value === 'boolean') return value ? 'sí' : 'no'
  if (Array.isArray(value)) return neutralizeFormula(value.map((v) => formatText(String(v ?? ''))).join(' | '))
  if (typeof value === 'object') return JSON.stringify(value)
  return neutralizeFormula(formatText(String(value)))
}

/** Also quotes `,` and tabs: a spreadsheet whose list separator is one of them would split the cell otherwise. */
const quote = (text: string) => (/[;,"\t\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text)

const isObject = (v: unknown): v is Row => !!v && typeof v === 'object' && !Array.isArray(v)

/** Header (technical key) of every file column and where it reads from, in the order of `export.columns`. */
export function csvColumns(columns: readonly string[], rows: readonly Row[]): { header: string; key: string; sub?: string }[] {
  return columns.flatMap((key) => {
    const prefix = FLATTEN_PREFIX[key]
    if (!prefix) return [{ header: key, key }]
    const subs = [...new Set(rows.flatMap((row) => (isObject(row[key]) ? Object.keys(row[key]) : [])))].sort()
    return subs.map((sub) => ({ header: `${prefix}${sub}`, key, sub }))
  })
}

export function toCsv(columns: readonly string[], rows: readonly Row[]): string {
  const cols = csvColumns(columns, rows)
  const lines = [cols.map((c) => quote(c.header)).join(SEPARATOR)]
  for (const row of rows) {
    lines.push(
      cols
        .map((c) => {
          const raw = c.sub === undefined ? row[c.key] : isObject(row[c.key]) ? (row[c.key] as Row)[c.sub] : null
          return quote(cellText(raw))
        })
        .join(SEPARATOR),
    )
  }
  return CSV_BOM + lines.join('\r\n') + '\r\n'
}
