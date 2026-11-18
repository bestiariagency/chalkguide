<script setup lang="ts">
import type { AdminEvent } from '~/utils/admin-events'

/** Withdraw a published event: it leaves /agenda and the home board in a few minutes and goes back to Por aprobar, losing nothing. */
defineProps<{ event: AdminEvent; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [] }>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="`¿Retirar «${event.titleEs}» de la agenda?`" description="Deja de salir en /agenda y en la pizarra de la home en unos minutos. Vuelve a Por aprobar, sin perder nada.">
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('confirm')">Retirar</button>
    </template>
  </AdminModal>
</template>
