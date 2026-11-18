<script setup lang="ts">
import type { AdminMedia } from '~/utils/admin-media'
import { LEGAL_NO_UNPUBLISH, PAGE_DEFS, revisedLabel, todayIso, type PageKey } from '~/utils/admin-pages'
import { isEmptyDoc } from '~/utils/article-editor'
import type { FormLocale } from '~/utils/article-form'
import { loadSeoDefaults } from '~/utils/page-seo-defaults'
import { englishComplete, englishFilled, textChanged, type PageChecklistItem } from '~/utils/page-form'
import type { PageRevision } from '~/services/admin/page-drafts'

/**
 * Editor of a fixed page (F6.13, D34): the article editor with fewer pieces. Not-published pages are
 * edited directly; published ones on a draft of changes with "Publicar cambios" (D23). No cover, lead,
 * category, schedule or URL: the routes are fixed.
 */
const props = defineProps<{ pageKey: PageKey }>()
const def = PAGE_DEFS[props.pageKey]
const editor = usePageEditor(props.pageKey)
const { form, meta, errors, autosave, draft } = editor
const { success, error: toastError } = useAdminToast()
useAdminHead(() => form.value?.es.title || def.label)

const lang = ref<FormLocale>('es')
const settingsOpen = ref(false)
const publishOpen = ref(false)
const changesOpen = ref(false)
const discardOpen = ref(false)
const unpublishOpen = ref(false)
const pickerOpen = ref(false)
const revision = ref<PageRevision>('today')
const attempted = ref(false)
const errorsBanner = ref<{ focus: () => void } | null>(null)

const today = computed(() => revisedLabel(todayIso()))
const empty = computed(() => !form.value || isEmptyDoc(form.value.es.body.json))
const enIncomplete = computed(() => !!form.value && englishFilled(form.value.en) && !englishComplete(form.value.en))
const enLive = computed(() => !!draft.published.value && englishComplete(draft.published.value.en))
const enBlocker = computed(() => editor.blockers.value.find((i) => (i.key === 'en' || i.key === 'alt-en') && i.blocking) ?? null)
const changed = computed(() => (editor.live.value ? draft.changed.value : []))
const entries = computed(() => (editor.live.value ? draft.entries() : []))
const og = computed(() => editor.mediaOf(form.value?.ogMediaId ?? null))
/** Default description of the page in the active language (the panel does not load the EN messages, so read the files). */
const seoDefaults = shallowRef<Awaited<ReturnType<typeof loadSeoDefaults>> | null>(null)
onMounted(async () => (seoDefaults.value = await loadSeoDefaults()))
const fallback = computed(() => seoDefaults.value?.[lang.value][def.descriptionKey] ?? '')
const savedAt = computed(() => {
  if (autosave.savedAt.value) return autosave.savedAt.value
  if (editor.live.value) return draft.storedAt.value ? Date.parse(draft.storedAt.value) : null
  return meta.value ? Date.parse(meta.value.updatedAt) : null
})
/** The reader's date moves only when the title or the text change (legal pages). */
const textDirty = computed(() => editor.live.value && !!form.value && !!draft.published.value && textChanged(draft.published.value, form.value))
const revised = computed(() => {
  if (!def.legal || !meta.value) return null
  if (!meta.value.published || !meta.value.revisedOn) return { text: today.value, note: 'se fija al publicar' }
  return { text: revisedLabel(meta.value.revisedOn), note: textDirty.value ? 'se actualizará al publicar los cambios' : '' }
})
const previous = computed(() => (meta.value?.revisedOn ? revisedLabel(meta.value.revisedOn) : null))
const unpublishDisabled = computed(() => (def.legal ? LEGAL_NO_UNPUBLISH : undefined))

watch([publishOpen, changesOpen], ([publishing, reviewing]) => {
  if (publishing || reviewing) void editor.checkAlt()
  if (reviewing) revision.value = 'today'
})
// `#cambios` (row menu of the list): open the diff once the editor has loaded.
const route = useRoute()
const stop = watch(() => [form.value, editor.live.value, changed.value.length] as const, ([loaded, live, count]) => {
  if (!loaded) return
  if (live && count && route.hash === '#cambios') changesOpen.value = true
  stop()
}, { flush: 'post' })

function chosen(item: AdminMedia) {
  if (!form.value) return
  editor.remember(item)
  form.value.ogMediaId = item.id
}

const visible = (selector: string) => [...document.querySelectorAll<HTMLElement>(selector)].find((el) => el.offsetParent !== null)
/** Brings the author to what has to be fixed: language, settings panel if needed, then focus. */
async function goTo(target: NonNullable<PageChecklistItem['target']>) {
  const seoKey = Object.keys(errors.value).find((k) => /seo/i.test(k))
  if (target === 'en' || (target === 'seo' && seoKey?.startsWith('en'))) lang.value = 'en'
  else if (target !== 'marks') lang.value = 'es'
  const selector = target === 'title' ? '[data-page-field="title"]'
    : target === 'seo' ? `[data-page-field="${seoKey?.endsWith('Description') ? 'seo-description' : 'seo-title'}"] :is(input, textarea)`
    : '[data-page-field="body"] [role="textbox"]'
  if (target === 'seo' && !matchMedia('(min-width: 1280px)').matches) settingsOpen.value = true
  publishOpen.value = false
  changesOpen.value = false
  await nextTick()
  await new Promise((resolve) => setTimeout(resolve, 60))
  const el = visible(selector)
  el?.scrollIntoView({ block: 'center' })
  el?.focus()
}

async function startPublish() {
  await editor.checkAlt()
  if (editor.blockers.value.length) {
    attempted.value = true
    toastError({ message: `No se ha publicado: ${editor.blockers.value.length === 1 ? 'hay 1 cosa' : `hay ${editor.blockers.value.length} cosas`} que arreglar.`, action: { label: 'Cerrar', run: () => {} } })
    await nextTick()
    errorsBanner.value?.focus()
    return
  }
  attempted.value = false
  publishOpen.value = true
}
async function publishFirst() {
  if (!(await editor.publishNow())) return
  publishOpen.value = false
  attempted.value = false
  success({ message: `«${form.value?.es.title || def.label}» publicada · se verá en el sitio en unos minutos`, action: { label: 'Ver en el sitio', run: () => window.open(def.routeEs, '_blank', 'noopener') } })
}
async function publishChanges(force = false) {
  if (!(await editor.publishChanges(force, revision.value))) return
  changesOpen.value = false
  success('Cambios publicados · se verán en el sitio en unos minutos')
}
async function discard() {
  if (!(await editor.discardChanges())) return
  discardOpen.value = false
  changesOpen.value = false
  success('Cambios descartados')
}
async function unpublish() {
  if (await editor.unpublish()) unpublishOpen.value = false
}
async function reload() {
  changesOpen.value = false
  await editor.reload()
}

const copyLink = useCopyLink()
const copyPreviewLink = () => copyLink(`${window.location.origin}${adminPath(`paginas/${def.key}/vista-previa`)}`, 'Enlace de vista previa copiado. Solo se abre con la sesión del panel.')
/** The preview reads the saved draft, so flush the autosave first. */
async function preview() {
  await autosave.save()
  if (autosave.state.value === 'error') return toastError('No se ha guardado el último cambio. Reintenta antes de abrir la vista previa.')
  await navigateTo({ path: adminPath(`paginas/${def.key}/vista-previa`), query: { lang: lang.value } })
}
const primary = () => (editor.live.value ? (changesOpen.value = true) : startPublish())

const shared = computed(() => ({
  def,
  meta: meta.value!,
  lang: lang.value,
  readonly: !editor.editable.value,
  errors: errors.value,
  checklist: editor.checklist.value,
  og: og.value,
  changed: changed.value,
  enLive: enLive.value,
  enReady: !!form.value && englishComplete(form.value.en),
  empty: empty.value,
  fallback: fallback.value,
  versions: editor.versions.value,
  draftAt: draft.storedAt.value,
  nextRevision: textDirty.value ? `hoy, ${today.value}` : undefined,
}))
</script>

<template>
  <div v-if="editor.load.error.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="error" :title="`No se ha podido abrir «${def.label}»`" description="Lo publicado no ha cambiado. Comprueba la conexión y vuelve a intentarlo." @retry="editor.load.refresh()">
      <NuxtLink :to="adminPath('paginas')" :class="admBtnGhost">Volver a páginas</NuxtLink>
    </AdminStateBlock>
  </div>
  <div v-else-if="editor.notFound.value" class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="empty" title="Esta página no existe todavía" description="Falta crearla en la base de datos. Avisa a quien mantiene el sistema.">
      <NuxtLink :to="adminPath('paginas')" :class="admBtnGhost">Volver a páginas</NuxtLink>
    </AdminStateBlock>
  </div>
  <AdminPagesEditorSkeleton v-else-if="!form || !meta" />

  <div v-else>
    <AdminEditorHeader
      v-model:lang="lang"
      :title="form.es.title || def.label"
      :display="meta.published ? 'published' : 'draft'"
      :status-label="meta.published ? 'Publicada' : empty ? 'Sin contenido' : 'Borrador'"
      :readonly="!editor.editable.value"
      :live="editor.live.value"
      :changes="changed.length"
      :save="{ state: autosave.state.value, savedAt, message: autosave.errorMessage.value }"
      :en-incomplete="enIncomplete"
      :busy="editor.busy.value"
      :settings-open="settingsOpen"
      :section="{ slug: 'paginas', label: 'Páginas' }"
      settings-label="Ajustes de la página"
      no-schedule
      :publish-blocked="empty"
      :unpublish-disabled="unpublishDisabled"
      @retry="autosave.retry()"
      @publish="startPublish"
      @settings="settingsOpen = true"
      @preview="preview"
      @publish-changes="changesOpen = true"
      @changes="changesOpen = true"
      @discard="discardOpen = true"
      @copy="copyPreviewLink"
      @unpublish="unpublishOpen = true"
    />
    <AdminEditorChangesBand v-if="editor.live.value" :count="changed.length" :since="draft.version.value" :conflict="draft.conflict.value" published="Esta página está publicada" @view="changesOpen = true" @discard="discardOpen = true" @reload="reload" />
    <AdminPagesBands :def="def" :live="editor.live.value" :english="enBlocker" @goto="goTo" />
    <AdminPagesErrors v-if="attempted && (editor.blockers.value.length || editor.publishError.value)" ref="errorsBanner" :items="editor.blockers.value" :message="editor.publishError.value" @goto="(item) => item.target && goTo(item.target)" />
    <div class="flex items-center justify-end border-b border-adm-line px-4 py-1.5 xl:hidden">
      <AdminEditorSaveStatus :state="autosave.state.value" :saved-at="savedAt" :message="autosave.errorMessage.value" :readonly="!editor.editable.value" @retry="autosave.retry()" />
    </div>

    <div class="flex items-start">
      <AdminPagesCanvas :key="draft.revision.value" v-model:form="form" :def="def" :lang="lang" :readonly="!editor.editable.value" :changed="changed" :errors="errors" :revised="revised" @media="editor.remember" />
      <aside aria-label="Ajustes de la página" class="sticky top-12 hidden h-[calc(100dvh-3rem)] w-[340px] flex-none overflow-y-auto border-l border-adm-line bg-adm-side xl:block">
        <AdminPagesInspector v-model:form="form" v-bind="shared" @og="pickerOpen = true" @remove-og="form.ogMediaId = null" @view-changes="changesOpen = true" />
      </aside>
    </div>

    <AdminEditorBottomBar :live="editor.live.value" :changes="changed.length" :busy="editor.busy.value" :settings-open="settingsOpen" :unpublish-disabled="unpublishDisabled" :publish-blocked="empty" @settings="settingsOpen = true" @preview="preview" @primary="primary" @changes="changesOpen = true" @discard="discardOpen = true" @copy="copyPreviewLink" @unpublish="unpublishOpen = true" />

    <AdminModal v-model:open="settingsOpen" title="Ajustes de la página" placement="right">
      <!-- The modal body already pads (px-5): the inspector's own padding replaces it. -->
      <div class="-mx-5 -my-4"><AdminPagesInspector v-model:form="form" v-bind="shared" @og="pickerOpen = true" @remove-og="form.ogMediaId = null" @view-changes="changesOpen = true" /></div>
    </AdminModal>
    <AdminMediaPicker v-model:open="pickerOpen" title="Imagen para compartir" @select="chosen" />
    <AdminPagesPublishDialog v-model:open="publishOpen" :def="def" :checklist="editor.checklist.value" :busy="editor.busy.value" :today="today" :noindex="form.noindex" :marks="editor.marks.value" :error="editor.publishError.value" @publish="publishFirst" @review="goTo('marks')" />
    <AdminEditorChangesDialog
      v-if="editor.live.value"
      v-model:open="changesOpen"
      :entries="entries"
      :checklist="editor.checklist.value"
      :media-of="editor.mediaOf"
      :busy="editor.busy.value"
      :conflict="draft.conflict.value"
      :error="editor.publishError.value || draft.errorMessage.value"
      description="Frente a la versión publicada. Revisa y publica: los cambios se verán en el sitio en unos minutos."
      @revert="draft.revert"
      @publish="publishChanges(false)"
      @force="publishChanges(true)"
      @discard="discardOpen = true"
      @reload="reload"
    >
      <template #extra><AdminPagesChangesExtra v-model="revision" :legal="def.legal" :text-changed="textDirty" :today="today" :previous="previous" :marks="editor.marks.value" @review="goTo('marks')" /></template>
    </AdminEditorChangesDialog>
    <AdminConfirmDelete
      v-model:open="unpublishOpen"
      level="simple"
      :title="`¿Despublicar «${form.es.title || def.label}»?`"
      :description="`${def.routeEs} mostrará «Esta página aún no está publicada» y dejará de salir en buscadores; ${def.routeEn} dará error 404. Los enlaces del sitio que apuntan aquí (${def.links.join(', ')}) seguirán llevando a ese aviso. El texto no se borra: vuelve a borrador y puedes publicarlo otra vez.`"
      confirm-label="Despublicar"
      :busy="editor.busy.value"
      @confirm="unpublish"
    />
    <AdminConfirmDelete
      v-model:open="discardOpen"
      level="simple"
      :title="`¿Descartar ${changed.length === 1 ? 'el cambio' : `los ${changed.length} cambios`}?`"
      :description="`«${def.label}» vuelve a la versión publicada. Lo que se ve en el sitio no cambia.`"
      confirm-label="Descartar cambios"
      :busy="editor.busy.value"
      @confirm="discard"
    />
  </div>
</template>
