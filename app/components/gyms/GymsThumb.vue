<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/** Decorative gym thumbnail (the name sits next to it): 112x84 from md, 72 px square below. */
defineProps<{ media: MediaRef | null }>()
</script>

<template>
  <div
    aria-hidden="true"
    class="relative size-18 shrink-0 overflow-hidden rounded-xs md:h-21 md:w-28"
  >
    <UiPhoto :media="media" sizes="112px" class="size-full" />
  </div>
</template>
