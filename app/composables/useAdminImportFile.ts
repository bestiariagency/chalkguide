import { parseCsv } from '~/utils/admin-import-csv'
import { readCsvText, readImportFile, type FileFormatError, type SheetInfo } from '~/utils/admin-import-file'
import { parseImportGrid, type ParsedImport } from '~/utils/admin-import-parse'
import type { Cell } from '~/utils/admin-import-values'
import type { ItemCategory } from '~/utils/item-spec'

export interface ImportFileMeta {
  name: string
  sheet?: string
  separator?: ';' | ','
  commaFallback?: boolean
  /** Ready to compare with the server: unknown columns are decided. */
  readAt: number
}

/**
 * Step 1 of the importer (README §13.2): reads the file in the browser, finds the type and the columns, and keeps
 * the grid so "Comprobar fotos" can check again without uploading the file twice. Nothing is written.
 */
export function useAdminImportFile(category: ItemCategory) {
  const reading = ref(false)
  const fileName = ref('')
  const error = ref<FileFormatError>()
  const sheets = ref<SheetInfo[]>()
  const meta = ref<ImportFileMeta>()
  /** Parsed file; `ready` once the unknown columns are accepted (or there were none). */
  const parsed = shallowRef<ParsedImport>()
  const ready = ref(false)
  let books: Record<string, Cell[][]> = {}
  let csvText: string | undefined
  let token = 0

  function reset() {
    token++
    reading.value = false
    error.value = undefined
    sheets.value = undefined
    meta.value = undefined
    parsed.value = undefined
    ready.value = false
    books = {}
    csvText = undefined
  }

  function useGrid(grid: Cell[][], info: Omit<ImportFileMeta, 'readAt'>) {
    const outcome = parseImportGrid(grid, category)
    if (!outcome.ok) {
      error.value = outcome.error
      return
    }
    meta.value = { ...info, readAt: Date.now() }
    parsed.value = outcome.value
    ready.value = outcome.value.unknown.length === 0
  }

  async function load(file: File) {
    reset()
    fileName.value = file.name
    const mine = token
    reading.value = true
    const read = await readImportFile(file, category)
    if (mine !== token) return
    reading.value = false
    if (read.kind === 'error') error.value = read.error
    else if (read.kind === 'sheets') {
      books = read.books
      sheets.value = read.sheets
      meta.value = { name: read.name, readAt: Date.now() }
    } else {
      if (read.separator) csvText = await file.text()
      useGrid(read.grid, { name: read.name, sheet: read.sheet, separator: read.separator, commaFallback: read.commaFallback })
    }
  }

  function chooseSheet(name: string) {
    const grid = books[name]
    if (!grid || !meta.value) return
    sheets.value = undefined
    useGrid(grid, { name: meta.value.name, sheet: name })
  }

  /** Re-reads the CSV with the other separator (the `seg` "; | ,"). */
  function setSeparator(separator: ';' | ',') {
    if (csvText === undefined || !meta.value) return
    error.value = undefined
    const grid = separator === ';' ? parseCsv(csvText, ';') : parseCsv(csvText, ',')
    useGrid(grid, { name: meta.value.name, separator, commaFallback: readCsvText(csvText).separator !== separator })
  }

  const acceptUnknown = () => (ready.value = true)

  return { reading, fileName, error, sheets, meta, parsed, ready, load, chooseSheet, setSeparator, acceptUnknown, reset }
}
