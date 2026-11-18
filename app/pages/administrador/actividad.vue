<script setup lang="ts">
import { History, SearchX } from 'lucide-vue-next'
import type { ActivityRecord } from '~/utils/admin-activity'

/**
 * Actividad (F6.18, D23; docs/design/admin/actividad.html): the audit log of the panel, grouped by day. Tabs
 * (Todo, Contenido, Publicaciones, Moderación, Exportaciones, Sistema), search and period live in the URL
 * (`?vista=&q=&periodo=&desde=&hasta=`). Read only: there is no «Recuperar» (no RPC restores deleted content).
 * The Exportaciones tab opens a drawer with what each export asked for.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Actividad')

const activity = useAdminActivity()
const { filters, list } = activity
const selected = ref<ActivityRecord>()

const plural = (n: number) => `${fmtInt(n)} ${n === 1 ? 'entrada' : 'entradas'}`
const pending = computed(() => list.status.value === 'pending')
/** Skeleton only on the first load; later reloads keep the rows (dimmed). */
const loading = computed(() => pending.value && !list.data.value)
const refreshing = computed(() => pending.value && !loading.value)
const failed = computed(() => list.status.value === 'error')
const total = computed(() => activity.counts.value?.[filters.value.tab] ?? 0)
const searching = computed(() => !!searchTerm(activity.search.value))
const filtered = computed(() => hasActivityFilters(filters.value))
const summary = computed(() => (loading.value ? 'Cargando la actividad…' : `${plural(activity.entries.value.length)} de ${fmtInt(total.value)}`))

function clearFilters() {
  activity.search.value = ''
  void activity.setQuery({ q: undefined, periodo: undefined, desde: undefined, hasta: undefined })
}
</script>

<template>
  <div>
    <AdminPageBar title="Actividad">
      <template #meta><span class="hidden text-xs text-adm-muted sm:inline">· se conserva 24 meses</span></template>
    </AdminPageBar>

    <AdminActivityToolbar v-model:search="activity.search.value" :filters="filters" :counts="activity.counts.value" @filter="activity.setQuery" />

    <div id="act-panel" role="tabpanel" :aria-labelledby="`act-tab-${filters.tab}`" :aria-busy="pending" :class="['max-w-[960px] px-4 py-4 transition-opacity duration-150 md:px-6', refreshing && 'opacity-60']">
      <p class="sr-only" role="status">{{ summary }}</p>

      <div v-if="loading" class="space-y-6" aria-hidden="true">
        <div v-for="n in 2" :key="n">
          <span class="mb-2 block h-3 w-16 animate-pulse rounded bg-adm-subtle motion-reduce:animate-none" />
          <ul :class="[admCard, 'divide-y divide-adm-line']">
            <li v-for="m in 3" :key="m" class="flex gap-3 px-4 py-3">
              <span class="size-7 flex-none animate-pulse rounded-md bg-adm-subtle motion-reduce:animate-none" />
              <span class="mt-1 h-4 w-2/3 animate-pulse rounded bg-adm-subtle motion-reduce:animate-none" />
            </li>
          </ul>
        </div>
      </div>

      <AdminStateBlock v-else-if="failed" kind="error" title="No se ha podido cargar la actividad" :code="activity.errorCode.value" @retry="list.refresh()">
        <button v-if="filtered" type="button" :class="admBtnGhost" @click="clearFilters">Quitar filtros</button>
      </AdminStateBlock>

      <template v-else-if="activity.entries.value.length">
        <AdminActivityFeed :days="activity.days.value" @detail="selected = $event" />
        <div class="flex flex-col items-center gap-2 pb-2">
          <p v-if="activity.moreFailed.value" class="text-[13px] text-adm-danger" role="alert">No se han podido cargar más entradas.</p>
          <button v-if="activity.hasMore.value" type="button" :class="admBtnGhost" :aria-busy="activity.loadingMore.value" :disabled="activity.loadingMore.value" @click="activity.more()">
            {{ activity.loadingMore.value ? 'Cargando…' : activity.moreFailed.value ? 'Reintentar' : 'Cargar más' }}
          </button>
          <p v-else class="text-xs text-adm-muted">{{ filters.period === 'all' ? 'No hay más entradas.' : 'No hay más entradas en este periodo.' }}</p>
          <p v-if="activity.hasMore.value" class="text-xs text-adm-muted tabular-nums" aria-hidden="true">{{ summary }}</p>
        </div>
      </template>

      <AdminStateBlock
        v-else-if="searching"
        kind="no-results"
        :icon="SearchX"
        :title="`Nada coincide con «${activity.search.value.trim()}»`"
        description="Busca por título, nombre de archivo o el email exacto de un suscriptor."
      >
        <button type="button" :class="admBtnGhost" @click="clearFilters">Quitar filtros</button>
      </AdminStateBlock>
      <AdminStateBlock v-else-if="filters.tab === 'exp' && !filtered" kind="empty" :icon="History" title="Aún no has exportado nada" description="Cada exportación queda registrada: qué, filtros, columnas, formato y filas. Nunca los datos." />
      <AdminStateBlock v-else kind="empty" :icon="History" title="Nada en este periodo" :description="filters.period === 'all' ? 'Todavía no hay actividad registrada.' : 'Prueba con un periodo más largo.'">
        <button v-if="filters.period !== 'all'" type="button" :class="admBtnGhost" @click="activity.setQuery({ periodo: 'todo', desde: undefined, hasta: undefined })">Ver todo el registro</button>
      </AdminStateBlock>
    </div>

    <AdminActivityExportDetail :entry="selected" @close="selected = undefined" />
  </div>
</template>
