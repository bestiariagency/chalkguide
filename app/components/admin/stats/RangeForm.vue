<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'
import { fmtNum, rangeText } from '~/utils/admin-stats-format'
import { allowedGrains, daysIn, GRAIN_NOUN, rangeIssue } from '~/utils/admin-stats-range'

/**
 * Body of the custom range picker (README §16.10): «Desde» / «Hasta» (native date inputs), one error line, a live
 * summary. «Aplicar» is never disabled: with an error it explains it and moves the focus to the field.
 */
const props = defineProps<{ from: string; to: string; today: string; cutoff: string }>()
const emit = defineEmits<{ apply: [from: string, to: string]; cancel: [] }>()

const from = ref(props.from)
const to = ref(props.to)
const tried = ref(false)
const fromEl = ref<HTMLInputElement>()
const toEl = ref<HTMLInputElement>()
const id = useId()

const issue = computed(() => rangeIssue(from.value, to.value, props.today, props.cutoff))
const shown = computed(() => (tried.value ? issue.value : null))
const summary = computed(() => {
  if (issue.value) return ''
  const days = daysIn(from.value, to.value)
  const grains = allowedGrains('custom', days).map((g) => GRAIN_NOUN[g][0])
  return `${rangeText(from.value, to.value)} · ${fmtNum(days)} ${days === 1 ? 'día' : 'días'} · agrupar por ${grains.join(' o ')}`
})

function submit() {
  tried.value = true
  const found = issue.value
  if (found) {
    void nextTick(() => (found.field === 'to' ? toEl : fromEl).value?.focus())
    return
  }
  emit('apply', from.value, to.value)
}
onMounted(() => fromEl.value?.focus())
const invalid = (field: 'from' | 'to') => !!shown.value && (shown.value.field === field || shown.value.field === 'both')
</script>

<template>
  <form novalidate @submit.prevent="submit">
    <div class="grid grid-cols-2 gap-3">
      <div class="min-w-0">
        <label :for="`${id}-from`" :class="admLabel">Desde</label>
        <input :id="`${id}-from`" ref="fromEl" v-model="from" type="date" :min="cutoff" :max="today" required :aria-invalid="invalid('from')" :aria-describedby="`${id}-err`" :class="[admInput, 'tabular-nums', invalid('from') && admInputInvalid]" data-autofocus />
      </div>
      <div class="min-w-0">
        <label :for="`${id}-to`" :class="admLabel">Hasta</label>
        <input :id="`${id}-to`" ref="toEl" v-model="to" type="date" :min="cutoff" :max="today" required :aria-invalid="invalid('to')" :aria-describedby="`${id}-err`" :class="[admInput, 'tabular-nums', invalid('to') && admInputInvalid]" />
      </div>
    </div>
    <p :id="`${id}-err`" :class="shown ? 'mt-2 flex items-start gap-1.5 text-xs text-adm-danger' : 'sr-only'">
      <template v-if="shown"><CircleAlert class="mt-px size-3.5 flex-none" aria-hidden="true" /><span>{{ shown.message }}</span></template>
    </p>
    <p class="mt-3 min-h-4 text-xs text-adm-meta tabular-nums" aria-live="polite">{{ summary }}</p>
    <div class="mt-4 flex justify-end gap-2 max-md:[&>*]:flex-1">
      <button type="button" :class="admBtnGhost" @click="emit('cancel')">Cancelar</button>
      <button type="submit" :class="admBtnPrimary">Aplicar</button>
    </div>
  </form>
</template>
