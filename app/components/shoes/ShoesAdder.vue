<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/**
 * "Añadir un modelo": combobox over every model (brand, model, rubber; accent-insensitive, all
 * words must appear). Picking a model already in the comparison is not possible; picking one
 * with the comparison full opens the replace dialog (handled by the parent).
 */
const props = defineProps<{
  shoes: ShoeSummary[]
  selectedSlugs: string[]
  /** id of the element that describes the field (capacity hint). */
  hintId: string
}>()
const emit = defineEmits<{ pick: [shoe: ShoeSummary] }>()
const { t, locale } = useI18n()

const query = ref('')
const tokens = computed(() => searchTokens(query.value))
const combobox = ref<{ focus: () => void } | null>(null)

const options = computed(() =>
  sortShoesByName(props.shoes)
    .filter((shoe) => matchesTokens(shoeSearchFields(shoe), tokens.value))
    .map((shoe) => ({ id: shoe.slug, disabled: props.selectedSlugs.includes(shoe.slug), shoe })),
)
const count = useDebouncedValue(() => options.value.length, 400)
defineExpose({ focus: () => combobox.value?.focus() })
</script>

<template>
  <div>
    <UiCombobox
      ref="combobox"
      v-model:query="query"
      :label="t('shoes.compare.adder.label')"
      :placeholder="t('shoes.compare.adder.placeholder')"
      :options="options"
      :described-by="hintId"
      @pick="emit('pick', $event.shoe)"
    >
      <template #option="{ option }">
        <span class="flex w-full items-center justify-between gap-4" :class="option.disabled && 'text-meta'">
          <span class="min-w-0">
            <span class="block truncate text-caption text-meta">
              <UiHighlight :text="option.shoe.brand" :tokens="tokens" />
              <template v-if="option.shoe.rubber"> · <UiHighlight :text="option.shoe.rubber" :tokens="tokens" /></template>
            </span>
            <span class="block truncate font-medium" :class="!option.disabled && 'text-foreground'">
              <UiHighlight :text="option.shoe.model" :tokens="tokens" />
            </span>
          </span>
          <span class="flex shrink-0 flex-col items-end gap-1 sm:flex-row sm:items-center sm:gap-3">
            <UiBadge v-if="option.disabled">{{ t('shoes.compare.inComparison') }}</UiBadge>
            <span class="font-mono text-caption tabular-nums" :class="!option.disabled && 'text-accent'">
              {{ formatEurRange(option.shoe.priceMin, option.shoe.priceMax, locale) ?? t('common.priceUnavailable') }}
            </span>
          </span>
        </span>
      </template>
      <template #empty>
        {{ t('shoes.compare.adder.noMatch', { query: query.trim() }) }}
      </template>
    </UiCombobox>
    <p class="sr-only" aria-live="polite" aria-atomic="true">
      {{ t('shoes.compare.adder.count', count) }}
    </p>
  </div>
</template>
