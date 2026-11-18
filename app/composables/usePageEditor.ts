import type { Database } from '~/types/database.types'
import { fetchMediaByIds } from '~/services/admin/article-editor'
import { fetchPageDraft, type PageRevision } from '~/services/admin/page-drafts'
import { fetchPageForEdit, fetchPageState, fetchPageVersions, publishPage, refreshPageBodies, unpublishPage, type PageVersion } from '~/services/admin/pages'
import { PAGE_DEFS, pageErrorMessage, type PageKey } from '~/utils/admin-pages'
import type { AdminMedia } from '~/utils/admin-media'
import { articleCheckFields, violatedCheck } from '~/utils/check-violation'
import { altRefusal, mergeAlt } from '~/utils/content-alt'
import { applyDraftPage, draftPageOf } from '~/utils/page-changes'
import { pageChecklist, pageFormFromRow, pageMetaFromRow, provisionalCount, validatePage, type PageForm, type PageMeta } from '~/utils/page-form'

/**
 * Editor of one of the five fixed pages (F6.13, D34): loads it, keeps the form, validates, autosaves
 * and runs publish / unpublish. A not-published page is edited directly; a PUBLISHED one on a draft of
 * changes laid over the published version (D23, `usePageDraft`): nothing is written to `pages` until
 * "Publicar cambios". Same shape as `useArticleEditor`, without categories, slugs, cover or schedule.
 */
export function usePageEditor(key: PageKey) {
  const def = PAGE_DEFS[key]
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const id = ref('')
  const form = ref<PageForm | null>(null)
  const meta = ref<PageMeta | null>(null)
  const media = ref<Record<string, AdminMedia>>({})
  const versions = ref<PageVersion[]>([])

  const load = useAsyncData(
    `admin-page-${key}`,
    async () => {
      const loaded = await fetchPageForEdit(client, key)
      if (!loaded) return { found: false as const }
      const stored = await fetchPageDraft(client, loaded.id)
      const [row, shown] = await refreshPageBodies(client, [loaded, applyDraftPage(loaded, draftPageOf(stored?.payload))])
      if (!row || !shown) return { found: false as const }
      const ids = [...new Set([row.og_media_id, shown.og_media_id].filter((v): v is string => !!v))]
      const [mediaRows, history] = await Promise.all([fetchMediaByIds(client, ids), def.legal ? fetchPageVersions(client, key).catch(() => []) : Promise.resolve([])])
      return { found: true as const, row, shown, stored, mediaRows, history }
    },
    { server: false },
  )
  const notFound = computed(() => load.data.value?.found === false)

  /** CHECKs the database refused while autosaving, shown on their fields. */
  const refused = useServerFieldErrors((path) => path.split('.').reduce<unknown>((value, part) => (value as Record<string, unknown> | null | undefined)?.[part], form.value))
  const errors = computed(() => (form.value ? { ...refused.errors.value, ...validatePage(form.value) } : {}))
  const live = computed(() => !!meta.value?.published)
  const editable = computed(() => !!form.value && !!meta.value)

  function onSaveError(e: unknown) {
    const constraint = violatedCheck(e)
    const check = constraint ? articleCheckFields(constraint, form.value?.en.title ?? '') : null
    if (check && refused.add(check)) setTimeout(() => void (live.value ? draft.save() : direct.save()), 0)
  }

  const alt = useContentAlt('page', id)
  const mediaOf = (mediaId: string | null) => (mediaId ? (media.value[mediaId] ?? null) : null)
  const remember = (item: AdminMedia) => (media.value = { ...media.value, [item.id]: item })
  const nameOf = (mediaId: string) => mediaOf(mediaId)?.original_filename ?? alt.issues.value.find((i) => i.id === mediaId)?.name
  const draft = usePageDraft({ id, form, errors, enabled: live, onError: onSaveError, nameOf, onAltRefused: () => void alt.refresh() })
  const direct = usePageAutosave({
    id,
    form,
    errors,
    enabled: computed(() => editable.value && !live.value),
    onError: onSaveError,
    onSaved: (updatedAt) => {
      if (meta.value) meta.value.updatedAt = updatedAt
    },
  })

  watch(
    () => load.data.value,
    (data) => {
      if (!data?.found || form.value) return
      id.value = data.row.id
      form.value = pageFormFromRow(data.shown)
      meta.value = pageMetaFromRow(data.row)
      media.value = Object.fromEntries(data.mediaRows.map((m) => [m.id, m]))
      versions.value = data.history
      direct.reset(form.value)
      if (live.value) {
        const { stored } = data
        draft.init(pageFormFromRow(data.row), data.row.updated_at, stored ? { page: draftPageOf(stored.payload), baseUpdatedAt: stored.baseUpdatedAt, updatedAt: stored.updatedAt } : null)
      }
    },
    { immediate: true },
  )

  /** One saver for the page: the draft's when the page is published, the direct one otherwise. */
  const autosave = {
    state: computed(() => (live.value ? draft.state.value : direct.state.value)),
    savedAt: computed(() => (live.value ? draft.savedAt.value : direct.savedAt.value)),
    errorMessage: computed(() => (live.value ? draft.errorMessage.value : direct.errorMessage.value)),
    save: () => (live.value ? draft.save() : direct.save()),
    retry: () => (live.value ? draft.save() : direct.save()),
  }

  /** Throws the local form away and reads everything again (after a publish conflict or unpublishing). */
  async function reload() {
    form.value = null
    meta.value = null
    await load.refresh()
  }

  const checklist = computed(() => {
    if (!form.value) return []
    const og = mediaOf(form.value.ogMediaId)
    const local = og && !og.alt_es?.trim() ? [{ id: og.id, name: og.original_filename }] : []
    return pageChecklist(def, form.value, errors.value, { hasCover: false, altIssues: mergeAlt(local, alt.issues.value), altEnIssues: alt.issuesEn.value, altEnAdvice: alt.adviceEn.value })
  })
  const marks = computed(() => (form.value ? provisionalCount(form.value) : 0))
  const blockers = computed(() => checklist.value.filter((i) => i.blocking && !i.ok))
  /** D27: reads the saved page's images without alt text (flushing the autosave first). */
  async function checkAlt() {
    await autosave.save()
    await alt.refresh()
  }

  const busy = ref(false)
  /** Message of the last refused publication, shown in the banner of the editor. */
  const publishError = ref('')
  const failed = () => autosave.state.value === 'error' || autosave.state.value === 'blocked'
  const CAN_NOT_SAVE = 'Hay cambios sin guardar con errores. Corrígelos primero.'

  async function refreshVersions() {
    if (def.legal) versions.value = await fetchPageVersions(client, key).catch(() => versions.value)
  }

  /** First publication: flushes the autosave, then `published = true` (legal pages get `revised_on` = today and a version). */
  async function publishNow() {
    if (!meta.value || !form.value || busy.value) return false
    busy.value = true
    publishError.value = ''
    try {
      await autosave.save()
      if (failed()) {
        publishError.value = CAN_NOT_SAVE
        return false
      }
      const done = await publishPage(client, id.value)
      meta.value = { ...meta.value, published: true, updatedAt: done.updatedAt, revisedOn: done.revisedOn }
      draft.init(form.value, done.updatedAt, null)
      await refreshVersions()
      return true
    } catch (e) {
      publishError.value = pageErrorMessage(e, nameOf)
      if (altRefusal(e)) void alt.refresh()
      return false
    } finally {
      busy.value = false
    }
  }

  /** Publishes the draft of changes. `how` (legal pages only): today's date or keep the previous one. */
  async function publishChanges(force = false, how: PageRevision = 'today') {
    if (!meta.value || busy.value) return false
    busy.value = true
    publishError.value = ''
    try {
      const version = await draft.publish(force, def.legal ? how : undefined)
      if (!version) {
        publishError.value = draft.errorMessage.value
        return false
      }
      const state = await fetchPageState(client, id.value).catch(() => null)
      meta.value = { ...meta.value, updatedAt: version, revisedOn: state?.revisedOn ?? meta.value.revisedOn }
      await refreshVersions()
      return true
    } finally {
      busy.value = false
    }
  }

  async function discardChanges() {
    if (busy.value) return false
    busy.value = true
    try {
      if (await draft.discard()) return true
      toastError(draft.errorMessage.value)
      return false
    } finally {
      busy.value = false
    }
  }

  /** Takes the page off the site (about / transparency; the database refuses legal ones). Reloads it as a plain draft. */
  async function unpublish() {
    if (!meta.value || busy.value || !live.value || def.legal) return false
    busy.value = true
    try {
      await autosave.save()
      if (failed()) {
        toastError(CAN_NOT_SAVE)
        return false
      }
      await unpublishPage(client, id.value)
      await reload()
      success('Página despublicada · vuelve a borrador')
      return true
    } catch (e) {
      toastError({ message: pageErrorMessage(e), action: { label: 'Cerrar', run: () => {} } })
      return false
    } finally {
      busy.value = false
    }
  }

  return {
    def,
    id,
    load,
    form,
    meta,
    notFound,
    errors,
    live,
    editable,
    autosave,
    draft,
    versions,
    reload,
    mediaOf,
    remember,
    checklist,
    blockers,
    marks,
    checkAlt,
    busy,
    publishError,
    publishNow,
    publishChanges,
    discardChanges,
    unpublish,
  }
}
