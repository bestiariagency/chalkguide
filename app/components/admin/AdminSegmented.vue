<script setup lang="ts" generic="V extends string | number | boolean | null">
import { RadioGroupItem, RadioGroupRoot } from 'reka-ui'

/**
 * Segmented single choice (radio group: Tab enters once, arrows move). `null` is a valid value
 * ("No lo sé", "Sin nota"). An option with `unavailable` (the reason) is dimmed, keeps focus and cannot be picked. `stacked` shows the sub-label under the label (1–5 scales). `fill` only applies to the
 * inline layout: with `stacked` (fixed 5-column grid) it is ignored.
 */
const props = defineProps<{
  /** `dot`: amber marker (e.g. EN incomplete) with `dotLabel` for screen readers. */
  options: readonly { value: V; label: string; sub?: string; dot?: boolean; dotLabel?: string; unavailable?: string }[]
  /** Id of the element that names the group. */
  labelledby?: string
  label?: string
  stacked?: boolean
  disabled?: boolean
  /** Below 640 px: equal columns across the full width (one per option). Ignored with `stacked`. */
  fill?: boolean
}>()
const model = defineModel<V>({ required: true })
const key = (value: unknown) => JSON.stringify(value)
const current = computed({
  get: () => key(model.value),
  set: (k: string) => {
    const hit = props.options.find((o) => key(o.value) === k)
    if (hit && !hit.unavailable) model.value = hit.value
  },
})
</script>

<template>
  <RadioGroupRoot v-model="current" :aria-labelledby="labelledby" :aria-label="label" :disabled="disabled" orientation="horizontal" :class="['max-w-full rounded-md border border-adm-line-strong bg-adm-elev p-0.5', stacked ? 'grid grid-cols-5 gap-0.5' : 'inline-flex flex-wrap gap-0.5', fill && !stacked && 'max-sm:grid max-sm:w-full max-sm:[grid-template-columns:repeat(var(--seg-cols),minmax(0,1fr))]']" :style="fill && !stacked ? { '--seg-cols': options.length } : undefined">
    <RadioGroupItem
      v-for="option in options"
      :key="key(option.value)"
      :value="key(option.value)"
      :aria-disabled="option.unavailable ? true : undefined"
      :class="[
        option.unavailable && 'cursor-not-allowed opacity-60 hover:bg-transparent! hover:text-adm-muted!',
        'inline-flex min-w-9 items-center whitespace-nowrap justify-center rounded px-2.5 text-[13px] font-medium text-adm-meta transition-colors hover:bg-adm-subtle hover:text-adm-fg focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-adm-acc disabled:opacity-45 max-md:min-h-11 max-md:min-w-11',
        option.value === null ? 'data-[state=checked]:bg-adm-subtle data-[state=checked]:text-adm-fg data-[state=checked]:inset-ring data-[state=checked]:inset-ring-adm-line-strong' : 'data-[state=checked]:bg-adm-primary data-[state=checked]:text-adm-on-primary',
        stacked ? 'min-h-12 flex-col gap-0.5 py-1.5' : 'h-7 max-md:h-11',
      ]"
    >
      <b v-if="stacked" class="text-sm tabular-nums">{{ option.label }}</b><span v-else>{{ option.label }}</span>
      <span v-if="option.unavailable" class="sr-only"> (no disponible: {{ option.unavailable }})</span>
      <template v-if="option.dot"><span class="ml-1 size-1.5 flex-none rounded-full bg-adm-warn-icon" aria-hidden="true" /><span class="sr-only"> ({{ option.dotLabel ?? 'incompleto' }})</span></template>
      <span v-if="stacked && option.sub" class="text-center text-[11px] leading-tight font-normal">{{ option.sub }}</span>
    </RadioGroupItem>
  </RadioGroupRoot>
</template>
