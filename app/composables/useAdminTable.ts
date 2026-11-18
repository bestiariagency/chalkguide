import { useTable, type ColumnDef, type RowData, type OnChangeFn, type PaginationState, type RowSelectionState, type SortingState } from '@tanstack/vue-table'

export interface AdminTableOptions<T extends RowData> {
  rows: Ref<readonly T[]>
  columns: Ref<readonly AdminColumn<T>[]>
  rowId: (row: T) => string
  mode: Ref<'client' | 'server'>
  rowCount: Ref<number | undefined>
  query: Ref<AdminTableQuery>
  onQuery: (query: AdminTableQuery) => void
}

function resolve<S>(next: S | ((old: S) => S), old: S): S {
  return typeof next === 'function' ? (next as (old: S) => S)(old) : next
}

/**
 * Wires TanStack Table (client or server mode) to the panel's own query contract. Sorting, search
 * and pagination live in `query`; row selection is local and survives paging.
 */
export function useAdminTable<T extends RowData>(options: AdminTableOptions<T>) {
  const { query, onQuery } = options
  const selection = ref<RowSelectionState>({})
  const server = computed(() => options.mode.value === 'server')

  const sorting = computed<SortingState>(() => (query.value.sort ? [query.value.sort] : []))
  const pagination = computed<PaginationState>(() => ({
    pageIndex: query.value.page,
    pageSize: query.value.pageSize,
  }))

  const columnDefs = computed<ColumnDef<AdminTableFeatures, T>[]>(() =>
    options.columns.value.map((column) => ({
      id: column.key,
      header: column.label,
      accessorFn: (row: T) => column.accessor?.(row) ?? ((row as Record<string, unknown>)[column.key] as never),
      enableSorting: column.sortable ?? false,
      meta: column,
    })),
  )

  const onSortingChange: OnChangeFn<SortingState> = (next) => {
    const [first] = resolve(next, sorting.value)
    onQuery({ ...query.value, sort: first ? { id: first.id, desc: first.desc } : null, page: 0 })
  }
  const onPaginationChange: OnChangeFn<PaginationState> = (next) => {
    const value = resolve(next, pagination.value)
    onQuery({ ...query.value, page: value.pageIndex, pageSize: value.pageSize })
  }
  const onGlobalFilterChange: OnChangeFn<string> = (next) => {
    onQuery({ ...query.value, search: resolve(next, query.value.search), page: 0 })
  }

  const table = useTable<AdminTableFeatures, T>({
    features: adminTableFeatures,
    columns: columnDefs,
    data: options.rows as Ref<T[]>,
    getRowId: (row: T) => options.rowId(row),
    state: computed(() => ({
      sorting: sorting.value,
      pagination: pagination.value,
      globalFilter: query.value.search,
      rowSelection: selection.value,
    })),
    onSortingChange,
    onPaginationChange,
    onGlobalFilterChange,
    onRowSelectionChange: (next: RowSelectionState | ((old: RowSelectionState) => RowSelectionState)) => {
      selection.value = resolve(next, selection.value)
    },
    globalFilterFn: 'includesString',
    getColumnCanGlobalFilter: (column) => (column.columnDef.meta as AdminColumn<T> | undefined)?.searchable !== false,
    enableSortingRemoval: true,
    manualSorting: server,
    manualFiltering: server,
    manualPagination: server,
    rowCount: options.rowCount,
    autoResetPageIndex: false,
  })

  const selectedIds = computed(() => Object.keys(selection.value).filter((id) => selection.value[id]))
  const clearSelection = () => (selection.value = {})

  return { table, selection, selectedIds, clearSelection }
}
