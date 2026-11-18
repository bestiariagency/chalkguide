<script setup lang="ts">
import { articleDisplay } from '~/utils/admin-articles'
import { pluralArticles, statusSummary, type AdminCategory, type AdminCategoryArticle, type CategoryCounts } from '~/utils/admin-categories'

/** Order of the articles inside a category (all of them, drafts included: the RPC wants the full list). */
defineProps<{
  category: AdminCategory
  categories: readonly AdminCategory[]
  counts: CategoryCounts
}>()
const items = defineModel<AdminCategoryArticle[]>('items', { required: true })
const emit = defineEmits<{ select: [id: string]; reorder: [] }>()
</script>

<template>
  <section aria-labelledby="h-arts">
    <h2 id="h-arts" class="flex items-center gap-1.5 text-sm font-semibold">
      Artículos en
      <span class="inline-flex items-center gap-1.5">
        <span class="size-2 rounded-full bg-adm-muted" :style="category.color ? { backgroundColor: category.color } : undefined" aria-hidden="true" />{{ category.name_es }}
      </span>
    </h2>
    <p class="mt-0.5 text-xs text-adm-meta">
      {{ pluralArticles(counts.total) }}: {{ statusSummary(counts) }}.
      Orden dentro de la página de la categoría; los destacados van primero en el sitio sea cual sea su posición.
    </p>
    <div class="mt-3 xl:hidden">
      <label class="sr-only" for="cat-select">Categoría</label>
      <select id="cat-select" :class="admInput" :value="category.id" @change="emit('select', ($event.target as HTMLSelectElement).value)">
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.name_es }}</option>
      </select>
    </div>
    <div v-if="items.length" class="mt-3">
      <AdminSortableList
        v-model:items="items"
        :label="`Artículos de ${category.name_es}, ordenables`"
        :item-key="(a: AdminCategoryArticle) => a.id"
        :item-label="(a: AdminCategoryArticle) => a.title_es"
        @reorder="emit('reorder')"
      >
        <template #item="{ item, index }">
          <div class="flex min-w-0 items-center gap-2">
            <span class="w-5 flex-none text-right text-xs text-adm-muted tabular-nums">{{ index + 1 }}</span>
            <span class="min-w-0 flex-1 truncate text-sm" :class="item.title_es ? undefined : 'text-adm-muted italic'">{{ item.title_es || 'Sin título' }}</span>
            <AdminStatusChip :status="articleDisplay(item)" class="max-sm:hidden" />
          </div>
        </template>
      </AdminSortableList>
    </div>
    <AdminStateBlock v-else class="mt-3" kind="empty" title="Esta categoría no tiene artículos" description="Cuando muevas o escribas artículos aquí, podrás ordenarlos." />
  </section>
</template>
