<script setup lang="ts">
import { PHOTO_REJECT_REASONS, type AdminReview } from '~/utils/admin-reviews'

/**
 * Hiding a review does not close the public URLs of its published photos: offer to retire them in
 * the same step (the reason is the one the reader sees).
 */
const props = defineProps<{ review: AdminReview; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [reason?: string] }>()
const reason = ref<string>()
const published = computed(() => props.review.photos.filter((p) => p.status === 'approved').length)
</script>

<template>
  <AdminModal v-model:open="open" stacked :busy="busy" :title="`¿Ocultar la opinión de ${review.author}?`" :description="`Tiene ${published} ${published === 1 ? 'foto publicada' : 'fotos publicadas'}. Si solo ocultas la opinión, las fotos dejan de salir en la ficha pero su dirección pública sigue abierta para quien la tenga. Retirarlas las cierra.`">
    <AdminSelect v-model="reason" label="Motivo para retirar las fotos" :options="PHOTO_REJECT_REASONS" placeholder="Elige un motivo" help="Es el que verá el lector." />
    <template #footer>
      <button type="button" data-autofocus :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="emit('confirm')">Ocultar solo la opinión</button>
      <button type="button" :class="admBtnPrimary" :disabled="!reason || busy" @click="reason && emit('confirm', reason)">Ocultar y retirar las fotos</button>
    </template>
  </AdminModal>
</template>
