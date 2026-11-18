<script setup lang="ts">
/** Row-shaped placeholder while the criteria load; appears only after the parent's delay (no flash). */
defineProps<{ visible: boolean }>()
</script>

<template>
  <div aria-busy="true" role="status" class="grid grid-cols-[minmax(0,1fr)] gap-6 xl:grid-cols-[minmax(0,1fr)_400px]">
    <span class="sr-only">Cargando criterios…</span>
    <div v-if="visible" class="min-w-0" aria-hidden="true">
      <h2 class="mb-3 text-sm font-semibold">Orden al puntuar y en la ficha</h2>
      <ul :class="[admCard, 'divide-y divide-adm-line']">
        <li v-for="n in 7" :key="n" class="flex h-12 items-center gap-3 px-3">
          <span class="size-4 flex-none rounded bg-adm-subtle motion-safe:animate-pulse" />
          <span class="h-3 rounded bg-adm-subtle motion-safe:animate-pulse" :style="{ width: `${28 + ((n * 13) % 26)}%` }" />
          <span class="ml-auto hidden h-5 w-24 rounded bg-adm-subtle motion-safe:animate-pulse sm:block" />
        </li>
      </ul>
    </div>
    <div v-if="visible" :class="[admCard, 'hidden space-y-3 p-4 xl:block']" aria-hidden="true">
      <span class="block h-4 w-32 rounded bg-adm-subtle motion-safe:animate-pulse" />
      <span class="block h-3 w-full rounded bg-adm-subtle motion-safe:animate-pulse" />
      <span class="block h-3 w-3/5 rounded bg-adm-subtle motion-safe:animate-pulse" />
    </div>
  </div>
</template>
