<script setup lang="ts" generic="T extends Record<string, any>">
import { ArrowDown, ArrowUp, ChevronsUpDown } from 'lucide-vue-next'
import { emptyAdminQuery, groupHeadings, hideClass, sortOf, stickyClass } from '~/utils/admin-table'

/**
 * Data table over TanStack Table (markup is ours). Sorting by column (`aria-sort`), debounced search
 * (`/`), `filters` slot, pagination, row/page selection with a bulk bar, sticky columns, and
 * loading / empty / no-results / error states.
 *
 * Contract (works for client and server data):
 * - `mode="client"` (default): pass all `rows`; the table sorts, filters and pages them.
 * - `mode="server"`: pass the already sorted/filtered/paged `rows` plus `row-count`; react to
 *   `update:query` ({ search, sort, page, pageSize }) to refetch.
 * - `v-model:query` is optional in client mode (use it to sync with the URL).
 * Clickable rows: the primary cell (first column) holds the real link (`row-href`) or button
 * (`@row-click`), so keyboard and screen readers get it; clicking elsewhere on the row does the same
 * for the mouse. Do not put interactive content in the primary cell slot.
 * Slots: `cell-<key>` ({ row, value }), `filters`, `toolbar-end`, `bulk` ({ ids, clear }), `empty`.
 */
const props = withDefaults(
  defineProps<{
    rows: readonly T[]
    columns: readonly AdminColumn<T>[]
    rowId: (row: T) => string
    /** Accessible name of the table. */
    caption: string
    mode?: 'client' | 'server'
    /** Server mode: total rows of the whole result. */
    rowCount?: number
    loading?: boolean
    /** Error message (truthy = error state). */
    error?: string
    errorCode?: string
    selectable?: boolean
    /** Feminine noun for the bulk bar count ("1 seleccionada"). */
    feminine?: boolean
    searchable?: boolean
    searchPlaceholder?: string
    pageSize?: number
    /** Name of a row for aria-labels ("Seleccionar …"). */
    rowLabel?: (row: T) => string
    /** Rows open this URL (primary cell becomes a link). */
    rowHref?: (row: T) => string
    clickable?: boolean
    /** Column whose cell is the row's link/button (default: the first one). */
    primaryKey?: string
    /** Group rows: a heading row ("Noviembre 2026 · 4") each time the key changes between consecutive rows of the page. */
    groupOf?: (row: T) => { key: string; label: string }
    emptyTitle?: string
    emptyDescription?: string
    /** Overrides for the no-results block when `filtered` (otherwise "Sin resultados" and a description by search / filters). */
    noResultsTitle?: string
    noResultsDescription?: string
    /** Filters outside the table are active: an empty result is "no results", not "nothing yet". */
    filtered?: boolean
  }>(),
  {
    mode: 'client',
    pageSize: 25,
    rowCount: undefined,
    error: undefined,
    errorCode: undefined,
    searchPlaceholder: undefined,
    rowLabel: undefined,
    rowHref: undefined,
    primaryKey: undefined,
    groupOf: undefined,
    emptyTitle: undefined,
    emptyDescription: undefined,
    noResultsTitle: undefined,
    noResultsDescription: undefined,
  },
)
const emit = defineEmits<{
  'row-click': [row: T]
  'update:selection': [ids: string[]]
  retry: []
  'clear-filters': []
}>()
const query = defineModel<AdminTableQuery | undefined>('query')

const local = ref(emptyAdminQuery(props.pageSize))
const current = computed(() => query.value ?? local.value)
function setQuery(next: AdminTableQuery) {
  local.value = next
  query.value = next
}

const { table, selectedIds, clearSelection } = useAdminTable<T>({
  rows: toRef(props, 'rows') as Ref<readonly T[]>,
  columns: toRef(props, 'columns') as Ref<readonly AdminColumn<T>[]>,
  rowId: props.rowId,
  mode: toRef(props, 'mode'),
  rowCount: toRef(props, 'rowCount'),
  query: current,
  onQuery: setQuery,
})
watch(selectedIds, (ids) => emit('update:selection', ids))

const noResultsText = computed(() => {
  if (props.noResultsDescription && props.filtered) return props.noResultsDescription
  const searching = !!current.value.search
  if (searching && props.filtered) return 'Prueba con otra búsqueda o quita los filtros.'
  return searching ? 'Prueba con otra búsqueda.' : 'Prueba con otra vista o quita los filtros.'
})
const server = computed(() => props.mode === 'server')
const total = computed(() => (server.value ? (props.rowCount ?? props.rows.length) : table.getFilteredRowModel().rows.length))
const pageRows = computed(() => table.getRowModel().rows)
const primary = computed(() => props.primaryKey ?? props.columns[0]?.key)
const cardColumns = computed(() => props.columns.filter((c) => c.card && c.key !== primary.value && !c.hideLabel))
const actionColumns = computed(() => props.columns.filter((c) => c.hideLabel && c.key !== primary.value))
const link = resolveComponent('NuxtLink')
const grouped = computed(() => groupHeadings(pageRows.value, props.rows, (row) => row.original, props.groupOf))
const pageSelected = computed(() => table.getIsAllPageRowsSelected())
const pageCheck = () => (table.getIsAllPageRowsSelected() ? true : table.getIsSomePageRowsSelected() ? 'indeterminate' : false)
const togglePage = (value: boolean | 'indeterminate') => table.toggleAllPageRowsSelected(value === true)
const canSelectAll = computed(() => props.selectable && !server.value && pageSelected.value && total.value > pageRows.value.length && !table.getIsAllRowsSelected())
const view = computed<AdminTableState>(() => {
  if (props.error) return 'error'
  if (props.loading && !props.rows.length) return 'loading'
  if (!total.value) return current.value.search || props.filtered ? 'no-results' : 'empty'
  return 'ready'
})

const scroller = ref<HTMLElement>()
const { fromStart, toEnd } = useScrollEdges(scroller)

const showSkeleton = useDelayedFlag(() => view.value === 'loading', 300)
const sortState = (id: string) => sortOf(current.value.sort, id)
const resultsLive = computed(() => (view.value === 'ready' ? countOf(total.value, 'resultado', 'resultados') : ''))
function toggleSort(id: string) {
  const state = sortState(id)
  table.setSorting(state === 'none' ? [{ id, desc: false }] : state === 'ascending' ? [{ id, desc: true }] : [])
}
function open(row: T, event?: MouseEvent) {
  if (!props.clickable && !props.rowHref) return
  if (event && (event.target as HTMLElement).closest('a,button,input,label,[role=checkbox]')) return
  if (props.rowHref) void navigateTo(props.rowHref(row))
  else emit('row-click', row)
}

const th = 'sticky top-0 z-[2] h-9 whitespace-nowrap border-b border-adm-line bg-adm-side px-3 text-left text-xs font-medium text-adm-meta'
const sticky = (key: string, header = false) =>
  stickyClass(props.columns.find((c) => c.key === key)?.pin, { header, selectable: props.selectable, fromStart: fromStart.value, toEnd: toEnd.value })
</script>

<template>
  <div class="overflow-hidden rounded-lg border border-adm-line bg-adm-elev">
    <AdminTableToolbar
      v-if="searchable || $slots.filters || $slots['toolbar-end']"
      :search="current.search"
      :label="`Buscar en ${caption}`"
      :searchable="searchable"
      :placeholder="searchPlaceholder"
      @update:search="(search) => setQuery({ ...current, search, page: 0 })"
    >
      <template #filters><slot name="filters" /></template>
      <template #end><slot name="toolbar-end" /></template>
    </AdminTableToolbar>

    <p v-if="canSelectAll" class="flex flex-wrap items-center gap-2 border-b border-adm-line bg-adm-acc-soft px-3 py-2 text-[13px]" role="status">
      Se han seleccionado las {{ pageRows.length }} filas de esta página.
      <button type="button" class="font-medium underline underline-offset-2 max-md:min-h-11" @click="table.toggleAllRowsSelected(true)">
        Seleccionar las {{ total }}
      </button>
    </p>
    <AdminStateBlock v-if="view === 'error'" kind="error" :description="error" :code="errorCode" @retry="emit('retry')" />
    <template v-else-if="view === 'empty' || view === 'no-results'">
      <slot v-if="view === 'empty'" name="empty">
        <AdminStateBlock kind="empty" :title="emptyTitle" :description="emptyDescription" />
      </slot>
      <AdminStateBlock v-else kind="no-results" :title="filtered ? noResultsTitle : undefined" :description="noResultsText">
        <button v-if="current.search" type="button" :class="admBtnGhost" @click="setQuery({ ...current, search: '', page: 0 })">Borrar la búsqueda</button>
        <button v-if="filtered" type="button" :class="admBtnGhost" @click="emit('clear-filters')">Quitar filtros</button>
      </AdminStateBlock>
    </template>

    <template v-else>
      <div ref="scroller" class="relative overflow-x-auto max-md:hidden" :aria-busy="loading || undefined">
        <table class="w-full border-separate border-spacing-0 text-[13px]">
          <caption class="sr-only">{{ caption }}</caption>
          <thead>
            <tr>
              <th v-if="selectable" :class="[th, 'sticky left-0 z-[3] w-11 min-w-11']" scope="col">
                <AdminCheckbox :model-value="pageCheck()" label="Seleccionar todas las filas de esta página" @update:model-value="togglePage" />
              </th>
              <th
                v-for="column in columns"
                :key="column.key"
                scope="col"
                :aria-sort="column.sortable ? sortState(column.key) : undefined"
                :class="[th, sticky(column.key, true), column.align === 'right' && 'text-right', column.minWidth, hideClass(column)]"
              >
                <span v-if="column.hideLabel" class="sr-only">{{ column.label }}</span>
                <button v-else-if="column.sortable" type="button" class="-mx-1 inline-flex items-center gap-1 rounded px-1 hover:text-adm-fg" @click="toggleSort(column.key)">
                  {{ column.label }}
                  <ArrowUp v-if="sortState(column.key) === 'ascending'" class="size-3" aria-hidden="true" />
                  <ArrowDown v-else-if="sortState(column.key) === 'descending'" class="size-3" aria-hidden="true" />
                  <ChevronsUpDown v-else class="size-3 opacity-60" aria-hidden="true" />
                  <span class="sr-only">, ordenar</span>
                </button>
                <abbr v-else-if="column.title" :title="column.title" class="no-underline">{{ column.label }}</abbr>
                <template v-else>{{ column.label }}</template>
              </th>
            </tr>
          </thead>
          <AdminTableSkeleton v-if="view === 'loading'" kind="table" :columns="columns.length + (selectable ? 1 : 0)" :visible="showSkeleton" />
          <tbody v-else :class="loading && 'opacity-60'">
            <template v-for="{ row, heading } in grouped" :key="row.id">
            <tr v-if="heading">
              <th :colspan="columns.length + (selectable ? 1 : 0)" scope="colgroup" class="h-8 border-b border-adm-line bg-adm-side px-3 text-left text-xs font-medium text-adm-meta">{{ heading }}</th>
            </tr>
            <tr
              :data-selected="selectable && row.getIsSelected() ? '' : undefined"
              :class="['group', (clickable || rowHref) && 'cursor-pointer']"
              @click="open(row.original, $event)"
            >
              <td v-if="selectable" :class="['sticky left-0 z-[1] w-11 min-w-11 h-10 border-b border-adm-line bg-adm-bg px-3 group-hover:bg-adm-subtle group-data-[selected]:bg-adm-acc-soft']">
                <AdminCheckbox
                  :model-value="row.getIsSelected()"
                  :label="`Seleccionar ${rowLabel?.(row.original) ?? 'la fila'}`"
                  @update:model-value="(value) => row.toggleSelected(value === true)"
                />
              </td>
              <td
                v-for="column in columns"
                :key="column.key"
                :class="[
                  'h-10 border-b border-adm-line bg-adm-bg px-3 whitespace-nowrap group-hover:bg-adm-subtle group-data-[selected]:bg-adm-acc-soft',
                  sticky(column.key),
                  column.align === 'right' && 'text-right',
                  column.minWidth,
                  hideClass(column),
                ]"
              >
                <component
                  :is="rowHref ? link : 'button'"
                  v-if="column.key === primary && (rowHref || clickable)"
                  v-bind="rowHref ? { to: rowHref(row.original) } : { type: 'button' }"
                  class="-mx-1 rounded px-1 text-left font-medium hover:underline hover:underline-offset-2"
                  @click.stop="!rowHref && emit('row-click', row.original)"
                >
                  <slot :name="`cell-${column.key}`" :row="row.original" :value="row.getValue(column.key)">{{ row.getValue(column.key) ?? '—' }}</slot>
                </component>
                <slot v-else :name="`cell-${column.key}`" :row="row.original" :value="row.getValue(column.key)">{{ row.getValue(column.key) ?? '—' }}</slot>
              </td>
            </tr>
            </template>
          </tbody>
        </table>
      </div>

      <!-- < 768: one card per row (no horizontal scroll). Same selection, links and slots as the table. -->
      <div class="md:hidden" :aria-busy="loading || undefined">
        <div v-if="selectable" class="flex min-h-12 items-center border-b border-adm-line bg-adm-side px-3">
          <AdminCheckbox :model-value="pageCheck()" label="Seleccionar todas las filas de esta página" @update:model-value="togglePage" />
          <span class="ml-2 text-xs text-adm-meta" aria-hidden="true">Seleccionar página</span>
        </div>
        <AdminTableSkeleton v-if="view === 'loading'" kind="cards" :visible="showSkeleton" />
        <ul v-else :class="loading && 'opacity-60'">
          <template v-for="{ row, heading } in grouped" :key="row.id">
          <li v-if="heading" class="border-b border-adm-line bg-adm-side px-3 py-2 text-xs font-medium text-adm-meta">{{ heading }}</li>
          <li
            :data-selected="selectable && row.getIsSelected() ? '' : undefined"
            :class="['flex items-start gap-3 border-b border-adm-line bg-adm-bg p-3 data-[selected]:bg-adm-acc-soft', (clickable || rowHref) && 'cursor-pointer active:bg-adm-subtle']"
            @click="open(row.original, $event)"
          >
            <AdminCheckbox
              v-if="selectable"
              class="mt-[14px]"
              :model-value="row.getIsSelected()"
              :label="`Seleccionar ${rowLabel?.(row.original) ?? 'la fila'}`"
              @update:model-value="(value) => row.toggleSelected(value === true)"
            />
            <div class="min-w-0 flex-1 space-y-1.5">
              <div class="text-sm font-medium">
                <component
                  :is="rowHref ? link : 'button'"
                  v-if="primary && (rowHref || clickable)"
                  v-bind="rowHref ? { to: rowHref(row.original) } : { type: 'button' }"
                  class="inline-flex min-h-11 max-w-full items-center rounded text-left hover:underline hover:underline-offset-2"
                  @click.stop="!rowHref && emit('row-click', row.original)"
                >
                  <slot :name="`cell-${primary}`" :row="row.original" :value="row.getValue(primary)">{{ row.getValue(primary) ?? '—' }}</slot>
                </component>
                <slot v-else-if="primary" :name="`cell-${primary}`" :row="row.original" :value="row.getValue(primary)">{{ row.getValue(primary) ?? '—' }}</slot>
              </div>
              <dl v-if="cardColumns.length" class="grid grid-cols-[max-content_1fr] items-center gap-x-3 gap-y-1 text-xs text-adm-meta">
                <div v-for="column in cardColumns" :key="column.key" class="contents">
                  <dt>{{ column.label }}</dt>
                  <dd class="text-adm-fg"><slot :name="`cell-${column.key}`" :row="row.original" :value="row.getValue(column.key)">{{ row.getValue(column.key) ?? '—' }}</slot></dd>
                </div>
              </dl>
            </div>
            <div v-for="column in actionColumns" :key="column.key" class="shrink-0">
              <slot :name="`cell-${column.key}`" :row="row.original" :value="row.getValue(column.key)" />
            </div>
          </li>
          </template>
        </ul>
      </div>
    </template>

    <AdminTablePager
      v-if="view === 'ready' || view === 'loading'"
      :page="current.page"
      :page-size="current.pageSize"
      :total="total"
      :disabled="loading"
      @update:page="(page) => setQuery({ ...current, page })"
      @update:page-size="(pageSize) => setQuery({ ...current, pageSize, page: 0 })"
    />
    <p class="sr-only" role="status">{{ resultsLive }}</p>
  </div>

  <AdminBulkBar :count="selectedIds.length" :feminine="feminine" @clear="clearSelection">
    <slot name="bulk" :ids="selectedIds" :clear="clearSelection" />
  </AdminBulkBar>
</template>
