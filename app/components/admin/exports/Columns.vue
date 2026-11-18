<script setup lang="ts">
import { ChevronDown } from 'lucide-vue-next'
import { SUBSCRIBER_PRESETS, type ExportConfig, type ExportFormat } from '~/utils/admin-export'

/** "Columnas" section: subscribers pick a preset (minimal / with proof of consent); the rest list their technical keys. */
const props = defineProps<{ config: ExportConfig; columns: readonly string[]; format: ExportFormat }>()
const preset = defineModel<'min' | 'proof'>('preset', { required: true })
const withBody = defineModel<boolean>('withBody', { required: true })

const isSubscribers = computed(() => props.config.module === 'subscribers')
const presets = [
  { value: 'min', title: 'Lo mínimo', note: 'Email, idioma, estado y fechas de alta y confirmación.' },
  { value: 'proof', title: 'Con prueba de consentimiento', note: 'Añade el origen, la versión y la página del texto aceptado, y los datos de la baja.' },
] as const
const shown = computed(() => (isSubscribers.value ? SUBSCRIBER_PRESETS[preset.value] : props.columns))
const bodyOff = computed(() => props.format === 'csv')
</script>

<template>
  <div class="space-y-3">
    <div v-if="isSubscribers" role="radiogroup" aria-label="Columnas" class="grid gap-2">
      <label v-for="p in presets" :key="p.value" class="flex min-h-14 cursor-pointer items-start gap-2.5 rounded-lg border border-adm-line-strong p-3 has-[:checked]:border-adm-acc has-[:checked]:bg-adm-subtle has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-adm-acc">
        <input v-model="preset" type="radio" name="export-columns" :value="p.value" class="mt-0.5 size-4 accent-adm-acc" />
        <span><b class="block text-[13px]">{{ p.title }}</b><span class="text-xs text-adm-meta">{{ p.note }}</span></span>
      </label>
    </div>

    <details v-if="shown.length" class="group" :open="isSubscribers || undefined">
      <summary class="flex h-8 cursor-pointer list-none items-center gap-1.5 text-[13px] font-medium max-md:h-11 [&::-webkit-details-marker]:hidden">
        <ChevronDown class="size-4 transition-transform group-open:rotate-180" aria-hidden="true" />{{ shown.length }} columnas, con su clave técnica
      </summary>
      <ul class="mt-1 flex flex-wrap gap-1.5">
        <li v-for="c in shown" :key="c" class="rounded bg-adm-subtle px-1.5 font-mono text-xs leading-5">{{ c }}</li>
      </ul>
    </details>

    <p v-if="isSubscribers" class="text-xs text-adm-meta">Nunca salen: tokens y enlaces de baja, la cuenta, datos del proveedor ni los suprimidos.</p>
    <p v-else-if="config.module === 'user_reviews'" class="text-xs text-adm-meta">Con el nombre público del lector. Nunca su email ni su cuenta, ni las fotos.</p>

    <div v-if="config.hasBody">
      <label :class="['flex min-h-8 items-center gap-2 text-[13px] max-md:min-h-11', bodyOff ? 'cursor-not-allowed text-adm-meta' : 'cursor-pointer']">
        <input v-model="withBody" type="checkbox" class="size-4 accent-adm-acc" :disabled="bodyOff" aria-describedby="ex-body-help" />Incluir el texto completo
      </label>
      <p id="ex-body-help" class="text-xs text-adm-meta">{{ bodyOff ? 'Solo con JSON: el texto no cabe bien en una celda de Excel.' : 'El texto completo de cada fila, en español e inglés.' }}</p>
    </div>
  </div>
</template>
