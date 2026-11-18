<script setup lang="ts">
/** Shape of the page editor (header, sheet and inspector) while it loads. */
const bar = 'block rounded bg-adm-subtle motion-safe:animate-pulse'
const lines = ['w-11/12', 'w-10/12', 'w-9/12', 'w-8/12', 'w-7/12', 'w-6/12', 'w-5/12']
/** Appears after 300 ms so fast loads do not flash. */
const shown = useDelayedFlag(true, 300)
</script>

<template>
  <div aria-busy="true" role="status">
    <span class="sr-only">Cargando la página…</span>
    <div v-if="shown" aria-hidden="true">
      <div class="flex h-12 items-center gap-3 border-b border-adm-line px-4"><span :class="[bar, 'size-8']" /><span :class="[bar, 'h-3 w-40']" /><span :class="[bar, 'h-5 w-20']" /><span :class="[bar, 'ml-auto h-8 w-32']" /></div>
      <div class="flex">
        <div class="mx-auto max-w-[760px] flex-1 space-y-4 px-8 pt-10">
          <span :class="[bar, 'h-3 w-28']" /><span :class="[bar, 'h-8 w-1/2']" /><span :class="[bar, 'h-3 w-64']" />
          <div class="space-y-3 pt-6"><span v-for="w in lines" :key="w" :class="[bar, 'h-3', w]" /></div>
        </div>
        <div class="hidden h-[80vh] w-[340px] space-y-4 border-l border-adm-line bg-adm-side p-4 xl:block">
          <template v-for="n in 5" :key="n"><span :class="[bar, 'h-4 w-2/3']" /><span :class="[bar, 'h-8 w-full']" /></template>
        </div>
      </div>
    </div>
  </div>
</template>
