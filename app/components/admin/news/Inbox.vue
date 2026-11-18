<script setup lang="ts">
import type { AdminNews } from '~/utils/admin-news'

/**
 * Por revisar: list of 420 px and detail from 1024 px; below, the list alone and the detail in a sheet. Keys: J/K move, A approves,
 * E edits, D opens the reject menu (not while typing or inside a dialog). After deciding, the selection (and focus) moves to the next one.
 */
const props = defineProps<{ rows: readonly AdminNews[]; busy: boolean; labels: Record<string, string> }>()
const selectedId = defineModel<string | undefined>('selectedId')
const checked = defineModel<string[]>('checked', { default: () => [] })
const emit = defineEmits<{
  approve: [news: AdminNews, next: string | undefined]
  edit: [news: AdminNews, focus?: 'note']
  reject: [news: AdminNews, reason: string | null, next: string | undefined]
}>()

/** From the sheet the selection is dropped first, so the editor does not open on top of another dialog. */
function edit(n: AdminNews, focus?: 'note') {
  if (!desktop.value) selectedId.value = undefined
  emit('edit', n, focus)
}
const approve = (n: AdminNews) => emit('approve', n, neighbour())
const reject = (n: AdminNews, reason: string | null) => emit('reject', n, reason, neighbour())

const { desktop, rejectOpen, selected, neighbour, step, sheetOpen, toggle } = useAdminInbox({
  kind: 'news',
  rows: () => props.rows,
  selectedId,
  checked,
  onApprove: approve,
  onEdit: (n) => edit(n),
})
</script>

<template>
  <div class="lg:grid lg:min-h-0 lg:flex-1 lg:grid-cols-[420px_minmax(0,1fr)] lg:grid-rows-1">
    <div class="min-w-0 lg:min-h-0 lg:overflow-y-auto lg:border-r lg:border-adm-line">
      <AdminNewsList
        :rows="rows"
        :selected-id="selectedId"
        :checked="checked"
        :busy="busy"
        :labels="labels"
        @open="selectedId = $event"
        @toggle="toggle"
        @toggle-all="checked = $event ? rows.map((n) => n.id) : []"
        @approve="approve"
        @edit="edit"
        @reject="reject"
      />
    </div>
    <section class="hidden min-w-0 lg:flex lg:min-h-0 lg:flex-col lg:overflow-y-auto">
      <!-- Only the title is announced when the selection changes, not the whole detail. -->
      <p class="sr-only" aria-live="polite" aria-atomic="true">{{ selected && desktop ? selected.titleEs : '' }}</p>
      <AdminNewsDetail
        v-if="selected && desktop"
        :key="selected.id"
        v-model:reject-open="rejectOpen"
        :news="selected"
        :busy="busy"
        :labels="labels"
        @approve="approve(selected)"
        @edit="(focus) => edit(selected!, focus)"
        @reject="(reason) => reject(selected!, reason)"
        @prev="step(-1)"
        @next="step(1)"
      />
      <p v-else class="p-6 text-sm text-adm-meta">Elige una noticia de la lista para ver su detalle.</p>
    </section>

    <AdminModal v-if="selected && !desktop" v-model:open="sheetOpen" placement="right" wide :title="selected.titleEs">
      <AdminNewsDetail :news="selected" :busy="busy" :labels="labels" sheet @approve="approve(selected)" @edit="(focus) => edit(selected!, focus)" @reject="(reason) => reject(selected!, reason)" />
      <template #footer>
        <AdminNewsActions :news="selected" :busy="busy" sheet @approve="approve(selected)" @edit="edit(selected)" @reject="(reason) => reject(selected!, reason)" />
      </template>
    </AdminModal>
  </div>
</template>
