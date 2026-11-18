<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import { STAT_LABEL_MAX, STAT_MAX_ROWS, STAT_VALUE_MAX, STATS_FIELD, statId, type StatRow } from '~/utils/admin-author-stats'
import { changedBar } from '~/utils/editor-classes'

/**
 * Ajustes › Autor del sitio › «En números» (README §17.2): up to 2 written figures (figure ≤ 24,
 * Spanish label ≤ 60, English label ≤ 60 and optional) and, read-only, the 2 calculated ones.
 */
const props = defineProps<{ errors: Record<string, string>; changed: boolean; calc: { gyms: number; shoes: number } | null }>()
const rows = defineModel<StatRow[]>('rows', { required: true })
const emit = defineEmits<{ add: []; remove: [index: number] }>()
const full = computed(() => rows.value.length >= STAT_MAX_ROWS)
const bar = computed(() => changedBar(props.changed))
</script>

<template>
  <fieldset :class="['rounded-lg border border-adm-line p-4', bar]" aria-describedby="stats-help">
    <legend class="-ml-1 flex items-center gap-1.5 px-1 text-sm font-medium">
      «En números»<span v-if="changed" class="text-[11px] font-medium text-adm-st-rev">Sin guardar</span>
    </legend>
    <p id="stats-help" class="text-xs text-adm-meta">Hasta 2 cifras que escribes tú. Las otras 2 se calculan solas. Una fila vacía no se guarda.</p>
    <ol v-if="rows.length" class="mt-3 space-y-4 sm:space-y-3">
      <li v-for="(row, index) in rows" :key="index" class="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-x-3 gap-y-3 sm:grid-cols-[8rem_minmax(0,1fr)_minmax(0,1fr)_auto]">
        <AdminTextField v-model="row.value" :name="statId(index, 'value')" :label="`Cifra ${index + 1}`" mono required :max="STAT_VALUE_MAX" :error="errors[statId(index, 'value')]" placeholder="12" />
        <div class="max-sm:order-2 max-sm:col-span-2 sm:col-span-1 sm:col-start-2 sm:row-start-1">
          <AdminTextField v-model="row.label_es" :name="statId(index, 'label_es')" :label="`Etiqueta de la cifra ${index + 1}`" lang="ES" required :max="STAT_LABEL_MAX" :error="errors[statId(index, 'label_es')]" placeholder="años escalando" />
        </div>
        <div class="max-sm:order-3 max-sm:col-span-2 sm:col-span-1 sm:col-start-3 sm:row-start-1">
          <AdminTextField v-model="row.label_en" :name="statId(index, 'label_en')" :label="`Etiqueta de la cifra ${index + 1}`" lang="EN" :max="STAT_LABEL_MAX" :error="errors[statId(index, 'label_en')]" placeholder="Opcional" />
        </div>
        <button type="button" :class="[admBtnQuiet, 'mt-[22px] max-md:min-h-11 max-sm:order-1 sm:col-start-4 sm:row-start-1']" @click="emit('remove', index)">Quitar<span class="sr-only"> la cifra {{ index + 1 }}</span></button>
      </li>
    </ol>
    <div class="mt-3 flex flex-wrap items-center gap-3">
      <button type="button" :name="STATS_FIELD" :class="[admBtnGhost, 'max-md:min-h-11']" :disabled="full" aria-describedby="stats-full" @click="emit('add')"><Plus aria-hidden="true" />Añadir cifra</button>
      <p id="stats-full" class="text-xs text-adm-meta">{{ full ? 'Ya tienes las 2 cifras. Quita una para añadir otra.' : '' }}</p>
    </div>
    <div class="mt-4 border-t border-adm-line pt-3">
      <p class="text-xs font-medium text-adm-meta">Se calculan solas</p>
      <ul class="mt-2 grid grid-cols-2 gap-2 text-sm">
        <li class="rounded-md border border-dashed border-adm-line-strong px-3 py-2"><span class="font-mono text-lg tabular-nums">{{ calc?.gyms ?? '–' }}</span><span class="block text-xs text-adm-meta">rocódromos con ficha</span></li>
        <li class="rounded-md border border-dashed border-adm-line-strong px-3 py-2"><span class="font-mono text-lg tabular-nums">{{ calc?.shoes ?? '–' }}</span><span class="block text-xs text-adm-meta">pies de gato comparados</span></li>
      </ul>
    </div>
  </fieldset>
</template>
