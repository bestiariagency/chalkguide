<script setup lang="ts">
import { Loader2, Sparkles } from 'lucide-vue-next'
import type { AdminNews } from '~/utils/admin-news'

/**
 * Delete confirmation (alertdialog, focus on Cancelar). An item from the agent is never deleted (its key is what stops the agent
 * from proposing it again): the dialog offers «Rechazar en su lugar». Only drafts and rejected manual items get here.
 */
defineProps<{ news: AdminNews; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: []; reject: [] }>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="news.source === 'agent' ? `Una noticia del agente no se elimina` : `¿Eliminar «${news.titleEs}»?`" :description="news.source === 'agent' ? undefined : 'Se borra para siempre. No se puede deshacer.'">
    <p v-if="news.source === 'agent'" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
      <Sparkles class="mt-0.5 size-4 flex-none" aria-hidden="true" />
      <span>La propuso el agente. Si se borrara, <b>podría volver a proponerla</b>. Si la rechazas, queda en Rechazadas y el agente la recuerda.</span>
    </p>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button v-if="news.source === 'agent'" type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('reject')">Rechazar en su lugar</button>
      <button v-else type="button" :class="admBtnDanger" :disabled="busy" :aria-busy="busy || undefined" @click="emit('confirm')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Eliminar</button>
    </template>
  </AdminModal>
</template>
