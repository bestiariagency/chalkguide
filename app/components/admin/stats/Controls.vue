<script setup lang="ts">
import { Calendar } from 'lucide-vue-next'
import { rangeText } from '~/utils/admin-stats-format'
import { allowedGrains, daysIn, GRAIN_LABEL, SHORT_RANGE_DAYS, type StatsGrain, type StatsPeriod, type StatsView } from '~/utils/admin-stats-range'

/**
 * Period and grouping controls (README §16.2, §16.10). «Personalizado» opens the picker and the period does not change
 * until «Aplicar». With a custom range the grouping always shows Día | Semana | Mes and the ones that do not fit are
 * `aria-disabled` (still focusable, so a screen reader reads why).
 */
const props = defineProps<{ view: StatsView; today: string; cutoff: string; last: { from: string; to: string } | null }>()
const emit = defineEmits<{ period: [value: '30d' | '12m']; grain: [value: StatsGrain]; range: [from: string, to: string] }>()

const root = ref<HTMLElement>()
const rangeBtn = ref<HTMLButtonElement>()
const open = ref(false)
const desktop = ref(true)
let opener: HTMLElement | null = null
let media: MediaQueryList | undefined

const sync = () => (desktop.value = !!media?.matches)
onMounted(() => {
  media = window.matchMedia('(min-width: 768px)')
  sync()
  media.addEventListener('change', sync)
  document.addEventListener('pointerdown', outside)
})
onBeforeUnmount(() => {
  media?.removeEventListener('change', sync)
  document.removeEventListener('pointerdown', outside)
})
function outside(event: PointerEvent) {
  if (open.value && desktop.value && root.value && !root.value.contains(event.target as Node)) dismiss()
}
function dismiss() {
  open.value = false
  opener = null
}
/** Tabbing out of the popover (desktop) closes it without stealing focus from where it went. */
function leave(event: FocusEvent) {
  const next = event.relatedTarget as Node | null
  if (open.value && desktop.value && next && root.value && !root.value.contains(next)) dismiss()
}

function openPicker() {
  opener = document.activeElement as HTMLElement | null
  open.value = true
}
function closed() {
  const target = opener
  opener = null
  void nextTick(() => target?.isConnected && target.focus())
}
function apply(from: string, to: string) {
  open.value = false
  opener = null
  emit('range', from, to)
  void nextTick(() => rangeBtn.value?.focus())
}

const period = computed<StatsPeriod>({
  get: () => props.view.period,
  set: (value) => (value === 'custom' ? openPicker() : emit('period', value)),
})
const periods: { value: StatsPeriod; label: string }[] = [
  { value: '30d', label: '30 días' },
  { value: '12m', label: '12 meses' },
  { value: 'custom', label: 'Personalizado' },
]

const days = computed(() => (props.view.period === 'custom' && props.view.from && props.view.to ? daysIn(props.view.from, props.view.to) : 0))
const grains = computed(() => {
  const fits = allowedGrains(props.view.period, days.value)
  const all: StatsGrain[] = props.view.period === 'custom' ? ['day', 'week', 'month'] : fits
  return all.map((value) => ({
    value,
    label: GRAIN_LABEL[value],
    unavailable: fits.includes(value) ? undefined : value === 'day' ? `solo con rangos de hasta ${SHORT_RANGE_DAYS} días` : `solo con rangos de más de ${SHORT_RANGE_DAYS} días`,
  }))
})
const grain = computed<StatsGrain>({ get: () => props.view.grain, set: (value) => emit('grain', value) })
const pickerRange = computed(() => (props.view.period === 'custom' && props.view.from && props.view.to ? { from: props.view.from, to: props.view.to } : (props.last ?? { from: keyAdd(props.today, -89), to: props.today })))
</script>

<template>
  <div ref="root" class="relative flex w-full flex-wrap items-center gap-2 sm:w-auto" @focusout="leave">
    <AdminSegmented v-model="period" :options="periods" label="Periodo" fill class="max-sm:w-full" />
    <button
      v-if="view.period === 'custom' && view.from && view.to" ref="rangeBtn" type="button" :class="[admBtnGhost, 'w-full justify-start tabular-nums sm:w-auto']"
      aria-haspopup="dialog" :aria-expanded="open" @click="open ? (open = false) : openPicker()"
    >
      <Calendar aria-hidden="true" />{{ rangeText(view.from, view.to) }}<span class="sr-only">. Cambiar el rango</span>
    </button>
    <AdminSegmented v-model="grain" :options="grains" label="Agrupar por" fill class="max-sm:w-full" />
    <AdminStatsRangePicker v-model:open="open" :desktop="desktop" :from="pickerRange.from" :to="pickerRange.to" :today="today" :cutoff="cutoff" @apply="apply" @close="closed" />
  </div>
</template>
