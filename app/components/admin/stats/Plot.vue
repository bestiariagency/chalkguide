<script setup lang="ts">
import { chartFrame, indexAt, labelIndexes, type ChartFrame } from '~/utils/admin-stats-chart'
import type { PlotTip } from '~/utils/admin-stats-series'

/**
 * Frame of one chart (README §16.4): measures its real width (the SVG is drawn at that width, not scaled), finds the
 * period under the pointer, and gives keyboard use (←/→, Inicio/Fin, Esc) with an `aria-live` announcement. The
 * period highlight band and the floating detail live here; the content of the SVG comes from the slot.
 */
const props = defineProps<{
  count: number
  height: number
  /** Top and height of the highlight band. */
  bandTop: number
  bandHeight: number
  label: string
  /** The detail card of the active period (only the chart that shows it). */
  tip?: PlotTip | null
  /** Text read out when the keyboard moves to period `i`. */
  describe: (i: number) => string
}>()
const active = defineModel<number | null>('active', { default: null })

defineSlots<{ default(props: { f: ChartFrame; ticks: Set<number> }): unknown }>()

const box = ref<HTMLElement>()
const width = ref(0)
const tipEl = ref<HTMLElement>()
const tipWidth = ref(160)
const live = ref('')
let observer: ResizeObserver | undefined

onMounted(() => {
  const measure = () => (width.value = Math.max(240, Math.round(box.value?.clientWidth ?? 0)))
  measure()
  observer = new ResizeObserver(measure)
  if (box.value) observer.observe(box.value)
})
onBeforeUnmount(() => observer?.disconnect())

const f = computed(() => chartFrame(width.value, props.count))
const ticks = computed(() => labelIndexes(props.count, f.value.band))

const tipLeft = computed(() => {
  if (active.value === null) return 0
  const x = f.value.cx(active.value)
  return Math.max(0, x + 12 + tipWidth.value > width.value ? x - 12 - tipWidth.value : x + 12)
})
watch(() => [active.value, props.tip], () => nextTick(() => (tipWidth.value = tipEl.value?.offsetWidth || 160)), { flush: 'post' })

function pointAt(event: PointerEvent) {
  const left = box.value?.getBoundingClientRect().left ?? 0
  active.value = indexAt(event.clientX - left, f.value, props.count)
}
function onKey(event: KeyboardEvent) {
  const last = props.count - 1
  const current = active.value
  const next =
    event.key === 'ArrowRight' ? (current === null ? 0 : Math.min(last, current + 1))
    : event.key === 'ArrowLeft' ? (current === null ? last : Math.max(0, current - 1))
    : event.key === 'Home' ? 0
    : event.key === 'End' ? last
    : undefined
  if (event.key === 'Escape') {
    active.value = null
    return
  }
  if (next === undefined) return
  event.preventDefault()
  active.value = next
  live.value = props.describe(next)
}
</script>

<template>
  <div
    ref="box"
    role="group"
    tabindex="0"
    :aria-label="label"
    class="relative touch-pan-y rounded-md outline-offset-2 focus-visible:outline-2 focus-visible:outline-adm-acc"
    @keydown="onKey"
    @pointermove="(e) => e.pointerType === 'mouse' && pointAt(e)"
    @pointerdown="pointAt"
    @pointerleave="(e) => e.pointerType === 'mouse' && (active = null)"
    @focusout="active = null"
  >
    <svg v-if="width" :width="width" :height="height" :viewBox="`0 0 ${width} ${height}`" class="block" aria-hidden="true">
      <rect v-if="active !== null" :x="f.left + f.band * active" :y="bandTop" :width="f.band" :height="bandHeight" class="fill-adm-subtle" />
      <slot :f="f" :ticks="ticks" />
    </svg>
    <div
      v-if="tip && active !== null"
      ref="tipEl"
      class="pointer-events-none absolute top-2 z-10 max-w-55 min-w-37 animate-adm-fade rounded-lg border border-adm-line bg-adm-elev px-3 py-2.5 text-xs leading-4 shadow-adm-pop motion-reduce:animate-none"
      :style="{ left: `${tipLeft}px` }"
      aria-hidden="true"
    >
      <b class="mb-1 block font-semibold">{{ tip.title }}<span v-if="tip.note" class="block text-xs font-normal text-adm-muted">{{ tip.note }}</span></b>
      <span v-for="row in tip.rows" :key="row.label" class="flex items-center gap-1.5 text-adm-meta tabular-nums">
        <AdminStatsSwatch :kind="row.swatch" />{{ row.label }}<strong class="ml-auto pl-3 font-semibold text-adm-fg">{{ row.value }}</strong>
      </span>
    </div>
    <p class="sr-only" aria-live="polite">{{ live }}</p>
  </div>
</template>
