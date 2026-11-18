<script setup lang="ts">
import type { BucketView } from '~/utils/admin-stats-buckets'
import { niceCeil } from '~/utils/admin-stats-chart'
import type { PlotTip, StatsCol } from '~/utils/admin-stats-series'

/**
 * Bars: stacked upwards (`up`) and, optionally, one series downwards (`down`, same scale: no second axis). A period in
 * progress or cut is drawn at 45 % with a dashed outline. The hidden series uses a diagonal pattern, not only colour.
 */
const props = defineProps<{
  buckets: BucketView[]
  up: StatsCol[]
  down?: StatsCol
  height: number
  label: string
  tip?: PlotTip | null
  describe: (i: number) => string
}>()
const active = defineModel<number | null>('active', { default: null })

const id = useId()
const TOP = 12
const bottom = computed(() => props.height - 24)
const upMax = computed(() => niceCeil(Math.max(1, ...props.buckets.map((b) => props.up.reduce((s, c) => s + c.value(b), 0)))))
const downMax = computed(() => (props.down ? Math.max(1, ...props.buckets.map((b) => props.down!.value(b))) : 0))
const unit = computed(() => (bottom.value - TOP) / (upMax.value + downMax.value))
const zero = computed(() => TOP + upMax.value * unit.value)

const fillClass: Record<string, string> = { acc: 'fill-adm-acc', muted: 'fill-adm-muted', hidden: 'stroke-adm-st-hidden' }

/** Segments of every period (y and height do not depend on the width). */
const stacks = computed(() =>
  props.buckets.map((b) => {
    let top = zero.value
    const segments = props.up.flatMap((c) => {
      const h = c.value(b) * unit.value
      if (!h) return []
      top -= h
      return [{ y: top, h, swatch: c.swatch }]
    })
    const out = props.down ? props.down.value(b) * unit.value : 0
    return { segments, top, out, outSwatch: props.down?.swatch ?? 'muted' }
  }),
)
</script>

<template>
  <AdminStatsPlot v-model:active="active" :count="buckets.length" :height="height" :band-top="TOP" :band-height="bottom - TOP" :label="label" :tip="tip" :describe="describe">
    <template #default="{ f, ticks }">
      <defs>
        <pattern :id="`hatch-${id}`" patternUnits="userSpaceOnUse" width="4" height="4" patternTransform="rotate(45)">
          <rect width="4" height="4" class="fill-adm-subtle" />
          <line x1="0" y1="0" x2="0" y2="4" stroke-width="1.5" class="stroke-adm-st-hidden" />
        </pattern>
      </defs>
      <line :x1="f.left" :x2="f.right" :y1="TOP" :y2="TOP" class="stroke-adm-line" />
      <line :x1="f.left" :x2="f.right" :y1="TOP + (upMax / 2) * unit" :y2="TOP + (upMax / 2) * unit" class="stroke-adm-line" />
      <text :x="f.left - 6" :y="TOP + 4" text-anchor="end" class="fill-adm-muted font-mono text-[11px]">{{ fmtNum(upMax) }}</text>
      <text :x="f.left - 6" :y="TOP + (upMax / 2) * unit + 4" text-anchor="end" class="fill-adm-muted font-mono text-[11px]">{{ fmtNum(upMax / 2) }}</text>
      <text :x="f.left - 6" :y="zero + 4" text-anchor="end" class="fill-adm-muted font-mono text-[11px]">0</text>
      <text v-if="down && downMax * unit >= 14" :x="f.left - 6" :y="bottom" text-anchor="end" class="fill-adm-muted font-mono text-[11px]">−{{ fmtNum(downMax) }}</text>
      <template v-for="(b, i) in buckets" :key="b.start">
        <g :opacity="b.partial ? 0.45 : 1">
          <rect
            v-for="(s, j) in stacks[i]!.segments" :key="j" :x="f.cx(i) - f.bw / 2" :y="s.y" :width="f.bw" :height="s.h"
            :fill="s.swatch === 'hidden' ? `url(#hatch-${id})` : undefined" :stroke-width="s.swatch === 'hidden' ? 1 : undefined" :class="fillClass[s.swatch]"
          />
          <rect v-if="stacks[i]!.out" :x="f.cx(i) - f.bw / 2" :y="zero + 1" :width="f.bw" :height="stacks[i]!.out" :class="fillClass[stacks[i]!.outSwatch]" />
        </g>
        <rect
          v-if="b.partial && (stacks[i]!.segments.length || stacks[i]!.out)"
          :x="f.cx(i) - f.bw / 2 - 0.5" :y="stacks[i]!.top - 0.5" :width="f.bw + 1" :height="zero - stacks[i]!.top + 1 + stacks[i]!.out"
          fill="none" stroke-dasharray="3 2" class="stroke-adm-acc"
        />
      </template>
      <line :x1="f.left" :x2="f.right" :y1="zero" :y2="zero" class="stroke-adm-line-strong" />
      <AdminStatsXAxis :buckets="buckets" :f="f" :ticks="ticks" :y="height - 4" />
    </template>
  </AdminStatsPlot>
</template>
