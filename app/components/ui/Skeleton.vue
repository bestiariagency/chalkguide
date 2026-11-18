<script setup lang="ts">
/**
 * Placeholder with the final component's shape (CLS 0). Size it with classes (h-3 w-24…).
 * The loading container carries aria-busy="true"; static block with reduced motion.
 */
defineProps<{ circle?: boolean }>()
</script>

<template>
  <div
    aria-hidden="true"
    class="animate-skeleton bg-[linear-gradient(90deg,var(--color-board)_0%,var(--color-elevated)_50%,var(--color-board)_100%)] bg-size-[200%_100%] motion-reduce:animate-none motion-reduce:bg-elevated motion-reduce:bg-none"
    :class="circle ? 'rounded-full' : 'rounded-xs'"
  />
</template>
