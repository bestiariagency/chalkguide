<script setup lang="ts">
import { Check, Clock, Image as ImageIcon, Maximize2 } from 'lucide-vue-next'
import { formatBytes } from '~/utils/admin-media-library'
import { photoReasonLabel, type AdminReview, type AdminReviewPhoto } from '~/utils/admin-reviews'

/**
 * "Fotos" section of the review detail (docs/design/admin/README.md §8.2): 4:3 thumbnails with a
 * status chip, weight and size, and the actions of each state. Under 1024 (`sheet`) the actions are
 * 44 px icon buttons. Rejecting needs a reason (the reader sees it); retiring too.
 */
const props = defineProps<{
  review: AdminReview
  srcOf: (photo: AdminReviewPhoto) => string | undefined
  busy: boolean
  sheet?: boolean
}>()
const emit = defineEmits<{ open: [index: number]; approve: [photo: AdminReviewPhoto]; approveAll: []; reject: [photo: AdminReviewPhoto, reason: string] }>()

const pending = computed(() => props.review.photos.filter((p) => p.status === 'pending').length)
const chip = (p: AdminReviewPhoto) => ({ pending: { status: 'pending', label: 'Por revisar' }, approved: { status: 'visible', label: 'Publicada' }, rejected: { status: 'hidden', label: 'Rechazada' } })[p.status] as { status: 'pending' | 'visible' | 'hidden'; label: string }
</script>

<template>
  <section v-if="review.photos.length" aria-labelledby="rev-photos-h">
    <div class="mb-2 flex flex-wrap items-center gap-2">
      <h3 id="rev-photos-h" class="text-xs font-medium text-adm-meta">
        Fotos · {{ review.photos.length }}<template v-if="pending"> · {{ pending }} por revisar</template>
      </h3>
      <button v-if="pending > 1" type="button" :class="[admBtnGhost, 'ml-auto h-8 max-lg:order-last max-lg:h-11 max-lg:w-full']" :disabled="busy" @click="emit('approveAll')">
        <Check aria-hidden="true" />Aprobar las {{ pending }}
      </button>
    </div>
    <ul :class="['grid grid-cols-3', sheet ? 'gap-2' : 'gap-3']">
      <li v-for="(photo, index) in review.photos" :key="photo.id" class="min-w-0">
        <button type="button" class="group relative block aspect-[4/3] w-full overflow-hidden rounded-lg bg-adm-subtle focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc" :aria-label="`Ampliar la foto ${index + 1} de ${review.photos.length}`" @click="emit('open', index)">
          <img v-if="srcOf(photo)" :src="srcOf(photo)" alt="" loading="lazy" :width="photo.width" :height="photo.height" :class="['size-full object-cover', photo.status === 'rejected' && 'opacity-40 grayscale']" />
          <ImageIcon v-else class="absolute inset-0 m-auto size-6 text-adm-muted" aria-hidden="true" />
          <span class="pointer-events-none absolute inset-0 rounded-lg shadow-[inset_0_0_0_1px_rgb(0_0_0/0.1)]" aria-hidden="true" />
          <span class="absolute top-1.5 left-1.5">
            <span v-if="photo.status === 'pending'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Clock aria-hidden="true" />Por revisar</span>
            <AdminStatusChip v-else :status="chip(photo).status" :label="chip(photo).label" />
          </span>
          <Maximize2 class="absolute right-1.5 bottom-1.5 size-4 rounded bg-black/60 p-0.5 text-white opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100" aria-hidden="true" />
        </button>
        <p class="mt-1 text-[11px] text-adm-muted tabular-nums">{{ formatBytes(photo.size) }} · {{ photo.width }} × {{ photo.height }}</p>
        <p v-if="photo.status === 'rejected'" class="text-xs text-adm-meta">{{ photoReasonLabel(photo.rejectReason) }}</p>
        <div class="mt-1.5 flex flex-wrap gap-1.5">
          <template v-if="photo.status === 'pending'">
            <template v-if="sheet">
              <button type="button" :class="[admIconBtn, 'size-11']" :disabled="busy" @click="emit('approve', photo)"><Check aria-hidden="true" /><span class="sr-only">Aprobar la foto {{ index + 1 }}</span></button>
              <AdminReviewsRejectMenu label="Rechazar" :photo-label="`la foto ${index + 1}`" :disabled="busy" quiet @select="emit('reject', photo, $event)" />
            </template>
            <template v-else>
              <button type="button" :class="[admBtnGhost, 'h-8']" :disabled="busy" @click="emit('approve', photo)">Aprobar</button>
              <AdminReviewsRejectMenu label="Rechazar" :photo-label="`la foto ${index + 1}`" :disabled="busy" @select="emit('reject', photo, $event)" />
            </template>
          </template>
          <AdminReviewsRejectMenu v-else-if="photo.status === 'approved'" label="Retirar" hint="Elige el motivo. No se puede deshacer." :photo-label="`la foto ${index + 1}`" :disabled="busy" quiet @select="emit('reject', photo, $event)" />
          <button v-else type="button" :class="[admBtnQuiet, 'h-8 max-lg:h-11']" :disabled="busy" @click="emit('approve', photo)">Aprobar<span class="sr-only"> la foto {{ index + 1 }} (deshace el rechazo)</span></button>
        </div>
      </li>
    </ul>
  </section>
</template>
