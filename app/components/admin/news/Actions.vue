<script setup lang="ts">
import { Check, ChevronDown, Pencil, X } from 'lucide-vue-next'
import type { AdminNews } from '~/utils/admin-news'

/** Decisions on a draft: Rechazar ▾ (D), Editar (E) and Aprobar (A, primary). */
defineProps<{ news: AdminNews; busy: boolean; sheet?: boolean }>()
const emit = defineEmits<{ approve: []; edit: []; reject: [reason: string | null] }>()
const rejectOpen = defineModel<boolean>('rejectOpen', { default: false })
const kbd = 'rounded border border-white/30 px-1 font-mono text-[11px] leading-4 text-white/70 max-lg:hidden'
</script>

<template>
  <div :class="['flex flex-wrap items-center gap-2', sheet && 'w-full [&>*]:flex-1']">
    <AdminNewsRejectMenu v-model:open="rejectOpen" :agent="news.source === 'agent'" side="top" @select="(reason) => emit('reject', reason)">
      <button type="button" :class="admBtnGhost" :disabled="busy" aria-haspopup="menu"><X aria-hidden="true" />Rechazar<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /><span :class="[admKbd, 'max-lg:hidden']">D</span></button>
    </AdminNewsRejectMenu>
    <button type="button" :class="[admBtnGhost, !sheet && 'ml-auto']" @click="emit('edit')"><Pencil aria-hidden="true" />Editar <span :class="[admKbd, 'max-lg:hidden']">E</span></button>
    <button type="button" :class="[admBtnPrimary, sheet && 'basis-full']" :disabled="busy" @click="emit('approve')"><Check aria-hidden="true" />Aprobar <span :class="kbd">A</span></button>
  </div>
</template>
