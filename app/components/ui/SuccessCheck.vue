<script setup lang="ts">
/** Success tick drawn once on mount (`.success-check` in main.css). Decorative; pair it with text. */
withDefaults(defineProps<{ size?: number }>(), { size: 56 })
</script>

<template>
  <svg class="success-check text-success-text" :width="size" :height="size" viewBox="0 0 56 56" aria-hidden="true">
    <circle cx="28" cy="28" r="24" fill="none" stroke="currentColor" stroke-width="2.5" />
    <path
      d="M17 29l7 7 15-16"
      fill="none"
      stroke="currentColor"
      stroke-width="3"
      stroke-linecap="round"
      stroke-linejoin="round"
    />
  </svg>
</template>
