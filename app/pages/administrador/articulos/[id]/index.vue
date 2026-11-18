<script setup lang="ts">
import { articleDisplay } from '~/utils/admin-articles'
import type { AdminMedia } from '~/utils/admin-media'
import { isEmptyDoc } from '~/utils/article-editor'
import type { FormLocale } from '~/utils/article-form'

/**
 * `/administrador/articulos/[id]`: article editor (F6.4). Not-live articles are edited directly;
 * live ones on a draft of changes with "Publicar cambios" and a preview (part 2b, D23).
 */
definePageMeta({ layout: 'admin', i18n: false, adminEditor: true })

const id = String(useRoute().params.id)
const editor = useArticleEditor(id)
const { form, meta, errors, autosave, draft } = editor
const { success, error: toastError } = useAdminToast()
useAdminHead(() => form.value?.es.title || 'Editor de artículo')

const lang = ref<FormLocale>('es')
const settingsOpen = ref(false)
const publishOpen = ref(false)
const publishMode = ref<'now' | 'schedule'>('now')
const changesOpen = ref(false)
const discardOpen = ref(false)
const unpublishOpen = ref(false)
const picking = ref<'cover' | 'og' | null>(null)
const pickerOpen = computed({ get: () => picking.value !== null, set: (value) => !value && (picking.value = null) })

const display = computed(() => (meta.value ? articleDisplay({ status: meta.value.status, published_at: meta.value.publishedAt }) : 'draft'))
const cover = computed(() => editor.mediaOf(form.value?.coverMediaId ?? null))
const og = computed(() => editor.mediaOf(form.value?.ogMediaId ?? null))
const categoryOf = (categoryId: string) => editor.categories.value.find((c) => c.id === categoryId)?.name ?? 'Sin categoría'
const categoryColor = computed(() => {
  const color = editor.categories.value.find((c) => c.id === form.value?.categoryId)?.color
  return color && /^#[0-9a-f]{6}$/i.test(color) ? color : null
})
const categoryName = computed(() => categoryOf(form.value?.categoryId ?? ''))
const enIncomplete = computed(() => !!form.value && (!form.value.en.title.trim() || isEmptyDoc(form.value.en.body.json)))
/** Last save: this session's, or the stored time before the first autosave. */
const savedAt = computed(() => {
  if (autosave.savedAt.value) return autosave.savedAt.value
  if (editor.live.value) return draft.storedAt.value ? Date.parse(draft.storedAt.value) : null
  return meta.value ? Date.parse(meta.value.updatedAt) : null
})
const slugTaken = computed(() => ({ es: editor.slugTaken('es'), en: editor.slugTaken('en') }))
/** Slugs of the published version: an empty EN one means that language was never published. */
const publishedSlug = computed(() => ({ es: draft.published.value?.es.slug ?? '', en: draft.published.value?.en.slug ?? '' }))
const slugSuggestion = computed(() => ({ es: editor.slugSuggestion('es'), en: editor.slugSuggestion('en') }))

const changed = computed(() => (editor.live.value ? draft.changed.value : []))
const siteAuthor = useNoteAuthorName()
const authorOf = (id: string | null) =>
  (id && editor.authors.value.find((a) => a.id === id)?.name) || `Autor del sitio${siteAuthor.value ? ` (${siteAuthor.value})` : ''}`
const entries = computed(() => (editor.live.value ? draft.entries(categoryOf, authorOf) : []))

function chosen(item: AdminMedia) {
  if (!form.value) return
  editor.remember(item)
  if (picking.value === 'og') form.value.ogMediaId = item.id
  else form.value.coverMediaId = item.id
}
watch([publishOpen, changesOpen], ([publishing, reviewing]) => {
  if (publishing || reviewing) void editor.checkAlt()
})
function openPublish(mode: 'now' | 'schedule') {
  publishMode.value = mode
  publishOpen.value = true
}
async function run(action: () => Promise<boolean>) {
  if (await action()) publishOpen.value = false
}

async function publishChanges(force = false) {
  if (editor.busy.value) return
  editor.busy.value = true
  try {
    const version = await draft.publish(force)
    if (!version) return
    if (meta.value) meta.value.updatedAt = version
    changesOpen.value = false
    success('Cambios publicados')
  } finally {
    editor.busy.value = false
  }
}
async function discardChanges() {
  if (editor.busy.value) return
  editor.busy.value = true
  try {
    if (!(await draft.discard())) return toastError(draft.errorMessage.value)
    discardOpen.value = false
    changesOpen.value = false
    success('Cambios descartados')
  } finally {
    editor.busy.value = false
  }
}
async function unpublish() {
  if (await editor.unpublish()) unpublishOpen.value = false
}
const copyLink = useCopyLink()
const copyPreviewLink = () => copyLink(`${window.location.origin}${adminPath(`articulos/${id}/vista-previa`)}`, 'Enlace de vista previa copiado. Solo se abre con la sesión del panel.')
async function reload() {
  changesOpen.value = false
  await editor.reload()
}
/** The preview reads the saved draft, so flush the autosave first. */
async function preview() {
  await autosave.save()
  if (autosave.state.value === 'error') return toastError('No se ha guardado el último cambio. Reintenta antes de abrir la vista previa.')
  await navigateTo({ path: adminPath(`articulos/${id}/vista-previa`), query: { lang: lang.value } })
}

const shared = computed(() => ({
  meta: meta.value!,
  categories: editor.categories.value,
  authors: editor.authors.value,
  lang: lang.value,
  readonly: !editor.editable.value,
  cover: cover.value,
  og: og.value,
  errors: errors.value,
  checklist: editor.checklist.value,
  changed: changed.value,
}))
</script>

<template>
  <div v-if="editor.load.error.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="error" title="No se ha podido abrir el artículo" @retry="editor.load.refresh()" />
  </div>
  <div v-else-if="editor.notFound.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="empty" title="Este artículo no existe" description="Puede que lo hayan eliminado.">
      <NuxtLink :to="adminPath('articulos')" :class="admBtnGhost">Volver a Artículos</NuxtLink>
    </AdminStateBlock>
  </div>
  <AdminEditorSkeleton v-else-if="!form || !meta" />

  <div v-else>
    <AdminEditorHeader
      v-model:lang="lang"
      :title="form.es.title"
      :display="display"
      :readonly="!editor.editable.value"
      :live="editor.live.value"
      :changes="changed.length"
      :save="{ state: autosave.state.value, savedAt, message: autosave.errorMessage.value }"
      :en-incomplete="enIncomplete"
      :busy="editor.busy.value"
      :settings-open="settingsOpen"
      @retry="autosave.retry()"
      @publish="openPublish"
      @draft="editor.backToDraft()"
      @settings="settingsOpen = true"
      @preview="preview"
      @publish-changes="changesOpen = true"
      @changes="changesOpen = true"
      @discard="discardOpen = true"
      @copy="copyPreviewLink"
      @unpublish="unpublishOpen = true"
    />
    <AdminEditorChangesBand
      v-if="editor.live.value"
      :count="changed.length"
      :since="draft.version.value"
      :conflict="draft.conflict.value"
      @view="changesOpen = true"
      @discard="discardOpen = true"
      @reload="reload"
    />
    <div class="flex items-center justify-end border-b border-adm-line px-4 py-1.5 xl:hidden">
      <AdminEditorSaveStatus :state="autosave.state.value" :saved-at="savedAt" :message="autosave.errorMessage.value" :readonly="!editor.editable.value" @retry="autosave.retry()" />
    </div>

    <div class="flex items-start">
      <AdminEditorCanvas
        :key="draft.revision.value"
        v-model:form="form"
        :lang="lang"
        :readonly="!editor.editable.value"
        :live="editor.live.value"
        :published-slug="publishedSlug"
        :changed="changed"
        :cover="cover"
        :category-name="categoryName"
        :category-color="categoryColor"
        :errors="errors"
        :slug-taken="slugTaken"
        :slug-suggestion="slugSuggestion"
        @cover="picking = 'cover'"
        @remove-cover="form.coverMediaId = null"
        @media="editor.remember"
      />
      <aside aria-label="Ajustes del artículo" class="sticky top-12 hidden h-[calc(100dvh-3rem)] w-[340px] flex-none overflow-y-auto border-l border-adm-line bg-adm-side xl:block">
        <AdminEditorInspector v-model:form="form" v-bind="shared" @cover="picking = 'cover'" @og="picking = 'og'" @remove-cover="form.coverMediaId = null" @remove-og="form.ogMediaId = null" @view-changes="changesOpen = true" />
      </aside>
    </div>

    <AdminEditorBottomBar
      :live="editor.live.value"
      :changes="changed.length"
      :scheduled="display === 'scheduled'"
      :busy="editor.busy.value"
      :settings-open="settingsOpen"
      @settings="settingsOpen = true"
      @preview="preview"
      @primary="editor.live.value ? (changesOpen = true) : openPublish('now')"
      @changes="changesOpen = true"
      @discard="discardOpen = true"
      @copy="copyPreviewLink"
      @unpublish="unpublishOpen = true"
      @draft="editor.backToDraft()"
    />

    <AdminModal v-model:open="settingsOpen" title="Ajustes del artículo" placement="right">
      <!-- The modal body already pads (px-5): the inspector's own padding replaces it. -->
      <div class="-mx-5 -my-4">
        <AdminEditorInspector v-model:form="form" v-bind="shared" @cover="picking = 'cover'" @og="picking = 'og'" @remove-cover="form.coverMediaId = null" @remove-og="form.ogMediaId = null" @view-changes="changesOpen = true" />
      </div>
    </AdminModal>
    <AdminMediaPicker v-model:open="pickerOpen" :title="picking === 'og' ? 'Imagen para compartir' : 'Elegir portada'" @select="chosen" />
    <AdminEditorPublishDialog
      v-model:open="publishOpen"
      v-model:mode="publishMode"
      :checklist="editor.checklist.value"
      :busy="editor.busy.value"
      :scheduled="display === 'scheduled'"
      :scheduled-at="meta.publishedAt"
      @now="run(editor.publishNow)"
      @schedule="run(() => editor.schedule($event))"
      @draft="run(editor.backToDraft)"
    />
    <AdminEditorChangesDialog
      v-if="editor.live.value"
      v-model:open="changesOpen"
      :entries="entries"
      :checklist="editor.checklist.value"
      :media-of="editor.mediaOf"
      :busy="editor.busy.value"
      :conflict="draft.conflict.value"
      :error="draft.errorMessage.value"
      @revert="draft.revert"
      @publish="publishChanges(false)"
      @force="publishChanges(true)"
      @discard="discardOpen = true"
      @reload="reload"
    />
    <AdminUnpublishDialog v-model:open="unpublishOpen" :title="form.es.title" :changes="changed.length" :busy="editor.busy.value" @confirm="unpublish" />
    <AdminConfirmDelete
      v-model:open="discardOpen"
      level="simple"
      :title="`¿Descartar ${changed.length === 1 ? 'el cambio' : `los ${changed.length} cambios`}?`"
      description="El editor vuelve a la versión publicada. Lo que se ve en el sitio no cambia."
      confirm-label="Descartar cambios"
      :busy="editor.busy.value"
      @confirm="discardChanges"
    />
  </div>
</template>
