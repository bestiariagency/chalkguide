import { parseCsv } from '~/utils/admin-import-csv'
import { IMPORT_MAX_BYTES, type ImportFileError } from '~/utils/admin-import-parse'
import { IMPORT_SPECS } from '~/utils/admin-import-spec'
import { isEmptyCell, type Cell } from '~/utils/admin-import-values'
import type { ItemCategory } from '~/utils/item-spec'

export interface SheetInfo {
  name: string
  rows: number
}

export type FileFormatError = { code: 'formato' } | { code: 'grande-bytes'; size: number } | ImportFileError

/** What reading a file gives: the grid, or the sheets to choose from, or why it cannot be read. */
export type FileRead =
  | { kind: 'grid'; name: string; grid: Cell[][]; sheet?: string; separator?: ';' | ','; commaFallback?: boolean }
  | { kind: 'sheets'; name: string; sheets: SheetInfo[]; books: Record<string, Cell[][]> }
  | { kind: 'error'; error: FileFormatError }

const fold = (value: string) => value.normalize('NFD').replace(/\p{M}/gu, '').trim().toLowerCase()
const countRows = (grid: Cell[][]) => grid.filter((row) => row.some((cell) => !isEmptyCell(cell))).length

/** CSV: `;` first (D37); if the header only reads with commas, comma (and the caller says so). */
export function readCsvText(text: string): { grid: string[][]; separator: ';' | ','; commaFallback: boolean } {
  const semi = parseCsv(text, ';')
  if ((semi[0]?.length ?? 0) > 1) return { grid: semi, separator: ';', commaFallback: false }
  const comma = parseCsv(text, ',')
  return (comma[0]?.length ?? 0) > 1 ? { grid: comma, separator: ',', commaFallback: true } : { grid: semi, separator: ';', commaFallback: false }
}

/** Picks the sheet named like the type; with one sheet with data, that one; otherwise the user chooses. */
export function pickSheet(books: Record<string, Cell[][]>, category: ItemCategory): string | null {
  const names = Object.keys(books)
  const wanted = fold(IMPORT_SPECS[category].sheet)
  const named = names.find((name) => fold(name) === wanted)
  if (named) return named
  const withData = names.filter((name) => countRows(books[name]!) > 0)
  return names.length === 1 ? names[0]! : withData.length === 1 && fold(withData[0]!) !== 'leeme' ? withData[0]! : null
}

export function sheetInfos(books: Record<string, Cell[][]>): SheetInfo[] {
  return Object.entries(books).map(([name, grid]) => ({ name, rows: countRows(grid) }))
}

/** Reads a `.xlsx` (cached values, no formulas or macros) or `.csv` in the browser. Nothing leaves the device. */
export async function readImportFile(file: File, category: ItemCategory): Promise<FileRead> {
  const ext = /\.([a-z0-9]+)$/i.exec(file.name)?.[1]?.toLowerCase()
  if (ext !== 'xlsx' && ext !== 'csv') return { kind: 'error', error: { code: 'formato' } }
  if (file.size > IMPORT_MAX_BYTES) return { kind: 'error', error: { code: 'grande-bytes', size: file.size } }
  try {
    if (ext === 'csv') {
      const { grid, separator, commaFallback } = readCsvText(await file.text())
      return { kind: 'grid', name: file.name, grid, separator, commaFallback }
    }
    const { default: readXlsxFile } = await import('read-excel-file/browser')
    const books = Object.fromEntries((await readXlsxFile(file)).map((sheet) => [sheet.sheet, sheet.data as Cell[][]]))
    const sheet = pickSheet(books, category)
    if (sheet === null) return { kind: 'sheets', name: file.name, sheets: sheetInfos(books), books }
    return { kind: 'grid', name: file.name, grid: books[sheet]!, sheet }
  } catch {
    return { kind: 'error', error: { code: 'formato' } }
  }
}
