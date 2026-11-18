<script setup lang="ts">
import type { Editor } from '@tiptap/vue-3'
import { TABLE_MAX_COLUMNS, TABLE_MAX_ROWS } from '~/utils/article-figure'
import { hasHeaderRow, tableSize } from '~/utils/article-table'

/**
 * Bar of the table block, shown while the cursor is inside one: add/remove row or column (up to
 * 5 columns and 30 rows), first row as header, remove table. No merged cells, no colours.
 */
const props = defineProps<{ editor: Editor | null; tick: number; disabled?: boolean }>()
const size = computed(() => (props.tick >= 0 && props.editor ? tableSize(props.editor.state) : { rows: 0, columns: 0 }))
const header = computed(() => (props.tick >= 0 && props.editor ? hasHeaderRow(props.editor.state) : false))
const run = (fn: (chain: ReturnType<Editor['chain']>) => ReturnType<Editor['chain']>) => props.editor && fn(props.editor.chain().focus()).run()
const btn = `${admBtnQuiet} !h-8 !px-2.5 text-xs max-md:!h-11`
</script>

<template>
  <div role="toolbar" aria-label="Tabla" class="mx-auto flex max-w-[760px] flex-wrap items-center gap-1 border-t border-adm-line px-2 py-1 md:px-6">
    <button type="button" :class="btn" :disabled="disabled || size.rows >= TABLE_MAX_ROWS" @click="run((c) => c.addRowAfter())">+ Fila</button>
    <button type="button" :class="btn" :disabled="disabled || size.columns >= TABLE_MAX_COLUMNS" @click="run((c) => c.addColumnAfter())">+ Columna</button>
    <button type="button" :class="btn" :disabled="disabled || size.rows <= 1" @click="run((c) => c.deleteRow())">Quitar fila</button>
    <button type="button" :class="btn" :disabled="disabled || size.columns <= 1" @click="run((c) => c.deleteColumn())">Quitar columna</button>
    <label class="flex min-h-8 items-center gap-1.5 px-2 text-xs text-adm-fg max-md:min-h-11">
      <input type="checkbox" class="size-4 accent-adm-acc" :checked="header" :disabled="disabled" @change="run((c) => c.toggleHeaderRow())" />
      Primera fila como encabezado
    </label>
    <button type="button" :class="[btn, 'ml-auto !text-adm-danger']" :disabled="disabled" @click="run((c) => c.deleteTable())">Quitar tabla</button>
    <span class="w-full text-[11px] text-adm-muted">Hasta {{ TABLE_MAX_COLUMNS }} columnas y {{ TABLE_MAX_ROWS }} filas. Las columnas con cifras se alinean solas a la derecha.</span>
  </div>
</template>
