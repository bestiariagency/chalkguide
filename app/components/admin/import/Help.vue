<script setup lang="ts">
import { Download } from 'lucide-vue-next'
import type { ImportBatchInfo } from '~/services/admin/import'
import type { ItemInfo } from '~/utils/item-spec'

/** Right column of step 1 (README §13.2): template, how it works and the last import. */
defineProps<{ info: ItemInfo; last?: ImportBatchInfo | null; loaded?: boolean }>()
const RULES = [
  'La URL identifica cada ficha: si ya existe, se actualiza.',
  'Una celda vacía no borra nada. Para vaciar un dato, usa el editor.',
  'Todo o nada: si algo falla al escribir, no se guarda nada de ese envío.',
  'Nada se publica. Una ficha publicada recibe un borrador de cambios.',
  'Las fotos se suben antes a Medios; en el archivo va su nombre.',
]
</script>

<template>
  <aside class="grid content-start gap-4" aria-label="Ayuda para importar">
    <section :class="[admCard, 'p-4']">
      <h2 class="text-sm font-semibold">Plantilla de {{ info.nouns }}</h2>
      <p class="mt-1 text-[13px] text-adm-meta">Una hoja con su fila de claves y un ejemplo. Rellena desde la fila 7.</p>
      <div class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2">
        <a :href="`/chalkguide-plantilla-${info.route}.xlsx`" download :class="admBtnGhost"><Download aria-hidden="true" />Descargar plantilla (.xlsx)</a>
        <NuxtLink :to="`${adminPath(info.route)}?exportar=1`" class="text-[13px] text-adm-acc underline-offset-2 hover:underline">Exporta el listado en CSV, edítalo y súbelo aquí</NuxtLink>
      </div>
    </section>
    <section :class="[admCard, 'p-4']">
      <h2 class="text-sm font-semibold">Cómo funciona</h2>
      <ul class="mt-2 grid list-disc gap-1.5 pl-4 text-[13px] text-adm-meta marker:text-adm-muted">
        <li v-for="rule in RULES" :key="rule">{{ rule }}</li>
        <li v-if="info.route === 'rocodromos'">Horarios como «10:00-14:00, 17:00-23:00» o «Cerrado». Para cerrar a medianoche, escribe 24:00.</li>
      </ul>
    </section>
    <p class="px-1 text-[13px] text-adm-meta">
      <template v-if="last">Última importación de {{ info.nouns }}: <AdminTime :iso="last.createdAt" /> · {{ last.rowCount }} {{ last.rowCount === 1 ? 'fila' : 'filas' }}{{ last.status === 'undone' ? ' · deshecha' : '' }}.</template>
      <template v-else-if="loaded">Todavía no has importado {{ info.nouns }}.</template>
    </p>
  </aside>
</template>
