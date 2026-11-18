<script setup lang="ts">
/** One filter group: legend + toggle chips (values with their i18n label key prefix). */
const props = defineProps<{
  legend: string
  options: string[]
  /** i18n prefix of the option labels, e.g. "shoes.profile" → shoes.profile.flat. */
  labelPrefix: string
  selected: string[]
  /** How many models carry each value (shown next to the label). */
  counts?: Record<string, number>
}>()
const emit = defineEmits<{ change: [values: string[]] }>()
const { t } = useI18n()

const toggle = (value: string) =>
  emit(
    'change',
    props.selected.includes(value)
      ? props.selected.filter((v) => v !== value)
      : [...props.selected, value],
  )
</script>

<template>
  <fieldset v-if="options.length">
    <legend class="label-mini mb-2">{{ legend }}</legend>
    <div class="flex flex-wrap gap-2">
      <UiChip
        v-for="value in options"
        :key="value"
        :pressed="selected.includes(value)"
        compact
        @update:pressed="toggle(value)"
      >
        {{ t(`${labelPrefix}.${value}`) }}
        <span v-if="counts?.[value]" class="font-mono text-micro font-normal text-meta">{{ counts[value] }}</span>
      </UiChip>
    </div>
  </fieldset>
</template>
