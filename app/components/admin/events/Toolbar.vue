<script setup lang="ts">
import { DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuItemIndicator, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger, PopoverContent, PopoverPortal, PopoverRoot, PopoverTrigger } from 'reka-ui'
import { Calendar, CalendarRange, Check, ChevronDown, Inbox, Search, Tag, X } from 'lucide-vue-next'
import { EVENT_TYPES, EVENT_VIEWS, eventTypeLabel, type EventFilters, type EventView } from '~/utils/admin-events'
import type { GymOption } from '~/services/admin/events'

/** Tabs with counts, search, filters (Tipo, Lugar, Fechas, Origen) with removable chips, and the List / Mes toggle. All of it lives in the URL. */
const props = defineProps<{
  counts?: Record<EventView, number>
  typeCounts: Record<string, number>
  gyms: readonly GymOption[]
  filters: EventFilters
  /** Collections of the last 30 days (Origen > Recogida). */
  runs?: readonly { id: string; label: string }[]
}>()
const view = defineModel<EventView>('view', { required: true })
const search = defineModel<string>('search', { required: true })
const calendar = defineModel<boolean>('calendar', { default: false })
const emit = defineEmits<{ filter: [patch: Partial<Record<'tipo' | 'lugar' | 'desde' | 'hasta' | 'origen' | 'recogida', string | undefined>>] }>()

const ALL = 'all'
const placeOptions = computed(() => [{ value: ALL, label: 'Todos los lugares' }, ...props.gyms.map((g) => ({ value: g.id, label: g.name }))])
const RUN = 'run:'
const sourceOptions = computed(() => [
  { value: ALL, label: 'Cualquier origen' },
  { value: 'agent', label: 'Agente' },
  { value: 'manual', label: 'Manual' },
  ...(props.runs ?? []).map((r) => ({ value: `${RUN}${r.id}`, label: `Recogida · ${r.label}` })),
])
const sourceValue = computed(() => (props.filters.run ? `${RUN}${props.filters.run}` : props.filters.source || ALL))
const runChip = computed(() => `Recogida · ${props.runs?.find((r) => r.id === props.filters.run)?.label ?? 'una recogida'}`)
function pickSource(v: string | undefined) {
  if (!v) return
  if (v.startsWith(RUN)) emit('filter', { origen: undefined, recogida: v.slice(RUN.length) })
  else emit('filter', { origen: v === ALL ? undefined : v, recogida: undefined })
}
const layoutOptions = [{ value: false, label: 'Lista' }, { value: true, label: 'Mes' }]
const gymName = (id: string) => props.gyms.find((g) => g.id === id)?.name ?? 'Un lugar'
const sourceLabel = (s: string) => (s === 'agent' ? 'Agente' : 'Manual')
const dateText = (iso: string) => adminDate(iso)
const dateChip = computed(() => (props.filters.from && props.filters.to ? `${dateText(props.filters.from)} – ${dateText(props.filters.to)}` : props.filters.from ? `Desde ${dateText(props.filters.from)}` : props.filters.to ? `Hasta ${dateText(props.filters.to)}` : ''))

function toggleType(type: string, on: boolean) {
  const next = on ? [...props.filters.types, type] : props.filters.types.filter((t) => t !== type)
  emit('filter', { tipo: next.join(',') || undefined })
}
const active = computed(() => props.filters.types.length > 0 || !!props.filters.itemId || !!dateChip.value || !!props.filters.source || !!props.filters.run)

function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = EVENT_VIEWS[(index + step + EVENT_VIEWS.length) % EVENT_VIEWS.length]
  if (!next) return
  view.value = next.value
  void nextTick(() => document.getElementById(`ev-tab-${next.value}`)?.focus())
}
const chipBtn = 'inline-flex h-6 items-center gap-1 rounded-full border border-adm-line-strong bg-adm-elev pr-1 pl-2.5 text-xs hover:border-adm-control max-md:h-8'
</script>

<template>
  <div class="flex-none">
    <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Vistas de la agenda" class="flex min-w-max gap-5">
        <button
          v-for="(tab, index) in EVENT_VIEWS"
          :id="`ev-tab-${tab.value}`"
          :key="tab.value"
          type="button"
          role="tab"
          :aria-selected="view === tab.value"
          :tabindex="view === tab.value ? 0 : -1"
          :class="[
            'relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11',
            view === tab.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg',
          ]"
          @click="view = tab.value"
          @keydown="move($event, index)"
        >
          <Inbox v-if="tab.value === 'revisar'" class="size-4" aria-hidden="true" />{{ tab.label }}
          <span v-if="counts" :class="tab.value === 'revisar' && counts.revisar ? 'rounded-full bg-adm-warn-soft px-1.5 text-adm-warn tabular-nums' : 'text-adm-muted tabular-nums'">{{ counts[tab.value] }}</span>
        </button>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
      <div class="relative w-full sm:w-64">
        <label for="ev-q" class="sr-only">Buscar eventos</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input id="ev-q" v-model="search" type="search" :class="[admInput, 'pl-8 [&::-webkit-search-cancel-button]:hidden']" placeholder="Buscar por título o lugar" autocomplete="off" />
      </div>

      <DropdownMenuRoot>
        <DropdownMenuTrigger :class="admBtnGhost" :aria-label="filters.types.length ? `Tipo, ${filters.types.length} seleccionados` : 'Tipo'">
          <Tag aria-hidden="true" />Tipo<span v-if="filters.types.length" class="rounded-full bg-adm-acc-soft px-1.5 text-adm-acc tabular-nums">{{ filters.types.length }}</span><ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" />
        </DropdownMenuTrigger>
        <DropdownMenuPortal>
          <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin font-sans']">
            <DropdownMenuCheckboxItem
              v-for="type in EVENT_TYPES"
              :key="type.value"
              :model-value="filters.types.includes(type.value)"
              :class="[admMenuItem, 'cursor-pointer']"
              @select.prevent
              @update:model-value="(on: boolean) => toggleType(type.value, on)"
            >
              <span class="grid size-4 place-items-center rounded border border-adm-control"><DropdownMenuItemIndicator><Check class="size-3! text-adm-acc!" aria-hidden="true" /></DropdownMenuItemIndicator></span>
              <span class="flex-1">{{ type.label }}</span><span class="text-adm-muted tabular-nums">{{ typeCounts[type.value] ?? 0 }}</span>
            </DropdownMenuCheckboxItem>
          </DropdownMenuContent>
        </DropdownMenuPortal>
      </DropdownMenuRoot>

      <div class="min-w-0 max-sm:flex-1 sm:w-52"><AdminSelect :model-value="filters.itemId || ALL" label="Lugar" :options="placeOptions" hide-label @update:model-value="(v) => emit('filter', { lugar: v === ALL ? undefined : v })" /></div>

      <PopoverRoot>
        <PopoverTrigger :class="admBtnGhost"><CalendarRange aria-hidden="true" />Fechas<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></PopoverTrigger>
        <PopoverPortal>
          <PopoverContent align="start" :side-offset="4" :class="[admPopover, 'admin w-72 space-y-3 p-3 font-sans']">
            <div><label for="ev-from" :class="admLabel">Desde</label><input id="ev-from" type="date" :class="admInput" :value="filters.from" @change="emit('filter', { desde: ($event.target as HTMLInputElement).value || undefined })" /></div>
            <div><label for="ev-to" :class="admLabel">Hasta</label><input id="ev-to" type="date" :class="admInput" :value="filters.to" @change="emit('filter', { hasta: ($event.target as HTMLInputElement).value || undefined })" /></div>
            <p class="text-xs text-adm-meta">Sin fechas, se ve todo el periodo de la vista. El sitio muestra los próximos 60 días.</p>
          </PopoverContent>
        </PopoverPortal>
      </PopoverRoot>

      <div class="min-w-0 max-sm:hidden sm:w-40"><AdminSelect :model-value="sourceValue" label="Origen" :options="sourceOptions" hide-label @update:model-value="pickSource" /></div>

      <AdminSegmented v-if="view === 'proximos'" v-model="calendar" class="ml-auto max-md:hidden" label="Presentación" :options="layoutOptions" />
      <p v-else-if="view === 'revisar'" class="ml-auto hidden items-center gap-2 text-xs text-adm-meta xl:flex">
        <span :class="admKbd">J</span><span :class="admKbd">K</span> moverse · <span :class="admKbd">A</span> aprobar · <span :class="admKbd">E</span> editar · <span :class="admKbd">D</span> descartar
      </p>
    </div>

    <div v-if="active" class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2 text-xs md:px-6">
      <span class="text-adm-meta">Filtros:</span>
      <button v-for="type in filters.types" :key="type" type="button" :class="chipBtn" @click="toggleType(type, false)">{{ eventTypeLabel(type) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="filters.itemId" type="button" :class="chipBtn" @click="emit('filter', { lugar: undefined })">{{ gymName(filters.itemId) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="dateChip" type="button" :class="chipBtn" @click="emit('filter', { desde: undefined, hasta: undefined })"><Calendar class="size-3.5" aria-hidden="true" />{{ dateChip }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="filters.source" type="button" :class="chipBtn" @click="emit('filter', { origen: undefined })">{{ sourceLabel(filters.source) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="filters.run" type="button" :class="chipBtn" @click="emit('filter', { recogida: undefined })">{{ runChip }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button type="button" class="ml-1 rounded px-1 text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" @click="emit('filter', { tipo: undefined, lugar: undefined, desde: undefined, hasta: undefined, origen: undefined, recogida: undefined })">Quitar todos</button>
    </div>
  </div>
</template>
