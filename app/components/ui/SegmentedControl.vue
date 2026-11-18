<script setup lang="ts" generic="T extends string">
import type { SegmentOption } from '~/types/ui'

/**
 * Same look, two semantics (design system):
 *  - mode="tabs": role="tablist", ←/→ move selection; the parent renders panels with
 *    id `${idPrefix}-panel-${value}` and aria-labelledby `${idPrefix}-tab-${value}`.
 *  - mode="segmented": buttons with aria-pressed (sort order, view).
 * Disabled options keep focus (aria-disabled) so the reason can be explained.
 */

const props = withDefaults(
  defineProps<{
    options: SegmentOption<T>[]
    label: string
    mode?: 'tabs' | 'segmented'
    idPrefix?: string
  }>(),
  { mode: 'segmented', idPrefix: undefined },
)

const model = defineModel<T>({ required: true })

const autoId = useId()
const prefix = computed(() => props.idPrefix ?? autoId)
const isTabs = computed(() => props.mode === 'tabs')

const track = ref<HTMLElement | null>(null)
const buttons = ref<HTMLButtonElement[]>([])
const { style: indicatorStyle, place, animated } = useSlidingIndicator(track, () =>
  buttons.value.find((b) => b.dataset.value === model.value),
)

watch(model, () => nextTick(place))

function select(option: SegmentOption<T>) {
  if (option.disabled) return
  model.value = option.value
}

function onKeydown(event: KeyboardEvent, index: number) {
  if (!isTabs.value || (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft')) return
  event.preventDefault()
  const step = event.key === 'ArrowRight' ? 1 : -1
  const total = props.options.length
  for (let i = 1; i <= total; i++) {
    const next = props.options[(index + step * i + total * i) % total]
    if (next && !next.disabled) {
      model.value = next.value
      nextTick(() => buttons.value.find((b) => b.dataset.value === next.value)?.focus())
      return
    }
  }
}
</script>

<template>
  <div
    ref="track"
    class="relative isolate inline-grid auto-cols-fr grid-flow-col rounded-md border-[0.5px] border-line-strong bg-background p-1"
    :role="isTabs ? 'tablist' : 'group'"
    :aria-label="label"
  >
    <span
      class="absolute inset-y-1 left-0 z-0 rounded-xs border-[0.5px] border-accent bg-elevated"
      :class="animated ? 'transition-[transform,width] duration-300 ease-out motion-reduce:transition-none' : ''"
      :style="indicatorStyle"
      aria-hidden="true"
    />
    <button
      v-for="(option, i) in options"
      :id="isTabs ? `${prefix}-tab-${option.value}` : undefined"
      :key="option.value"
      ref="buttons"
      type="button"
      :data-value="option.value"
      :role="isTabs ? 'tab' : undefined"
      :aria-selected="isTabs ? option.value === model : undefined"
      :aria-controls="isTabs ? `${prefix}-panel-${option.value}` : undefined"
      :aria-pressed="isTabs ? undefined : option.value === model"
      :aria-disabled="option.disabled || undefined"
      :tabindex="isTabs ? (option.value === model ? 0 : -1) : undefined"
      class="relative z-10 min-h-11 rounded-xs px-3 py-[.4rem] text-center text-body-sm leading-tight font-medium transition-colors duration-200 ease-standard md:px-4 md:whitespace-nowrap"
      :class="
        option.disabled
          ? 'cursor-not-allowed text-muted'
          : option.value === model
            ? 'text-foreground'
            : 'text-meta hover:text-foreground'
      "
      @click="select(option)"
      @keydown="onKeydown($event, i)"
    >
      <template v-if="option.shortLabel">
        <span class="md:hidden">{{ option.shortLabel }}</span>
        <span class="max-md:hidden">{{ option.label }}</span>
      </template>
      <template v-else>{{ option.label }}</template>
    </button>
  </div>
</template>
