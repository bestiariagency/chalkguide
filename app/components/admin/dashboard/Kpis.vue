<script setup lang="ts">
import type { DashboardStats } from '~/utils/admin-dashboard'

/** KPI strip: every card links to its section. Visits are omitted until `page_views` exists. */
const props = defineProps<{
  stats: DashboardStats
  /** Articles (not pages or fichas) with unpublished changes. */
  articleChanges: number
  newReviews: number
  totals: number[]
}>()

// A flat or empty series draws no line (README §14.3).
const hasSeries = computed(() => props.totals.filter((v) => v !== 0).length >= 2 && new Set(props.totals).size > 1)
const spark = computed(() => (hasSeries.value ? sparkPoints(props.totals) : ''))
const published = computed(() => props.stats.itemsPublished ?? 0)
const publishedOf = computed(() => {
  const by = props.stats.itemsPublishedByCategory
  const total = props.stats.itemsTotalByCategory
  if (!by) return ''
  return [GYM_INFO, RESOLER_INFO, SHOE_INFO]
    .map((info) => (by[info.category] || total?.[info.category] ? `${by[info.category]}${total ? ` de ${total[info.category]}` : ''} ${info.nouns}` : ''))
    .filter(Boolean)
    .join(' · ')
})
const growth = computed(() => props.stats.subscribers.new30 - props.stats.subscribers.newPrev30)
const card = 'block border-r border-b border-adm-line p-4 hover:bg-adm-side focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-adm-acc'
const label = 'text-xs text-adm-meta'
const value = 'mt-1 text-2xl font-semibold tracking-tight tabular-nums'
const unit = 'text-sm font-normal text-adm-meta'
</script>

<template>
  <div class="grid grid-cols-2 overflow-hidden rounded-lg border border-adm-line bg-adm-elev lg:grid-cols-4 [&>a]:lg:border-b-0 [&>a:nth-child(2n)]:max-lg:border-r-0 [&>a:nth-child(n+3)]:max-lg:border-b-0 [&>a:last-child]:lg:border-r-0">
    <NuxtLink :to="adminPath('suscriptores')" :class="card">
      <p :class="label">Suscriptores activos</p>
      <p :class="value">{{ fmtInt(stats.subscribers.active) }}</p>
      <p class="mt-1 text-xs tabular-nums">
        <span :class="stats.subscribers.new30 > 0 ? 'font-medium text-adm-ok' : 'text-adm-meta'">{{ signed(stats.subscribers.new30) }}</span>
        <span class="text-adm-meta">{{ ' ' }}{{ stats.subscribers.new30 === 1 ? 'alta' : 'altas' }} · {{ stats.subscribers.unsub30 }} {{ stats.subscribers.unsub30 === 1 ? 'baja' : 'bajas' }} (30 d)</span>
      </p>
      <p class="sr-only">{{ growth >= 0 ? 'Más' : 'Menos' }} altas que en los 30 días anteriores ({{ stats.subscribers.newPrev30 }}).</p>
      <svg v-if="spark" viewBox="0 0 120 28" class="mt-2 h-7 w-full text-adm-acc" preserveAspectRatio="none" aria-hidden="true">
        <polyline fill="none" stroke="currentColor" stroke-width="1.5" vector-effect="non-scaling-stroke" :points="spark" />
      </svg>
    </NuxtLink>
    <NuxtLink :to="adminPath('articulos')" :class="card">
      <p :class="label">Artículos</p>
      <p :class="value">{{ stats.articles.published }} <span :class="unit">{{ stats.articles.published === 1 ? 'publicado' : 'publicados' }}</span></p>
      <p class="mt-2 flex flex-wrap gap-1.5">
        <AdminStatusChip v-if="stats.articles.scheduled" status="scheduled" :label="`${stats.articles.scheduled} ${stats.articles.scheduled === 1 ? 'programado' : 'programados'}`" />
        <span v-else :class="[admChip, 'bg-adm-subtle text-adm-meta']">0 programados</span>
        <AdminStatusChip status="draft" :label="`${stats.articles.draft} ${stats.articles.draft === 1 ? 'borrador' : 'borradores'}`" />
        <span v-if="articleChanges" :class="[admChip, 'bg-adm-st-rev-bg text-adm-st-rev']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />{{ articleChanges }} con cambios</span>
      </p>
    </NuxtLink>
    <NuxtLink :to="adminPath('opiniones')" :class="card">
      <p :class="label">Opiniones</p>
      <p :class="value">{{ newReviews }} <span :class="unit">{{ newReviews === 1 ? 'nueva' : 'nuevas' }}</span></p>
      <p class="mt-2 text-xs text-adm-meta tabular-nums">
        desde tu última visita · {{ stats.reviews.last30 }} en 30 d · {{ stats.reviews.hidden }} {{ stats.reviews.hidden === 1 ? 'oculta' : 'ocultas' }}
      </p>
    </NuxtLink>
    <NuxtLink :to="adminPath('rocodromos')" :class="card">
      <p :class="label">Fichas publicadas</p>
      <p :class="value">{{ fmtInt(published) }}</p>
      <p class="mt-2 text-xs text-adm-meta tabular-nums">{{ publishedOf || 'rocódromos, resoladores y pies de gato' }}</p>
    </NuxtLink>
  </div>
</template>
