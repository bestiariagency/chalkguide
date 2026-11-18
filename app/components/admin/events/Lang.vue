<script setup lang="ts">
/** ES / EN pair like every other list: ES always (the Spanish title is required), EN solid with an English title (it shows in /en), dashed without. */
defineProps<{ has: boolean }>()
</script>

<template>
  <span class="inline-flex items-center gap-1 text-xs font-medium">
    <span class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">ES</span>
    <span v-if="has" class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg" title="Con título en inglés: sale en /en">EN<span class="sr-only"> (con título en inglés)</span></span>
    <span v-else class="rounded px-1 py-0.5 text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong" title="Sin título en inglés: no sale en /en">EN<span class="sr-only"> (falta el título en inglés: no sale en /en)</span></span>
  </span>
</template>
