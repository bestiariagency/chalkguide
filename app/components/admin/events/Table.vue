<script setup lang="ts">
import { Mountain, Undo2 } from 'lucide-vue-next'
import { eventTypeLabel, placeOf, rejectReasonLabel, isGymPlace, type AdminEvent, type EventView } from '~/utils/admin-events'
import { dayLabel, monthGroup, timeLabel } from '~/utils/admin-madrid'
import { emptyAdminQuery } from '~/utils/admin-table'

/**
 * Próximos, Pasados, Descartados and Todos: `AdminDataTable` (cards under 768) with a heading row per month.
 * The database already filtered and ordered the rows; the date column can be re-sorted here.
 */
const props = defineProps<{ events: readonly AdminEvent[]; view: EventView; loading: boolean; busy: boolean; error?: string; errorCode?: string }>()
const emit = defineEmits<{
  open: [event: AdminEvent]
  duplicate: [event: AdminEvent]
  retire: [event: AdminEvent]
  cancel: [event: AdminEvent]
  uncancel: [event: AdminEvent]
  remove: [event: AdminEvent]
  recover: [event: AdminEvent]
  retry: []
}>()

const query = ref<AdminTableQuery>(emptyAdminQuery(25))
const rejected = computed(() => props.view === 'descartados')
const columns = computed<AdminColumn<AdminEvent>[]>(() => [
  { key: 'date', label: 'Fecha', sortable: true, searchable: false, card: true, minWidth: 'w-36', accessor: (e) => e.startsAt },
  { key: 'title', label: 'Evento', pin: 'left', minWidth: 'min-w-72', accessor: (e) => `${e.titleEs} ${placeOf(e)}` },
  ...(props.view === 'todos' ? [{ key: 'status', label: 'Estado', card: true, searchable: false, minWidth: 'w-36' }] : []),
  { key: 'type', label: 'Tipo', searchable: false, hideBelow: 'lg' as const, card: true, accessor: (e) => e.type },
  rejected.value
    ? { key: 'reason', label: 'Motivo', searchable: false, card: true, accessor: (e) => rejectReasonLabel(e.rejectReason) }
    : { key: 'price', label: 'Precio', searchable: false, hideBelow: 'xl' as const, accessor: (e) => e.priceText ?? '' },
  { key: 'source', label: 'Origen', searchable: false, hideBelow: 'xl' as const, accessor: (e) => e.source },
  { key: 'lang', label: 'Idiomas', searchable: false, accessor: (e) => e.hasEn },
  { key: 'actions', label: 'Acciones', hideLabel: true, pin: 'right', searchable: false },
])
const groupOf = computed(() => (query.value.sort && query.value.sort.id !== 'date' ? undefined : (e: AdminEvent) => monthGroup(e.startsAt)))
const caption = computed(() => ({ proximos: 'Próximos eventos, por fecha', pasados: 'Eventos pasados, el más reciente primero', descartados: 'Eventos descartados', todos: 'Todos los eventos', revisar: 'Eventos por aprobar' })[props.view])
</script>

<template>
  <AdminDataTable
    :key="view"
    v-model:query="query"
    :rows="events"
    :columns="columns"
    :row-id="(e: AdminEvent) => e.id"
    :row-label="(e: AdminEvent) => `«${e.titleEs}»`"
    primary-key="title"
    clickable
    :group-of="groupOf"
    :caption="caption"
    :loading="loading"
    :error="error"
    :error-code="errorCode"
    @row-click="emit('open', $event)"
    @retry="emit('retry')"
  >
    <template #empty><slot name="empty" /></template>
    <template #cell-date="{ row }">
      <span class="tabular-nums"><span class="font-medium">{{ dayLabel(row.startsAt) }}</span><span class="block text-xs text-adm-meta">{{ timeLabel(row) }}</span></span>
    </template>
    <template #cell-title="{ row }">
      <span class="block max-w-full md:max-w-[34rem]">
        <span :class="['block truncate max-md:line-clamp-2 max-md:whitespace-normal', row.status === 'cancelled' && 'text-adm-meta line-through']">{{ row.titleEs }}</span>
        <span v-if="row.status === 'cancelled'" class="mt-0.5 block"><AdminEventsChip :event="row" /></span>
        <span v-if="placeOf(row)" class="block truncate text-xs font-normal text-adm-meta"><Mountain v-if="isGymPlace(row)" class="mr-1 -mt-0.5 inline size-3" aria-hidden="true" /><span v-if="isGymPlace(row)" class="sr-only">Ficha: </span>{{ placeOf(row) }}</span>
      </span>
    </template>
    <template #cell-status="{ row }"><AdminEventsChip :event="row" /></template>
    <template #cell-type="{ row }"><span :class="[admChip, 'bg-adm-subtle text-adm-meta']">{{ eventTypeLabel(row.type) }}</span></template>
    <template #cell-reason="{ row }"><span class="text-adm-meta">{{ rejectReasonLabel(row.rejectReason) }}</span></template>
    <template #cell-price="{ row }"><span class="block max-w-44 truncate text-adm-meta">{{ row.priceText ?? '—' }}</span></template>
    <template #cell-source="{ row }">
      <span class="inline-flex flex-wrap items-center gap-x-2"><AdminEventsOrigin :source="row.source" short /><AdminEventsSource :url="row.sourceUrl" :title="row.titleEs" /></span>
    </template>
    <template #cell-lang="{ row }"><AdminEventsLang :has="row.hasEn" /></template>
    <template #cell-actions="{ row }">
      <button v-if="row.status === 'rejected'" type="button" :class="admBtnQuiet" :disabled="busy" :aria-label="`Recuperar «${row.titleEs}»`" @click="emit('recover', row)"><Undo2 aria-hidden="true" />Recuperar</button>
      <AdminEventsRowMenu v-else :event="row" @edit="emit('open', row)" @duplicate="emit('duplicate', row)" @retire="emit('retire', row)" @cancel="emit('cancel', row)" @uncancel="emit('uncancel', row)" @remove="emit('remove', row)" />
    </template>
  </AdminDataTable>
</template>
