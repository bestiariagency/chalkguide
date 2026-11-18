<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'

/**
 * Label + control + help / error / counter. The label is always visible (never placeholder-only).
 * The default slot receives the ids and ARIA wiring for the control.
 */
const props = defineProps<{
  label: string
  id?: string
  help?: string
  error?: string
  /** e.g. "12 / 280" (already formatted by the caller via i18n). */
  counter?: string
}>()

const autoId = useId()
const controlId = computed(() => props.id ?? `field-${autoId}`)
const helpId = computed(() => `${controlId.value}-help`)
const errorId = computed(() => `${controlId.value}-error`)
const counterId = computed(() => `${controlId.value}-counter`)

const describedBy = computed(
  () =>
    [props.error && errorId.value, props.help && helpId.value, props.counter && counterId.value]
      .filter(Boolean)
      .join(' ') || undefined,
)
</script>

<template>
  <div>
    <label :for="controlId" class="mb-2 block text-caption text-meta">{{ label }}</label>
    <slot :id="controlId" :described-by="describedBy" :invalid="!!error" />
    <p
      v-if="error"
      :id="errorId"
      class="mt-1.5 flex items-center gap-1.5 text-caption text-danger-text"
    >
      <CircleAlert :size="16" aria-hidden="true" />{{ error }}
    </p>
    <p v-if="help" :id="helpId" class="mt-1.5 text-note text-meta">{{ help }}</p>
    <p
      v-if="counter"
      :id="counterId"
      class="mt-1.5 text-right font-mono text-note text-meta"
      aria-live="polite"
    >
      {{ counter }}
    </p>
  </div>
</template>
