<script setup lang="ts">
import type { ChartFrame } from '~/utils/admin-stats-chart'
import type { BucketView } from '~/utils/admin-stats-buckets'

/** x labels: thinned out, the current period always labelled; by day the month only shows when it changes. */
const props = defineProps<{ buckets: BucketView[]; f: ChartFrame; ticks: Set<number>; y: number }>()

const labels = computed(() => {
  let last = ''
  return props.buckets.flatMap((b, i) => {
    if (!props.ticks.has(i)) return []
    const text = b.axisFirst && b.month !== last ? b.axisFirst : b.axis
    last = b.month
    return [{ i, text }]
  })
})
</script>

<template>
  <text v-for="l in labels" :key="l.i" :x="f.cx(l.i)" :y="y" text-anchor="middle" class="fill-adm-muted font-mono text-[11px]">{{ l.text }}</text>
</template>
