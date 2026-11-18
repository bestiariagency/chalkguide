<script setup lang="ts">
import { CircleAlert, Download, Info, Loader2, TriangleAlert } from 'lucide-vue-next'
import { purposeLabel, type ExportInitial, type ExportTarget } from '~/utils/admin-export'
import { agoLabel } from '~/utils/admin-madrid'

/**
 * Export modal of every listing (F6.15, D37; docs/design/admin/README.md §12). Inherits the filters of the view, counts
 * live and downloads with one `admin_export` call (exports and registers together). Mount it with `v-if` so each opening
 * starts fresh (the personal-data confirmation never survives a close).
 */
const props = defineProps<{ target: ExportTarget; initial?: ExportInitial; categoryOptions?: readonly AdminOption[] }>()
const open = defineModel<boolean>('open', { default: true })

const exp = useAdminExport(props.target, props.initial ?? {}, () => (open.value = false))
const { config, personal, draft, format, withBody, preset, purpose, confirmed, count, counting, countError, rowCount, recent, fileName, disabledReason, canDownload, preparing, checking, recount, cancel } = exp
const unit = computed(() => config.noun)
const slowCount = useDebouncedValue(exp.counting, 300)
const sameView = computed(() => draft.status === (props.initial?.status ?? config.defaultStatus))
const description = computed(() => (props.initial?.viewLabel && sameView.value ? `Con los filtros de la vista ${props.initial.viewLabel}. Puedes ajustarlos aquí.` : 'Elige qué filas incluir. Puedes ajustar los filtros aquí.'))
const columns = computed(() => count.value?.columns ?? [])
const reasonId = 'ex-reason'
const emptyRows = computed(() => !counting.value && !!count.value && !rowCount.value)

const recentLine = computed(() => {
  const r = recent.value
  if (r === undefined) return undefined
  if (r === null) return `Aún no has exportado ${unit.value}`
  const parts = [agoLabel(r.occurredAt), countOf(r.rowCount, 'fila', 'filas'), r.format.toUpperCase(), r.purpose ? purposeLabel(r.purpose) : '']
  return `Última exportación de ${unit.value}: ${parts.filter(Boolean).join(' · ')}`
})

const hasFilters = computed(() => Object.entries(draft.values).some(([key, value]) => key !== 'date_field' && !!value))
/** Quitar filtros: first the chips and fields; with none left, the Estado goes to «Todos» (the 0 may come from it). */
const canClear = computed(() => hasFilters.value || draft.status !== 'all')
function clearFilters() {
  if (hasFilters.value) draft.values = {}
  else draft.status = 'all'
}
// Esc = Cancelar while the file is being prepared (README §12.5).
function onKey(event: KeyboardEvent) {
  if (event.key === 'Escape' && preparing.value) void cancel()
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <AdminModal v-model:open="open" size="md" :title="`Exportar ${unit}`" :description="description" :busy="preparing">
    <div class="space-y-0">
      <AdminExportsSection label="Filas" label-id="ex-h-rows">
        <AdminExportsRows v-model:draft="draft" :config="config" :category-options="categoryOptions" />
      </AdminExportsSection>

      <AdminExportsSection label="Columnas" label-id="ex-h-cols">
        <AdminExportsColumns v-model:preset="preset" v-model:with-body="withBody" :config="config" :columns="columns" :format="format" />
      </AdminExportsSection>

      <AdminExportsSection label="Formato" label-id="ex-h-format">
        <AdminSegmented v-model="format" class="sm:grid sm:w-60 sm:grid-cols-2" labelledby="ex-h-format" fill :options="[{ value: 'csv', label: 'CSV' }, { value: 'json', label: 'JSON' }]" />
        <p class="text-xs text-adm-meta">
          {{ format === 'csv' ? 'Para Excel o Numbers: separado por punto y coma, decimales con coma y acentos bien (UTF-8).' : 'Para copias de seguridad o para pasar a otra herramienta: el mismo contenido, sin aplanar, con los datos de la exportación al principio.' }}
        </p>
      </AdminExportsSection>

      <AdminExportsSection v-if="personal && count && rowCount" label="Datos personales" label-id="ex-h-personal">
        <AdminExportsPersonal v-model:purpose="purpose" v-model:confirmed="confirmed" :rows="rowCount" :status="draft.status" />
      </AdminExportsSection>

      <AdminExportsSection v-if="countError || emptyRows || count?.truncated" label="Resultado" label-id="ex-h-result">
        <div v-if="countError" class="flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] leading-5 text-adm-danger" role="alert">
          <CircleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
          <span class="min-w-0 flex-1"><b>No se han podido contar las filas.</b> Código: <span class="font-mono">{{ countError }}</span>.</span>
          <button type="button" :class="[admBtnGhost, 'flex-none']" @click="recount()">Reintentar</button>
        </div>
        <div v-else-if="emptyRows" class="flex items-start gap-2 rounded-lg bg-adm-subtle px-3 py-2 text-[13px] leading-5" role="status">
          <Info class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />
          <span class="min-w-0 flex-1">Ninguna fila con estos filtros. Sin filas no se genera archivo ni se registra nada.</span>
          <button v-if="canClear" type="button" :class="[admBtnGhost, 'flex-none']" @click="clearFilters">Quitar filtros</button>
        </div>
        <p v-else-if="count?.truncated" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn" role="status">
          <TriangleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
          <span>Hay {{ fmtInt(count.total) }} filas y un archivo admite {{ fmtInt(count.rowCount) }} como máximo: se exportan las primeras. Acota con las fechas para sacar el resto.</span>
        </p>
      </AdminExportsSection>

      <div v-if="preparing" class="pt-3" role="status">
        <div class="h-1 overflow-hidden rounded-full bg-adm-subtle"><div class="h-full w-1/3 animate-pulse rounded-full bg-adm-acc motion-reduce:animate-none" /></div>
        <p class="sr-only">Preparando el archivo…</p>
      </div>

      <div class="space-y-1 border-t border-adm-line pt-3 text-xs text-adm-meta">
        <p v-if="recentLine">{{ recentLine }}</p>
        <p>Cada exportación queda registrada: qué, filtros, columnas, formato, filas{{ personal ? ' y para qué' : '' }}. Nunca los datos.</p>
      </div>
    </div>

    <template #footer>
      <div class="flex w-full flex-wrap items-center justify-end gap-2">
      <div class="mr-auto min-w-0 text-[13px] max-md:mr-0 max-md:basis-full" aria-live="polite">
        <template v-if="preparing"><b>Preparando {{ countOf(rowCount, 'fila', 'filas') }}…</b></template>
        <template v-else-if="checking"><b>Comprobando el registro…</b></template>
        <template v-else-if="countError">Sin recuento</template>
        <template v-else-if="counting || !count">
          <span v-if="slowCount" class="block h-4 w-40 animate-pulse rounded bg-adm-subtle motion-reduce:animate-none" aria-hidden="true" /><span class="sr-only">Contando filas…</span>
        </template>
        <template v-else><b class="tabular-nums">{{ fmtInt(rowCount) }}</b> {{ rowCount === 1 ? config.nounOne : config.noun }} · {{ format.toUpperCase() }}</template>
        <span v-if="count && rowCount && !countError" class="block truncate font-mono text-xs text-adm-meta" :title="fileName">{{ fileName }}</span>
      </div>
      <button type="button" :class="[admBtnGhost, 'max-md:flex-1']" @click="preparing ? cancel() : (open = false)">Cancelar</button>
      <button type="button" :class="[admBtnPrimary, 'max-md:flex-1']" :disabled="!canDownload || preparing" :aria-busy="preparing || undefined" :aria-describedby="disabledReason ? reasonId : undefined" @click="exp.download()">
        <Loader2 v-if="preparing" class="animate-adm-spin" aria-hidden="true" /><Download v-else aria-hidden="true" />
        {{ preparing ? 'Preparando…' : rowCount ? `Descargar ${countOf(rowCount, 'fila', 'filas')}` : 'Descargar' }}
      </button>
      <p v-if="disabledReason" :id="reasonId" class="basis-full text-right text-xs text-adm-meta max-md:text-left">{{ disabledReason }}</p>
      </div>
    </template>
  </AdminModal>
</template>
