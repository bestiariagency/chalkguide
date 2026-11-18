<script setup lang="ts">
import { Mail } from 'lucide-vue-next'
import type { BucketView } from '~/utils/admin-stats-buckets'
import { STATS_COLS, statsCardEmpty } from '~/utils/admin-stats-series'

/** Suscriptores (README §16.5): total line + divergent bars (altas up, bajas down). They share the x axis and the detail. */
const props = defineProps<{ buckets: BucketView[]; grainLabel: string; subtitle: string; unit: string }>()
const [, ins, outs] = STATS_COLS.subs
const { active, hint, tip, describe } = useAdminStatsCard('subs', () => props.buckets, () => props.subtitle, () => props.unit)
</script>

<template>
  <AdminStatsCard id="subs" :buckets="buckets" :grain-label="grainLabel" :subtitle="subtitle" :empty="statsCardEmpty('subs', buckets)">
    <template #empty>
      <AdminStatsEmptyRow :icon="Mail" title="Aún no hay suscriptores" text="Con la primera alta verás aquí el total y las altas y bajas de cada periodo. La newsletter se conecta con Brevo antes del lanzamiento." />
    </template>
    <p class="mb-1 text-xs font-medium text-adm-meta">Total de suscriptores activos</p>
    <AdminStatsLineChart v-model:active="active" :buckets="buckets" :label="`Total de suscriptores activos. ${hint}`" :tip="tip" :describe="describe" />
    <p class="mt-4 mb-1 text-xs font-medium text-adm-meta">Altas y bajas</p>
    <AdminStatsBarChart v-model:active="active" :buckets="buckets" :up="[ins!]" :down="outs" :height="140" :label="`Altas y bajas. ${hint}`" :describe="describe" />
  </AdminStatsCard>
</template>
