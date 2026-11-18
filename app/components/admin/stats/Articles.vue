<script setup lang="ts">
import { FileText } from 'lucide-vue-next'
import type { StatsArticle } from '~/services/admin/stats'
import type { BucketView } from '~/utils/admin-stats-buckets'
import { STATS_COLS, statsCardEmpty } from '~/utils/admin-stats-series'

/**
 * Artículos publicados (README §16.5): bars. With 30 days, the list of what was published; with 12 months, one line
 * with the last one. With a custom range neither shows.
 */
const props = defineProps<{
  buckets: BucketView[]
  grainLabel: string
  subtitle: string
  unit: string
  range: '30d' | '12m' | 'custom'
  articles: StatsArticle[]
  last: StatsArticle | null
  drafts: number
}>()
const { active, hint, tip, describe } = useAdminStatsCard('articles', () => props.buckets, () => props.subtitle, () => props.unit)
const editor = (id: string) => adminPath(`articulos/${id}`)
const emptyText = computed(() => (props.drafts ? `Tienes ${props.drafts === 1 ? '1 borrador' : `${props.drafts} borradores`}.` : 'No tienes borradores.'))
</script>

<template>
  <AdminStatsCard id="articles" no-legend :buckets="buckets" :grain-label="grainLabel" :subtitle="subtitle" :empty="statsCardEmpty('articles', buckets)">
    <template #empty>
      <AdminStatsEmptyRow
        :icon="FileText" title="Ningún artículo publicado en este periodo" :text="emptyText"
        :link="drafts ? { to: `${adminPath('articulos')}?estado=borrador`, label: 'Ver borradores' } : undefined"
      />
    </template>
    <AdminStatsBarChart v-model:active="active" :buckets="buckets" :up="STATS_COLS.articles" :height="168" :label="`Artículos publicados. ${hint}`" :tip="tip" :describe="describe" />
    <template #foot>
      <ul v-if="range === '30d' && articles.length" class="mt-3 border-t border-adm-line pt-2 text-sm">
        <li v-for="a in articles" :key="a.id" class="flex items-baseline gap-3 py-1 max-md:min-h-11 max-md:items-center">
          <NuxtLink :to="editor(a.id)" class="min-w-0 truncate font-medium hover:underline">{{ a.title }}</NuxtLink>
          <span class="ml-auto text-xs whitespace-nowrap text-adm-meta tabular-nums">{{ adminDate(a.publishedAt) }}</span>
        </li>
      </ul>
      <p v-else-if="range === '12m' && last" class="mt-3 text-xs text-adm-meta">
        Último publicado: <NuxtLink :to="editor(last.id)" class="font-medium text-adm-fg hover:underline">«{{ last.title }}»</NuxtLink>, {{ adminDate(last.publishedAt) }}
      </p>
    </template>
  </AdminStatsCard>
</template>
