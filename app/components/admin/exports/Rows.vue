<script setup lang="ts">
import { ChevronDown, X } from 'lucide-vue-next'
import type { ExportConfig, ExportDraft, ExportField } from '~/utils/admin-export'

/**
 * "Filas" section: Estado (inherited from the listing's tab), the other inherited filters as chips with × and
 * «Ajustar filtros». Only affects the export, never the listing behind (README §12.2).
 */
const props = defineProps<{ config: ExportConfig; categoryOptions?: readonly AdminOption[] }>()
const draft = defineModel<ExportDraft>('draft', { required: true })

const fields = computed<ExportField[]>(() =>
  props.config.fields.map((f) => (f.key === 'category_id' ? { ...f, options: props.categoryOptions ?? [] } : f)),
)
const selectClass = [admInput, 'pr-8']
const valueOf = (key: string) => draft.value.values[key] ?? ''
function set(key: string, value: string) {
  draft.value.values[key] = value
}
function optionLabel(field: ExportField, value: string) {
  return field.options?.find((o) => o.value === value)?.label ?? value
}
const dmy = adminDate
const hasDates = computed(() => !!(valueOf('from') || valueOf('to')))
const chipValue = (f: ExportField) => (f.kind === 'date' ? dmy(valueOf(f.key)) : optionLabel(f, valueOf(f.key)))
const chips = computed(() => {
  // «Fecha de: Alta» alone says nothing: it only shows next to the dates it refers to.
  const shown = fields.value.filter((f) => valueOf(f.key) && (f.key !== 'date_field' || hasDates.value))
  const list = shown.map((f) => ({ key: f.key, text: `${f.label}: ${chipValue(f)}` }))
  if (valueOf('item_id')) list.push({ key: 'item_id', text: 'Una ficha concreta' })
  return list
})
</script>

<template>
  <div class="space-y-3">
    <div data-autofocus>
      <AdminSelect v-model="draft.status" label="Estado" :options="config.statuses.map((s) => ({ value: s.value, label: s.label }))" />
    </div>

    <ul v-if="chips.length" class="flex flex-wrap gap-1.5" aria-label="Filtros heredados de la vista">
      <li v-for="chip in chips" :key="chip.key" class="inline-flex h-7 max-w-full items-center gap-0.5 rounded-md border border-adm-line-strong bg-adm-subtle pl-2.5 text-xs max-md:h-11">
        <span class="truncate">{{ chip.text }}</span>
        <button type="button" class="grid size-7 flex-none place-items-center rounded text-adm-meta hover:text-adm-fg max-md:size-11" :aria-label="`Quitar el filtro ${chip.text}`" @click="set(chip.key, '')"><X class="size-3.5" aria-hidden="true" /></button>
      </li>
    </ul>

    <details class="group rounded-lg border border-adm-line">
      <summary class="flex h-8 cursor-pointer list-none items-center gap-1.5 px-3 text-[13px] font-medium max-md:h-11 [&::-webkit-details-marker]:hidden">
        <ChevronDown class="size-4 transition-transform group-open:rotate-180" aria-hidden="true" />Ajustar filtros
      </summary>
      <div class="grid gap-3 border-t border-adm-line p-3 sm:grid-cols-2">
        <div v-for="field in fields" :key="field.key">
          <label :for="`ex-${field.key}`" :class="admLabel">{{ field.label }}</label>
          <select v-if="field.kind === 'select'" :id="`ex-${field.key}`" :class="selectClass" :value="valueOf(field.key) || (field.required ? field.options?.[0]?.value : '')" @change="set(field.key, ($event.target as HTMLSelectElement).value)">
            <option v-if="!field.required" value="">Todos</option>
            <option v-for="o in field.options" :key="o.value" :value="o.value">{{ o.label }}</option>
          </select>
          <input v-else :id="`ex-${field.key}`" :type="field.kind === 'date' ? 'date' : 'text'" :placeholder="field.kind === 'text' ? '1, 2' : undefined" :class="admInput" :value="valueOf(field.key)" @input="set(field.key, ($event.target as HTMLInputElement).value)" />
        </div>
      </div>
    </details>
  </div>
</template>
