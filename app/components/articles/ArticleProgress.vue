<script setup lang="ts">
/** Reading progress: 2 px fixed bar at the top, below 1100 px only (the rail shows "Quedan N min" from there). */
defineProps<{ progress: number }>()
</script>

<template>
  <div class="pointer-events-none fixed inset-x-0 top-0 z-[60] h-0.5 min-[1100px]:hidden" aria-hidden="true">
    <i class="block size-full origin-left bg-chalk" :style="{ transform: `scaleX(${progress})` }" />
  </div>
</template>
