<script setup lang="ts">
import { FileSpreadsheet } from 'lucide-vue-next'

/** Drop zone (README §13.2): a real `input[type=file]` inside the `label`, so it works with the keyboard. */
const emit = defineEmits<{ file: [file: File] }>()
const { over } = useFileDrop((files) => files[0] && emit('file', files[0]))
const input = ref<HTMLInputElement>()
function pick(event: Event) {
  const target = event.target as HTMLInputElement
  const file = target.files?.[0]
  if (file) emit('file', file)
  target.value = ''
}
</script>

<template>
  <label
    :class="[
      'flex cursor-pointer flex-col items-center gap-2 rounded-xl border-2 border-dashed px-6 py-12 text-center transition-colors duration-150 has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc',
      over ? 'border-adm-acc bg-adm-acc-soft' : 'border-adm-line-strong bg-adm-elev hover:border-adm-control hover:bg-adm-subtle',
    ]"
  >
    <span class="grid size-10 place-items-center rounded-[10px] bg-adm-subtle text-adm-meta"><FileSpreadsheet class="size-5" aria-hidden="true" /></span>
    <span class="text-sm font-semibold">Elige un archivo o arrástralo aquí</span>
    <span class="text-[13px] text-adm-meta">.xlsx o .csv · hasta 500 filas y 5 MB</span>
    <input ref="input" type="file" class="sr-only" accept=".xlsx,.csv,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" @change="pick" />
  </label>
</template>
