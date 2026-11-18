<script setup lang="ts">
/** Loading skeleton with the real shape (README §16.6): flat, no shimmer. */
const block = 'block rounded bg-adm-subtle'
/** Appears after 300 ms so fast loads do not flash. */
const shown = useDelayedFlag(true, 300)
</script>

<template>
  <div role="status" aria-busy="true" aria-label="Cargando las estadísticas">
    <div v-if="shown" class="space-y-6" aria-hidden="true">
    <div :class="[block, 'h-26 rounded-lg']" />
    <div :class="[admCard, 'overflow-hidden']">
      <div class="flex h-11 items-center border-b border-adm-line px-4"><span :class="[block, 'h-3 w-24']" /></div>
      <div class="space-y-4 p-4"><span :class="[block, 'h-44']" /><span :class="[block, 'h-35']" /></div>
    </div>
    <div class="grid gap-6 lg:grid-cols-2">
      <div v-for="n in 4" :key="n" :class="[admCard, 'overflow-hidden']">
        <div class="flex h-11 items-center border-b border-adm-line px-4"><span :class="[block, 'h-3 w-28']" /></div>
        <div class="p-4"><span :class="[block, 'h-42']" /></div>
      </div>
    </div>
    </div>
  </div>
</template>
