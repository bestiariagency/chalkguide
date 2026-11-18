<script setup lang="ts">
import { Eye, Pencil } from 'lucide-vue-next'
import type { AdminCriterion, CriterionUsage } from '~/utils/admin-criteria'

/** Inactive criteria: no handle, notes kept. "Reactivar" is immediate (and undoable). */
defineProps<{ items: readonly AdminCriterion[]; usageOf: (id: string) => CriterionUsage; busy: boolean }>()
const emit = defineEmits<{ edit: [criterion: AdminCriterion]; reactivate: [criterion: AdminCriterion] }>()
</script>

<template>
  <section v-if="items.length" class="mt-6" aria-labelledby="h-off">
    <h3 id="h-off" class="flex items-center gap-2 text-sm font-semibold">Inactivos <span class="font-normal text-adm-muted tabular-nums">{{ items.length }}</span></h3>
    <p class="mt-0.5 text-xs text-adm-meta">No se puntúan ni cuentan en medias ni índices. Sus notas se conservan, salvo las de lectores que reenvíen su opinión mientras esté inactivo. Al reactivarlo vuelve al final del orden.</p>
    <ul :class="[admCard, 'mt-3 divide-y divide-adm-line']" aria-label="Criterios inactivos">
      <li v-for="item in items" :key="item.id" class="flex min-h-12 items-center gap-2 py-1.5 pr-2 pl-3">
        <AdminCriteriaRow class="flex-1" :criterion="item" :usage="usageOf(item.id)" inactive @edit="emit('edit', item)" />
        <span :class="[admChip, 'bg-adm-subtle text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']">Inactivo</span>
        <button type="button" :class="[admBtnQuiet, 'h-7 text-xs max-md:h-11 max-sm:w-11 max-sm:px-0']" :disabled="busy" @click="emit('reactivate', item)">
          <Eye aria-hidden="true" /><span class="max-sm:sr-only">Reactivar<span class="sm:sr-only"> {{ item.name_es }}</span></span>
        </button>
        <button type="button" :class="admIconBtn" :aria-label="`Editar ${item.name_es}`" @click="emit('edit', item)"><Pencil aria-hidden="true" /></button>
      </li>
    </ul>
  </section>
</template>
