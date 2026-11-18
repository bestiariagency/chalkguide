<script setup lang="ts">
import { DELETE_REASONS, type AdminReview } from '~/utils/admin-reviews'

/**
 * RGPD erasure / illegal content only: the reason is mandatory and stays in Actividad (without the
 * author's data). For anything else the review is hidden, which is reversible.
 */
defineProps<{ review: AdminReview; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [reason: string] }>()
const reason = ref<string>()
</script>

<template>
  <AdminModal v-model:open="open" alert stacked :busy="busy" :title="`¿Borrar la opinión de ${review.author}?`" description="Solo para solicitudes de supresión (RGPD) o contenido ilegal. Se borran su texto y sus notas, y la media de la ficha se recalcula. No se puede deshacer. En cualquier otro caso, ocúltala: es reversible.">
    <AdminSelect v-model="reason" label="Motivo" required :options="DELETE_REASONS" placeholder="Elige un motivo" help="Queda en Actividad con el motivo, sin datos del autor." />
    <template #footer>
      <button type="button" data-autofocus :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="!reason || busy" :aria-busy="busy" @click="reason && emit('confirm', reason)">Borrar opinión</button>
    </template>
  </AdminModal>
</template>
