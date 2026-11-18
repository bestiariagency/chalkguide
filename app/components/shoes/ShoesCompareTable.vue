<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Side-by-side table from lg (README §9.9.1): attribute column + up to 3 equal columns, header
 * stuck under the compact bar (top-14). No overflow container, so `sticky` works and the page
 * never scrolls sideways. The free slot is a dashed "add" column that focuses the adder.
 */
const props = defineProps<{ shoes: ShoeSummary[]; flashSlug: string | null }>()
const emit = defineEmits<{ remove: [shoe: ShoeSummary]; add: [] }>()
const { t } = useI18n()

const freeSlot = computed(() => props.shoes.length < MAX_COMPARE)
const flash = (slug: string) => props.flashSlug === slug && 'animate-flash motion-reduce:animate-none'
const sentinel = ref<HTMLElement | null>(null)
const STICKY_TOP_PX = 56 // = compact bar height (h-14)
const stuck = useStuck(sentinel, STICKY_TOP_PX)
// Once stuck, the cell paints the 56 px strip above it (the bar is hidden there, the dock floats over it).
const headCell = computed(() => [
  'sticky top-14 z-10 bg-elevated px-3 py-3 text-left align-bottom font-normal',
  stuck.value && 'before:absolute before:inset-x-0 before:bottom-full before:h-14 before:bg-elevated',
])
</script>

<template>
  <div class="hidden lg:block">
  <div ref="sentinel" class="h-px" aria-hidden="true" />
  <table class="w-full table-fixed text-left text-body-sm tabular-nums">
    <caption class="sr-only">
      {{ t('shoes.compare.caption', shoes.length) }}
    </caption>
    <colgroup>
      <col class="w-40" />
      <col v-for="shoe in shoes" :key="shoe.id" />
      <col v-if="freeSlot" />
    </colgroup>
    <thead>
      <tr>
        <th scope="col" :class="[headCell, 'label-mini']">{{ t('shoes.columns.model') }}</th>
        <th v-for="shoe in shoes" :key="shoe.id" scope="col" :class="[headCell, flash(shoe.slug)]">
          <ShoesPhotoTile :media="shoe.cover" :brand="shoe.brand" :model="shoe.model" sizes="320px" class="mb-3 h-28 w-full" />
          <span class="block text-caption text-meta">{{ shoe.brand }}</span>
          <span class="block text-lg leading-tight font-medium">{{ shoe.model }}</span>
          <button
            type="button"
            class="relative inline-flex min-h-11 items-center gap-1 text-note text-meta underline underline-offset-2 hover:text-foreground"
            :aria-label="t('shoes.compare.removeNamed', { name: shoe.model })"
            @click="emit('remove', shoe)"
          >
            <X :size="14" aria-hidden="true" />{{ t('common.remove') }}
          </button>
        </th>
        <th v-if="freeSlot" scope="col" :class="headCell">
          <button
            type="button"
            class="flex min-h-16 w-full flex-col items-center justify-center gap-0.5 rounded-md border border-dashed border-control px-2 text-body-sm font-medium text-meta hover:border-meta hover:text-foreground"
            @click="emit('add')"
          >
            <span class="inline-flex items-center gap-1.5"><Plus :size="16" aria-hidden="true" />{{ t('shoes.compare.addModel') }}</span>
            <span class="font-mono text-note font-normal">{{ t('shoes.compare.slot', { n: shoes.length + 1, max: MAX_COMPARE }) }}</span>
          </button>
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="row in COMPARE_FIELDS" :key="row.key" class="border-b-[0.5px] border-line">
        <th scope="row" class="px-4 py-3 text-left align-top font-normal text-meta">
          {{ t(`shoes.rows.${row.key}`) }}
        </th>
        <td v-for="shoe in shoes" :key="shoe.id" class="px-3 py-3 align-top" :class="flash(shoe.slug)">
          <ShoesCompareCell :shoe="shoe" :field="row.key" />
        </td>
        <td
          v-if="freeSlot"
          class="bg-[repeating-linear-gradient(135deg,transparent_0_6px,var(--color-line)_6px_7px)] opacity-60"
          aria-hidden="true"
        />
      </tr>
    </tbody>
  </table>
  </div>
</template>
