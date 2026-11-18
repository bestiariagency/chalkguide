<script setup lang="ts">
import { Image, MessageSquare, Zap } from 'lucide-vue-next'
import { ALL_OPTION, REVIEW_VIEWS, type AdminReview } from '~/utils/admin-reviews'

/**
 * Opiniones inbox (F6.11, docs/design/admin/opiniones.html): post-moderation (D9), so reviews are
 * already public and the author hides what should not be. Recent view by default; "Nueva" = arrived
 * since the last visit (D24). Filters in the URL (`?vista=&tipo=&item=&q=`); keys J/K/V/H.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Opiniones')

const rev = useAdminReviews()
const removing = ref<AdminReview>()
const photoViewer = reactive({ open: false, index: 0 })
const desktop = ref(true)
onMounted(() => {
  const mq = window.matchMedia('(min-width: 1024px)')
  const sync = () => (desktop.value = mq.matches)
  sync()
  mq.addEventListener('change', sync)
  window.addEventListener('keydown', onKey)
  onBeforeUnmount(() => {
    mq.removeEventListener('change', sync)
    window.removeEventListener('keydown', onKey)
  })
})

const viewModel = computed({ get: () => rev.view.value, set: (v) => void rev.setQuery({ vista: v }) })
const categoryModel = computed({ get: () => rev.category.value, set: (v) => void rev.setQuery({ tipo: v, item: undefined }) })
const itemModel = computed({ get: () => rev.item.value, set: (v) => void rev.setQuery({ item: v }) })
const realFilters = computed(() => rev.category.value !== ALL_OPTION || rev.item.value !== ALL_OPTION || !!rev.search.value.trim())
const viewEmpty = computed(() => ({ recent: 'Nada nuevo en los últimos 7 días', photos: 'No hay fotos por revisar', low: 'Ninguna opinión con nota de 2 o menos', hidden: 'No hay opiniones ocultas', all: '' })[rev.view.value])
const viewLabel = computed(() => REVIEW_VIEWS.find((v) => v.value === rev.view.value)?.label ?? '')
const loading = computed(() => rev.list.status.value === 'pending' && !rev.rows.value.length)
const showSkeleton = useDelayedFlag(loading, 300)
const counts = computed(() => {
  const s = rev.summary.value
  return s && { recent: s.recent7d, photos: s.photosPending, low: s.lowScore, hidden: s.hidden, all: s.total }
})
const newCount = computed(() => rev.rows.value.filter(rev.isNew).length)
const sheetOpen = computed({ get: () => !desktop.value && !!rev.selected.value, set: (v) => !v && (rev.selectedId.value = undefined) })
const seenText = computed(() => (rev.seenAt.value ? adminDateTime(rev.seenAt.value) : undefined))

function clearFilters() {
  rev.search.value = ''
  void rev.setQuery({ tipo: undefined, item: undefined, q: undefined })
}
function open(id: string) {
  rev.selectedId.value = id
}
function openPhoto(index: number) {
  photoViewer.index = index
  photoViewer.open = true
}
async function approvePhotos(review: AdminReview) {
  if (await rev.photos.approveAll(review)) {
    const next = rev.move(1)
    focusListRow('review', next?.id)
  }
}
function step(delta: 1 | -1) {
  focusListRow('review', rev.move(delta)?.id)
}
async function approve(review: AdminReview) {
  await rev.approveAndNext(review)
  focusListRow('review', rev.selectedId.value)
}
async function confirmRemove(reason: string) {
  if (removing.value && (await rev.remove(removing.value, reason))) removing.value = undefined
}
function onKey(event: KeyboardEvent) {
  if (isShortcutBlocked(event)) return
  const key = event.key.toLowerCase()
  const current = rev.selected.value
  if (key === 'j') step(1)
  else if (key === 'k') step(-1)
  else if (key === 'v' && current) void approve(current)
  else if (key === 'a' && current?.pendingPhotoCount) void approvePhotos(current)
  else if (key === 'h' && current && current.status !== 'hidden') void rev.setStatus(current, 'hidden')
  else return
  event.preventDefault()
}
</script>

<template>
  <div class="lg:flex lg:h-dvh lg:flex-col">
    <AdminPageBar title="Opiniones">
      <template #meta>
        <span :class="[admChip, 'ml-1 hidden bg-adm-subtle text-adm-meta sm:inline-flex']" title="Ajustes · Opiniones"><Zap aria-hidden="true" />Se publican al momento</span>
      </template>
      <AdminExportsButton target="user_reviews" :initial="reviewsExportInitial(rev.view.value, rev.category.value, rev.item.value)" />
    </AdminPageBar>

    <AdminReviewsToolbar
      v-model:view="viewModel"
      v-model:search="rev.search.value"
      v-model:category-filter="categoryModel"
      v-model:item="itemModel"
      :counts="counts"
      :items="rev.itemOptions.value"
      :selected-category="rev.category.value"
    />

    <AdminStateBlock v-if="rev.list.status.value === 'error'" kind="error" @retry="rev.list.refresh()" />
    <div v-else-if="loading" class="divide-y divide-adm-line" :aria-busy="true" :class="showSkeleton ? 'opacity-100' : 'opacity-0'">
      <span class="sr-only" role="status">Cargando opiniones…</span>
      <div v-for="n in 5" :key="n" class="space-y-2 px-4 py-4"><div class="h-3.5 w-1/3 animate-pulse rounded bg-adm-subtle" /><div class="h-3 w-2/3 animate-pulse rounded bg-adm-subtle" /></div>
    </div>
    <AdminStateBlock v-else-if="!rev.rows.value.length && realFilters" kind="no-results" description="Ninguna opinión cumple estos filtros.">
      <button type="button" :class="admBtnGhost" @click="clearFilters">Quitar filtros</button>
    </AdminStateBlock>
    <AdminStateBlock v-else-if="!rev.rows.value.length && rev.view.value !== 'all'" kind="empty" :icon="rev.view.value === 'photos' ? Image : MessageSquare" :title="viewEmpty" :description="rev.view.value === 'photos' ? 'Cuando un lector suba fotos, aparecerán aquí para que las apruebes.' : undefined">
      <button type="button" :class="admBtnGhost" @click="viewModel = 'all'">Ver todas ({{ counts?.all ?? 0 }})</button>
    </AdminStateBlock>
    <AdminStateBlock v-else-if="!rev.rows.value.length" kind="empty" :icon="MessageSquare" title="Todavía no hay opiniones" description="Cuando un lector puntúe una ficha, aparecerá aquí al momento." />

    <div v-else class="lg:grid lg:min-h-0 lg:flex-1 lg:grid-cols-[420px_1fr] lg:grid-rows-1">
      <div class="lg:min-h-0 lg:overflow-y-auto lg:border-r lg:border-adm-line">
        <p class="border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta" role="status">
          <template v-if="newCount">{{ newCount }} {{ newCount === 1 ? 'nueva' : 'nuevas' }} desde tu última visita<template v-if="seenText"> ({{ seenText }})</template></template>
          <template v-else>{{ viewLabel }} · {{ rev.total.value }} {{ rev.total.value === 1 ? 'opinión' : 'opiniones' }}</template>
        </p>
        <p v-if="rev.view.value === 'photos'" class="border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta">El texto ya está publicado. Las fotos salen en la ficha solo cuando las apruebas.</p>
        <AdminReviewsList :reviews="rev.rows.value" :selected-id="rev.selectedId.value" :is-new="rev.isNew" :label="`Opiniones: ${viewLabel}`" :src-of="rev.photos.srcOf" @open="open" @review-photos="open" />
        <div v-if="rev.hasMore.value" class="flex justify-center p-4">
          <button type="button" :class="admBtnGhost" :disabled="rev.loadingMore.value" @click="rev.loadMore()">{{ rev.loadingMore.value ? 'Cargando…' : 'Cargar más' }}</button>
        </div>
      </div>
      <section class="hidden lg:block lg:min-h-0 lg:overflow-y-auto" aria-live="polite">
        <AdminReviewsDetail
          v-if="rev.selected.value && desktop"
          :key="rev.selected.value.id"
          :review="rev.selected.value"
          :is-new="rev.isNew(rev.selected.value)"
          :min-for-average="rev.summary.value?.minForAverage ?? 3"
          :busy="rev.busy.value || rev.photos.busy.value"
          :src-of="rev.photos.srcOf"
          @open-photo="openPhoto"
          @approve-photo="(photo) => rev.photos.approveOne(rev.selected.value!, photo)"
          @approve-photos="approvePhotos(rev.selected.value!)"
          @reject-photo="(photo, reason) => rev.photos.reject(rev.selected.value!, photo, reason)"
          @hide="rev.setStatus(rev.selected.value, 'hidden')"
          @show="rev.setStatus(rev.selected.value, 'visible')"
          @approve="approve(rev.selected.value)"
          @remove="removing = rev.selected.value"
          @prev="step(-1)"
          @next="step(1)"
        />
        <p v-else class="p-6 text-sm text-adm-meta">Elige una opinión de la lista para ver su detalle.</p>
      </section>
    </div>

    <AdminModal v-if="rev.selected.value && !desktop" v-model:open="sheetOpen" placement="right" :title="`Opinión de ${rev.selected.value.author}`">
      <AdminReviewsDetail
        :review="rev.selected.value"
        :is-new="rev.isNew(rev.selected.value)"
        :min-for-average="rev.summary.value?.minForAverage ?? 3"
        :busy="rev.busy.value || rev.photos.busy.value"
        sheet
        :src-of="rev.photos.srcOf"
        @open-photo="openPhoto"
        @approve-photo="(photo) => rev.photos.approveOne(rev.selected.value!, photo)"
        @approve-photos="approvePhotos(rev.selected.value!)"
        @reject-photo="(photo, reason) => rev.photos.reject(rev.selected.value!, photo, reason)"
        @remove="removing = rev.selected.value"
      />
      <template #footer>
        <AdminReviewsActions :status="rev.selected.value.status" :busy="rev.busy.value || rev.photos.busy.value" :pending-photos="rev.selected.value.pendingPhotoCount" class="w-full" @approve-photos="approvePhotos(rev.selected.value)" @hide="rev.setStatus(rev.selected.value, 'hidden')" @show="rev.setStatus(rev.selected.value, 'visible')" @approve="approve(rev.selected.value)" />
      </template>
    </AdminModal>

    <AdminReviewsPhotoViewer
      v-if="rev.selected.value"
      v-model:open="photoViewer.open"
      v-model:index="photoViewer.index"
      :review="rev.selected.value"
      :src-of="rev.photos.srcOf"
      :busy="rev.busy.value || rev.photos.busy.value"
      @approve="(photo) => rev.photos.approveOne(rev.selected.value!, photo)"
      @reject="(photo, reason) => rev.photos.reject(rev.selected.value!, photo, reason)"
    />
    <AdminReviewsHideDialog v-if="rev.hidePrompt.value" :open="true" :review="rev.hidePrompt.value" :busy="rev.busy.value" @update:open="(v: boolean) => !v && (rev.hidePrompt.value = undefined)" @confirm="rev.confirmHide" />
    <AdminReviewsDelete v-if="removing" :open="true" :review="removing" :busy="rev.busy.value" @update:open="(v: boolean) => !v && (removing = undefined)" @confirm="confirmRemove" />
  </div>
</template>
