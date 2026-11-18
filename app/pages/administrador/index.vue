<script setup lang="ts">
import { ExternalLink, Plus } from 'lucide-vue-next'

/** Panel home (v2, D52/D55): pending, KPIs, editorial calendar (2 weeks), signups and recent activity. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Inicio')

const { today, view, title, summary, calendar, grid, upcoming, prev, next, refresh } = useAdminDashboard()
const data = computed(() => summary.data.value)
const changes = computed(() => {
  const drafts = data.value?.drafts ?? []
  const count = (entity: string) => drafts.filter((d) => d.entity === entity).length
  return { articles: count('article'), pages: count('page'), items: drafts.length - count('article') - count('page') }
})
const groups = computed(() =>
  data.value ? buildPending({ stats: data.value.stats, newReviews: data.value.newReviews, changes: changes.value, provisionalPages: data.value.provisionalPages, news: data.value.news, today }) : [],
)
const subtitle = computed(() => `${formatDayLong(today)} · últimos 30 días frente a los 30 anteriores`)
</script>

<template>
  <div>
    <AdminPageBar title="Inicio" desktop-only>
      <NuxtLink to="/" external target="_blank" :class="admBtnGhost"><ExternalLink aria-hidden="true" />Ver sitio</NuxtLink>
      <NuxtLink :to="adminPath('articulos/nuevo')" :class="admBtnPrimary"><Plus aria-hidden="true" />Nuevo artículo</NuxtLink>
    </AdminPageBar>

    <div class="max-w-[1440px] px-4 py-6 md:px-6">
      <div class="flex flex-wrap items-end gap-x-4 gap-y-1">
        <h1 class="text-xl font-semibold tracking-tight">{{ greeting() }}</h1>
        <p class="text-sm text-adm-meta">{{ subtitle }}</p>
      </div>

      <div v-if="summary.status.value === 'pending' && !data" class="mt-5 space-y-6" role="status" aria-label="Cargando el resumen">
        <div class="grid gap-px overflow-hidden rounded-lg border border-adm-line bg-adm-line lg:grid-cols-3">
          <div v-for="n in 3" :key="n" class="space-y-3 bg-adm-elev p-4"><span v-for="m in 3" :key="m" class="block h-10 rounded-lg bg-adm-subtle" /></div>
        </div>
        <div class="h-[104px] rounded-lg bg-adm-subtle" />
        <div class="h-60 rounded-lg bg-adm-subtle" />
      </div>
      <AdminStateBlock
        v-else-if="summary.error.value"
        class="mt-5"
        kind="error"
        :code="(summary.error.value as { statusCode?: number; code?: string }).code"
        @retry="refresh()"
      />
      <template v-else-if="data">
        <AdminDashboardPending class="mt-5" :groups="groups" />
        <AdminDashboardKpis class="mt-6" :stats="data.stats" :article-changes="changes.articles" :new-reviews="data.newReviews" :totals="data.totals" />
        <AdminDashboardCalendar
          v-model:view="view"
          class="mt-6"
          :title="title"
          :last-published="data.lastPublished"
          :drafts="data.stats.articles.draft"
          :grid="grid"
          :upcoming="upcoming"
          :loading="calendar.status.value === 'pending'"
          :failed="!!calendar.error.value"
          @prev="prev"
          @next="next"
          @retry="calendar.refresh()"
        />
        <div class="mt-6 grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">
          <AdminDashboardSignups :points="data.signups" :last30="data.stats.subscribers.new30" />
          <AdminDashboardActivity :entries="data.stats.activity" />
        </div>
      </template>
    </div>
  </div>
</template>
