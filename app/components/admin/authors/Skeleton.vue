<script setup lang="ts">
/** Placeholder of the authors list (2 rows); appears only after the parent's delay (no flash). */
defineProps<{ visible: boolean }>()
</script>

<template>
  <div aria-busy="true" role="status">
    <span class="sr-only">Cargando autores…</span>
    <div v-if="visible" aria-hidden="true">
      <span class="block h-4 w-32 rounded bg-adm-subtle motion-safe:animate-pulse" />
      <span class="mt-2 block h-3 w-72 max-w-full rounded bg-adm-subtle motion-safe:animate-pulse" />
      <ul class="mt-3 divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev">
        <li v-for="w in ['w-40', 'w-28']" :key="w" class="flex h-14 items-center gap-3 px-3">
          <span class="size-4 rounded bg-adm-subtle motion-safe:animate-pulse" />
          <span class="size-10 rounded-full bg-adm-subtle motion-safe:animate-pulse" />
          <span :class="['h-3 rounded bg-adm-subtle motion-safe:animate-pulse', w]" />
          <span class="ml-auto h-3 w-16 rounded bg-adm-subtle motion-safe:animate-pulse" />
        </li>
      </ul>
    </div>
  </div>
</template>
