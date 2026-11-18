<script setup lang="ts">
import { Image as ImageIcon, X } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'

/** Cover inside the canvas (16:9). Change/remove show on hover, focus and always on touch. */
defineProps<{ media: AdminMedia | null; readonly?: boolean }>()
defineEmits<{ change: []; remove: [] }>()
const mediaUrl = useMediaUrl()
</script>

<template>
  <figure class="group">
    <div class="relative">
      <div v-if="media" class="aspect-[16/9] overflow-hidden rounded-lg bg-adm-subtle" :style="{ backgroundColor: media.dominant_color ?? undefined }">
        <NuxtImg :src="mediaUrl(media.storage_path)" :alt="media.alt_es ?? ''" width="760" height="428" class="size-full object-cover" />
      </div>
      <button
        v-else
        type="button"
        :disabled="readonly"
        class="flex aspect-[16/9] w-full flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-adm-line-strong bg-adm-subtle text-sm text-adm-meta hover:border-adm-control hover:text-adm-fg disabled:cursor-not-allowed max-md:min-h-44"
        @click="$emit('change')"
      >
        <ImageIcon class="size-6" aria-hidden="true" />Añadir portada
      </button>
      <div v-if="media && !readonly" class="absolute inset-x-3 bottom-3 flex gap-1.5 opacity-0 transition-opacity motion-reduce:transition-none group-focus-within:opacity-100 group-hover:opacity-100 [@media(pointer:coarse)]:opacity-100">
        <button type="button" :class="admBtnGhost" @click="$emit('change')"><ImageIcon aria-hidden="true" />Cambiar</button>
        <button type="button" :class="admBtnGhost" @click="$emit('remove')"><X aria-hidden="true" />Quitar</button>
      </div>
    </div>
    <figcaption v-if="media" class="mt-2 text-xs text-adm-meta">
      <span v-if="media.alt_es">Alt ES: {{ media.alt_es }}</span>
      <span v-else class="text-adm-warn">Esta imagen no tiene texto alternativo. Añádelo en la biblioteca de medios.</span>
    </figcaption>
  </figure>
</template>
