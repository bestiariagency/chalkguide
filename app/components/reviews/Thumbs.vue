<script setup lang="ts">
/**
 * Photo thumbnails of a review (72 px, 88 from md). Each one is a button that opens the viewer.
 * `plain` = own photos, which may be signed/blob URLs that the image optimizer cannot fetch.
 */
export interface ThumbPhoto {
  id: string
  src: string
}
defineProps<{ photos: readonly ThumbPhoto[]; label: (n: number, total: number) => string; plain?: boolean }>()
const emit = defineEmits<{ open: [index: number, event: Event] }>()
</script>

<template>
  <ul v-if="photos.length" class="flex gap-2">
    <li v-for="(photo, index) in photos" :key="photo.id">
      <button
        type="button"
        class="group/t relative block size-18 overflow-hidden rounded-md bg-elevated md:size-22"
        :aria-label="label(index + 1, photos.length)"
        @click="emit('open', index, $event)"
      >
        <img
          v-if="plain"
          :src="photo.src"
          alt=""
          width="88"
          height="88"
          loading="lazy"
          class="size-full object-cover transition-transform duration-200 ease-standard group-hover/t:scale-[1.04] motion-reduce:transition-none"
        />
        <NuxtImg
          v-else
          :src="photo.src"
          alt=""
          width="88"
          height="88"
          densities="x1 x2"
          fit="cover"
          loading="lazy"
          class="size-full object-cover transition-transform duration-200 ease-standard group-hover/t:scale-[1.04] motion-reduce:transition-none"
        />
        <span class="pointer-events-none absolute inset-0 rounded-md shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.12)]" aria-hidden="true" />
      </button>
    </li>
  </ul>
</template>
