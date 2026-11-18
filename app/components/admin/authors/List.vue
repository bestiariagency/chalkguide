<script setup lang="ts">
import { Pencil } from 'lucide-vue-next'
import { pluralArticles } from '~/utils/admin-categories'
import type { AdminAuthor, AuthorCounts } from '~/utils/admin-authors'

/** Sortable list of the other authors (order of the editor's «Autor» selector). The row opens the drawer. */
defineProps<{ countsFor: (id: string) => AuthorCounts }>()
const items = defineModel<AdminAuthor[]>('items', { required: true })
const emit = defineEmits<{ edit: [author: AdminAuthor]; reorder: [] }>()
</script>

<template>
  <AdminSortableList
    v-model:items="items"
    label="Autores, ordenables"
    :item-key="(a: AdminAuthor) => a.id"
    :item-label="(a: AdminAuthor) => a.name"
    @reorder="emit('reorder')"
  >
    <template #item="{ item }">
      <div class="flex min-w-0 items-center gap-3">
        <AdminAuthorsAvatar :media="item.photo" :name="item.name" />
        <button type="button" class="min-w-0 flex-1 py-1 text-left max-md:min-h-11" @click="emit('edit', item)">
          <span class="block truncate text-sm font-medium">{{ item.name }}</span>
          <span class="block truncate text-xs text-adm-meta">{{ item.role_es || 'Sin rol' }}</span>
        </button>
        <span class="hidden text-xs text-adm-meta tabular-nums sm:inline">{{ countsFor(item.id).total ? pluralArticles(countsFor(item.id).total) : 'Sin artículos' }}</span>
        <AdminAuthorsEnBadge :role="item.role_en" :bio="item.bio_en" class="max-sm:hidden" />
        <button type="button" :class="admIconBtn" :aria-label="`Editar ${item.name}`" @click="emit('edit', item)">
          <Pencil aria-hidden="true" />
        </button>
      </div>
    </template>
  </AdminSortableList>
</template>
