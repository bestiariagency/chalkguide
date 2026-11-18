<script setup lang="ts">
import type { AdminEvent } from '~/utils/admin-events'

/**
 * Por aprobar: list of 420 px and detail from 1024 px; below, the list alone and the detail in a sheet.
 * Keys: J/K move, A approves, E edits, D opens the discard menu (not while typing or inside a dialog).
 * After deciding, the selection (and focus) moves to the next event.
 */
const props = defineProps<{ events: readonly AdminEvent[]; busy: boolean }>()
const selectedId = defineModel<string | undefined>('selectedId')
const checked = defineModel<string[]>('checked', { default: () => [] })
const emit = defineEmits<{
  approve: [event: AdminEvent, next: string | undefined]
  edit: [event: AdminEvent]
  reject: [event: AdminEvent, reason: string | null, next: string | undefined]
  duplicate: [event: AdminEvent]
  remove: [event: AdminEvent]
  openEvent: [id: string]
}>()

/** From the sheet the selection is dropped first, so the editor does not open on top of another dialog. */
function edit(e: AdminEvent) {
  if (!desktop.value) selectedId.value = undefined
  emit('edit', e)
}
const approve = (e: AdminEvent) => emit('approve', e, neighbour())
const reject = (e: AdminEvent, reason: string | null) => emit('reject', e, reason, neighbour())

const { desktop, rejectOpen, selected, neighbour, step, sheetOpen, toggle } = useAdminInbox({
  kind: 'event',
  rows: () => props.events,
  selectedId,
  checked,
  canApprove: (e) => !e.isPast,
  onApprove: approve,
  onEdit: edit,
})
</script>

<template>
  <div class="lg:grid lg:min-h-0 lg:flex-1 lg:grid-cols-[420px_minmax(0,1fr)] lg:grid-rows-1">
    <div class="min-w-0 lg:min-h-0 lg:overflow-y-auto lg:border-r lg:border-adm-line">
      <AdminEventsList
        :events="events"
        :selected-id="selectedId"
        :checked="checked"
        :busy="busy"
        @open="selectedId = $event"
        @toggle="toggle"
        @toggle-all="checked = $event ? events.map((e) => e.id) : []"
        @approve="approve"
        @edit="edit"
        @reject="reject"
      />
    </div>
    <section class="hidden min-w-0 lg:block lg:min-h-0 lg:overflow-y-auto" aria-live="polite">
      <AdminEventsDetail
        v-if="selected && desktop"
        :key="selected.id"
        v-model:reject-open="rejectOpen"
        :event="selected"
        :busy="busy"
        @approve="approve(selected)"
        @edit="edit(selected)"
        @reject="(reason) => reject(selected!, reason)"
        @prev="step(-1)"
        @next="step(1)"
        @open-event="emit('openEvent', $event)"
        @duplicate="emit('duplicate', selected)"
        @remove="emit('remove', selected)"
      />
      <p v-else class="p-6 text-sm text-adm-meta">Elige un evento de la lista para ver su detalle.</p>
    </section>

    <AdminModal v-if="selected && !desktop" v-model:open="sheetOpen" placement="right" :title="selected.titleEs">
      <AdminEventsDetail :event="selected" :busy="busy" sheet @approve="approve(selected)" @edit="edit(selected)" @reject="(reason) => reject(selected!, reason)" @open-event="emit('openEvent', $event)" />
      <template #footer>
        <AdminEventsActions :event="selected" :busy="busy" sheet @approve="approve(selected)" @edit="edit(selected)" @reject="(reason) => reject(selected!, reason)" />
      </template>
    </AdminModal>
  </div>
</template>
