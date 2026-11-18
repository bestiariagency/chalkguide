<script setup lang="ts">
import { ChevronDown, SlidersHorizontal } from 'lucide-vue-next'

/**
 * Comparator filters: a sidebar panel from lg, a disclosure below. Lists and "used by me" are
 * written to the URL by the parent; the max price is a v-model (debounced upstream).
 */
const props = defineProps<{
  filters: ShoeFilters
  options: ShoeFilterOptions
  counts: Record<ShoeListKey, Record<string, number>>
  bounds: { min: number; max: number }
  activeCount: number
}>()
const range = defineModel<[number, number]>('range', { required: true })
const query = defineModel<string>('query', { required: true })
const emit = defineEmits<{
  list: [key: ShoeListKey, values: string[]]
  owned: [value: boolean]
  clear: []
}>()
const { t, locale } = useI18n()

const open = ref(false)
const panelId = useId()
const groups: { key: ShoeListKey; legend: string; prefix: string }[] = [
  { key: 'level', legend: 'shoes.filters.level', prefix: 'shoes.level' },
  { key: 'profile', legend: 'shoes.filters.profile', prefix: 'shoes.profile' },
  { key: 'closure', legend: 'shoes.filters.closure', prefix: 'shoes.closure' },
  { key: 'stiffness', legend: 'shoes.filters.stiffness', prefix: 'shoes.stiffnessGroup' },
  { key: 'use', legend: 'shoes.filters.use', prefix: 'shoes.use' },
]
const maxText = computed(() => formatEur(range.value[1], locale.value) ?? '')
const onMax = (event: Event) => {
  const value = Number((event.target as HTMLInputElement).value)
  range.value = [range.value[0], Math.max(value, range.value[0])]
}
</script>

<template>
  <aside
    aria-labelledby="shoes-filters-title"
    class="lg:self-start lg:rounded-lg lg:border-[0.5px] lg:border-line-strong lg:bg-board lg:p-5"
  >
    <h2 id="shoes-filters-title" class="sr-only">{{ t('common.filters') }}</h2>
    <UiSearchField
      v-model="query"
      shortcut
      class="mb-5 lg:mb-0"
      :label="t('common.search.label')"
      :clear-label="t('common.search.clear')"
      :placeholder="t('shoes.search.placeholder')"
    />
    <button
      type="button"
      class="flex min-h-12 w-full items-center justify-between rounded-md border border-control px-4 lg:hidden"
      :aria-expanded="open"
      :aria-controls="panelId"
      @click="open = !open"
    >
      <span class="flex items-center gap-2">
        <SlidersHorizontal :size="16" aria-hidden="true" />
        {{ t('common.filters') }}
        <span v-if="activeCount" class="font-mono text-caption text-meta">({{ activeCount }})</span>
      </span>
      <ChevronDown
        :size="20"
        aria-hidden="true"
        class="transition-transform duration-200"
        :class="open && 'rotate-180'"
      />
    </button>

    <div :id="panelId" class="space-y-6 pt-6 lg:block" :class="open ? 'block' : 'hidden'">
      <ShoesChipGroup
        v-for="group in groups"
        :key="group.key"
        :legend="t(group.legend)"
        :options="props.options[group.key]"
        :label-prefix="group.prefix"
        :counts="props.counts[group.key]"
        :selected="props.filters[group.key]"
        @change="emit('list', group.key, $event)"
      />
      <div v-if="bounds.max > bounds.min">
        <div class="flex items-baseline justify-between gap-3">
          <label :for="`${panelId}-max`" class="label-mini">{{ t('shoes.filters.priceMax') }}</label>
          <output :for="`${panelId}-max`" class="font-mono text-data text-foreground tabular-nums">{{ maxText }}</output>
        </div>
        <input
          :id="`${panelId}-max`"
          type="range"
          :min="bounds.min"
          :max="bounds.max"
          :step="PRICE_STEP"
          :value="range[1]"
          :aria-valuetext="maxText"
          class="mt-1 h-11 w-full cursor-pointer accent-accent-fill focus-visible:ring-focus"
          @input="onMax"
        />
      </div>
      <div class="flex items-center justify-between gap-3 border-t-[0.5px] border-line pt-5">
        <span :id="`${panelId}-owned`">
          <span class="block font-hand text-hand leading-tight text-accent">{{ t('common.usedByMe') }}</span>
          <span class="block text-note text-meta">{{ t('shoes.filters.testedOnly') }}</span>
        </span>
        <button
          type="button"
          role="switch"
          :aria-checked="filters.owned"
          :aria-labelledby="`${panelId}-owned`"
          class="relative h-11 w-14 shrink-0 rounded-full focus-visible:ring-focus"
          @click="emit('owned', !filters.owned)"
        >
          <span
            class="absolute top-1/2 left-0 h-6 w-11 -translate-y-1/2 rounded-full border border-control transition-colors duration-200"
            :class="filters.owned ? 'border-accent-fill bg-accent-fill' : 'bg-elevated'"
          />
          <span
            class="absolute top-1/2 left-0.5 size-5 -translate-y-1/2 rounded-full bg-board shadow-sm transition-transform duration-200 motion-reduce:transition-none"
            :class="filters.owned ? 'translate-x-5' : 'translate-x-0.5'"
          />
        </button>
      </div>
      <UiButton v-if="activeCount" variant="inline" class="min-h-11" @click="emit('clear')">
        {{ t('common.clearFilters') }}
      </UiButton>
    </div>
  </aside>
</template>
