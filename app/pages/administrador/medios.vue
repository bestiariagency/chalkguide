<script setup lang="ts">
import { CircleCheck, Upload } from 'lucide-vue-next'
import { hasAlt, MEDIA_ACCEPT, formatBytes, MEDIA_PAGE_SIZE, MEDIA_QUOTA_BYTES, type AdminMediaItem, type MediaForm } from '~/utils/admin-media-library'

/**
 * Media library (F6.6, docs/design/admin/medios.html): grid with search and filters, multiple upload
 * (drop anywhere, with per-file progress), detail drawer (ES/EN texts, credit, colour, usage), replace
 * file and delete (blocked while in use).
 */
definePageMeta({ layout: 'admin', i18n: false })
const allGoodTitle: Record<string, string> = {
  missing_alt: 'Todas tienen texto alternativo',
  missing_en: 'Todas tienen versión en inglés',
  unused: 'Todas se usan',
  in_use: 'Ninguna se usa todavía',
}
useAdminHead('Medios')

const lib = useAdminMedia()
const { success, info: toastInfo } = useAdminToast()
const describeId = ref<string>()

const upload = useAdminMediaUpload({
  onUploaded: lib.upsert,
  onBatchDone(done, failed) {
    const noAlt = done.filter((m) => !hasAlt(m))
    const parts = [done.length ? `${done.length} ${done.length === 1 ? 'imagen subida' : 'imágenes subidas'}` : '', noAlt.length ? `${noAlt.length} sin texto alternativo` : '', failed ? `${failed} con error` : '']
    const first = noAlt[0]
    success({ message: parts.filter(Boolean).join(' · '), action: first ? { label: 'Describir ahora', run: () => open(first.id, true) } : undefined })
  },
})
const drop = useFileDrop((files) => upload.add(files))
const onPick = (e: Event) => {
  const input = e.target as HTMLInputElement
  if (input.files) upload.add(input.files)
  input.value = ''
}

const dialog = ref<'replace' | 'remove'>()
function open(id: string, describe = false) {
  describeId.value = describe ? id : undefined
  lib.selectedId.value = id
}

/** `?imagen=<id>` (links from the publish checklist, D27): list the images without alt and open that one to describe it. */
const wanted = useRoute().query.imagen
if (typeof wanted === 'string') {
  lib.filter.value = 'missing_alt'
  const stop = watch([lib.status, lib.items], () => {
    if (lib.status.value !== 'idle') return
    if (lib.items.value.some((i) => i.id === wanted)) open(wanted, true)
    stop()
  })
}
// Deep links: `?q=`, `?filtro=sin-alt` (Inicio) and `?medio=<id>` (⌘K).
const route = useRoute()
if (typeof route.query.q === 'string') lib.search.value = route.query.q
if (route.query.filtro === 'sin-alt') lib.filter.value = 'missing_alt'
const wantedMedia = route.query.medio
if (typeof wantedMedia === 'string') {
  const stop = watch(lib.status, async (status) => {
    if (status !== 'idle') return
    stop()
    if (!(await lib.openById(wantedMedia))) toastInfo('Esa imagen ya no existe')
  })
}
const closeDetail = (value: boolean) => {
  if (!value) lib.selectedId.value = describeId.value = dialog.value = undefined
}
const tryRemove = () => {
  if (lib.usageStatus.value === 'idle') dialog.value = 'remove'
}
async function save(media: AdminMediaItem, form: MediaForm) {
  if (await lib.save(media, form)) closeDetail(false)
}
async function remove(media: AdminMediaItem) {
  if (await lib.remove(media)) closeDetail(false)
}

const loading = computed(() => lib.status.value === 'pending' && !lib.items.value.length)
const showSkeleton = useDelayedFlag(loading, 300)
const counts = computed(() => lib.counts.value)
</script>

<template>
  <div>
    <AdminPageBar title="Medios" :count="counts?.total">
      <template #meta>
        <span v-if="counts" class="hidden text-xs text-adm-meta md:inline">· {{ formatBytes(counts.storageBytes) }} usados (referencia: {{ formatBytes(MEDIA_QUOTA_BYTES) }})</span>
      </template>
      <label :class="[admBtnPrimary, 'cursor-pointer has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc']">
        <Upload aria-hidden="true" />Subir
        <input type="file" multiple :accept="MEDIA_ACCEPT" class="sr-only" @change="onPick" />
      </label>
    </AdminPageBar>

    <AdminMediaToolbar v-model:search="lib.search.value" v-model:filter="lib.filter.value" :counts="counts" />

    <div class="max-w-[1680px] px-4 py-5 md:px-6">
      <AdminMediaUploads
        :entries="upload.entries.value"
        :over="drop.over.value"
        :active="upload.active.value"
        @cancel="upload.cancel"
        @dismiss="upload.dismiss"
        @clear="upload.clear"
        @describe="open($event, true)"
      />

      <div class="mt-6">
        <AdminStateBlock v-if="lib.status.value === 'error'" kind="error" @retry="lib.reload()" />
        <AdminMediaSkeleton v-else-if="loading" :visible="showSkeleton" />
        <AdminStateBlock v-else-if="!lib.items.value.length && !lib.search.value.trim() && lib.filter.value !== 'all'" kind="empty" :icon="CircleCheck" :title="allGoodTitle[lib.filter.value]" description="Nada que mostrar en este filtro.">
          <button type="button" :class="admBtnGhost" @click="lib.filter.value = 'all'">Ver todas</button>
        </AdminStateBlock>
        <AdminStateBlock v-else-if="!lib.items.value.length && lib.filtered.value" kind="no-results" description="Prueba con otra búsqueda o quita el filtro.">
          <button type="button" :class="admBtnGhost" @click="[(lib.search.value = ''), (lib.filter.value = 'all')]">Quitar filtros</button>
        </AdminStateBlock>
        <AdminStateBlock v-else-if="!lib.items.value.length" kind="empty" title="Todavía no hay imágenes" description="Sube la primera: arrástrala a esta pantalla o usa «Subir».">
        </AdminStateBlock>
        <template v-else>
          <AdminMediaGrid :items="lib.items.value" :aria-busy="lib.status.value === 'pending'" @open="open($event)" />
          <div v-if="lib.hasMore.value" class="mt-6 flex justify-center">
            <button type="button" :class="admBtnGhost" :disabled="lib.loadingMore.value" @click="lib.loadMore()">
              {{ lib.loadingMore.value ? 'Cargando…' : `Cargar ${Math.min(MEDIA_PAGE_SIZE, lib.total.value - lib.items.value.length)} más` }}
            </button>
          </div>
        </template>
      </div>
    </div>

    <AdminMediaDetail
      v-if="lib.selected.value"
      :key="lib.selected.value.id"
      :open="true"
      :media="lib.selected.value"
      :usage="lib.usage.value"
      :usage-status="lib.usageStatus.value"
      :busy="lib.busy.value"
      :focus-alt="!!describeId"
      @update:open="closeDetail"
      @save="save(lib.selected.value!, $event)"
      @replace="dialog = 'replace'"
      @remove="tryRemove"
    />
    <AdminMediaReplace
      v-if="lib.selected.value && dialog === 'replace'"
      :open="true"
      :media="lib.selected.value"
      @update:open="dialog = undefined"
      @replaced="lib.upsert"
    />
    <AdminMediaDelete
      v-if="lib.selected.value && dialog === 'remove'"
      :open="true"
      :media="lib.selected.value"
      :usage="lib.usage.value"
      :busy="lib.busy.value"
      @update:open="dialog = undefined"
      @confirm="remove(lib.selected.value!)"
      @replace="dialog = 'replace'"
    />
  </div>
</template>
