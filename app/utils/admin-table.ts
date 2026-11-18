import {
  columnFilteringFeature,
  createFilteredRowModel,
  createPaginatedRowModel,
  createSortedRowModel,
  filterFn_includesString,
  globalFilteringFeature,
  rowPaginationFeature,
  rowSelectionFeature,
  rowSortingFeature,
  sortFn_alphanumeric,
  sortFn_basic,
  sortFn_text,
  tableFeatures,
} from '@tanstack/vue-table'

/** Static TanStack Table v9 features of every panel table (stable: never rebuilt per render). */
export const adminTableFeatures = tableFeatures({
  columnFilteringFeature,
  globalFilteringFeature,
  rowSortingFeature,
  rowPaginationFeature,
  rowSelectionFeature,
  filteredRowModel: createFilteredRowModel(),
  sortedRowModel: createSortedRowModel(),
  paginatedRowModel: createPaginatedRowModel(),
  filterFns: { includesString: filterFn_includesString },
  sortFns: { alphanumeric: sortFn_alphanumeric, text: sortFn_text, basic: sortFn_basic },
})

export type AdminTableFeatures = typeof adminTableFeatures

/** Column of an `AdminDataTable`. Cells render the `cell-<key>` slot or the plain value. */
export interface AdminColumn<T> {
  key: string
  label: string
  /** Full name of an abbreviated header (rendered as `abbr title`). */
  title?: string
  /** Value to sort/search/show; defaults to `row[key]`. */
  accessor?: (row: T) => string | number | boolean | null | undefined
  sortable?: boolean
  /** Take part in the free-text search (default true). */
  searchable?: boolean
  /** Sticky column: the first on the left (next to the checkbox) and actions on the right. */
  pin?: 'left' | 'right'
  align?: 'left' | 'right'
  /** Tailwind min-width class, e.g. `min-w-48`. */
  minWidth?: string
  /** Visually hidden header (e.g. the actions column). */
  hideLabel?: boolean
  /** Hide the column below this breakpoint (table view only; cards are separate). */
  hideBelow?: 'lg' | 'xl'
  /** < 768 (card view): show as metadata (label + value) under the title. Aim for 2-3 per table. */
  card?: boolean
}

/**
 * Query contract of a table. In `client` mode the table keeps and applies it; in `server` mode the
 * parent receives it through `update:query`, fetches the page and passes `rows` + `rowCount`.
 */
export interface AdminTableQuery {
  search: string
  sort: { id: string; desc: boolean } | null
  page: number
  pageSize: number
}

export const ADMIN_PAGE_SIZES = [25, 50, 100] as const

export function emptyAdminQuery(pageSize = 25): AdminTableQuery {
  return { search: '', sort: null, page: 0, pageSize }
}

export type AdminTableState = 'loading' | 'error' | 'empty' | 'no-results' | 'ready'

/**
 * Group headings for a page of rows: a heading ("Label · n") on the first row of each run of equal keys.
 * The count is the whole group (all `allRows`), not only its part on this page.
 */
export function groupHeadings<R, T>(pageRows: readonly R[], allRows: readonly T[], original: (row: R) => T, groupOf?: (row: T) => { key: string; label: string }) {
  if (!groupOf) return pageRows.map((row) => ({ row, heading: undefined as string | undefined }))
  const counts = new Map<string, number>()
  for (const row of allRows) {
    const { key } = groupOf(row)
    counts.set(key, (counts.get(key) ?? 0) + 1)
  }
  let previous: string | undefined
  return pageRows.map((row) => {
    const g = groupOf(original(row))
    const heading = g.key !== previous ? `${g.label} · ${counts.get(g.key)}` : undefined
    previous = g.key
    return { row, heading }
  })
}

/** `aria-sort` value of a column for the current sort. */
export function sortOf(sort: AdminTableQuery['sort'], id: string): 'ascending' | 'descending' | 'none' {
  if (sort?.id !== id) return 'none'
  return sort.desc ? 'descending' : 'ascending'
}

/** Hide a column below its breakpoint (table view only). */
export function hideClass(column: { hideBelow?: 'lg' | 'xl' }): string {
  if (column.hideBelow === 'lg') return 'max-lg:hidden'
  if (column.hideBelow === 'xl') return 'max-xl:hidden'
  return ''
}

/** Sticky classes of a pinned column; the edge shadow shows only while content scrolls under it. */
export function stickyClass(
  pin: 'left' | 'right' | undefined,
  opts: { header?: boolean; selectable?: boolean; fromStart: boolean; toEnd: boolean },
): Array<string | false> | '' {
  const z = opts.header ? 'z-[3]' : 'z-[1]'
  if (pin === 'right') return [`sticky right-0 ${z}`, opts.toEnd && 'shadow-[-6px_0_6px_-6px_var(--adm-shadow-edge)]']
  if (pin === 'left') return [`sticky ${opts.selectable ? 'left-11' : 'left-0'} ${z}`, opts.fromStart && 'shadow-[6px_0_6px_-6px_var(--adm-shadow-edge)]']
  return ''
}
