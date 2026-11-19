<script setup lang="ts">
/** Climbing shoe (README §18.14): own icon, same grid and stroke as Lucide. Decorative: always next to its name. */
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
    <path d="M2.5 18.6c0-2.6 2.2-4.2 5.4-5.1l3.8-1.1 2.6-5.4a1 1 0 0 1 .9-.6h4.5a1 1 0 0 1 1 .9l1 10.3a1 1 0 0 1-1 1.1H3.4a.9.9 0 0 1-.9-.9Z" />
    <path d="M2.8 16.8h6.4" />
    <path d="m11.3 12.4 1.5 2.7" />
    <path d="m14.7 10.9 1.5 2.7" />
  </svg>
</template>
