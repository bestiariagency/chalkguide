<script setup lang="ts">
import type { BucketView } from '~/utils/admin-stats-buckets'
import { lineScale } from '~/utils/admin-stats-chart'
import type { PlotTip } from '~/utils/admin-stats-series'

/** «Total de suscriptores activos»: a 2 px line, no fill (the axis may not start at 0). The last value is written at the end. */
const props = defineProps<{
  buckets: BucketView[]
  label: string
  tip?: PlotTip | null
  describe: (i: number) => string
}>()
const active = defineModel<number | null>('active', { default: null })

const HEIGHT = 176
const TOP = 20
const BOTTOM = HEIGHT - 24
const scale = computed(() => lineScale(props.buckets.map((b) => b.subsTotal)))
const y = (value: number) => BOTTOM - ((value - scale.value.lo) / (scale.value.hi - scale.value.lo)) * (BOTTOM - TOP)
const lastIndex = computed(() => props.buckets.length - 1)
const trailing = computed(() => props.buckets.length > 1 && !!props.buckets[lastIndex.value]?.partial)
const last = computed(() => props.buckets[lastIndex.value]?.subsTotal ?? 0)
</script>

<template>
  <AdminStatsPlot v-model:active="active" :count="buckets.length" :height="HEIGHT" :band-top="TOP" :band-height="BOTTOM - TOP" :label="label" :tip="tip" :describe="describe">
    <template #default="{ f, ticks }">
      <g v-for="t in scale.ticks" :key="t">
        <line :x1="f.left" :x2="f.right" :y1="y(t)" :y2="y(t)" :class="t === scale.lo ? 'stroke-adm-line-strong' : 'stroke-adm-line'" />
        <text :x="f.left - 6" :y="y(t) + 4" text-anchor="end" class="fill-adm-muted font-mono text-[11px]">{{ fmtNum(t) }}</text>
      </g>
      <polyline
        :points="buckets.slice(0, trailing ? -1 : undefined).map((b, i) => `${f.cx(i)},${y(b.subsTotal)}`).join(' ')"
        fill="none" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" class="stroke-adm-acc"
      />
      <polyline
        v-if="trailing"
        :points="buckets.slice(-2).map((b, i) => `${f.cx(lastIndex - 1 + i)},${y(b.subsTotal)}`).join(' ')"
        fill="none" stroke-width="2" stroke-dasharray="4 3" class="stroke-adm-acc"
      />
      <circle :cx="f.cx(lastIndex)" :cy="y(last)" r="4" stroke-width="2" class="fill-adm-acc stroke-adm-elev" />
      <text :x="Math.min(f.cx(lastIndex), f.right - 2)" :y="y(last) - 10" text-anchor="end" class="fill-adm-fg text-xs font-semibold tabular-nums">{{ fmtNum(last) }}</text>
      <circle v-if="active !== null && active !== lastIndex" :cx="f.cx(active)" :cy="y(buckets[active]?.subsTotal ?? 0)" r="4" stroke-width="2" class="fill-adm-acc stroke-adm-elev" />
      <AdminStatsXAxis :buckets="buckets" :f="f" :ticks="ticks" :y="HEIGHT - 4" />
    </template>
  </AdminStatsPlot>
</template>
