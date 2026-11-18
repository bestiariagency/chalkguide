<script setup lang="ts">
import { CircleCheck, Download, GitBranch, ImageOff, OctagonAlert, Plus } from 'lucide-vue-next'
import { reviewChip, type ReviewRow } from '~/utils/admin-import-report'
import { blockerShort, coverStatus } from '~/utils/admin-import-texts'

/** Review table (README §13.3): variable-height rows aligned to the top, 25 per page, errors marked with a bar and an icon. */
const props = defineProps<{ id: string; title: string; rows: ReviewRow[]; letters: Record<string, string>; names: Record<string, string>; changed: number[]; errors: number }>()
defineEmits<{ download: [] }>()
const query = reactive({ page: 0, pageSize: 25 })
watch(() => [props.rows.length, props.title], () => (query.page = 0))
const shown = computed(() => props.rows.slice(query.page * query.pageSize, (query.page + 1) * query.pageSize))
const TONES = { acc: 'bg-adm-acc-soft text-adm-acc', neutral: 'bg-adm-subtle text-adm-fg', hidden: 'bg-adm-subtle text-adm-meta outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line', rev: 'bg-adm-st-rev-bg text-adm-st-rev', danger: 'bg-adm-danger-soft text-adm-danger' }
const publishable = (row: ReviewRow) => (row.report.blockers ?? []).length === 0
</script>

<template>
  <section :id="id" :class="[admCard, 'overflow-hidden']" :aria-labelledby="`${id}-title`" tabindex="-1">
    <header class="flex flex-wrap items-center gap-2 border-b border-adm-line px-3 py-2">
      <h2 :id="`${id}-title`" class="text-sm font-semibold">{{ title }}</h2>
      <button v-if="errors > 0" type="button" :class="[admBtnGhost, 'ml-auto']" @click="$emit('download')"><Download aria-hidden="true" />Descargar errores</button>
    </header>
    <div class="overflow-x-auto">
      <table class="w-full min-w-[960px] border-collapse text-[13px]" :aria-labelledby="`${id}-title`">
        <thead class="bg-adm-subtle text-left text-xs text-adm-meta">
          <tr>
            <th scope="col" class="w-14 px-3 py-2 font-medium">Fila</th>
            <th scope="col" class="w-44 px-3 py-2 font-medium">Qué pasará</th>
            <th scope="col" class="w-56 px-3 py-2 font-medium">Ficha</th>
            <th scope="col" class="w-36 px-3 py-2 font-medium">Portada</th>
            <th scope="col" class="px-3 py-2 font-medium">Errores, avisos y cambios</th>
            <th scope="col" class="w-36 px-3 py-2 font-medium">Al publicar</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in shown" :key="row.row" :class="['border-t border-adm-line align-top', changed.includes(row.row) && 'bg-adm-st-rev-bg/40']">
            <td :class="['px-3 py-2.5 font-mono text-xs text-adm-meta tabular-nums', row.report.action === 'error' && 'shadow-[inset_3px_0_0_var(--adm-danger)]']">{{ row.row }}</td>
            <td class="px-3 py-2.5">
              <span :class="[admChip, TONES[reviewChip(row.report).tone]]">
                <Plus v-if="reviewChip(row.report).icon === 'plus'" aria-hidden="true" /><GitBranch v-else-if="reviewChip(row.report).icon === 'branch'" aria-hidden="true" />
                {{ reviewChip(row.report).label }}
              </span>
              <p v-if="changed.includes(row.row)" class="mt-1 text-xs font-medium text-adm-st-rev">Ha cambiado desde la revisión</p>
            </td>
            <td class="px-3 py-2.5">
              <p :class="['font-medium break-words', !row.name && 'text-adm-muted italic']">{{ row.name || 'Sin nombre' }}</p>
              <code class="font-mono text-xs break-all text-adm-meta">{{ row.slug || '(sin URL)' }}</code>
            </td>
            <td class="px-3 py-2.5 text-[13px]">
              <span v-if="row.report.action === 'error'" class="text-adm-muted">—</span>
              <span v-else :class="['inline-flex items-center gap-1.5', coverStatus(row.report.issues, row.cover).ok ? 'text-adm-meta' : 'text-adm-warn']">
                <CircleCheck v-if="coverStatus(row.report.issues, row.cover).ok" class="size-3.5 text-adm-ok" aria-hidden="true" /><ImageOff v-else class="size-3.5" aria-hidden="true" />
                {{ coverStatus(row.report.issues, row.cover).label }}
              </span>
              <code v-if="row.cover" class="mt-0.5 block font-mono text-xs break-all text-adm-muted">{{ row.cover }}</code>
            </td>
            <td class="px-3 py-2.5"><AdminImportIssues :row="row" :letters="letters" :names="names" /></td>
            <td class="px-3 py-2.5 text-[13px] whitespace-nowrap">
              <span v-if="row.report.action === 'error'" class="text-adm-muted">—</span>
              <span v-else-if="!publishable(row)" class="inline-flex items-center gap-1.5 text-adm-danger"><OctagonAlert class="size-3.5" aria-hidden="true" />{{ blockerShort(row.report.blockers ?? []) }}</span>
              <span v-else-if="row.report.action === 'drafted'" :class="[admChip, 'bg-adm-st-rev-bg text-adm-st-rev']" title="Se publican una a una, con su diff, desde el listado">Publicar cambios</span>
              <span v-else-if="row.report.hidden" class="text-adm-meta">Oculta</span>
              <span v-else class="inline-flex items-center gap-1.5 text-adm-ok"><CircleCheck class="size-3.5" aria-hidden="true" />Lista</span>
            </td>
          </tr>
          <tr v-if="!shown.length"><td colspan="6" class="px-3 py-10 text-center text-adm-meta">Ninguna fila con este filtro.</td></tr>
        </tbody>
      </table>
    </div>
    <AdminTablePager v-model:page="query.page" v-model:page-size="query.pageSize" :total="rows.length" />
    <footer class="flex flex-wrap gap-x-4 gap-y-1 border-t border-adm-line px-3 py-2 text-xs text-adm-meta">
      <span>Error: la fila no se importa.</span><span>Bloqueará publicar: entra, pero la ficha no estará lista.</span><span>Aviso: no bloquea.</span>
    </footer>
  </section>
</template>
