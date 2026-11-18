<script setup lang="ts">
/** `EN` mark: solid when the item has title and summary in English, dashed when it does not (it stays out of /en/news). */
defineProps<{ has: boolean }>()
</script>

<template>
  <span :class="['rounded px-1 py-0.5 text-xs font-medium', has ? 'bg-adm-subtle text-adm-fg' : 'text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong']">EN<span class="sr-only">{{ has ? ': con versión en inglés' : ': sin versión en inglés' }}</span></span>
</template>
