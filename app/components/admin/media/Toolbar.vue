<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import type { MediaCounts, MediaFilter } from '~/utils/admin-media-library'

/** Search (name, alt, caption, credit) and filter segments with counters. */
defineProps<{ counts?: MediaCounts }>()
const search = defineModel<string>('search', { default: '' })
const filter = defineModel<MediaFilter>('filter', { required: true })
const id = `q-${useId()}`

const segments = [
  { key: 'all', label: 'Todas' },
  { key: 'missing_alt', label: 'Sin alt' },
  { key: 'missing_en', label: 'Sin inglés' },
  { key: 'unused', label: 'Sin usar' },
  { key: 'in_use', label: 'En uso' },
] as const
const count = (key: MediaFilter, counts?: MediaCounts) =>
  counts ? { all: counts.total, missing_alt: counts.missingAlt, missing_en: counts.missingEn, unused: counts.unused, in_use: counts.inUse }[key] : undefined
</script>

<template>
  <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
    <div class="relative w-full sm:w-72">
      <label :for="id" class="sr-only">Buscar medios</label>
      <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted max-md:hidden" aria-hidden="true" />
      <input :id="id" v-model="search" type="search" placeholder="Buscar por nombre, alt, pie o crédito" :class="[admInput, 'md:pl-8']" />
    </div>
    <div class="flex max-w-full overflow-x-auto rounded-md border border-adm-line-strong bg-adm-elev p-0.5" role="group" aria-label="Filtro">
      <button
        v-for="s in segments"
        :key="s.key"
        type="button"
        :aria-pressed="filter === s.key"
        class="inline-flex h-7 items-center gap-1.5 rounded px-2.5 text-[13px] whitespace-nowrap text-adm-meta hover:text-adm-fg aria-pressed:bg-adm-subtle aria-pressed:font-medium aria-pressed:text-adm-fg max-md:h-11 max-md:px-3"
        @click="filter = s.key"
      >
        {{ s.label }}
        <span v-if="count(s.key, counts) !== undefined" :class="['tabular-nums', s.key === 'missing_alt' && count(s.key, counts) ? 'text-adm-warn' : 'opacity-70']">{{ count(s.key, counts) }}</span>
      </button>
    </div>
  </div>
</template>
