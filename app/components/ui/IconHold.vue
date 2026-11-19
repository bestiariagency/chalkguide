<script setup lang="ts">
/** Climbing hold with its bolt hole (README §18.14): own icon, same grid and stroke as Lucide. Decorative: always next to its name. */
withDefaults(defineProps<{ size?: number | string; strokeWidth?: number | string }>(), { size: 24, strokeWidth: 1.75 })
</script>

<template>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    :width="size"
    :height="size"
    fill="none"
    stroke="currentColor"
    :stroke-width="strokeWidth"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
    focusable="false"
  >
    <path d="M5.2 16.2c-1.8-2.4-1.6-5.9.6-8.2C7.6 6 10.4 4.7 13.3 5.1c2.4.3 3.6 1.9 5.2 2.6 1.7.8 2.3 2.6 1.6 4.4-.6 1.5-1.9 2.2-2.4 3.7-.6 1.9-1.9 3.6-4.3 3.9-3.3.4-6.4-1.1-8.2-3.5Z" />
    <circle cx="11.4" cy="11.6" r="1.75" />
  </svg>
</template>
