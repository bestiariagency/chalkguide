<script setup lang="ts">
/** Loading placeholder of the settings sections (shown after a short delay by the page). */
defineProps<{ visible: boolean }>()
</script>

<template>
  <div class="space-y-10" role="status" aria-label="Cargando ajustes" :aria-busy="true">
    <div v-for="n in 3" :key="n" :class="['space-y-3 motion-safe:animate-pulse', visible ? '' : 'invisible']">
      <div class="h-5 w-40 rounded bg-adm-subtle" />
      <div class="h-8 w-full rounded bg-adm-subtle sm:w-1/2" />
      <div class="grid gap-4 lg:grid-cols-2"><div class="h-8 rounded bg-adm-subtle" /><div class="h-8 rounded bg-adm-subtle" /></div>
    </div>
  </div>
</template>
