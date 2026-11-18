import {
  IMPORT_DAYS, IMPORT_SPECS, dayOf, isHoursKey, isKnownKey, isReadOnlyKey, isScoreKey, scoreOf, suggestKey,
  type ImportSpec,
} from '~/utils/admin-import-spec'
import { convertCell, isEmptyCell, parseHours, toNumber, type Cell } from '~/utils/admin-import-values'
import type { ImportIssue } from '~/utils/admin-import-report'
import type { ItemCategory } from '~/utils/item-spec'

export const IMPORT_MAX_ROWS = 500
export const IMPORT_MAX_BYTES = 5 * 1024 * 1024

export interface ParsedColumn {
  index: number
  /** Letter of the column in the spreadsheet (A, B, … AA). */
  letter: string
  key: string
}

export interface UnknownColumn extends ParsedColumn {
  suggestion?: string
}

/** A row ready for the server (`payload`) plus the problems only the client can see (`issues`). */
export interface ParsedRow {
  row: number
  payload: Record<string, unknown>
  issues: ImportIssue[]
}

export interface ParsedImport {
  category: ItemCategory
  columns: ParsedColumn[]
  unknown: UnknownColumn[]
  /** Read-only columns of the export, ignored without asking. */
  ignored: string[]
  /** Known columns the file does not have (no problem: empty never touches). */
  missing: string[]
  rows: ParsedRow[]
  /** Column key (or `scores.<criterion>`) to its letter, to point at the cell in the review. */
  letters: Record<string, string>
  /** Same keys as `letters` to the visible name of the column (row "Campo" of the template); missing in a CSV export. */
  names: Record<string, string>
}

export type ImportFileError =
  | { code: 'plantilla' }
  | { code: 'tipo'; found: ItemCategory }
  | { code: 'falta'; key: 'slug' | 'name' }
  | { code: 'vacio' }
  | { code: 'grande'; rows: number }

export type ParseOutcome = { ok: true; value: ParsedImport } | { ok: false; error: ImportFileError }

export function columnLetter(index: number): string {
  let n = index + 1
  let letter = ''
  while (n > 0) {
    letter = String.fromCharCode(65 + ((n - 1) % 26)) + letter
    n = Math.floor((n - 1) / 26)
  }
  return letter
}

const KEY_ROW_LABEL = 'clave'
/** Labels of column A of the template rows that are not data. */
const META_ROWS = new Set(['clave', 'nivel', 'formato y reglas', 'ejemplo', 'campo', 'pestana del panel', 'pestaña del panel'])
const norm = (cell: Cell) => (isEmptyCell(cell) ? '' : String(cell).trim().toLowerCase())

/** Where the keys are: the row with `clave` in A (template) or the first row when it already has `slug` or `name` (export). */
function findKeyRow(grid: readonly (readonly Cell[])[]): { index: number; template: boolean } | null {
  const limit = Math.min(grid.length, 15)
  for (let i = 0; i < limit; i++) if (norm(grid[i]?.[0]) === KEY_ROW_LABEL) return { index: i, template: true }
  const first = (grid[0] ?? []).map(norm)
  return first.includes('slug') || first.includes('name') ? { index: 0, template: false } : null
}

function detectOtherType(spec: ImportSpec, keys: ReadonlySet<string>): ItemCategory | null {
  const score = (s: ImportSpec) => s.signature.filter((k) => keys.has(k)).length
  if (score(spec) > 0) return null
  const other = Object.values(IMPORT_SPECS).map((s) => [s.category, score(s)] as const).sort((a, b) => b[1] - a[1])[0]
  return other && other[1] > 0 ? other[0] : null
}

/** Cells of one data row to the object the server takes, with the client-side issues. */
function buildRow(spec: ImportSpec, columns: readonly ParsedColumn[], cells: readonly Cell[], rowNumber: number): ParsedRow {
  const payload: Record<string, unknown> = { _row: rowNumber }
  const issues: ImportIssue[] = []
  const scores: Record<string, unknown> = {}
  const hours: Record<string, [string, string][]> = {}
  for (const { index, key } of columns) {
    const cell = cells[index]
    if (isEmptyCell(cell)) continue
    const value = cell as Exclude<Cell, null | undefined>
    if (isScoreKey(key) && !spec.columns.has(key)) scores[scoreOf(key)] = toNumber(value, true)
    else if (isHoursKey(key)) {
      const parsed = parseHours(String(value))
      if (parsed) hours[dayOf(key)] = parsed
      else issues.push({ column: key, code: 'invalid_hours', level: 'error' })
    } else if (key === 'opening_hours') {
      try {
        payload.opening_hours = JSON.parse(String(value))
      } catch {
        issues.push({ column: 'opening_hours', code: 'invalid_hours', level: 'error' })
      }
    } else if (key === 'postal_code' && /^\d{1,5}$/.test(String(value).trim())) {
      // Excel drops the leading 0 of a postal code typed as a number.
      const raw = String(value).trim()
      payload.postal_code = raw.padStart(5, '0')
      if (raw.length < 5) issues.push({ column: key, code: 'postal_zero', level: 'warning', params: { value: payload.postal_code } })
    } else {
      const column = spec.columns.get(key)
      if (column) payload[key] = convertCell(column, value)
    }
  }
  if (Object.keys(scores).length) payload.scores = scores
  if (Object.keys(hours).length) payload.opening_hours = Object.fromEntries(IMPORT_DAYS.filter((day) => hours[day]).map((day) => [day, hours[day]]))
  return { row: rowNumber, payload, issues }
}

/** Marks as error the rows whose URL repeats an earlier row: the server only sees 100 rows per call. */
function markDuplicates(rows: ParsedRow[]) {
  const seen = new Map<string, number>()
  for (const row of rows) {
    const slug = typeof row.payload.slug === 'string' ? row.payload.slug.toLowerCase() : ''
    if (!slug) continue
    const first = seen.get(slug)
    if (first === undefined) seen.set(slug, row.row)
    else row.issues.push({ column: 'slug', code: 'duplicate_in_file', level: 'error', params: { first } })
  }
}

/**
 * Grid of a sheet or CSV to rows for the server (README §13.2): finds the key row, checks the type, drops the
 * columns that are not known (they are listed so Xavi decides) and maps labels to DB values.
 */
export function parseImportGrid(grid: readonly (readonly Cell[])[], category: ItemCategory): ParseOutcome {
  const spec = IMPORT_SPECS[category]
  const keyRow = findKeyRow(grid)
  if (!keyRow) return { ok: false, error: { code: 'plantilla' } }
  const header = grid[keyRow.index] ?? []

  const columns: ParsedColumn[] = []
  const unknown: UnknownColumn[] = []
  const ignored: string[] = []
  const letters: Record<string, string> = {}
  const names: Record<string, string> = {}
  const labelRow = keyRow.template ? grid.slice(0, keyRow.index).find((cells) => norm(cells[0]) === 'campo') : undefined
  const seen = new Set<string>()
  header.forEach((cell, index) => {
    const key = norm(cell)
    if (!key || (keyRow.template && index === 0) || seen.has(key)) return
    seen.add(key)
    const column = { index, letter: columnLetter(index), key }
    if (isReadOnlyKey(key)) ignored.push(key)
    else if (isKnownKey(spec, key)) {
      columns.push(column)
      const label = labelRow && !isEmptyCell(labelRow[index]) ? String(labelRow[index]).trim() : ''
      // Hours: the server reports `opening_hours` (first hours column); the client reports the day column.
      const ids = isScoreKey(key) && !spec.columns.has(key) ? [`scores.${scoreOf(key)}`] : isHoursKey(key) ? ['opening_hours', key] : [key]
      for (const id of ids) {
        letters[id] ??= column.letter
        if (label && !names[id]) names[id] = id === 'opening_hours' && id !== key ? 'Horario' : label
      }
    } else unknown.push({ ...column, suggestion: suggestKey(spec, key) })
  })

  const keys = new Set([...columns.map((c) => c.key), ...unknown.map((c) => c.key), ...ignored])
  const other = detectOtherType(spec, keys)
  if (other) return { ok: false, error: { code: 'tipo', found: other } }
  for (const key of ['slug', 'name'] as const) if (!seen.has(key)) return { ok: false, error: { code: 'falta', key } }

  const rows: ParsedRow[] = []
  for (let i = keyRow.index + 1; i < grid.length; i++) {
    const cells = grid[i] ?? []
    if (keyRow.template && META_ROWS.has(norm(cells[0]))) continue
    // In the template column A is a helper (status formula): it does not make a row a data row.
    if ((keyRow.template ? cells.slice(1) : cells).every(isEmptyCell)) continue
    rows.push(buildRow(spec, columns, cells, i + 1))
  }
  if (!rows.length) return { ok: false, error: { code: 'vacio' } }
  if (rows.length > IMPORT_MAX_ROWS) return { ok: false, error: { code: 'grande', rows: rows.length } }
  markDuplicates(rows)

  const present = new Set(columns.map((c) => c.key))
  const missing = [...spec.columns.keys()].filter((key) => !present.has(key))
  return { ok: true, value: { category, columns, unknown, ignored, missing, rows, letters, names } }
}
