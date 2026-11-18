<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import type { AdminAuthor, AuthorForm } from '~/utils/admin-authors'

/**
 * Authors (D62, docs/design/admin/ajustes-autores.html, README §17.4–17.6): the site author fixed on top,
 * the other authors sortable, create / edit drawer and delete (their articles pass to the site author).
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Autores')

const authorsData = useAdminAuthors()
const { authors, site, siteCounts } = authorsData
const loading = computed(() => authorsData.list.status.value === 'pending' && !site.value)
const showSkeleton = useDelayedFlag(loading, 300)
const failed = computed(() => !!authorsData.list.error.value && !site.value)
const errorCode = computed(() => (authorsData.list.error.value as { code?: string } | undefined)?.code)

/** Drawer state: `author` absent = new author. */
const dialog = ref<{ author?: AdminAuthor }>()
const edited = computed(() => dialog.value?.author)
// Deleting opens over the drawer: cancelling it leaves the drawer (and its edits) as it was.
const stackedRemove = ref<AdminAuthor>()
const closeEdit = (open: boolean) => { if (!open) dialog.value = undefined }

async function save(form: AuthorForm) {
  if (await authorsData.save(edited.value?.id, form)) dialog.value = undefined
}
async function confirmRemove(moved: number) {
  if (stackedRemove.value && (await authorsData.remove(stackedRemove.value, moved))) {
    stackedRemove.value = undefined
    dialog.value = undefined
  }
}
</script>

<template>
  <div>
    <AdminPageBar title="Autores" :count="site ? authors.length + 1 : undefined">
      <button type="button" :class="admBtnPrimary" @click="dialog = {}">
        <Plus aria-hidden="true" /><span class="max-sm:hidden">Nuevo autor</span><span class="sm:hidden">Nuevo</span>
      </button>
    </AdminPageBar>

    <div class="grid max-w-[1440px] items-start gap-6 px-4 py-6 md:px-6 xl:grid-cols-[minmax(0,760px)_320px]">
      <div class="min-w-0 space-y-6">
        <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar los autores" description="Comprueba la conexión. Si sigue, puede ser Supabase: mira su estado." :code="errorCode" @retry="authorsData.list.refresh()" />
        <AdminAuthorsSkeleton v-else-if="loading || !site" :visible="showSkeleton" />
        <template v-else>
          <AdminAuthorsSiteCard :site="site" :counts="siteCounts" />
          <section v-if="authors.length" aria-labelledby="h-list">
            <h2 id="h-list" class="text-sm font-semibold">Otros autores</h2>
            <p class="mt-0.5 text-xs text-adm-meta">Orden del selector «Autor» del editor. Arrastra desde el asa, usa Espacio y flechas o el menú «Mover».</p>
            <div class="mt-3">
              <AdminAuthorsList v-model:items="authors" :counts-for="authorsData.countsFor" @edit="dialog = { author: $event }" @reorder="authorsData.reorder()" />
            </div>
          </section>
          <AdminStateBlock v-else kind="empty" title="Solo firmas tú" description="Añade un autor si alguien más escribe en el blog. Lo eliges en el editor de cada artículo, en «Autor».">
            <button type="button" :class="admBtnPrimary" @click="dialog = {}"><Plus aria-hidden="true" />Nuevo autor</button>
          </AdminStateBlock>
        </template>
      </div>
      <AdminAuthorsSide />
    </div>

    <AdminAuthorsForm
      v-if="dialog"
      :key="edited?.id ?? 'new'"
      :open="true"
      :author="edited"
      :authors="authors"
      :counts="edited ? authorsData.countsFor(edited.id) : { total: 0, live: 0 }"
      :busy="authorsData.busy.value"
      :slug-taken="authorsData.slugTaken.value"
      @update:open="closeEdit"
      @save="save"
      @remove="stackedRemove = edited"
    />
    <AdminAuthorsDelete
      v-if="stackedRemove"
      :key="stackedRemove.id"
      :open="true"
      :author="stackedRemove"
      :site-name="site?.name ?? null"
      :busy="authorsData.busy.value"
      @update:open="(open: boolean) => !open && (stackedRemove = undefined)"
      @confirm="confirmRemove"
    />
  </div>
</template>
