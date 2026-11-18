<script setup lang="ts">
import { CircleCheck, TriangleAlert } from 'lucide-vue-next'
import type { ImportOutcome } from '~/composables/useAdminImport'
import type { ImportTotals } from '~/utils/admin-import-report'
import type { ItemInfo } from '~/utils/item-spec'

/** Step 4 (README §13.5): what was written, how to undo it, and what to do now (one card per action). */
const props = defineProps<{
  info: ItemInfo
  totals: ImportTotals
  outcome: ImportOutcome
  excluded: number
  fileRows: number
  chunks: number
  failure?: string
  undone: boolean
  undoing: boolean
  canUndo: boolean
}>()
const emit = defineEmits<{ undo: []; again: []; errors: [] }>()
const confirmUndo = ref(false)
const written = computed(() => props.totals.created + props.totals.updated + props.totals.drafted)
const processed = computed(() => written.value + props.totals.unchanged)
const figures = computed(() => [
  { label: 'Creadas', n: props.totals.created, note: 'Sin publicar' },
  { label: 'Actualizadas', n: props.totals.updated + props.totals.drafted, note: props.totals.drafted ? `${props.totals.drafted} publicadas, con borrador` : undefined },
  { label: 'Sin tocar', n: props.totals.unchanged },
  { label: 'Fuera', n: props.excluded, note: props.excluded ? 'Con error' : undefined },
])
const route = computed(() => adminPath(props.info.route))
async function doUndo() {
  emit('undo')
  confirmUndo.value = false
}
</script>

<template>
  <section class="mx-auto grid max-w-3xl gap-5 py-6" aria-labelledby="import-result">
    <div :class="['flex items-start gap-3 rounded-lg border p-4', outcome === 'done' ? 'border-adm-ok/30 bg-adm-ok-soft' : 'border-adm-warn/30 bg-adm-warn-soft']">
      <CircleCheck v-if="outcome === 'done'" class="mt-0.5 size-5 flex-none text-adm-ok" aria-hidden="true" />
      <TriangleAlert v-else class="mt-0.5 size-5 flex-none text-adm-warn-icon" aria-hidden="true" />
      <div class="grid gap-1 text-[13px]">
        <h2 id="import-result" class="text-base font-semibold focus:outline-none" tabindex="-1">{{ outcome === 'done' ? 'Importación terminada' : outcome === 'stopped' ? 'Importación detenida' : 'Importación a medias' }}</h2>
        <p v-if="outcome === 'done'">{{ written }} {{ written === 1 ? 'ficha guardada' : 'fichas guardadas' }}, ninguna publicada. Queda en Actividad.</p>
        <template v-else>
          <p>Archivo de {{ countOf(fileRows, 'fila', 'filas') }} en {{ countOf(chunks, 'trozo', 'trozos') }} de 100. Procesadas: {{ countOf(processed, 'fila', 'filas') }} ({{ countOf(written, 'escrita', 'escritas') }}, {{ totals.unchanged }} sin cambios).<template v-if="processed < fileRows"> El resto no se procesó.</template></p>
          <p v-if="failure">{{ failure }}</p>
          <p>Puedes subir el archivo de nuevo (es seguro: lo ya escrito sale «Sin cambios») o deshacer lo escrito.</p>
        </template>
        <div class="mt-1 flex flex-wrap gap-2">
          <button v-if="outcome !== 'done'" type="button" :class="admBtnPrimary" @click="emit('again')">Subir de nuevo</button>
          <button v-if="canUndo && !undone && written > 0" type="button" :class="admBtnGhost" :disabled="undoing" :aria-busy="undoing || undefined" @click="confirmUndo = true">Deshacer importación…</button>
          <span v-if="undone" class="inline-flex items-center text-adm-meta">Importación deshecha.</span>
        </div>
      </div>
    </div>

    <dl class="grid grid-cols-2 gap-2 md:grid-cols-4">
      <div v-for="figure in figures" :key="figure.label" :class="[admCard, 'grid px-3 py-2.5']">
        <dt class="row-start-2 text-xs text-adm-meta">{{ figure.label }}</dt>
        <dd class="row-start-1 text-xl leading-7 font-semibold tabular-nums">{{ figure.n }}</dd>
        <dd v-if="figure.note" class="row-start-3 text-xs text-adm-muted">{{ figure.note }}</dd>
      </div>
    </dl>

    <AdminImportNext :totals="totals" :outcome="outcome" :excluded="excluded" :route="route" @errors="emit('errors')" @again="emit('again')" />

    <AdminModal v-model:open="confirmUndo" title="¿Deshacer la importación?" :busy="undoing">
      <ul class="grid list-disc gap-1.5 pl-4 text-[13px]">
        <li v-if="totals.created > 0">{{ totals.created === 1 ? 'Se borra la creada, si nadie la ha tocado.' : `Se borran las ${totals.created} creadas, si nadie las ha tocado.` }}</li>
        <li v-if="totals.drafted > 0">Se descartan los borradores nuevos de las publicadas.</li>
        <li v-if="totals.updated > 0"><b class="font-semibold">{{ totals.updated === 1 ? 'La actualizada sin publicar no vuelve atrás.' : `Las ${totals.updated} actualizadas sin publicar no vuelven atrás.` }}</b></li>
      </ul>
      <template #footer>
        <button type="button" :class="admBtnGhost" data-autofocus @click="confirmUndo = false">Cancelar</button>
        <button type="button" :class="admBtnDanger" @click="doUndo">Deshacer importación</button>
      </template>
    </AdminModal>
  </section>
</template>
