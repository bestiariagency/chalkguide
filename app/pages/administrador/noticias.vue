<script setup lang="ts">
import { Check, EyeOff, FolderTree, Globe, Plus, X } from 'lucide-vue-next'
import type { NewsSaveAction } from '~/composables/useAdminNewsSave'
import { hasNewsFilters, splitByWarnings, type AdminNews, type NewsView } from '~/utils/admin-news'
import type { NewsForm } from '~/utils/admin-news-form'

/**
 * Noticias (F8, docs/design/admin/noticias.html): Por revisar is the inbox of Agenda (list + detail, batch with «Deshacer»),
 * Publicadas / Rechazadas / Todas are `AdminDataTable`, and the editor and the categories are drawers. View and filters live in
 * the URL (`?vista=&categoria=&alcance=&fuente=&recogida=&q=`). Nothing the agent proposes is published without `approve_news`
 * (rule 6); everything it wrote is shown by interpolation only (F1).
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Noticias')

const route = useRoute()
const nw = useAdminNews()
// The export takes one category: carried over only when the listing filters exactly one.
const exportCategoryId = computed(() => (nw.filters.value.categories.length === 1 ? (nw.categories.value.find((c) => c.key === nw.filters.value.categories[0])?.id ?? '') : ''))
const actions = useAdminNewsActions(nw.reload)
const saver = useAdminNewsSave(nw.reload)
const cats = useAdminNewsCategories(() => nw.categories.value, nw.reloadCategories)
const { rows } = nw

const selectedId = ref<string>()
const checked = ref<string[]>([])
const viewModel = computed<NewsView>({
  get: () => nw.view.value ?? 'publicadas',
  set: (v) => {
    selectedId.value = undefined
    checked.value = []
    void nw.setQuery({ vista: v })
  },
})
const filtering = computed(() => hasNewsFilters(nw.filters.value))
// Until the counters pick the default view nothing is known: show the loading state, never a false "empty".
const waiting = computed(() => !nw.view.value || nw.list.status.value === 'pending')
const loading = computed(() => waiting.value && !rows.value.length)
const showSkeleton = useDelayedFlag(loading, 300)
const failed = computed(() => nw.list.status.value === 'error')
const errorCode = computed(() => (nw.list.error.value as { code?: string } | undefined)?.code)
const total = computed(() => nw.summary.value?.total ?? 0)
const labels = computed(() => Object.fromEntries(nw.categories.value.map((c) => [c.key, c.labelEs])))
const sumLine = computed(() => {
  const s = nw.summary.value
  return s ? `${s.published} publicadas · ${s.publishedIndexable} con nota (indexables) · ${s.publishedNoindex} con noindex. El sitio las muestra de 20 en 20.` : ''
})

// Editor and dialogs ----------------------------------------------------------------------------------------
const editing = ref<{ news?: AdminNews; focus?: 'note' }>()
const retiring = ref<AdminNews>()
const removing = ref<AdminNews>()
const batchDialog = ref(false)
const categoriesOpen = ref(false)

function create() {
  saver.error.value = undefined
  editing.value = {}
}
function edit(news: AdminNews, focus?: 'note') {
  saver.error.value = undefined
  editing.value = { news, focus }
}
// "Nuevo → Noticia" of the shell arrives as `?nuevo=1`.
watch(
  () => route.query.nuevo,
  (value) => {
    if (!value) return
    create()
    void nw.setQuery({ nuevo: undefined })
  },
  { immediate: true },
)
// Deep link `?noticia=<id>`: drafts open the inbox on them, the rest open the drawer.
const wanted = useAdminNewsLookup(() => (typeof route.query.noticia === 'string' ? route.query.noticia : undefined))
watch(wanted, (news) => {
  if (!news) return
  void nw.setQuery({ noticia: undefined })
  if (news.status !== 'draft') return edit(news)
  selectedId.value = news.id
  void nw.setQuery({ vista: 'revisar' })
})

watch(categoriesOpen, (is) => is && void cats.load())

async function save(form: NewsForm, action: NewsSaveAction) {
  if (await saver.save(editing.value?.news, form, action)) editing.value = undefined
}
/** Runs a status change from the drawer and closes it when it worked. */
async function fromEditor(run: (news: AdminNews) => Promise<boolean>) {
  const news = editing.value?.news
  if (news && (await run(news))) editing.value = undefined
}

// Decisions of the inbox: the selection and the focus pass to the next item -----------------------------------
async function approve(news: AdminNews, next?: string) {
  if (await actions.approve([news.id])) {
    selectedId.value = next
    focusListRow('news', next)
  }
}
async function reject(news: AdminNews, reason: string | null, next?: string) {
  if (await actions.reject([news], reason)) {
    selectedId.value = next
    focusListRow('news', next)
  }
}
const selection = computed(() => rows.value.filter((n) => checked.value.includes(n.id)))
/** D77: approves at once; the dialog only opens when something in the selection has warnings. */
async function approveBatch() {
  if (!selection.value.length) return
  if (splitByWarnings(selection.value).warned.length) batchDialog.value = true
  else if (await actions.approve(selection.value.map((n) => n.id))) checked.value = []
}
async function approveFromDialog(only: 'all' | 'clean') {
  const ids = (only === 'all' ? selection.value : splitByWarnings(selection.value).clean).map((n) => n.id)
  batchDialog.value = false
  if (await actions.approve(ids)) checked.value = []
}
async function rejectBatch(reason: string | null) {
  if (await actions.reject(selection.value, reason)) checked.value = []
}
async function confirmRetire() {
  if (retiring.value && (await actions.retire(retiring.value))) {
    retiring.value = undefined
    editing.value = undefined
  }
}
async function confirmRemove() {
  if (removing.value && (await actions.remove(removing.value))) {
    removing.value = undefined
    editing.value = undefined
  }
}
async function rejectInstead() {
  if (removing.value && (await actions.reject([removing.value], null))) {
    removing.value = undefined
    editing.value = undefined
  }
}
function clearFilters() {
  nw.search.value = ''
  void nw.setQuery({ q: undefined, categoria: undefined, alcance: undefined, fuente: undefined, recogida: undefined })
}
</script>

<template>
  <div :class="viewModel === 'revisar' && 'lg:flex lg:h-dvh lg:flex-col'">
    <AdminPageBar title="Noticias">
      <template #meta>
        <span :class="[admChip, 'ml-1 hidden bg-adm-subtle text-adm-meta md:inline-flex']" title="Solo se indexan las fichas con una «Nota de Xavi» de unas 60 palabras o más"><EyeOff aria-hidden="true" />Sin «Nota de Xavi», la ficha va con noindex</span>
      </template>
      <AdminExportsButton target="news" :initial="newsExportInitial(viewModel, nw.filters.value, exportCategoryId)" :category-options="nw.categories.value.map((c) => ({ value: c.id, label: c.labelEs }))" />
      <button type="button" :class="[admBtnGhost, 'max-md:hidden']" @click="categoriesOpen = true"><FolderTree aria-hidden="true" />Categorías</button>
      <button type="button" :class="admBtnPrimary" @click="create()"><Plus aria-hidden="true" /><span class="max-sm:hidden">Nueva noticia</span><span class="sm:hidden">Nueva</span></button>
    </AdminPageBar>

    <AdminNewsStrip :summary="nw.summary.value" />

    <AdminNewsToolbar
      v-model:view="viewModel"
      v-model:search="nw.search.value"
      :counts="nw.counts.value"
      :categories="nw.categories.value"
      :category-counts="nw.categoryCounts.value"
      :sources="nw.sourceFacets.value"
      :runs="nw.runOptions.value"
      :filters="nw.filters.value"
      @filter="nw.setQuery"
    />

    <p v-if="viewModel === 'publicadas' && sumLine" class="flex gap-2 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta md:px-6"><Globe class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />{{ sumLine }}</p>

    <!-- `contents`: the panel only carries the tab semantics; the inbox keeps laying out against the page. -->
    <div id="news-panel" role="tabpanel" :aria-labelledby="`news-tab-${viewModel}`" class="contents">
    <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar las noticias" description="Comprueba la conexión y vuelve a intentarlo." :code="errorCode" @retry="nw.list.refresh()" />
    <div v-else-if="loading && viewModel === 'revisar'" :aria-busy="true" :class="['lg:grid lg:grid-cols-[420px_1fr]', showSkeleton ? 'opacity-100' : 'opacity-0']">
      <span class="sr-only" role="status">Cargando noticias…</span>
      <div class="divide-y divide-adm-line lg:border-r lg:border-adm-line">
        <div v-for="n in 4" :key="n" class="space-y-2 p-4"><span class="block h-4 animate-pulse rounded bg-adm-subtle" :style="{ width: `${60 + ((n * 13) % 35)}%` }" /><span class="block h-3 w-1/2 animate-pulse rounded bg-adm-subtle" /><span class="block h-4 w-40 animate-pulse rounded bg-adm-subtle" /></div>
      </div>
      <div class="hidden space-y-4 p-6 lg:block"><span class="block h-5 w-40 animate-pulse rounded bg-adm-subtle" /><span class="block h-7 w-3/4 animate-pulse rounded bg-adm-subtle" /><span class="block h-16 animate-pulse rounded bg-adm-subtle" /><span class="block h-24 animate-pulse rounded bg-adm-subtle" /></div>
    </div>

    <template v-else-if="viewModel === 'revisar'">
      <AdminNewsEmpty v-if="!rows.length" view="revisar" :filtered="filtering" :search="nw.search.value" :total="total" @goto="viewModel = $event" @create="create()" @clear="clearFilters" />
      <AdminNewsInbox v-else v-model:selected-id="selectedId" v-model:checked="checked" :rows="rows" :busy="actions.busy.value" :labels="labels" @approve="approve" @reject="reject" @edit="edit" />
    </template>

    <div v-else class="max-w-[1440px] px-4 py-4 md:px-6">
      <AdminNewsTable
        :rows="rows"
        :view="viewModel"
        :loading="waiting"
        :busy="actions.busy.value"
        :labels="labels"
        @open="edit"
        @retire="retiring = $event"
        @recover="actions.recover"
        @release="actions.release"
        @remove="removing = $event"
        @retry="nw.list.refresh()"
      >
        <template #empty><AdminNewsEmpty :view="viewModel" :filtered="filtering" :search="nw.search.value" :total="total" @goto="viewModel = $event" @create="create()" @clear="clearFilters" /></template>
      </AdminNewsTable>
    </div>
    </div>

    <AdminBulkBar :count="viewModel === 'revisar' ? checked.length : 0" feminine @clear="checked = []">
      <button type="button" :class="admBtnPrimary" :disabled="actions.busy.value" @click="approveBatch"><Check aria-hidden="true" />Aprobar</button>
      <AdminNewsRejectMenu agent side="top" @select="rejectBatch">
        <button type="button" :class="admBtnGhost" :disabled="actions.busy.value" aria-haspopup="menu"><X aria-hidden="true" />Rechazar…</button>
      </AdminNewsRejectMenu>
    </AdminBulkBar>

    <AdminNewsBatch v-if="batchDialog" :open="true" :rows="selection" :busy="actions.busy.value" @update:open="(v: boolean) => !v && (batchDialog = false)" @all="approveFromDialog('all')" @clean="approveFromDialog('clean')" />

    <AdminNewsEditor
      v-if="editing"
      :key="editing.news?.id ?? 'new'"
      :open="true"
      :news="editing.news"
      :focus="editing.focus"
      :categories="nw.categories.value"
      :labels="labels"
      :busy="saver.busy.value || actions.busy.value"
      :server-error="saver.error.value"
      @update:open="(v: boolean) => { if (!v) editing = undefined }"
      @save="save"
      @reject="(reason) => fromEditor((n) => actions.reject([n], reason))"
      @recover="fromEditor(actions.recover)"
      @retire="retiring = editing.news"
      @remove="removing = editing.news"
    />
    <AdminNewsRetire v-if="retiring" :open="true" :news="retiring" :busy="actions.busy.value" @update:open="(v: boolean) => !v && (retiring = undefined)" @confirm="confirmRetire" />
    <AdminNewsDelete v-if="removing" :open="true" :news="removing" :busy="actions.busy.value" @update:open="(v: boolean) => !v && (removing = undefined)" @confirm="confirmRemove" @reject="rejectInstead" />
    <AdminNewsCategories
      v-if="categoriesOpen"
      v-model:open="categoriesOpen"
      v-model:items="cats.items.value"
      :counts="cats.counts.value"
      :busy="cats.busy.value"
      :error="cats.error.value"
      @reorder="cats.reorder"
      @create="cats.create"
      @rename="cats.rename"
      @remove="cats.remove"
    />
  </div>
</template>
