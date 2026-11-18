<script setup lang="ts">
import { ChevronLeft, ChevronRight, Check } from 'lucide-vue-next'
import { formatBytes } from '~/utils/admin-media-library'
import { photoReasonLabel, type AdminReview, type AdminReviewPhoto } from '~/utils/admin-reviews'

/** Large view of one photo with the same actions as the grid; ← → move between the photos of the review. */
const props = defineProps<{ review: AdminReview; srcOf: (photo: AdminReviewPhoto) => string | undefined; busy: boolean }>()
const open = defineModel<boolean>('open', { required: true })
const index = defineModel<number>('index', { required: true })
const emit = defineEmits<{ approve: [photo: AdminReviewPhoto]; reject: [photo: AdminReviewPhoto, reason: string] }>()

const total = computed(() => props.review.photos.length)
const photo = computed(() => props.review.photos[index.value])
const go = (delta: number) => (index.value = (index.value + delta + total.value) % total.value)
const state = computed(() => ({ pending: 'Por revisar', approved: 'Publicada', rejected: 'Rechazada' })[photo.value?.status ?? 'pending'])

function onKey(event: KeyboardEvent) {
  if (!open.value || total.value < 2) return
  if (event.key === 'ArrowLeft') go(-1)
  else if (event.key === 'ArrowRight') go(1)
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <AdminModal v-model:open="open" size="lg" stacked :title="`Foto ${index + 1} de ${total} · ${review.author}`">
    <template v-if="photo">
      <div class="flex items-center gap-2 pb-3 text-xs text-adm-meta">
        <span class="font-medium text-adm-fg">{{ state }}</span>
        <span v-if="photo.status === 'rejected'">· {{ photoReasonLabel(photo.rejectReason) }}</span>
        <span class="tabular-nums">· {{ formatBytes(photo.size) }} · {{ photo.width }} × {{ photo.height }}</span>
        <span class="ml-auto flex gap-1">
          <button type="button" :class="admIconBtn" :disabled="total < 2" aria-label="Foto anterior (←)" @click="go(-1)"><ChevronLeft aria-hidden="true" /></button>
          <button type="button" :class="admIconBtn" :disabled="total < 2" aria-label="Foto siguiente (→)" @click="go(1)"><ChevronRight aria-hidden="true" /></button>
        </span>
      </div>
      <div class="flex min-h-48 items-center justify-center rounded-lg bg-[#0E0E10]">
        <img v-if="srcOf(photo)" :src="srcOf(photo)" :alt="`Foto ${index + 1} de ${total} de ${review.author} en ${review.itemName}`" class="max-h-[60dvh] max-w-full object-contain" />
        <p v-else class="p-6 text-sm text-white/70">No se puede mostrar esta foto (el original ya no existe).</p>
      </div>
    </template>
    <template #footer>
      <template v-if="photo">
        <button v-if="photo.status !== 'approved'" type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('approve', photo)"><Check aria-hidden="true" />Aprobar</button>
        <AdminReviewsRejectMenu v-if="photo.status === 'pending'" label="Rechazar" photo-label="esta foto" :disabled="busy" @select="emit('reject', photo, $event)" />
        <AdminReviewsRejectMenu v-else-if="photo.status === 'approved'" label="Retirar" photo-label="esta foto" hint="Elige el motivo. No se puede deshacer." :disabled="busy" @select="emit('reject', photo, $event)" />
      </template>
      <button type="button" :class="admBtnGhost" @click="open = false">Cerrar</button>
    </template>
  </AdminModal>
</template>
