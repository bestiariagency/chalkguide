<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import type { UnknownColumn } from '~/utils/admin-import-parse'

/** Columns that are not recognised (README §13.2): Xavi decides before going on; they are ignored and their data not imported. */
defineProps<{ columns: UnknownColumn[]; ignored: string[] }>()
defineEmits<{ accept: []; other: [] }>()
</script>

<template>
  <section class="grid gap-3 rounded-lg border border-adm-warn/30 bg-adm-warn-soft p-4 text-[13px]" aria-labelledby="import-unknown">
    <div class="flex items-start gap-3">
      <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
      <div>
        <h2 id="import-unknown" class="font-semibold">{{ columns.length === 1 ? 'Hay 1 columna que no reconocemos' : `Hay ${columns.length} columnas que no reconocemos` }}</h2>
        <p class="mt-0.5 text-adm-meta">Si sigues, se ignoran y sus datos no se importan.</p>
      </div>
    </div>
    <ul class="grid gap-1.5">
      <li v-for="column in columns" :key="column.index" class="flex flex-wrap items-center gap-2">
        <span class="inline-grid h-[18px] min-w-[22px] place-items-center rounded-[3px] bg-adm-subtle px-1 font-mono text-[11px] text-adm-meta" :title="`Columna ${column.letter}`">{{ column.letter }}</span>
        <code class="font-mono text-xs">{{ column.key }}</code>
        <span v-if="column.suggestion" class="text-adm-meta">¿querías decir <code class="font-mono text-xs">{{ column.suggestion }}</code>?</span>
      </li>
    </ul>
    <p v-if="ignored.length" class="text-adm-meta">También se ignoran, sin pedir nada, las columnas de solo lectura del listado: <code class="font-mono text-xs">{{ ignored.join(', ') }}</code>.</p>
    <div class="flex flex-wrap gap-2">
      <button type="button" :class="admBtnPrimary" @click="$emit('accept')">Seguir sin {{ columns.length === 1 ? 'esa' : `esas ${columns.length}` }}</button>
      <button type="button" :class="admBtnGhost" @click="$emit('other')">Subir otro archivo</button>
    </div>
  </section>
</template>
