<script setup lang="ts">
import { MessageSquare } from 'lucide-vue-next'
import type { BucketView } from '~/utils/admin-stats-buckets'
import { STATS_COLS, statsCardEmpty } from '~/utils/admin-stats-series'

/** Opiniones (README §16.5): stacked bars, visibles at the bottom and ocultas (diagonal pattern) on top. */
const props = defineProps<{ buckets: BucketView[]; grainLabel: string; subtitle: string; unit: string }>()
const { active, hint, tip, describe } = useAdminStatsCard('reviews', () => props.buckets, () => props.subtitle, () => props.unit)
</script>

<template>
  <AdminStatsCard id="reviews" :buckets="buckets" :grain-label="grainLabel" :subtitle="subtitle" :empty="statsCardEmpty('reviews', buckets)">
    <template #empty>
      <AdminStatsEmptyRow :icon="MessageSquare" title="Aún no hay opiniones" text="Cuando los lectores opinen sobre una ficha, verás aquí cuántas llegan y cuántas ocultas." />
    </template>
    <AdminStatsBarChart v-model:active="active" :buckets="buckets" :up="STATS_COLS.reviews" :height="168" :label="`Opiniones recibidas. ${hint}`" :tip="tip" :describe="describe" />
  </AdminStatsCard>
</template>
