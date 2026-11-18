<script setup lang="ts">
/** Placeholder of the pages list (five rows) while it loads. */
const widths = ['w-1/5', 'w-1/4', 'w-1/3', 'w-2/5', 'w-1/2']
/** Appears after 300 ms so fast loads do not flash. */
const shown = useDelayedFlag(true, 300)
</script>

<template>
  <div aria-busy="true" role="status">
    <span class="sr-only">Cargando páginas…</span>
    <div v-if="shown" class="mt-4 border-t border-adm-line" aria-hidden="true">
      <div class="h-9 bg-adm-side" />
      <div v-for="w in widths" :key="w" class="flex h-14 items-center gap-4 border-b border-adm-line px-4 md:px-6">
        <span class="flex-1 space-y-2"><span :class="['block h-3 rounded bg-adm-subtle motion-safe:animate-pulse', w]" /><span class="block h-2.5 w-32 rounded bg-adm-subtle motion-safe:animate-pulse" /></span>
        <span class="h-5 w-24 rounded bg-adm-subtle motion-safe:animate-pulse" />
        <span class="hidden h-4 w-14 rounded bg-adm-subtle motion-safe:animate-pulse md:block" />
      </div>
    </div>
  </div>
</template>
