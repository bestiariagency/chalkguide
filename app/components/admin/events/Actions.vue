<script setup lang="ts">
import { Check, ChevronDown, Pencil, X } from 'lucide-vue-next'
import type { AdminEvent } from '~/utils/admin-events'

/**
 * Decisions on a draft. Normal: Aprobar (A), Editar y aprobar (E), Descartar ▾ (D). Already past: Descartar
 * is the primary one and the other option is changing the date (approving it would fail).
 */
const props = defineProps<{ event: AdminEvent; busy: boolean; sheet?: boolean }>()
const emit = defineEmits<{ approve: []; edit: []; reject: [reason: string | null] }>()
const rejectOpen = defineModel<boolean>('rejectOpen', { default: false })
const kbd = 'rounded border border-white/30 px-1 font-mono text-[11px] leading-4 text-white/70 max-lg:hidden'
const agent = computed(() => props.event.source === 'agent')
</script>

<template>
  <div :class="['flex flex-wrap gap-2', sheet && 'w-full [&>*]:flex-1']">
    <template v-if="event.isPast">
      <AdminEventsRejectMenu v-model:open="rejectOpen" :agent="agent" @select="(reason) => emit('reject', reason)">
        <button type="button" :class="admBtnPrimary" :disabled="busy" aria-haspopup="menu"><X aria-hidden="true" />Descartar <span :class="kbd">D</span><ChevronDown class="size-3.5!" aria-hidden="true" /></button>
      </AdminEventsRejectMenu>
      <button type="button" :class="admBtnGhost" @click="emit('edit')"><Pencil aria-hidden="true" />Cambiar la fecha</button>
    </template>
    <template v-else>
      <button type="button" :class="[admBtnPrimary, sheet && 'basis-full']" :disabled="busy" @click="emit('approve')"><Check aria-hidden="true" />Aprobar <span :class="kbd">A</span></button>
      <button type="button" :class="admBtnGhost" @click="emit('edit')"><Pencil aria-hidden="true" />Editar y aprobar <span :class="[admKbd, 'max-lg:hidden']">E</span></button>
      <AdminEventsRejectMenu v-model:open="rejectOpen" :agent="agent" @select="(reason) => emit('reject', reason)">
        <button type="button" :class="admBtnGhost" :disabled="busy" aria-haspopup="menu"><X aria-hidden="true" />Descartar<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></button>
      </AdminEventsRejectMenu>
    </template>
  </div>
</template>
