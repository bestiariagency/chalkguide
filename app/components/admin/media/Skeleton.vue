<script setup lang="ts">
/** Grid-shaped placeholder while the library loads; appears only after the parent's delay (no flash). */
defineProps<{ visible: boolean }>()
</script>

<template>
  <div aria-busy="true" role="status">
    <span class="sr-only">Cargando medios…</span>
    <ul v-if="visible" class="grid grid-cols-2 gap-3 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6" aria-hidden="true">
      <li v-for="n in 12" :key="n">
        <span class="block aspect-[4/3] rounded-lg bg-adm-subtle motion-safe:animate-pulse" />
        <span class="mt-2 block h-3 w-2/3 rounded bg-adm-subtle motion-safe:animate-pulse" />
      </li>
    </ul>
  </div>
</template>
