<script setup lang="ts">
import type { Database } from '~/types/database.types'
import { fetchUserAverage } from '~/services/admin/gym-ratings'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemSpec } from '~/utils/item-spec'
import { changedTabs, errorsByTab } from '~/utils/item-tabs'

/**
 * Editor shell shared by gyms (F6.7) and resolers (F6.8). An unpublished item is edited in place; a
 * published one on a draft of changes with "Publicar cambios" (D23). General, gallery, related and SEO
 * are common; the category's own tabs (and the review, which gyms extend with indices) come in the
 * `panel` slot.
 */
const props = defineProps<{ id: string; spec: ItemSpec<ItemForm> }>()
defineSlots<{ panel(props: { tab: string }): unknown }>()

const editor = useItemEditor(props.id, props.spec)
const { form, errors, saver } = editor
useAdminHead(() => form.value?.name || `Editor de ${props.spec.noun}`)

const { tab } = useItemTabs(props.spec.tabs)
const publishOpen = ref(false)
const changesOpen = ref(false)
const discardOpen = ref(false)
const hideOpen = ref(false)
const removeOpen = ref(false)
const picking = ref<'cover' | 'og' | 'gallery' | null>(null)
const pickerOpen = computed({ get: () => picking.value !== null, set: (value) => !value && (picking.value = null) })
provideItemEditor({ id: props.id, editor, spec: props.spec, pick: (what) => (picking.value = what) })

const client = useSupabaseClient<Database>()
const average = ref<number | null>(null)
watch([publishOpen, changesOpen], ([publishing, reviewing]) => {
  if (publishing || reviewing) void editor.checkAlt()
})
const item = computed(() => editor.loaded.value?.item)
const hidden = computed(() => !editor.live.value && !!item.value?.published_at)
const changed = computed(() => editor.changed.value)
const count = computed(() => changed.value.length)
const tabErrors = computed(() => errorsByTab(props.spec.tabs, errors.value))
const tabChanged = computed(() => changedTabs(props.spec.tabs, changed.value))
const savedAt = computed(() => saver.savedAt.value ?? (editor.storedAt.value ? Date.parse(editor.storedAt.value) : Date.parse(editor.updatedAt.value || '') || null))
const publishedSlug = computed(() => (editor.published.value as { slug?: string } | null)?.slug ?? '')
const cover = computed(() => editor.mediaOf(form.value?.cover_media_id ?? null))
const og = computed(() => editor.mediaOf(form.value?.og_media_id ?? null))

onMounted(() => {
  fetchUserAverage(client, props.id).then((value) => (average.value = value), () => {})
  watch(() => editor.load.data.value, () => {
    if (useRoute().hash === '#cambios' && editor.live.value && changed.value.length) changesOpen.value = true
  }, { once: true })
})

function chosen(media: AdminMedia) {
  if (!form.value) return
  editor.remember(media)
  if (picking.value === 'og') form.value.og_media_id = media.id
  else form.value.cover_media_id = media.id
}
function addPhotos(list: AdminMedia[]) {
  if (!form.value) return
  for (const media of list) {
    editor.remember(media)
    if (!form.value.gallery.includes(media.id)) form.value.gallery.push(media.id)
  }
}
async function publish() {
  if (await editor.publish()) publishOpen.value = false
}
async function publishChanges(force: boolean) {
  if (await editor.publishChanges(force)) changesOpen.value = false
}
async function discard() {
  if (await editor.discardChanges()) {
    discardOpen.value = false
    changesOpen.value = false
  }
}
async function hide() {
  if (await editor.hide()) hideOpen.value = false
}
async function reload() {
  changesOpen.value = false
  await editor.reload()
}
const hiddenOpinions = computed(() => {
  const reviews = editor.loaded.value?.reviews ?? 0
  return reviews === 0 ? ' Tu reseña se conserva.' : reviews === 1 ? ' Su opinión y tu reseña se conservan.' : ` Sus ${reviews} opiniones y tu reseña se conservan.`
})
</script>

<template>
  <div v-if="editor.load.error.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="error" title="No se ha podido abrir la ficha" @retry="editor.load.refresh()" />
  </div>
  <div v-else-if="editor.notFound.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="empty" title="Esta ficha no existe" description="Puede que la hayan eliminado.">
      <NuxtLink :to="adminPath(spec.route)" :class="admBtnGhost">Volver a {{ spec.title }}</NuxtLink>
    </AdminStateBlock>
  </div>
  <AdminEditorSkeleton v-else-if="!form || !item" label="Cargando la ficha…" />

  <div v-else>
    <AdminItemsHeader
      :info="spec"
      :name="form.name"
      :live="editor.live.value"
      :hidden="hidden"
      :slug="publishedSlug || form.slug"
      :changes="count"
      :save="{ state: saver.state.value, savedAt, message: saver.errorMessage.value }"
      :busy="editor.busy.value"
      :can-publish="editor.canPublish.value"
      @retry="saver.retry()"
      @publish="publishOpen = true"
      @publish-changes="changesOpen = true"
      @changes="changesOpen = true"
      @discard="discardOpen = true"
      @hide="hideOpen = true"
    />
    <AdminEditorChangesBand v-if="editor.live.value" published="Esta ficha está publicada" :count="count" :since="editor.version.value" :conflict="editor.conflict.value" @view="changesOpen = true" @discard="discardOpen = true" @reload="reload" />
    <div class="flex items-center justify-end border-b border-adm-line px-4 py-1.5 xl:hidden">
      <AdminEditorSaveStatus :state="saver.state.value" :saved-at="savedAt" :message="saver.errorMessage.value" @retry="saver.retry()" />
    </div>

    <AdminItemsTabs v-model="tab" :tabs="spec.tabs" :errors="tabErrors" :changed="tabChanged" :gallery="form.gallery.length" />

    <div class="grid justify-between gap-8 px-4 py-6 pb-28 md:px-6 md:pb-10 xl:grid-cols-[minmax(0,760px)_320px]">
      <div :key="editor.revision.value" class="min-w-0">
        <template v-for="t in spec.tabs" :key="t.key">
          <div v-show="tab === t.key" :id="`item-panel-${t.key}`" role="tabpanel" :aria-labelledby="`item-tab-${t.key}`" tabindex="0" class="focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-adm-acc">
            <AdminItemsPanelGeneral
              v-if="t.key === 'general'"
              v-model:form="form"
              :info="spec"
              :errors="errors"
              :changed="changed"
              :live="editor.live.value"
              :published-slug="publishedSlug"
              :slug-taken="editor.slugTaken.value"
              :slug-suggestion="editor.slugSuggestion.value"
              :cover="cover"
              :busy="editor.busy.value"
              @cover="picking = 'cover'"
              @remove-cover="form.cover_media_id = null"
              @verify="editor.verifyToday($event)"
            />
            <AdminItemsPanelGallery v-else-if="t.key === 'gallery'" v-model:form="form" :changed="changed.includes('gallery')" :media-of="editor.mediaOf" @add="picking = 'gallery'" />
            <AdminItemsPanelRelated v-else-if="t.key === 'related'" :articles="editor.loaded.value?.articles ?? []" :noun="spec.noun" />
            <AdminItemsPanelSeo v-else-if="t.key === 'seo'" v-model:form="form" :info="spec" :errors="errors" :changed="changed" :og="og" @og="picking = 'og'" @remove-og="form.og_media_id = null" />
            <slot v-else name="panel" :tab="t.key" />
          </div>
        </template>
      </div>
      <AdminItemsSide
        :id="id"
        :average="average"
        :live="editor.live.value"
        :hidden="hidden"
        :published-at="item.published_at"
        :changes="count"
        :verified-at="form.verified_at"
        :reviews="editor.loaded.value?.reviews ?? 0"
        :checklist="editor.checklist.value"
        @changes="changesOpen = true"
        @hide="hideOpen = true"
        @remove="removeOpen = true"
      />
    </div>

    <AdminItemsBottomBar :info="spec" :live="editor.live.value" :slug="publishedSlug || form.slug" :changes="count" :busy="editor.busy.value" @publish="publishOpen = true" @changes="changesOpen = true" @discard="discardOpen = true" @hide="hideOpen = true" />

    <AdminMediaPicker v-if="picking !== 'gallery'" v-model:open="pickerOpen" :title="picking === 'og' ? 'Imagen para compartir' : 'Elegir portada'" @select="chosen" />
    <AdminMediaPicker v-else v-model:open="pickerOpen" title="Añadir a la galería" multiple :exclude="form.gallery" @select-many="addPhotos" />

    <AdminItemsPublishDialog v-model:open="publishOpen" :checklist="editor.checklist.value" :busy="editor.busy.value" :error="editor.publishError.value" :name="form.name" @confirm="publish" />
    <AdminEditorChangesDialog
      v-if="editor.live.value"
      v-model:open="changesOpen"
      :entries="editor.entries.value"
      :checklist="editor.checklist.value"
      :media-of="editor.mediaOf"
      :busy="editor.busy.value"
      :conflict="editor.conflict.value"
      :error="editor.draftError.value"
      @revert="editor.revert"
      @publish="publishChanges(false)"
      @force="publishChanges(true)"
      @discard="discardOpen = true"
      @reload="reload"
    />
    <AdminConfirmDelete
      v-model:open="discardOpen"
      level="simple"
      :title="`¿Descartar ${count === 1 ? 'el cambio' : `los ${count} cambios`}?`"
      description="El editor vuelve a la versión publicada. Lo que se ve en el sitio no cambia."
      confirm-label="Descartar cambios"
      :busy="editor.busy.value"
      @confirm="discard"
    />
    <AdminConfirmDelete
      v-model:open="hideOpen"
      level="simple"
      :title="`¿Ocultar «${form.name || 'Sin nombre'}»?`"
      :description="`Deja de verse en el sitio.${hiddenOpinions}${count ? ' Los cambios sin publicar se aplican a la ficha antes de ocultarla.' : ''} Puedes volver a publicarla cuando quieras.`"
      confirm-label="Ocultar ficha"
      :busy="editor.busy.value"
      @confirm="hide"
    />
    <AdminConfirmDelete
      v-model:open="removeOpen"
      level="simple"
      :title="`¿Eliminar «${form.name || 'Sin nombre'}»?`"
      description="No está publicada ni tiene opiniones. Queda en el registro de actividad."
      confirm-label="Eliminar ficha"
      :busy="editor.busy.value"
      @confirm="editor.remove"
    />
  </div>
</template>
