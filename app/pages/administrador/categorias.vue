<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import type { AdminCategory, CategoryForm } from '~/utils/admin-categories'

/**
 * Categories (F6.5, docs/design/admin/categorias.html): order of the categories, edit drawer (ES/EN,
 * colour, URL with 301 on change), delete with reassignment and order of the articles of one category.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Categorías')

const cats = useAdminCategories()
const { categories, selected, selectedArticles } = cats
const loading = computed(() => cats.list.status.value === 'pending' && !categories.value.length)
const showSkeleton = useDelayedFlag(loading, 300)
const errorText = computed(() => (cats.list.error.value ? categoryErrorMessage(cats.list.error.value) : undefined))

type Dialog = { kind: 'edit'; category?: AdminCategory; draft?: CategoryForm } | { kind: 'remove'; category: AdminCategory; fromForm?: boolean; draft?: CategoryForm }
const dialog = ref<Dialog>()
const editing = computed(() => (dialog.value?.kind === 'edit' ? dialog.value : undefined))
const removing = computed(() => (dialog.value?.kind === 'remove' ? dialog.value.category : undefined))
const close = (open: boolean) => { if (!open) dialog.value = undefined }
/** Cancelling a delete opened from the form goes back to that category's form, not to the list. */
function closeRemove(open: boolean) {
  if (open) return
  const current = dialog.value
  dialog.value = current?.kind === 'remove' && current.fromForm ? { kind: 'edit', category: current.category, draft: current.draft } : undefined
}

async function save(form: CategoryForm) {
  if (await cats.save(editing.value?.category?.id, form)) dialog.value = undefined
}
async function confirmRemove(reassignTo: string | undefined) {
  if (removing.value && (await cats.remove(removing.value, reassignTo))) dialog.value = undefined
}
</script>

<template>
  <div>
    <AdminPageBar title="Categorías del blog" :count="loading ? undefined : categories.length">
      <button type="button" :class="admBtnPrimary" @click="dialog = { kind: 'edit' }">
        <Plus aria-hidden="true" /><span class="max-sm:hidden">Nueva categoría</span><span class="sm:hidden">Nueva</span>
      </button>
    </AdminPageBar>

    <div class="max-w-[1440px] px-4 py-6 md:px-6">
      <AdminStateBlock v-if="errorText" kind="error" :description="errorText" @retry="cats.list.refresh()" />
      <AdminCategoriesSkeleton v-else-if="loading" :visible="showSkeleton" />
      <AdminStateBlock v-else-if="!categories.length" kind="empty" title="Todavía no hay categorías" description="Crea la primera para poder escribir artículos.">
        <button type="button" :class="admBtnPrimary" @click="dialog = { kind: 'edit' }"><Plus aria-hidden="true" />Nueva categoría</button>
      </AdminStateBlock>
      <div v-else class="grid gap-6 xl:grid-cols-2">
        <section aria-labelledby="h-cats">
          <h2 id="h-cats" class="text-sm font-semibold">Orden en el sitio</h2>
          <p class="mt-0.5 text-xs text-adm-meta">Es el orden del menú del blog y de la home. Arrastra desde el asa, usa Espacio y flechas o el menú «Mover».</p>
          <div class="mt-3">
            <AdminCategoriesList
              v-model:items="categories"
              :selected-id="selected?.id"
              :counts-for="cats.countsFor"
              @select="cats.selectedId.value = $event"
              @edit="dialog = { kind: 'edit', category: $event }"
              @reorder="cats.reorder()"
            />
          </div>
        </section>
        <AdminCategoriesArticles
          v-if="selected"
          v-model:items="selectedArticles"
          :category="selected"
          :categories="categories"
          :counts="cats.selectedCounts.value"
          @select="cats.selectedId.value = $event"
          @reorder="cats.reorderArticles()"
        />
      </div>
    </div>

    <AdminCategoriesForm
      v-if="editing"
      :key="editing.category?.id ?? 'new'"
      :open="true"
      :category="editing.category"
      :draft="editing.draft"
      :categories="categories"
      :live="editing.category ? cats.countsFor(editing.category.id).published : 0"
      :busy="cats.busy.value"
      @update:open="close"
      @save="save"
      @remove="dialog = { kind: 'remove', category: editing.category!, fromForm: true, draft: $event }"
    />
    <AdminCategoriesDelete
      v-if="removing"
      :open="true"
      :category="removing"
      :counts="cats.countsFor(removing.id)"
      :targets="categories.filter((c) => c.id !== removing!.id)"
      :needs-target="cats.needsTargetId.value === removing.id"
      :busy="cats.busy.value"
      @update:open="closeRemove"
      @confirm="confirmRemove"
    />
  </div>
</template>
