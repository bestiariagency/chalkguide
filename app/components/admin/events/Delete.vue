<script setup lang="ts">
import { Loader2, Sparkles } from 'lucide-vue-next'
import type { AdminEvent } from '~/utils/admin-events'

/**
 * Delete confirmation (alertdialog, focus on Cancelar). If the agent proposed it, it warns that it may propose
 * it again and offers "Descartar en su lugar". Only drafts and discarded events get here (a published one is
 * withdrawn first).
 */
defineProps<{ event: AdminEvent; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: []; discard: [] }>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="`¿Eliminar «${event.titleEs}»?`" description="Se borra para siempre. No se puede deshacer.">
    <p v-if="event.source === 'agent'" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
      <Sparkles class="mt-0.5 size-4 flex-none" aria-hidden="true" />
      <span>Lo propuso el agente. Si lo eliminas, <b>puede volver a proponerlo</b> más adelante. Para que no vuelva, descártalo: queda en Descartados y el agente lo recuerda.</span>
    </p>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button v-if="event.source === 'agent' && event.status !== 'rejected'" type="button" :class="admBtnGhost" :disabled="busy" @click="emit('discard')">Descartar en su lugar</button>
      <button type="button" :class="admBtnDanger" :disabled="busy" :aria-busy="busy || undefined" @click="emit('confirm')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Eliminar</button>
    </template>
  </AdminModal>
</template>
