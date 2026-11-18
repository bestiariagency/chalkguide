<script setup lang="ts">
/** Row-shaped placeholder while the categories load; appears only after the parent's delay (no flash). */
defineProps<{ visible: boolean }>()
</script>

<template>
  <div aria-busy="true" role="status">
    <span class="sr-only">Cargando categorías…</span>
    <ul v-if="visible" class="max-w-2xl divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev" aria-hidden="true">
      <li v-for="n in 5" :key="n" class="flex min-h-12 items-center gap-3 px-3 py-2">
        <span class="size-8 flex-none rounded bg-adm-subtle motion-safe:animate-pulse" />
        <span class="size-2.5 flex-none rounded-full bg-adm-subtle motion-safe:animate-pulse" />
        <span class="flex-1 space-y-1.5">
          <span class="block h-3 w-1/3 rounded bg-adm-subtle motion-safe:animate-pulse" />
          <span class="block h-2.5 w-1/2 rounded bg-adm-subtle motion-safe:animate-pulse" />
        </span>
      </li>
    </ul>
  </div>
</template>
