import type { ImportColumn } from '~/utils/admin-import-spec'

/** Cell of the grid read from the file: text, number, boolean or Date (xlsx), or empty. */
export type Cell = string | number | boolean | Date | null | undefined

/** Text as it was typed: the `'` that the export puts before texts that start with `= + - @` comes off (D37). */
const EXPORT_APOSTROPHE = /^'(?=[\s\p{Cc}\p{Cf}]*[=+\-@＝＋－＠]|[\t\r\n])/u

export const isEmptyCell = (cell: Cell) => cell === null || cell === undefined || (typeof cell === 'string' && cell.trim() === '')

function textOf(cell: Exclude<Cell, null | undefined>): string {
  if (cell instanceof Date) return isoDate(cell)
  if (typeof cell === 'string') return cell.replace(EXPORT_APOSTROPHE, '')
  if (typeof cell === 'boolean') return cell ? 'Sí' : 'No'
  return String(cell)
}

const isoDate = (date: Date) => date.toISOString().slice(0, 10)
const fold = (value: string) => value.normalize('NFD').replace(/\p{M}/gu, '').trim().toLowerCase()

const YES = new Set(['si', 'sí', 'yes', 'true', '1', 'verdadero', 'x'])
const NO = new Set(['no', 'false', '0', 'falso'])

/** `Sí`/`No` and the DB values to a boolean; anything else goes as text so the server says what is wrong. */
export function toBool(cell: Exclude<Cell, null | undefined>): unknown {
  if (typeof cell === 'boolean') return cell
  const t = fold(textOf(cell))
  return YES.has(t) ? true : NO.has(t) ? false : textOf(cell).trim()
}

/** `12,5` and `12.5` to a number. Text that is not a number goes as text (the server rejects it with `invalid_type`). */
export function toNumber(cell: Exclude<Cell, null | undefined>, integer: boolean): unknown {
  if (typeof cell === 'number') return cell
  const raw = textOf(cell).trim().replace(/\s/g, '').replace(',', '.')
  if (!/^-?\d+(\.\d+)?$/.test(raw)) return textOf(cell).trim()
  const value = Number(raw)
  return integer && !Number.isInteger(value) ? textOf(cell).trim() : value
}

/** A Date (xlsx), `YYYY-MM-DD` or `d/m/yyyy` to `YYYY-MM-DD`. */
export function toDate(cell: Exclude<Cell, null | undefined>): unknown {
  if (cell instanceof Date) return isoDate(cell)
  const raw = textOf(cell).trim()
  const iso = /^(\d{4}-\d{2}-\d{2})(?:[T ].*)?$/.exec(raw)
  if (iso) return iso[1]
  const es = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/.exec(raw)
  return es ? `${es[3]}-${es[2]!.padStart(2, '0')}-${es[1]!.padStart(2, '0')}` : raw
}

/** Same text without a final «s», so «Otro» and «Otros» (singular and plural) match. */
const loose = (value: string) => fold(value).replace(/s$/, '')

/** Label of the template or DB value to the DB value (singular or plural); unknown text goes as it is (the server answers `not_allowed_value`). */
export function toOption(cell: Exclude<Cell, null | undefined>, options: NonNullable<ImportColumn['options']>): unknown {
  const raw = typeof cell === 'number' ? cell : textOf(cell).trim()
  const wanted = fold(String(raw))
  const hit = options.find(([value, label]) => String(value) === String(raw) || fold(label) === wanted || fold(String(value)) === wanted)
    ?? options.find(([value, label]) => loose(label) === loose(String(raw)) || loose(String(value)) === loose(String(raw)))
  return hit ? hit[0] : raw
}

/** ` | ` list (also the plain `|`), without empty items. */
export function toList(cell: Exclude<Cell, null | undefined>): string[] {
  return textOf(cell).split('|').map((part) => part.trim()).filter(Boolean)
}

/** Time as `HH:MM`; the closing time may be `24:00` (midnight) and `00:00` as closing is stored as `24:00`. Null if not valid. */
function toTime(h: string, m: string, closing: boolean): string | null {
  const hour = Number(h)
  const min = Number(m)
  if (min > 59 || hour > 24 || (hour === 24 && (!closing || min !== 0))) return null
  if (closing && hour === 0 && min === 0) return '24:00'
  return `${String(hour).padStart(2, '0')}:${m}`
}

/** `10:00-14:00, 17:00-23:00` to tramos (closing may be `24:00`/`00:00` = midnight); `Cerrado` to none; `null` if it cannot be read. */
export function parseHours(raw: string): [string, string][] | null {
  const t = raw.trim().toLowerCase()
  if (/^(cerrad[oa]|-|—|–)$/.test(t)) return []
  const out: [string, string][] = []
  for (const part of t.split(/\s*[,;]\s*/)) {
    const m = /^(\d{1,2}):(\d{2})\s*[-–—]\s*(\d{1,2}):(\d{2})$/.exec(part)
    if (!m) return null
    const open = toTime(m[1]!, m[2]!, false)
    const close = toTime(m[3]!, m[4]!, true)
    if (!open || !close || open >= close) return null
    out.push([open, close])
  }
  return out
}

/** One non-empty cell to the value the server takes, following the kind of the column. */
export function convertCell(column: ImportColumn, cell: Exclude<Cell, null | undefined>): unknown {
  switch (column.kind) {
    case 'int': return toNumber(cell, true)
    case 'num': return toNumber(cell, false)
    case 'bool': return toBool(cell)
    case 'date': return toDate(cell)
    case 'enum': return toOption(cell, column.options ?? [])
    case 'enums': return toList(cell).map((item) => toOption(item, column.options ?? []))
    case 'list':
    case 'photos': return toList(cell)
    case 'longtext': return typeof cell === 'string' ? cell.replace(EXPORT_APOSTROPHE, '').replace(/\r\n/g, '\n') : textOf(cell)
    default: return trimInvisible(textOf(cell))
  }
}
