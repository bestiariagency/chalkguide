<script setup lang="ts">
import { FolderInput, Loader2, Plus, Star, Trash2 } from 'lucide-vue-next'
import { emptyAdminQuery } from '~/utils/admin-table'
import {
  chipStatus,
  publicationLabel,
  type AdminArticleRow,
  type ArticleView,
} from '~/utils/admin-articles'

/**
 * Articles list (F6.4, docs/design/admin/articulos.html). Client-side table: the blog is an author's,
 * dozens of rows; sorting, search and paging are instant and the lists never go stale between pages.
 * Live articles are not touched here (they change through drafts in the editor).
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Artículos')

const articles = useAdminArticles()
const { view, categoryId, authorId, featuredOnly, visible, counts, categories, authors } = articles
const route = useRoute()
onMounted(() => {
  if (route.hash === '#cambios') view.value = 'changes'
})

// Deep links: `?q=` (⌘K, «Abrir «q» en Artículos») and `?estado=borrador|programado|publicado|cambios` (Inicio).
const ESTADOS: Record<string, ArticleView> = { borrador: 'draft', programado: 'scheduled', publicado: 'published', cambios: 'changes' }
// `?autor=<id>` («Ver en Artículos» of the author drawer): only that author's articles.
if (typeof route.query.autor === 'string') authorId.value = route.query.autor
const estado = route.query.estado
if (typeof estado === 'string' && ESTADOS[estado]) view.value = ESTADOS[estado]
const query = ref<AdminTableQuery>({ ...emptyAdminQuery(25), search: typeof route.query.q === 'string' ? route.query.q : '', sort: { id: 'updated', desc: true } })
const columns: AdminColumn<AdminArticleRow>[] = [
  { key: 'title', label: 'Título', sortable: true, pin: 'left', minWidth: 'min-w-72', accessor: (r) => `${r.title_es} ${r.slug_es} ${r.title_en ?? ''} ${r.slug_en ?? ''}` },
  { key: 'status', label: 'Estado', sortable: true, card: true, searchable: false, accessor: (r) => chipStatus(r) },
  { key: 'category', label: 'Categoría', sortable: true, searchable: false, accessor: (r) => r.category_name },
  { key: 'lang', label: 'Idiomas', card: true, searchable: false, accessor: (r) => r.has_en },
  { key: 'published', label: 'Publicación', sortable: true, card: true, searchable: false, accessor: (r) => r.published_at ?? '' },
  { key: 'updated', label: 'Actualizado', sortable: true, searchable: false, accessor: (r) => r.updated_at },
  { key: 'actions', label: 'Acciones', hideLabel: true, pin: 'right', searchable: false },
]

const selectedIds = ref<string[]>([])
/** Only what is on screen: a row hidden by a filter can never be deleted by surprise. */
const selected = computed(() => visible.value.filter((row) => selectedIds.value.includes(row.id)))
const errorText = computed(() => (articles.list.error.value ? articleErrorMessage(articles.list.error.value) : undefined))

// Dialogs
type Dialog = { kind: 'remove' | 'move'; targets: AdminArticleRow[] } | { kind: 'discard' | 'unpublish'; row: AdminArticleRow }
const dialog = ref<Dialog>()
const open = computed({ get: () => !!dialog.value, set: (value) => { if (!value) dialog.value = undefined } })
const removing = computed(() => (dialog.value?.kind === 'remove' ? dialog.value.targets : []))
const liveTargets = computed(() => removing.value.filter((row) => articles.isLive(row)))
const removeTitle = computed(() => {
  const n = removing.value.length
  if (liveTargets.value.length) return n === 1 ? 'No se puede eliminar un artículo publicado' : 'Hay artículos publicados en la selección'
  return n === 1 ? '¿Eliminar este borrador?' : `¿Eliminar ${n} artículos?`
})
const removeText = computed(() => {
  const names = removing.value.slice(0, 3).map((row) => `«${row.title_es}»`).join(', ')
  const more = removing.value.length > 3 ? ` y ${removing.value.length - 3} más` : ''
  if (liveTargets.value.length) return 'Lo publicado no se elimina desde aquí. Quita los publicados de la selección y vuelve a intentarlo.'
  return `${names}${more}. Nunca se han publicado. Quedan en el registro de actividad por si hay que recuperarlos.`
})
const moveTarget = ref<string>()
const moveLive = computed(() => (dialog.value?.kind === 'move' ? dialog.value.targets.some((row) => articles.isLive(row)) : false))

async function confirmRemove() {
  if (await articles.remove(removing.value)) {
    dialog.value = undefined
    selectedIds.value = []
  }
}
async function confirmMove() {
  if (dialog.value?.kind !== 'move' || !moveTarget.value) return
  if (await articles.move(dialog.value.targets, moveTarget.value)) dialog.value = undefined
}
async function confirmDiscard() {
  if (dialog.value?.kind !== 'discard') return
  if (await articles.discardChanges(dialog.value.row)) dialog.value = undefined
}
async function confirmUnpublish() {
  if (dialog.value?.kind !== 'unpublish') return
  if (await articles.unpublish(dialog.value.row)) dialog.value = undefined
}
const filterClass = [admInput, 'md:w-auto! min-w-40 pr-8']
</script>

<template>
  <div>
    <AdminPageBar title="Artículos" :count="articles.list.status.value === 'pending' ? undefined : articles.rows.value.length">
      <AdminExportsButton target="articles" :initial="articlesExportInitial(view, categoryId)" :category-options="categories.map((c) => ({ value: c.id, label: c.name }))" />
      <button type="button" :class="admBtnPrimary" :disabled="articles.busy.value" :aria-busy="articles.busy.value || undefined" @click="articles.create()">
        <Loader2 v-if="articles.busy.value" class="animate-adm-spin" aria-hidden="true" />
        <Plus v-else aria-hidden="true" />
        <span class="max-sm:hidden">Nuevo artículo</span><span class="sm:hidden">Nuevo</span>
      </button>
    </AdminPageBar>

    <AdminArticleTabs v-model="view" :counts="counts" />

    <div class="max-w-[1440px] px-4 py-4 md:px-6">
      <AdminDataTable
        v-model:query="query"
        :rows="visible"
        :columns="columns"
        :row-id="(row: AdminArticleRow) => row.id"
        :row-label="(row: AdminArticleRow) => `«${row.title_es}»`"
        :row-href="(row: AdminArticleRow) => adminPath(`articulos/${row.id}`)"
        caption="Artículos, ordenados por última actualización"
        selectable
        searchable
        search-placeholder="Buscar por título o slug"
        :loading="articles.list.status.value === 'pending'"
        :error="errorText"
        :error-code="(articles.list.error.value as { code?: string } | undefined)?.code"
        empty-title="Todavía no hay artículos"
        empty-description="Empieza por el que más te pregunten. Se guarda solo mientras escribes."
        no-results-title="Ningún artículo con estos filtros"
        no-results-description="Prueba con otra vista, categoría o autor."
        :filtered="articles.filtering.value"
        @update:selection="selectedIds = $event"
        @clear-filters="articles.clearFilters()"
        @retry="articles.list.refresh()"
      >
        <template #filters>
          <label class="sr-only" for="art-cat">Categoría</label>
          <select id="art-cat" v-model="categoryId" :class="filterClass">
            <option value="">Todas las categorías</option>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
          </select>
          <template v-if="authors.length">
            <label class="sr-only" for="art-author">Autor</label>
            <select id="art-author" v-model="authorId" :class="filterClass">
              <option value="">Todos los autores</option>
              <option :value="SITE_AUTHOR_FILTER">Autor del sitio</option>
              <option v-for="author in authors" :key="author.id" :value="author.id">{{ author.name }}</option>
            </select>
          </template>
          <button type="button" :class="admBtnPressed" :aria-pressed="featuredOnly" @click="featuredOnly = !featuredOnly">
            <Star aria-hidden="true" />Destacados
          </button>
        </template>

        <template #empty>
          <AdminStateBlock
            kind="empty"
            title="Todavía no hay artículos"
            description="Empieza por el que más te pregunten. Se guarda solo mientras escribes."
          >
            <button type="button" :class="admBtnPrimary" @click="articles.create()"><Plus aria-hidden="true" />Nuevo artículo</button>
          </AdminStateBlock>
        </template>

        <template #cell-title="{ row }">
          <span class="inline-flex max-w-full items-center gap-2 align-middle md:max-w-[34rem]">
            <span :class="['truncate max-md:line-clamp-2 max-md:whitespace-normal', !row.title_es && 'italic text-adm-muted']">{{ row.title_es || 'Sin título' }}</span>
            <Star v-if="row.is_featured" class="size-3.5 flex-none text-adm-acc" role="img" aria-label="Destacado" />
          </span>
        </template>
        <template #cell-status="{ row }"><AdminStatusChip :status="chipStatus(row)" :changes="row.changes" /></template>
        <template #cell-category="{ row }">
          <span class="inline-flex items-center gap-2 text-adm-meta">
            <span class="size-2 flex-none rounded-full bg-adm-muted" :style="row.category_color ? { backgroundColor: row.category_color } : undefined" aria-hidden="true" />{{ row.category_name }}
          </span>
        </template>
        <template #cell-lang="{ row }">
          <span class="inline-flex items-center gap-1 text-xs font-medium">
            <span class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">ES</span>
            <span v-if="row.has_en" class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">EN</span>
            <span v-else class="rounded px-1 py-0.5 text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong">EN<span class="sr-only"> pendiente</span></span>
          </span>
        </template>
        <template #cell-published="{ row }"><span class="tabular-nums text-adm-meta">{{ publicationLabel(row) }}</span></template>
        <template #cell-updated="{ row }"><AdminTime :iso="row.updated_at" class="text-adm-meta" /></template>
        <template #cell-actions="{ row }">
          <AdminArticleRowMenu
            :row="row"
            :live="articles.isLive(row)"
            @duplicate="articles.duplicate(row)"
            @discard="dialog = { kind: 'discard', row }"
            @unpublish="dialog = { kind: 'unpublish', row }"
            @remove="dialog = { kind: 'remove', targets: [row] }"
          />
        </template>

        <template #bulk>
          <button type="button" :class="admBtnGhost" @click="moveTarget = undefined; dialog = { kind: 'move', targets: selected }"><FolderInput aria-hidden="true" />Mover a…</button>
          <button type="button" :class="admBtnDangerGhost" @click="dialog = { kind: 'remove', targets: selected }"><Trash2 aria-hidden="true" />Eliminar…</button>
        </template>
      </AdminDataTable>
    </div>

    <AdminConfirmDelete
      :open="dialog?.kind === 'remove'"
      :level="liveTargets.length ? 'in-use' : 'simple'"
      :title="removeTitle"
      :description="removeText"
      :usages="liveTargets.map((row) => ({ label: row.title_es, where: 'Publicado', href: adminPath(`articulos/${row.id}`) }))"
      :confirm-label="removing.length === 1 ? 'Eliminar borrador' : `Eliminar ${removing.length} artículos`"
      :busy="articles.busy.value"
      @update:open="open = $event"
      @confirm="confirmRemove"
    />

    <AdminConfirmDelete
      :open="dialog?.kind === 'discard'"
      level="simple"
      :title="dialog?.kind === 'discard' ? `¿Descartar los ${dialog.row.changes} cambios sin publicar?` : ''"
      :description="dialog?.kind === 'discard' ? `«${dialog.row.title_es}» vuelve a la versión publicada. Lo publicado no cambia.` : ''"
      confirm-label="Descartar cambios"
      :busy="articles.busy.value"
      @update:open="open = $event"
      @confirm="confirmDiscard"
    />

    <AdminUnpublishDialog
      :open="dialog?.kind === 'unpublish'"
      :title="dialog?.kind === 'unpublish' ? dialog.row.title_es : ''"
      :changes="dialog?.kind === 'unpublish' ? dialog.row.changes : 0"
      :busy="articles.busy.value"
      @update:open="open = $event"
      @confirm="confirmUnpublish"
    />

    <AdminModal :open="dialog?.kind === 'move'" title="Mover a otra categoría" :busy="articles.busy.value" @update:open="open = $event">
      <p v-if="moveLive" class="text-sm text-adm-meta" role="status">
        Hay artículos publicados en la selección. Cambiar la categoría de algo publicado se hace desde el editor, como cambio sin publicar.
      </p>
      <AdminSelect v-else v-model="moveTarget" label="Categoría de destino" :options="categories.map((c) => ({ value: c.id, label: c.name }))" required />
      <template #footer>
        <button type="button" :class="admBtnGhost" data-autofocus :disabled="articles.busy.value" @click="open = false">{{ moveLive ? 'Entendido' : 'Cancelar' }}</button>
        <button v-if="!moveLive" type="button" :class="admBtnPrimary" :disabled="!moveTarget || articles.busy.value" @click="confirmMove">Mover</button>
      </template>
    </AdminModal>
  </div>
</template>
