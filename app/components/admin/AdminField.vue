<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'

/**
 * Label + control + help/error (+ optional length counter and meter). The control goes in the
 * default slot and must bind the slot props: `id`, `describedby` and `invalid`.
 * Errors are announced (`aria-live`) and linked with `aria-describedby`; a counter over `max`
 * produces its own error when none is given.
 */
const props = defineProps<{
  label: string
  help?: string
  error?: string
  required?: boolean
  /** Language tag (ES / EN) next to the label. */
  lang?: 'ES' | 'EN'
  hideLabel?: boolean
  /** Shows the «Sin guardar» mark next to the label (unsaved edit). */
  changed?: boolean
  id?: string
  /** Counter: current length with its recommended (`ideal`) and hard (`max`) limits. */
  count?: number
  max?: number
  ideal?: number
}>()

const uid = useId()
const fieldId = computed(() => props.id ?? `f-${uid}`)
const helpId = computed(() => `${fieldId.value}-h`)
const errorId = computed(() => `${fieldId.value}-e`)
const counterId = computed(() => `${fieldId.value}-c`)

const counter = computed(() =>
  props.count !== undefined && props.max ? counterInfo(props.count, props.max, props.ideal) : null,
)
const message = computed(() => {
  if (props.error) return props.error
  if (counter.value?.tone === 'over') {
    const n = counter.value.excess
    return `Sobra${n === 1 ? '' : 'n'} ${n} carácter${n === 1 ? '' : 'es'}. No se puede guardar por encima de ${props.max}.`
  }
  return ''
})
const describedby = computed(() =>
  describedBy(props.help && helpId.value, counter.value && counterId.value, message.value && errorId.value),
)
const tones = { ok: 'text-adm-meta', warn: 'text-adm-warn', over: 'font-medium text-adm-danger' }
const bars = { ok: 'bg-adm-ok', warn: 'bg-adm-warn-icon', over: 'bg-adm-danger' }
</script>

<template>
  <div>
    <div :class="hideLabel ? 'sr-only' : 'mb-1.5 flex items-center gap-1.5'">
      <label :for="fieldId" class="flex items-center gap-1.5 text-xs font-medium text-adm-fg">
        {{ label }}
        <span v-if="lang" class="rounded-[3px] border border-adm-line-strong px-1 font-mono text-[11px] leading-4 font-medium text-adm-meta">
          {{ lang }}<span class="sr-only"> (idioma)</span>
        </span>
        <template v-if="required">
          <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span>
        </template>
      </label>
      <span v-if="changed" class="text-[11px] font-medium text-adm-st-rev">Sin guardar</span>
      <span v-if="counter" :id="counterId" :class="['ml-auto text-xs tabular-nums', tones[counter.tone]]">
        {{ count }} / {{ max }}
        <span v-if="counter.tone !== 'ok'" class="sr-only">{{ counter.tone === 'over' ? ' (límite superado)' : ' (por encima de lo recomendado)' }}</span>
      </span>
    </div>
    <slot :id="fieldId" :describedby="describedby" :invalid="!!message" />
    <div v-if="counter" class="mt-1.5 h-[3px] overflow-hidden rounded-full bg-adm-line" aria-hidden="true">
      <span :class="['block h-full rounded-[inherit]', bars[counter.tone]]" :style="{ width: `${counter.percent}%` }" />
    </div>
    <p v-if="help" :id="helpId" class="mt-1.5 text-xs leading-4 text-adm-meta">{{ help }}</p>
    <p :id="errorId" aria-live="polite" :class="message ? 'mt-1.5 flex items-start gap-1.5 text-xs leading-4 text-adm-danger' : 'sr-only'">
      <template v-if="message">
        <CircleAlert class="mt-px size-3.5 flex-none" aria-hidden="true" /><span>{{ message }}</span>
      </template>
    </p>
  </div>
</template>
