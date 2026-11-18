<script setup lang="ts">
import { FileSpreadsheet } from 'lucide-vue-next'

/**
 * Reading / checking (`#leyendo`, nothing is written) and importing (`#aplicando`). Up to 100 rows is one call: indeterminate
 * bar and no "Detener" (it would not undo anything). With more, a bar per chunk and "Detener" after the current chunk.
 */
const props = defineProps<{
  kind: 'reading' | 'applying'
  fileName: string
  type: string
  chunks: number
  chunk: number
  stopping?: boolean
}>()
defineEmits<{ cancel: []; stop: [] }>()
const multi = computed(() => props.kind === 'applying' && props.chunks > 1)
const percent = computed(() => (props.chunks ? Math.round(((props.chunk - 1) / props.chunks) * 100) : 0))
const text = computed(() =>
  props.kind === 'reading'
    ? `Leyendo el archivo y comprobándolo con tus ${props.type}. Todavía no se escribe nada…`
    : multi.value ? `Trozo ${props.chunk} de ${props.chunks}. Comprobando otra vez y escribiendo…` : 'Comprobando otra vez y escribiendo… o entran todas o ninguna.',
)
</script>

<template>
  <section class="mx-auto grid max-w-xl gap-4 py-10" aria-live="polite">
    <div v-if="fileName" class="inline-flex w-fit max-w-full items-center gap-2 rounded-md border border-adm-line bg-adm-elev px-2.5 py-1 text-[13px]">
      <FileSpreadsheet class="size-4 flex-none text-adm-meta" aria-hidden="true" /><code class="truncate font-mono text-xs">{{ fileName }}</code>
    </div>
    <div class="h-1.5 overflow-hidden rounded-full bg-adm-subtle" role="progressbar" aria-busy="true" :aria-label="kind === 'reading' ? 'Comprobando el archivo' : 'Importando'" :aria-valuenow="multi ? percent : undefined" aria-valuemin="0" aria-valuemax="100">
      <span v-if="multi" class="block h-full rounded-full bg-adm-primary transition-[width] duration-150 motion-reduce:transition-none" :style="{ width: `${Math.max(percent, 4)}%` }" />
      <span v-else class="block h-full w-full animate-pulse rounded-full bg-adm-primary/60 motion-reduce:animate-none" />
    </div>
    <p class="text-[13px] text-adm-meta focus:outline-none" tabindex="-1" data-step-title>{{ text }}</p>
    <div class="flex gap-2">
      <button v-if="kind === 'reading'" type="button" :class="admBtnGhost" @click="$emit('cancel')">Cancelar</button>
      <button v-else-if="multi" type="button" :class="admBtnGhost" :disabled="stopping" @click="$emit('stop')">{{ stopping ? 'Parando al acabar este trozo…' : 'Detener' }}</button>
    </div>
  </section>
</template>
