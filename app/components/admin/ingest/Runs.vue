<script setup lang="ts">
import type { Component } from 'vue'
import { Bot, Check, ChevronDown, ChevronRight, CircleAlert, Loader, TriangleAlert } from 'lucide-vue-next'
import { RUN_CHIPS, runChip, runDuration, runErrorCount, runFound, runNew, runRejected, type AdminRun, type RunChip } from '~/utils/admin-ingest'

/**
 * Collections of the last 30 days (README §19.4): KPIs and the table with an expandable row (`aria-expanded`, `aria-controls`);
 * under 768, cards with the counters line. «Rechazados» are the rows the database did not accept, not the ones Xavi rejects.
 */
const props = defineProps<{ runs: readonly AdminRun[]; kpis: { ok: number; total: number; created: number; duplicates: number; approved: number | null }; open?: string }>()
const expanded = ref<string | undefined>(props.open)
watch(() => props.open, (id) => id && (expanded.value = id))
const toggle = (id: string) => (expanded.value = expanded.value === id ? undefined : id)
const tones: Record<RunChip, string> = {
  open: 'bg-adm-st-sched-bg text-adm-st-sched',
  ok: 'bg-adm-st-pub-bg text-adm-st-pub',
  warn: 'bg-adm-warn-soft text-adm-warn',
  fail: 'bg-adm-danger-soft text-adm-danger',
  abandoned: 'bg-adm-subtle text-adm-meta',
  revoked: 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line',
}
const icons: Record<RunChip, Component> = { open: Loader, ok: Check, warn: TriangleAlert, fail: CircleAlert, abandoned: TriangleAlert, revoked: CircleAlert }
const dash = '—'
const num = (n: number | null) => (n === null ? dash : n)
const th = 'h-9 px-3 text-left text-xs font-medium text-adm-meta'
const td = 'h-11 px-3 align-middle'
</script>

<template>
  <div>
    <div class="grid grid-cols-2 gap-3 px-4 py-4 md:px-6 lg:grid-cols-4">
      <div :class="[admCard, 'p-3']"><p class="text-xs text-adm-meta">Recogidas correctas · 30 días</p><p class="mt-1 text-2xl font-semibold tabular-nums">{{ kpis.ok }} <span class="text-sm font-normal text-adm-meta">de {{ kpis.total }}</span></p></div>
      <div :class="[admCard, 'p-3']"><p class="text-xs text-adm-meta">Noticias creadas</p><p class="mt-1 text-2xl font-semibold tabular-nums">{{ kpis.created }}</p></div>
      <div :class="[admCard, 'p-3']"><p class="text-xs text-adm-meta">Aprobadas de esas</p><p class="mt-1 text-2xl font-semibold tabular-nums">{{ kpis.approved === null ? dash : `${kpis.approved} %` }}</p></div>
      <div :class="[admCard, 'p-3']"><p class="text-xs text-adm-meta">Duplicados evitados</p><p class="mt-1 text-2xl font-semibold tabular-nums">{{ kpis.duplicates }}</p></div>
    </div>

    <div v-if="!runs.length" class="border-t border-adm-line">
      <AdminStateBlock kind="empty" :icon="Bot" title="Todavía no hay recogidas" description="La rutina recoge lunes y jueves. Cuando termine la primera aparecerá aquí." />
    </div>
    <template v-else>
      <div class="hidden overflow-x-auto border-t border-adm-line md:block">
        <table class="w-full min-w-[760px] border-collapse text-[13px]">
          <caption class="sr-only">Recogidas de los últimos 30 días, la más reciente primero</caption>
          <thead class="border-b border-adm-line">
            <tr>
              <th :class="[th, 'w-10']"><span class="sr-only">Desplegar</span></th>
              <th :class="th" aria-sort="descending">Empezó</th>
              <th :class="th">Estado</th>
              <th :class="[th, 'max-lg:hidden']">Modo</th>
              <th :class="[th, 'text-right max-lg:hidden']">Duración</th>
              <th :class="[th, 'text-right']">Encontrados</th><th :class="[th, 'text-right']">Nuevos</th><th :class="[th, 'text-right']">Duplicados</th><th :class="[th, 'text-right']">Rechazados</th><th :class="[th, 'text-right']">Errores</th>
            </tr>
          </thead>
          <tbody>
            <template v-for="r in runs" :key="r.id">
              <tr class="border-b border-adm-line hover:bg-adm-subtle/50">
                <td :class="td"><button type="button" :class="admIconBtn" :aria-expanded="expanded === r.id" :aria-controls="`run-${r.id}`" :aria-label="expanded === r.id ? 'Ocultar detalle' : 'Ver detalle'" @click="toggle(r.id)"><component :is="expanded === r.id ? ChevronDown : ChevronRight" aria-hidden="true" /></button></td>
                <td :class="[td, 'tabular-nums']">{{ runLabel(r.startedAt) }}</td>
                <td :class="td"><span :class="[admChip, tones[runChip(r)]]"><component :is="icons[runChip(r)]" aria-hidden="true" />{{ RUN_CHIPS[runChip(r)] }}</span></td>
                <td :class="[td, 'max-lg:hidden']"><span v-if="r.dryRun" :class="[admChip, 'bg-adm-subtle text-adm-meta']">dry_run · no escribe</span><span v-else class="text-adm-meta">Real</span></td>
                <td :class="[td, 'text-right text-adm-meta tabular-nums max-lg:hidden']">{{ runDuration(r) ?? dash }}</td>
                <td :class="[td, 'text-right tabular-nums']">{{ num(runFound(r)) }}</td>
                <td :class="[td, 'text-right font-medium tabular-nums']">{{ r.status === 'open' ? dash : runNew(r) }}</td>
                <td :class="[td, 'text-right tabular-nums']">{{ r.status === 'open' ? dash : r.duplicates }}</td>
                <td :class="[td, 'text-right tabular-nums']">{{ r.status === 'open' ? dash : runRejected(r) }}</td>
                <td :class="[td, 'text-right tabular-nums', runErrorCount(r) && 'font-medium text-adm-danger']">{{ r.status === 'open' ? dash : runErrorCount(r) }}</td>
              </tr>
              <tr v-if="expanded === r.id" :id="`run-${r.id}`" class="border-b border-adm-line bg-adm-side"><td /><td colspan="9" class="px-3 py-4"><AdminIngestRunDetail :run="r" /></td></tr>
            </template>
          </tbody>
        </table>
      </div>
      <ul class="divide-y divide-adm-line border-t border-adm-line md:hidden" aria-label="Recogidas de los últimos 30 días">
        <li v-for="r in runs" :key="r.id" class="px-4 py-3">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium tabular-nums">{{ runLabel(r.startedAt) }}</span>
            <span :class="[admChip, 'ml-auto', tones[runChip(r)]]"><component :is="icons[runChip(r)]" aria-hidden="true" />{{ RUN_CHIPS[runChip(r)] }}</span>
          </div>
          <p class="mt-1.5 text-xs text-adm-meta tabular-nums">
            <template v-if="r.status === 'open'">En curso…</template>
            <template v-else>{{ num(runFound(r)) }} encontrados · <b class="font-medium text-adm-fg">{{ runNew(r) }} nuevos</b> · {{ r.duplicates }} duplicados · {{ runRejected(r) }} rechazados<template v-if="runErrorCount(r)"> · <span class="font-medium text-adm-danger">{{ runErrorCount(r) }} {{ runErrorCount(r) === 1 ? 'error' : 'errores' }}</span></template></template><template v-if="r.dryRun"> · dry_run</template>
          </p>
          <button type="button" class="mt-1 min-h-11 text-xs underline underline-offset-2" :aria-expanded="expanded === r.id" :aria-controls="`runc-${r.id}`" @click="toggle(r.id)">{{ expanded === r.id ? 'Ocultar detalle' : 'Ver detalle' }}</button>
          <div v-if="expanded === r.id" :id="`runc-${r.id}`" class="mt-2"><AdminIngestRunDetail :run="r" /></div>
        </li>
      </ul>
      <p class="border-t border-adm-line px-4 py-3 text-xs text-adm-meta md:px-6">«Rechazados» = filas que la base de datos no aceptó (formato, fuera de alcance o tope de {{ RUN_ROW_LIMIT }} por recogida). Lo que tú rechazas está en Noticias y Agenda. Topes: 1 recogida abierta, 3 cada 24 h.</p>
    </template>
  </div>
</template>
