<script setup lang="ts">
import { History, Loader2, MegaphoneOff } from 'lucide-vue-next'
import { WITHDRAW_REASONS } from '~/utils/admin-subscribers-related'
import type { Subscriber } from '~/utils/admin-subscribers'

/**
 * Retirar afines (D66, README §18.4): same pattern as the unsubscribe dialog (alertdialog, focus on Cancelar, reason
 * required, no undo). It touches only the related-products consent: the newsletter does not change.
 */
const props = defineProps<{ subscriber: Subscriber; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [reason: string] }>()
const reason = ref<string>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" title="¿Retirar los avisos afines?">
    <template #title><span class="break-words">¿Retirar los avisos afines de <span class="font-mono text-sm break-all">{{ props.subscriber.email }}</span>?</span></template>
    <div class="space-y-4">
      <p class="text-sm text-adm-meta">
        Dejará de recibir avisos de Chalk app y productos afines. <b class="text-adm-fg">La newsletter no cambia.</b>
        <b class="text-adm-fg"> Desde el panel no se puede deshacer:</b> solo esa persona puede volver a darlos, desde sus preferencias.
      </p>
      <fieldset>
        <legend :class="admLabel">Motivo <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></legend>
        <div class="space-y-1 text-sm">
          <label v-for="r in WITHDRAW_REASONS" :key="r.value" class="flex min-h-8 cursor-pointer items-center gap-2 max-md:min-h-11">
            <input v-model="reason" type="radio" name="withdraw-related-reason" :value="r.value" class="size-4 accent-adm-acc" :disabled="busy" />{{ r.label }}
          </label>
        </div>
      </fieldset>
      <p class="flex items-start gap-1.5 text-xs text-adm-meta"><History class="mt-px size-3.5 flex-none" aria-hidden="true" />Queda en su historial como «Afines · retirado desde el panel», con la fecha y el motivo. La prueba de que los dio se conserva.</p>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="!reason || busy" :aria-busy="busy || undefined" @click="reason && emit('confirm', reason)">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" /><MegaphoneOff v-else aria-hidden="true" />{{ busy ? 'Retirando…' : 'Retirar afines' }}
      </button>
    </template>
  </AdminModal>
</template>
