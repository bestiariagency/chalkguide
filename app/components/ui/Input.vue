<script setup lang="ts">
defineOptions({ inheritAttrs: false })
const { rootAttrs, controlAttrs } = useSplitAttrs()
defineProps<{ label: string; id?: string; help?: string; error?: string }>()
const model = defineModel<string>({ default: '' })
const input = ref<HTMLInputElement | null>(null)
defineExpose({ focus: () => input.value?.focus() })
</script>

<template>
  <UiField v-bind="rootAttrs" :id="id" :label="label" :help="help" :error="error">
    <template #default="{ id: controlId, describedBy, invalid }">
      <input
        :id="controlId"
        ref="input"
        v-model="model"
        v-bind="controlAttrs"
        :aria-invalid="invalid || undefined"
        :aria-describedby="describedBy"
        :class="fieldClasses"
      />
    </template>
  </UiField>
</template>
