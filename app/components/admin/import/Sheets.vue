<script setup lang="ts">
import type { SheetInfo } from '~/utils/admin-import-file'

/** Several sheets and none named like the type (README §13.2, `#hojas`): radios with the rows of each; empty ones disabled. */
defineProps<{ sheets: SheetInfo[]; fileName: string; type: string }>()
const emit = defineEmits<{ choose: [name: string]; other: [] }>()
const choice = ref('')
</script>

<template>
  <section :class="[admCard, 'grid gap-3 p-4']" aria-labelledby="import-sheets">
    <div>
      <h2 id="import-sheets" class="text-sm font-semibold">¿Qué hoja importamos?</h2>
      <p class="mt-0.5 text-[13px] text-adm-meta"><code class="font-mono text-xs">{{ fileName }}</code> no tiene una hoja que se llame «{{ type }}».</p>
    </div>
    <fieldset class="grid gap-1.5">
      <legend class="sr-only">Hoja del archivo</legend>
      <label v-for="sheet in sheets" :key="sheet.name" :class="['flex items-center gap-2 text-[13px]', sheet.rows === 0 && 'text-adm-muted']">
        <input v-model="choice" type="radio" name="import-sheet" :value="sheet.name" :disabled="sheet.rows === 0" class="size-4 accent-adm-primary" />
        {{ sheet.name }} <span class="text-adm-meta tabular-nums">· {{ sheet.rows }} {{ sheet.rows === 1 ? 'fila' : 'filas' }}{{ sheet.rows === 0 ? ' (vacía)' : '' }}</span>
      </label>
    </fieldset>
    <div class="flex flex-wrap gap-2">
      <button type="button" :class="admBtnPrimary" :disabled="!choice" @click="emit('choose', choice)">Usar esta hoja</button>
      <button type="button" :class="admBtnGhost" @click="$emit('other')">Subir otro archivo</button>
    </div>
  </section>
</template>
