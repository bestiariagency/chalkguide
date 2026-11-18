<script setup lang="ts">
import { CircleX, Info } from 'lucide-vue-next'
import type { FileFormatError } from '~/utils/admin-import-file'
import { IMPORT_SPECS } from '~/utils/admin-import-spec'
import { IMPORT_MAX_ROWS } from '~/utils/admin-import-parse'
import type { ItemInfo } from '~/utils/item-spec'

/** Error of the file itself (README §13.2): what happens and what to do, with a way out when there is one. `role=alert`. */
const props = defineProps<{ error: FileFormatError; fileName: string; info: ItemInfo }>()

const ROUTES = { gym: 'rocodromos', resoler: 'resoladores', shoe: 'pies-de-gato' } as const
const mb = (bytes: number) => (bytes / 1024 / 1024).toFixed(1).replace('.', ',')
const e = computed(() => props.error)
const kind = computed<'error' | 'info'>(() => (e.value.code === 'vacio' ? 'info' : 'error'))
const other = computed(() => (e.value.code === 'tipo' ? e.value.found : undefined))
const text = computed((): string => {
  const v = e.value
  switch (v.code) {
    case 'formato': return 'Este archivo no se puede leer. Sube un .xlsx o un .csv. En Numbers: Archivo › Exportar a › Excel.'
    case 'grande-bytes': return `Pesa ${mb(v.size)} MB y el máximo es 5 MB. Divídelo en dos archivos.`
    case 'plantilla': return 'No encontramos la fila de claves. Es una plantilla anterior: descarga la nueva y pega tus filas debajo; las columnas siguen en el mismo orden.'
    case 'tipo': return `Este archivo es de ${IMPORT_SPECS[v.found].sheet.toLowerCase()} y estás en ${props.info.title}.`
    case 'falta': return `Falta la columna «${v.key}» (${v.key === 'slug' ? 'URL' : 'nombre'}). ${v.key === 'slug' ? 'Es la que dice qué ficha es cada fila: sin ella no se puede importar.' : 'Cada ficha necesita un nombre.'}`
    case 'vacio': return 'El archivo no tiene filas de datos. Rellena desde la fila 7 de la plantilla y vuelve a subirlo.'
    case 'grande': return `Tiene ${v.rows} filas y el máximo es ${IMPORT_MAX_ROWS}. Divídelo en dos archivos.`
    default: return 'Este archivo no se puede importar.'
  }
})
const download = computed(() => ['plantilla', 'falta'].includes(e.value.code))
</script>

<template>
  <div :class="['flex items-start gap-3 rounded-lg border p-3 text-[13px]', kind === 'error' ? 'border-adm-danger/30 bg-adm-danger-soft' : 'border-adm-line bg-adm-subtle']" role="alert">
    <CircleX v-if="kind === 'error'" class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />
    <Info v-else class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />
    <div class="grid min-w-0 gap-2">
      <p><code v-if="fileName" class="mr-1 break-all rounded bg-adm-elev/70 px-1 font-mono text-xs">{{ fileName }}</code>{{ text }}</p>
      <div v-if="download || other" class="flex flex-wrap gap-2">
        <a v-if="download" :href="`/chalkguide-plantilla-${info.route}.xlsx`" download :class="admBtnGhost">Descargar plantilla nueva</a>
        <NuxtLink v-if="other" :to="`${adminPath(ROUTES[other])}/importar`" :class="admBtnGhost">Importar {{ IMPORT_SPECS[other].sheet.toLowerCase() }}</NuxtLink>
      </div>
    </div>
  </div>
</template>
