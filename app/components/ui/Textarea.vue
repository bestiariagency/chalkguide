<script setup lang="ts">
defineOptions({ inheritAttrs: false })
const { rootAttrs, controlAttrs } = useSplitAttrs()
const props = defineProps<{
  label: string
  id?: string
  help?: string
  error?: string
  /** Shows a "count / max" counter (formatted with the reviews.charLimit key). */
  maxlength?: number
}>()
const model = defineModel<string>({ default: '' })
const { t } = useI18n()

const counter = computed(() =>
  props.maxlength
    ? t('reviews.charLimit', { count: model.value.length, max: props.maxlength })
    : undefined,
)
</script>

<template>
  <UiField
    v-bind="rootAttrs"
    :id="id"
    :label="label"
    :help="help"
    :error="error"
    :counter="counter"
  >
    <template #default="{ id: controlId, describedBy, invalid }">
      <textarea
        :id="controlId"
        v-model="model"
        v-bind="controlAttrs"
        :maxlength="maxlength"
        :aria-invalid="invalid || undefined"
        :aria-describedby="describedBy"
        :class="fieldClasses"
        class="min-h-[104px] resize-y py-3 leading-[1.6]"
      />
    </template>
  </UiField>
</template>
