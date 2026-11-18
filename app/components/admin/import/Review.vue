<script setup lang="ts">
import { FileSpreadsheet, TriangleAlert } from 'lucide-vue-next'
import type { ParsedImport } from '~/utils/admin-import-parse'
import type { ImportFileMeta } from '~/composables/useAdminImportFile'
import { matchesReviewFilter, type ReviewCounts, type ReviewFilter, type ReviewRow } from '~/utils/admin-import-report'

/** Step 2 (README §13.3): nothing is written yet. The review opens filtered on "Con error" when there are errors. */
const props = defineProps<{ rows: ReviewRow[]; counts: ReviewCounts; parsed: ParsedImport; meta: ImportFileMeta; fileName: string; changed: number[] }>()
const emit = defineEmits<{ again: []; check: []; separator: [value: ';' | ','] ; download: [] }>()

const filter = ref<ReviewFilter>(props.counts.errors > 0 ? 'errors' : 'all')
// A new check (photos, stale) can add or clear errors: reopen on the useful view.
watch(() => props.meta.readAt + props.counts.errors, () => (filter.value = props.counts.errors > 0 ? 'errors' : filter.value))
const visible = computed(() => props.rows.filter((row) => matchesReviewFilter(row, filter.value)))
const TITLES: Record<ReviewFilter, string> = { all: 'Todas las filas', created: 'Nuevas', changed: 'Actualizan', unchanged: 'Sin cambios', warnings: 'Con avisos', errors: 'Con error' }
const title = computed(() => `${TITLES[filter.value]} · ${visible.value.length}`)
const missingCovers = computed(() => props.rows.filter((r) => r.report.issues.some((i) => i.code === 'media_not_found' && i.column === 'cover')).length)
const SEPARATORS = [{ value: ';' as const, label: ';' }, { value: ',' as const, label: ',' }]
const separator = computed({ get: () => props.meta.separator ?? ';', set: (value: ';' | ',') => emit('separator', value) })
</script>

<template>
  <div class="grid gap-4">
    <div class="flex flex-wrap items-center gap-x-3 gap-y-2 rounded-lg border border-adm-line bg-adm-elev px-3 py-2 text-[13px]">
      <FileSpreadsheet class="size-4 flex-none text-adm-meta" aria-hidden="true" />
      <code class="font-mono text-xs break-all">{{ fileName }}</code>
      <span class="text-adm-meta">{{ meta.sheet ? `hoja «${meta.sheet}» · ` : '' }}{{ rows.length }} filas · leído hace un momento</span>
      <div v-if="meta.separator" class="flex items-center gap-1.5">
        <span id="import-sep" class="text-adm-meta">Separador</span><AdminSegmented v-model="separator" :options="SEPARATORS" labelledby="import-sep" />
      </div>
      <details class="relative">
        <summary class="cursor-pointer text-adm-acc">{{ parsed.columns.length }} columnas reconocidas</summary>
        <div class="mt-1.5 grid max-w-xl gap-1 text-xs text-adm-meta">
          <p v-if="parsed.missing.length"><b class="font-medium text-adm-fg">No vienen en el archivo (no se tocan):</b> {{ parsed.missing.join(', ') }}</p>
          <p v-if="parsed.ignored.length"><b class="font-medium text-adm-fg">Se ignoran (solo lectura):</b> {{ parsed.ignored.join(', ') }}</p>
          <p v-if="parsed.unknown.length"><b class="font-medium text-adm-fg">No reconocidas (se ignoran):</b> {{ parsed.unknown.map((c) => c.key).join(', ') }}</p>
        </div>
      </details>
      <button type="button" :class="[admBtnGhost, 'ml-auto']" @click="emit('again')">Cambiar archivo</button>
    </div>
    <p v-if="meta.commaFallback" class="flex items-start gap-2 rounded-lg border border-adm-line bg-adm-subtle p-3 text-[13px]" role="status">
      La cabecera solo se puede leer con comas, así que se ha leído con comas. Si no es lo que esperabas, cambia el separador.
    </p>

    <AdminImportStats v-model="filter" :counts="counts" controls="import-table" />

    <div v-if="missingCovers" class="flex flex-wrap items-start gap-3 rounded-lg border border-adm-warn/30 bg-adm-warn-soft p-3 text-[13px]">
      <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
      <p class="min-w-0 flex-1">{{ missingCovers }} {{ missingCovers === 1 ? 'portada no está' : 'portadas no están' }} en Medios todavía. Puedes importar igual y asignarlas después, o subirlas ahora y comprobar de nuevo sin volver a subir el archivo.</p>
      <div class="flex flex-wrap gap-2">
        <a :href="adminPath('medios')" target="_blank" rel="noopener" :class="admBtnGhost">Abrir Medios<span class="sr-only"> (pestaña nueva)</span> ↗</a>
        <button type="button" :class="admBtnGhost" @click="emit('check')">Comprobar fotos</button>
      </div>
    </div>

    <AdminImportTable id="import-table" :title="title" :rows="visible" :letters="parsed.letters" :names="parsed.names" :changed="changed" :errors="counts.errors" @download="emit('download')" />
  </div>
</template>
