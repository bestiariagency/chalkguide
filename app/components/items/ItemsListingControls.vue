<script setup lang="ts" generic="F extends string, S extends string">
import { SlidersHorizontal } from 'lucide-vue-next'
import type { SegmentOption } from '~/types/ui'

/**
 * Listing controls shared by gyms and resolers (README §9.6): search + sort row, filter chips
 * (desktop) or a "Filtros (n)" sheet (below lg), result counter and "clear filters". The
 * counter is announced in a separate polite region after 400 ms so each key is not read out.
 * State lives in the URL (the parent owns it).
 */
const props = defineProps<{
  /** Prefix for the ids of the chip groups. */
  idPrefix: string
  filterKeys: readonly F[]
  /** Translated label of a filter chip. */
  filterLabel: (key: F) => string
  active: F[]
  sortKey: S
  sortOptions: SegmentOption<S>[]
  /** Results shown, and every item of the listing. */
  count: number
  total: number
  /** Singular / plural noun of the listing ("rocódromo" / "rocódromos"). */
  nounOne: string
  nounMany: string
  placeholder: string
}>()
const query = defineModel<string>('query', { required: true })
const emit = defineEmits<{ toggle: [key: F]; sort: [key: S]; clear: [] }>()
const { t } = useI18n()

const sheetOpen = ref(false)
const noun = (count: number) => (count === 1 ? props.nounOne : props.nounMany)
const text = computed(() => query.value.trim())
const summary = computed(() =>
  text.value
    ? t('common.search.countQuery', {
        count: props.count,
        total: props.total,
        noun: props.nounMany,
        query: text.value,
      })
    : t('common.results', props.count),
)
const announce = useDebouncedValue(summary, 400)
</script>

<template>
  <div>
    <div class="flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between lg:gap-8">
      <UiSearchField
        v-model="query"
        shortcut
        :label="t('common.search.label')"
        :clear-label="t('common.search.clear')"
        :placeholder="placeholder"
        class="w-full lg:max-w-[420px]"
      />
      <button
        type="button"
        class="flex min-h-12 items-center justify-between rounded-md border border-control px-4 hover:bg-elevated lg:hidden"
        aria-haspopup="dialog"
        @click="sheetOpen = true"
      >
        <span class="flex items-center gap-2">
          <SlidersHorizontal :size="16" aria-hidden="true" />
          {{ t('common.filters') }}
          <span v-if="active.length" class="font-mono text-caption text-meta">({{ active.length }})</span>
        </span>
      </button>
      <div class="lg:shrink-0">
        <p class="label-mini mb-3">{{ t('common.sortBy') }}</p>
        <UiSegmentedControl
          :model-value="sortKey"
          :label="t('common.sortBy')"
          :options="sortOptions"
          class="w-full lg:w-auto"
          @update:model-value="emit('sort', $event)"
        />
      </div>
    </div>

    <ItemsFilterChips
      class="mt-6 hidden lg:block"
      :label-id="`${idPrefix}-filters-label`"
      :label="t('common.filters')"
      :filter-keys="filterKeys"
      :filter-label="filterLabel"
      :active="active"
      @toggle="emit('toggle', $event)"
    />

    <p class="mt-6 flex flex-wrap items-center gap-x-4 text-caption text-meta">
      <span class="text-foreground" aria-hidden="true">{{ summary }}</span>
      <UiButton v-if="active.length" variant="inline" class="min-h-11" @click="emit('clear')">
        {{ t('common.clearFiltersCount', { count: active.length }) }}
      </UiButton>
    </p>
    <p class="sr-only" aria-live="polite" aria-atomic="true">{{ announce }}</p>

    <UiSheet v-model:open="sheetOpen" :title="t('common.filters')" :close-label="t('common.search.closeFilters')">
      <ItemsFilterChips
        :label-id="`${idPrefix}-sheet-filters-label`"
        :label="t('common.filters')"
        hide-label
        :filter-keys="filterKeys"
        :filter-label="filterLabel"
        :active="active"
        @toggle="emit('toggle', $event)"
      />
      <div class="mt-6 flex flex-col gap-3">
        <UiButton v-if="active.length" variant="ghost" @click="emit('clear')">
          {{ t('common.clearFiltersCount', { count: active.length }) }}
        </UiButton>
        <UiButton @click="sheetOpen = false">
          {{ count ? t('common.search.see', { count, noun: noun(count) }) : t('common.search.none') }}
        </UiButton>
      </div>
    </UiSheet>
  </div>
</template>
