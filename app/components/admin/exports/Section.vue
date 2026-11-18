<script setup lang="ts">
/** One row of the export modal: label on the left (96 px), content on the right; stacked under 768. */
defineProps<{ label: string; labelId?: string }>()
</script>

<template>
  <section class="grid gap-2 border-t border-adm-line py-4 first:border-t-0 first:pt-0 md:grid-cols-[96px_1fr] md:gap-4" :aria-labelledby="labelId">
    <h3 :id="labelId" :class="[admGroupLabel, 'pt-1.5']">{{ label }}</h3>
    <div class="min-w-0 space-y-3"><slot /></div>
  </section>
</template>
