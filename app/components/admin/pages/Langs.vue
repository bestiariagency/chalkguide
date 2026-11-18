<script setup lang="ts">
/** ES / EN pair of the list: EN is dashed (pending) while the page has no English version. */
defineProps<{ hasEn: boolean }>()
</script>

<template>
  <span class="inline-flex items-center gap-1 text-xs font-medium">
    <span class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">ES</span>
    <span v-if="hasEn" class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">EN</span>
    <span v-else class="rounded px-1 py-0.5 text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong" title="Sin versión en inglés">EN<span class="sr-only"> pendiente</span></span>
  </span>
</template>
