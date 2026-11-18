<script setup lang="ts">
import { Download } from 'lucide-vue-next'
import { bucketViews } from '~/utils/admin-stats-buckets'
import { GRAIN_NOUN } from '~/utils/admin-stats-range'
import { comparisonNote, grainColumn, statsSubtitle } from '~/utils/admin-stats-text'

/**
 * Estadísticas (F6.16, D59, D61; docs/design/admin/estadisticas.html, README §16): suscriptores, artículos,
 * opiniones y fichas por periodo. The view (`?periodo=&agrupar=&desde=&hasta=`) lives in the URL; one `admin_stats`
 * call feeds everything. Visits are left out until D5 («Sin conectar»). CSV of the current view: desktop only.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Estadísticas')

const page = useAdminStats()
const { stats } = page

const result = computed(() => stats.data.value)
const data = computed(() => result.value?.data)
const today = computed(() => (data.value?.generatedAt ? dayKey(data.value.generatedAt) : page.today))
const buckets = computed(() => (data.value ? bucketViews(data.value.buckets, data.value.grain, today.value) : []))
const subtitle = computed(() => (data.value ? statsSubtitle(data.value) : ''))
const unit = computed(() => (data.value ? GRAIN_NOUN[data.value.grain][0] : 'mes'))
const column = computed(() => (data.value ? grainColumn(data.value.grain) : ''))
const note = computed(() => (data.value ? comparisonNote(data.value, today.value) : ''))
const noteId = useId()
</script>

<template>
  <div>
    <AdminPageBar title="Estadísticas" desktop-only>
      <button type="button" :class="admBtnGhost" :disabled="!data || page.failed.value" @click="page.exportCsv()"><Download aria-hidden="true" />Exportar CSV</button>
    </AdminPageBar>

    <div class="max-w-[1440px] px-4 py-6 pb-24 md:px-6 md:pb-6">
      <div class="flex flex-wrap items-end gap-x-6 gap-y-3">
        <div class="mr-auto min-w-0">
          <h1 class="text-xl font-semibold tracking-tight">Estadísticas</h1>
          <p class="text-sm text-adm-meta tabular-nums" aria-live="polite">{{ subtitle }}</p>
        </div>
        <AdminStatsControls :view="page.view.value" :today="page.today" :cutoff="page.cutoff" :last="page.lastCustom.value" @period="page.setPeriod" @grain="page.setGrain" @range="page.applyRange" />
      </div>

      <div class="mt-5">
        <AdminStatsSkeleton v-if="page.loading.value" />
        <div v-else-if="page.failed.value" :class="admCard">
          <AdminStateBlock kind="error" title="No se han podido cargar las estadísticas" description="Puede ser la conexión o el servidor. Tus datos no se han tocado. Vuelve a intentarlo; si sigue fallando, prueba en unos minutos." @retry="page.retry()" />
        </div>
        <div v-else-if="data && result" :aria-busy="page.refreshing.value" :class="['transition-opacity', page.refreshing.value && 'opacity-60']">
          <AdminStatsKpis :data="data" :today="today" :describedby="noteId" />
          <p :id="noteId" class="mt-2 text-xs text-adm-meta tabular-nums">{{ note }}</p>
          <div class="mt-6"><AdminStatsSubs :buckets="buckets" :grain-label="column" :subtitle="subtitle" :unit="unit" /></div>
          <div class="mt-6 grid items-start gap-6 lg:grid-cols-2">
            <AdminStatsArticles :buckets="buckets" :grain-label="column" :subtitle="subtitle" :unit="unit" :range="data.range" :articles="result.articles" :last="result.lastArticle" :drafts="result.drafts" />
            <AdminStatsReviews :buckets="buckets" :grain-label="column" :subtitle="subtitle" :unit="unit" />
            <AdminStatsFichas :data="data" :today="today" />
            <AdminStatsVisitsEmpty />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
