<script setup lang="ts">
import { ChevronDown, ChevronUp, Trash2 } from 'lucide-vue-next'
import { categoryOfReview, reviewItemHref, type AdminReview, type AdminReviewPhoto } from '~/utils/admin-reviews'

/**
 * Detail of one review (read only: nobody's text or score is edited, only shown or hidden). The
 * impact box tells what the item's average would be without it.
 */
const props = defineProps<{
  review: AdminReview
  isNew: boolean
  busy: boolean
  /** Visible reviews the site needs before it shows the readers' average. */
  minForAverage: number
  /** Inside the sheet (< 1024): the title is the dialog's and the actions sit in the footer. */
  sheet?: boolean
  srcOf: (photo: AdminReviewPhoto) => string | undefined
}>()
const emit = defineEmits<{
  hide: []
  show: []
  approve: []
  approvePhotos: []
  remove: []
  prev: []
  next: []
  openPhoto: [index: number]
  approvePhoto: [photo: AdminReviewPhoto]
  rejectPhoto: [photo: AdminReviewPhoto, reason: string]
}>()

const href = computed(() => reviewItemHref(props.review))
const kind = computed(() => categoryOfReview(props.review.category)?.singular)
const hiding = computed(() => props.review.status === 'visible')
</script>

<template>
  <article :aria-labelledby="sheet ? undefined : 'rev-detail-h'" class="flex min-h-0 flex-1 flex-col">
    <header v-if="!sheet" class="flex h-12 flex-none items-center gap-2 border-b border-adm-line px-6">
      <h2 id="rev-detail-h" class="text-base font-semibold">{{ review.author }}</h2>
      <AdminReviewsMeter :score="review.overall" />
      <span class="ml-auto flex gap-1">
        <button type="button" :class="admIconBtn" aria-label="Anterior (K)" @click="emit('prev')"><ChevronUp aria-hidden="true" /></button>
        <button type="button" :class="admIconBtn" aria-label="Siguiente (J)" @click="emit('next')"><ChevronDown aria-hidden="true" /></button>
        <button type="button" :class="admIconBtn" aria-label="Borrar opinión (solo supresión RGPD o contenido ilegal)" title="Borrar (solo supresión RGPD o contenido ilegal)" @click="emit('remove')"><Trash2 aria-hidden="true" /></button>
      </span>
    </header>

    <div :class="['max-w-[720px] space-y-5', sheet ? '' : 'p-6']">
      <p v-if="sheet" class="flex items-center gap-2 text-sm"><span class="font-medium">{{ review.author }}</span><AdminReviewsMeter :score="review.overall" /></p>
      <div class="flex flex-wrap items-center gap-2 text-sm">
        <NuxtLink v-if="href" :to="href" class="font-medium underline underline-offset-2">{{ review.itemName }}</NuxtLink>
        <span v-else class="font-medium">{{ review.itemName }}</span>
        <span class="text-adm-meta">
          · {{ kind }} · <AdminTime :iso="review.createdAt" /> · escrita en {{ review.locale === 'es' ? 'español' : 'inglés' }}<template v-if="review.editedAt"> · editada</template>
        </span>
        <AdminStatusChip v-if="isNew" status="new" />
        <AdminStatusChip :status="review.status" :label="review.status === 'hidden' ? 'Oculta' : review.status === 'pending' ? 'Pendiente: aún no sale en la ficha' : 'Visible en la ficha'" />
      </div>

      <blockquote v-if="review.body" class="border-l-2 border-adm-line-strong pl-4 text-sm leading-7 whitespace-pre-line">{{ review.body }}</blockquote>
      <p v-else class="text-sm text-adm-meta">Sin texto: solo puntuación.</p>

      <AdminReviewsPhotos
        :review="review"
        :src-of="srcOf"
        :busy="busy"
        :sheet="sheet"
        @open="emit('openPhoto', $event)"
        @approve="emit('approvePhoto', $event)"
        @approve-all="emit('approvePhotos')"
        @reject="(photo, reason) => emit('rejectPhoto', photo, reason)"
      />

      <div v-if="review.scores.length">
        <p class="mb-2 text-xs font-medium text-adm-meta">Notas por criterio (opcionales)</p>
        <dl class="grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
          <div v-for="s in review.scores" :key="s.criterionId" class="flex items-center gap-2">
            <dt :class="['flex-1', s.active ? 'text-adm-meta' : 'text-adm-muted']">{{ s.name }}<span v-if="!s.active"> (inactivo, no cuenta)</span></dt>
            <dd><AdminReviewsMeter :score="s.score" :dim="!s.active" /></dd>
          </div>
        </dl>
      </div>
      <p v-else class="text-xs text-adm-meta">Sin notas por criterio.</p>

      <div class="space-y-1 rounded-lg border border-adm-line bg-adm-side p-3 text-xs text-adm-meta">
        <p aria-live="polite">
          <template v-if="review.itemAvg !== null">Media de lectores de la ficha: <b class="tabular-nums text-adm-fg">{{ formatAverage(review.itemAvg) }}</b> con {{ review.itemVisibleCount }} {{ review.itemVisibleCount === 1 ? 'opinión visible' : 'opiniones visibles' }}</template>
          <template v-else>La ficha no tiene opiniones visibles</template>
          <template v-if="review.avgIfToggled !== null"> · {{ hiding ? 'si la ocultas' : 'si la muestras' }} quedaría en <b class="tabular-nums text-adm-fg">{{ formatAverage(review.avgIfToggled) }}</b> con {{ review.countIfToggled }} {{ review.countIfToggled === 1 ? 'opinión' : 'opiniones' }}</template>
          <template v-else-if="hiding"> · sin ella no quedaría ninguna nota</template>.
        </p>
        <p v-if="review.itemVisibleCount < minForAverage || (review.countIfToggled < minForAverage && review.countIfToggled > 0)">El sitio solo muestra la media de lectores a partir de {{ minForAverage }} opiniones visibles.</p>
        <p v-if="review.authorCount > 1">Este lector ha escrito {{ review.authorCount }} opiniones en total.</p>
        <p v-if="review.photos.length">Las fotos no cambian la media. Si ocultas la opinión, sus fotos tampoco salen. Las fotos de lectores no entran en Medios.</p>
        <p>Es su opinión: no se edita ni el texto ni la nota. Solo puedes mostrarla u ocultarla.</p>
      </div>
    </div>

    <AdminReviewsActions v-if="!sheet" class="px-6 pb-6" :status="review.status" :busy="busy" :pending-photos="review.pendingPhotoCount" @hide="emit('hide')" @show="emit('show')" @approve="emit('approve')" @approve-photos="emit('approvePhotos')" />
    <button v-else type="button" :class="[admBtnDangerGhost, 'mt-5 w-full']" @click="emit('remove')"><Trash2 aria-hidden="true" />Borrar (solo RGPD o contenido ilegal)</button>
  </article>
</template>
