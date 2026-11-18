<script setup lang="ts">
import { FilePlus, GitBranch, Info, RefreshCcw, ShieldCheck, Undo2, XCircle } from 'lucide-vue-next'
import type { Component } from 'vue'
import type { ReviewCounts } from '~/utils/admin-import-report'

/** Confirmation (README §13.4): what is going to happen, always, because updates cannot be undone. */
const props = defineProps<{ counts: ReviewCounts; nouns: string; withoutErrors: boolean }>()
defineEmits<{ confirm: [] }>()
const open = defineModel<boolean>('open', { required: true })
const write = computed(() => props.counts.created + props.counts.changed)
const plain = computed(() => props.counts.changed - props.counts.drafted)
const lines = computed(() => ([
  { icon: FilePlus, show: props.counts.created > 0, text: props.counts.created === 1 ? 'Se crea 1 ficha nueva, sin publicar.' : `Se crean ${props.counts.created} fichas nuevas, sin publicar.` },
  { icon: RefreshCcw, show: plain.value > 0, text: `${plain.value === 1 ? 'Se actualiza 1' : `Se actualizan ${plain.value}`} sin publicar: cambian los campos que traen dato.`, strong: 'Esto no se puede deshacer.' },
  { icon: GitBranch, show: props.counts.drafted > 0, text: props.counts.drafted === 1 ? '1 ficha publicada recibe un borrador de cambios y el sitio no cambia.' : `${props.counts.drafted} fichas publicadas reciben un borrador de cambios y el sitio no cambia.` },
  { icon: XCircle, show: props.withoutErrors && props.counts.errors > 0, text: props.counts.errors === 1 ? '1 fila con error queda fuera y no se envía.' : `${props.counts.errors} filas con error quedan fuera y no se envían.` },
  { icon: Undo2, show: props.counts.created > 0, text: 'Las fichas creadas se pueden deshacer mientras no se toquen.' },
  { icon: ShieldCheck, show: true, text: 'Nada se publica ni se borra, y queda en Actividad.' },
  { icon: Info, show: true, text: 'Antes de escribir se comprueba todo otra vez.' },
] as { icon: Component; show: boolean; text: string; strong?: string }[]).filter((line) => line.show))
</script>

<template>
  <AdminModal v-model:open="open" :title="`Importar ${write} ${nouns}`">
    <ul class="grid gap-2.5 text-[13px]">
      <li v-for="line in lines" :key="line.text" class="flex items-start gap-2.5">
        <component :is="line.icon" class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />
        <span>{{ line.text }} <b v-if="line.strong" class="font-semibold">{{ line.strong }}</b></span>
      </li>
    </ul>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus @click="open = false">Volver a la revisión</button>
      <button type="button" :class="admBtnPrimary" @click="$emit('confirm')">Importar {{ write }} {{ nouns }}</button>
    </template>
  </AdminModal>
</template>
