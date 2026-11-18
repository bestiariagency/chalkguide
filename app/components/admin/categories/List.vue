<script setup lang="ts">
import { Pencil } from 'lucide-vue-next'
import { pluralArticles, type AdminCategory, type CategoryCounts } from '~/utils/admin-categories'

/** Sortable list of categories (order of the blog menu and the home). Selecting one shows its articles. */
defineProps<{
  selectedId?: string
  countsFor: (id: string) => CategoryCounts
}>()
const items = defineModel<AdminCategory[]>('items', { required: true })
const emit = defineEmits<{ select: [id: string]; edit: [category: AdminCategory]; reorder: [] }>()
</script>

<template>
  <AdminSortableList
    v-model:items="items"
    label="Categorías, ordenables"
    :item-key="(c: AdminCategory) => c.id"
    :item-label="(c: AdminCategory) => c.name_es"
    :item-class="(c: AdminCategory) => c.id === selectedId && 'bg-adm-acc-soft'"
    @reorder="emit('reorder')"
  >
    <template #item="{ item }">
      <div class="flex min-w-0 items-center gap-2">
        <span class="size-2.5 flex-none rounded-full bg-adm-muted" :style="item.color ? { backgroundColor: item.color } : undefined" aria-hidden="true" />
        <button type="button" class="min-w-0 flex-1 py-1 text-left" :aria-current="item.id === selectedId || undefined" @click="emit('select', item.id)">
          <span class="block truncate text-sm font-medium">{{ item.name_es }}</span>
          <span class="block truncate font-mono text-[11px] text-adm-muted">/blog/categoria/{{ item.slug_es }}</span>
        </button>
        <span class="hidden text-xs text-adm-meta tabular-nums sm:inline">{{ pluralArticles(countsFor(item.id).total) }}</span>
        <span
          :class="['rounded px-1 py-0.5 text-xs font-medium', item.has_en ? 'bg-adm-subtle text-adm-fg' : 'text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong']"
        >EN<span v-if="!item.has_en" class="sr-only"> pendiente</span></span>
        <button type="button" :class="admIconBtn" :aria-label="`Editar ${item.name_es}`" @click="emit('edit', item)">
          <Pencil aria-hidden="true" />
        </button>
      </div>
    </template>
  </AdminSortableList>
</template>
