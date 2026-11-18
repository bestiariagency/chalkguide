<script setup lang="ts">
import { Image } from 'lucide-vue-next'
import { categoryOfReview, type AdminReview, type AdminReviewPhoto } from '~/utils/admin-reviews'

/** Rows of the inbox: author, score, item, language, chips, two lines of text. One button per row opens the detail. */
defineProps<{ reviews: readonly AdminReview[]; selectedId?: string; isNew: (review: AdminReview) => boolean; label: string; srcOf: (photo: AdminReviewPhoto) => string | undefined }>()
const emit = defineEmits<{ open: [id: string]; reviewPhotos: [id: string] }>()
</script>

<template>
  <ul class="divide-y divide-adm-line" :aria-label="label">
    <li
      v-for="r in reviews"
      :key="r.id"
      :class="['relative', selectedId === r.id && 'bg-adm-acc-soft before:absolute before:inset-y-0 before:left-0 before:w-0.5 before:bg-adm-acc']"
    >
      <button
        type="button"
        :data-review="r.id"
        :aria-current="selectedId === r.id ? 'true' : undefined"
        class="block w-full min-w-0 px-4 py-3 text-left max-md:min-h-11 focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-adm-acc"
        @click="emit('open', r.id)"
      >
        <span class="flex items-center gap-2 text-sm">
          <span class="truncate font-medium">{{ r.author }}</span>
          <AdminReviewsMeter :score="r.overall" />
          <AdminTime :iso="r.createdAt" :class="['ml-auto text-xs whitespace-nowrap', selectedId === r.id ? 'text-adm-meta' : 'text-adm-muted']" />
        </span>
        <span class="mt-0.5 flex flex-wrap items-center gap-1.5 text-xs text-adm-meta">
          <span class="max-w-full truncate">{{ r.itemName }}</span>
          <span>· {{ categoryOfReview(r.category)?.singular }}</span>
          <span class="rounded-[3px] border border-adm-line-strong px-1 font-mono text-[11px] leading-4 font-medium uppercase">{{ r.locale }}<span class="sr-only"> (idioma de la opinión)</span></span>
          <AdminStatusChip v-if="isNew(r)" status="new" />
          <AdminStatusChip v-if="r.status === 'pending'" status="pending" />
          <AdminStatusChip v-if="r.status === 'hidden'" status="hidden" label="Oculta" />
          <span v-if="r.pendingPhotoCount" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Image aria-hidden="true" />{{ r.pendingPhotoCount }} {{ r.pendingPhotoCount === 1 ? 'foto por revisar' : 'fotos por revisar' }}</span>
          <span v-else-if="r.photoCount" class="inline-flex items-center gap-1 text-adm-muted"><Image class="size-3.5" aria-hidden="true" />{{ r.photoCount }}<span class="sr-only"> {{ r.photoCount === 1 ? 'foto' : 'fotos' }}</span></span>
        </span>
        <span class="mt-1.5 line-clamp-2 block text-sm text-adm-fg">{{ r.body || 'Sin texto: solo puntuación.' }}</span>
        <span v-if="r.photos.length" class="mt-1.5 flex gap-1.5" aria-hidden="true">
          <template v-for="p in r.photos" :key="p.id">
            <img v-if="srcOf(p)" :src="srcOf(p)" alt="" width="32" height="32" loading="lazy" :class="['size-8 rounded object-cover', p.status === 'pending' && 'outline-1 outline-offset-1 outline-dashed outline-adm-warn-icon', p.status === 'rejected' && 'opacity-35']" />
            <span v-else class="size-8 rounded bg-adm-subtle" />
          </template>
        </span>
      </button>
      <button v-if="r.pendingPhotoCount" type="button" :class="[admBtnGhost, 'mx-4 mb-3 h-11 lg:hidden']" @click="emit('reviewPhotos', r.id)">Revisar {{ r.pendingPhotoCount }} {{ r.pendingPhotoCount === 1 ? 'foto' : 'fotos' }}</button>
    </li>
  </ul>
</template>
