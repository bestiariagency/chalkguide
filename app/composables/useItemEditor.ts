import type { Database } from '~/types/database.types'
import { publishItemDraft, discardItemDraft, saveItemDraft } from '~/services/admin/item-drafts'
import { deleteItems } from '~/services/admin/items'
import { hideItem, publishItem, saveItemChanges, stampItemVerified, type LoadedItem, type PriceStamp } from '~/services/admin/item-editor'
import { loadItemForEditor } from '~/services/admin/item-editor-load'
import { uniqueSlug } from '~/utils/admin-articles'
import { itemErrorMessage } from '~/utils/admin-items'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm, Sections } from '~/utils/item-fields'
import type { ItemSpec } from '~/utils/item-spec'
import { altRefusal } from '~/utils/content-alt'
import { patchOf, revertField, type ItemPatch } from '~/utils/item-patch'
import { duplicateShoeCheck, itemCheckFields, violatedCheck } from '~/utils/check-violation'

const codeOf = (e: unknown) => (e as { code?: string } | null)?.code

/**
 * Editor of an item: gym (F6.7) or resoler (F6.8), per `spec`. An unpublished item is edited in place
 * (autosave to its tables); a published one on a draft of changes (D23: `save_draft` / `publish_draft` /
 * `discard_draft`, entity `item`). Nothing is written to a published item until "Publicar cambios".
 */
export function useItemEditor<F extends ItemForm>(id: string, spec: ItemSpec<F>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const form = ref<F | null>(null) as Ref<F | null>
  const loaded = shallowRef<LoadedItem | null>(null)
  const published = shallowRef<F | null>(null)
  const saved = shallowRef<Sections | null>(null)
  const taken = ref<Set<string>>(new Set())
  const media = ref<Record<string, AdminMedia>>({})
  const reviewId = ref<string | null>(null)
  const updatedAt = ref('')
  const live = ref(false)
  const base = ref('')
  const version = ref('')
  const storedAt = ref<string | null>(null)
  const hasDraft = ref(false)
  const conflict = ref(false)
  const draftError = ref('')
  const publishError = ref('')
  /** Bumped when the form is replaced from outside the editors (revert, discard) so they remount. */
  const revision = ref(0)
  const busy = ref(false)

  const load = useAsyncData(
    `admin-${spec.category}-${id}`,
    async () => {
      await loadAdminSanitizer() // `sectionsOf` (below) cleans the bodies synchronously
      return loadItemForEditor(client, id, spec)
    },
    { server: false },
  )
  const notFound = computed(() => load.data.value?.found === false)

  /** CHECKs the database refused while autosaving, shown on their fields. */
  const refused = useServerFieldErrors((key) => (form.value as unknown as Record<string, unknown> | null)?.[key])
  const duplicate = useShoeDuplicate(client, id, spec.category, form as Ref<{ brand?: string; model?: string } | null>)
  const errors = computed(() => (form.value ? { ...refused.errors.value, ...duplicate.errors.value, ...spec.validate(form.value, taken.value, live.value) } : {}))
  const editable = computed(() => !!form.value)

  const saver = useItemSaver<F>({
    form,
    errors,
    sectionsOf: spec.sectionsOf,
    enabled: editable,
    baseline: () => (live.value ? (published.value ? spec.sectionsOf(published.value, (h) => h) : null) : saved.value),
    sendEmpty: live,
    describe: (e) => itemErrorMessage(e, undefined, spec.noun),
    onError: (e) => {
      if (codeOf(e) === 'PT409') conflict.value = true
      const constraint = violatedCheck(e)
      const check = duplicateShoeCheck(e) ?? (constraint ? itemCheckFields(constraint, (field) => !!form.value && field in form.value) : null)
      // Held back on its field; one more save (without it) so the rest is not lost. Never twice for the same values.
      if (check && refused.add(check)) setTimeout(() => void saver.save(), 0)
    },
    send: async (patch, sections) => {
      if (live.value) {
        if (!Object.keys(patch).length) {
          await discardItemDraft(client, id)
          hasDraft.value = false
          return
        }
        const out: ItemPatch = { ...patch }
        if (!reviewId.value && (out.scores || out.author_review)) out.author_review = { visit_type: form.value?.visit_type ?? 'paid', ...out.author_review }
        const stored = await saveItemDraft(client, id, out, base.value)
        base.value = stored.baseUpdatedAt
        storedAt.value = stored.updatedAt
        hasDraft.value = true
        return
      }
      const result = await saveItemChanges(client, id, spec.category, patch, reviewId.value)
      reviewId.value = result.reviewId
      updatedAt.value = result.updatedAt
      saved.value = sections
    },
  })
  const { clean } = saver

  watch(
    () => load.data.value,
    (data) => {
      if (!data?.found || form.value) return
      const row = data.row
      loaded.value = row
      live.value = row.item.published
      reviewId.value = row.review?.id ?? null
      updatedAt.value = row.item.updated_at
      published.value = spec.fromRows({ item: row.item, detail: row.detail, review: row.review }, row.scores, row.gallery)
      taken.value = data.slugs
      media.value = Object.fromEntries(data.mediaRows.map((m) => [m.id, m]))
      form.value = data.shown
      saved.value = spec.sectionsOf(data.shown, clean)
      base.value = data.stored?.baseUpdatedAt ?? row.version
      version.value = row.version
      storedAt.value = data.stored?.updatedAt ?? null
      hasDraft.value = !!data.stored
      conflict.value = false
      saver.reset(live.value ? patchOf(data.stored?.payload) : {})
    },
    { immediate: true },
  )

  async function reload() {
    form.value = null
    publishError.value = ''
    draftError.value = ''
    await load.refresh()
  }

  const mediaOf = (mediaId: string | null) => (mediaId ? (media.value[mediaId] ?? null) : null)
  const remember = (item: AdminMedia) => (media.value = { ...media.value, [item.id]: item })
  const criteriaNames = computed(() => new Map((loaded.value?.criteria ?? []).map((c) => [c.id, c.name])))

  const slugTaken = computed(() => !!form.value?.slug && taken.value.has(form.value.slug))
  const slugSuggestion = computed(() => uniqueSlug(form.value?.slug || spec.slugBase, taken.value))

  const alt = useContentAlt('item', id)
  /** D27: reads the saved item's images without alt text; flushes the autosave first so it sees the latest edits. */
  async function checkAlt() {
    await saver.save()
    await alt.refresh()
  }
  const nameOf = (mediaId: string) => mediaOf(mediaId)?.original_filename ?? alt.issues.value.find((i) => i.id === mediaId)?.name
  const checklist = computed(() => (form.value ? spec.checklist(form.value, errors.value, mediaOf, alt.issues.value, { required: alt.issuesEn.value, advisory: alt.adviceEn.value }) : []))
  const canPublish = computed(() => checklist.value.filter((i) => i.blocking).every((i) => i.ok))

  const changed = computed(() => (live.value && form.value && published.value ? spec.changedIds(form.value, published.value) : []))
  const entries = computed(() => (live.value && form.value && published.value ? spec.describe(published.value, form.value, criteriaNames.value) : []))
  const revert = (key: string) => {
    if (!form.value || !published.value) return
    revertField(form.value, published.value, key)
    if (key.startsWith('body_json')) revision.value++
  }

  async function guarded<T>(work: () => Promise<T>, onError: (e: unknown) => void): Promise<T | null> {
    if (busy.value) return null
    busy.value = true
    try {
      return await work()
    } catch (e) {
      onError(e)
      return null
    } finally {
      busy.value = false
    }
  }
  /** Flushes the autosave; false (with a toast) when something could not be saved. */
  async function flush() {
    await saver.save()
    if (saver.state.value === 'error' || saver.state.value === 'blocked') {
      toastError('Hay cambios sin guardar con errores. Corrígelos primero.')
      return false
    }
    return true
  }
  const fail = (e: unknown) => {
    publishError.value = itemErrorMessage(e, nameOf, spec.noun)
    if (altRefusal(e)) void alt.refresh()
    toastError({ message: publishError.value, action: { label: 'Cerrar', run: () => {} } })
  }

  /** "Publicar" an unpublished item. */
  async function publish() {
    publishError.value = ''
    const done = await guarded(async () => {
      if (!(await flush())) return false
      await publishItem(client, id)
      return true
    }, fail)
    if (!done) return false
    await reload()
    success(spec.publishedToast)
    return true
  }

  /** "Publicar cambios" of a published item (applies the draft). */
  async function publishChanges(force = false) {
    draftError.value = ''
    const done = await guarded(async () => {
      if (!(await flush())) return false
      await publishItemDraft(client, id, force)
      return true
    }, (e) => {
      conflict.value = codeOf(e) === 'PT409'
      draftError.value = itemErrorMessage(e, nameOf, spec.noun)
      if (altRefusal(e)) void alt.refresh()
    })
    if (!done) return false
    await reload()
    success('Cambios publicados')
    return true
  }

  async function discardChanges() {
    const done = await guarded(async () => {
      await saver.save()
      await discardItemDraft(client, id)
      return true
    }, (e) => toastError(itemErrorMessage(e, undefined, spec.noun)))
    if (!done) return false
    revision.value++
    await reload()
    success('Cambios descartados')
    return true
  }

  /** Takes the item off the site; opinions and review stay. */
  async function hide() {
    const done = await guarded(async () => {
      if (!(await flush())) return false
      await hideItem(client, id)
      return true
    }, fail)
    if (!done) return false
    await reload()
    success('Ficha oculta')
    return true
  }

  /**
   * "Verificar hoy" (`verified_at`, or the prices date: `prices_verified_at` / `price_checked_at`). Unpublished: just
   * fills the field (autosave). Published: stamps only that column straight on the item (the database
   * allows it on live items), not into the draft, and moves the published baseline so the field does
   * not show as a pending change.
   */
  async function verifyToday(date: string, column: PriceStamp = 'verified_at') {
    if (!form.value) return false
    const target = form.value as unknown as Record<string, unknown>
    if (!live.value) {
      target[column] = date
      return true
    }
    const done = await guarded(async () => {
      const stamped = await stampItemVerified(client, id, spec.category, column, date)
      if (published.value) published.value = { ...published.value, [column]: date }
      base.value = stamped
      version.value = stamped
      return true
    }, fail)
    if (!done || !form.value) return false
    target[column] = date
    // A draft of changes may carry another date: rewrite it now so "Publicar cambios" cannot overwrite the new date.
    if (hasDraft.value) await saver.save()
    success('Verificación guardada')
    return true
  }

  async function remove() {
    const done = await guarded(async () => (await deleteItems(client, spec.category, [id])) > 0, fail)
    if (!done) return false
    success(spec.removedToast)
    await navigateTo(adminPath(spec.route))
    return true
  }

  return {
    load, form, loaded, notFound, errors, live, editable, busy, saver, reload, mediaOf, remember,
    slugTaken, slugSuggestion, checklist, checkAlt, canPublish, changed, entries, revert, revision, conflict, draftError, publishError,
    base, version, storedAt, hasDraft, updatedAt, published, publish, publishChanges, discardChanges, hide, remove, verifyToday,
  }
}
