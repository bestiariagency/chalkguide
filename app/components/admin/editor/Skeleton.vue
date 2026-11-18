<script setup lang="ts">
/** Editor placeholder with the real shape: header bar, title and body column, inspector at xl. */
withDefaults(defineProps<{ label?: string }>(), { label: 'Cargando el artículo…' })
/** Appears after 300 ms so fast loads do not flash. */
const shown = useDelayedFlag(true, 300)
</script>

<template>
  <div role="status" aria-busy="true">
    <span class="sr-only">{{ label }}</span>
    <div v-if="shown" aria-hidden="true">
      <div class="flex h-12 items-center gap-3 border-b border-adm-line px-4 md:px-6">
        <span class="h-3 w-40 rounded bg-adm-subtle motion-safe:animate-pulse" />
        <span class="ml-auto h-8 w-24 rounded-md bg-adm-subtle motion-safe:animate-pulse" />
        <span class="hidden h-8 w-32 rounded-md bg-adm-subtle motion-safe:animate-pulse md:block" />
      </div>
      <div class="flex items-start">
        <div class="min-w-0 flex-1 px-4 py-10 md:px-6">
          <div class="mx-auto max-w-[720px] space-y-4">
            <span class="block h-10 w-3/4 rounded bg-adm-subtle motion-safe:animate-pulse" />
            <span class="block h-4 w-1/2 rounded bg-adm-subtle motion-safe:animate-pulse" />
            <span class="mt-6 block aspect-[16/7] w-full rounded-lg bg-adm-subtle motion-safe:animate-pulse" />
            <span v-for="(w, i) in ['w-full', 'w-11/12', 'w-full', 'w-4/5', 'w-full', 'w-2/3']" :key="i" :class="['block h-3.5 rounded bg-adm-subtle motion-safe:animate-pulse', w]" />
          </div>
        </div>
        <div class="hidden h-[calc(100dvh-3rem)] w-[340px] flex-none space-y-4 border-l border-adm-line bg-adm-side p-4 xl:block">
          <span v-for="n in 5" :key="n" class="block h-9 rounded-md bg-adm-subtle motion-safe:animate-pulse" />
        </div>
      </div>
    </div>
  </div>
</template>
