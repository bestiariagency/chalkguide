<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/** Cover (eager) + thumbnails. The page only renders it when there is real media. */
defineProps<{ cover: MediaRef | null; gallery: MediaRef[] }>()
</script>

<template>
  <div>
    <UiPhoto :media="cover ?? gallery[0] ?? null" eager class="aspect-[16/9] rounded-lg" />
    <ul v-if="gallery.length > 1" class="mt-3 grid grid-cols-3 gap-3">
      <li v-for="media in gallery.slice(1, 4)" :key="media.path">
        <UiPhoto :media="media" sizes="33vw md:22vw" class="aspect-[4/3] rounded-md" />
      </li>
    </ul>
  </div>
</template>
