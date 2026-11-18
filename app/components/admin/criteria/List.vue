<script setup lang="ts">
import { Pencil } from 'lucide-vue-next'
import type { AdminCriterion, CriterionUsage } from '~/utils/admin-criteria'

/** Sortable list of the active criteria (order of the editor, the opinion form and the site's score block). */
defineProps<{ usageOf: (id: string) => CriterionUsage; categoryLabel: string }>()
const items = defineModel<AdminCriterion[]>('items', { required: true })
const emit = defineEmits<{ edit: [criterion: AdminCriterion]; reorder: [] }>()
</script>

<template>
  <AdminSortableList
    v-model:items="items"
    :label="`Criterios activos de ${categoryLabel}, ordenables`"
    :item-key="(c: AdminCriterion) => c.id"
    :item-label="(c: AdminCriterion) => c.name_es"
    @reorder="emit('reorder')"
  >
    <template #item="{ item, index }">
      <div class="flex min-w-0 items-center gap-1">
        <AdminCriteriaRow class="flex-1" :criterion="item" :usage="usageOf(item.id)" :position="index + 1" @edit="emit('edit', item)" />
        <button type="button" :class="admIconBtn" :aria-label="`Editar ${item.name_es}`" @click="emit('edit', item)">
          <Pencil aria-hidden="true" />
        </button>
      </div>
    </template>
  </AdminSortableList>
</template>
