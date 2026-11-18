import type { Database } from '~/types/database.types'
import { articleCheckFields, violatedCheck } from '~/utils/check-violation'
import { fetchArticleDraft } from '~/services/admin/article-drafts'
import { fetchArticleForEdit, fetchMediaByIds, refreshArticleBodies, saveArticleChanges } from '~/services/admin/article-editor'
import { fetchArticleAuthors, fetchArticleCategories, takenSlugs, unpublishArticle } from '~/services/admin/articles'
import { articleDisplay, articleErrorMessage, uniqueSlug } from '~/utils/admin-articles'
import type { AdminMedia } from '~/utils/admin-media'
import { altRefusal, mergeAlt } from '~/utils/content-alt'
import { applyDraftArticle, draftArticleOf } from '~/utils/article-changes'
import {
  formFromRow,
  metaFromRow,
  publishChecklist,
  validateArticle,
  type ArticleForm,
  type ArticleMeta,
  type FormLocale,
  type TakenSlugs,
} from '~/utils/article-form'

/**
 * Editor of an article (F6.4): loads it, keeps the form, validates, autosaves and runs the status
 * transitions. A not-live article is edited directly (part 2a); a LIVE one is edited on a draft of
 * changes laid over the published version (part 2b, D23, `useArticleDraft`): nothing is written to
 * `articles` until "Publicar cambios".
 */
export function useArticleEditor(id: string) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const form = ref<ArticleForm | null>(null)
  const meta = ref<ArticleMeta | null>(null)
  const taken = ref<TakenSlugs>({ es: new Set(), en: new Set() })
  const media = ref<Record<string, AdminMedia>>({})

  const load = useAsyncData(
    `admin-article-${id}`,
    async () => {
      const loaded = await fetchArticleForEdit(client, id)
      if (!loaded) return { found: false as const }
      const stored = await fetchArticleDraft(client, id)
      const [row, shown] = await refreshArticleBodies(client, [loaded, applyDraftArticle(loaded, draftArticleOf(stored?.payload))])
      if (!row || !shown) return { found: false as const }
      const ids = [row.cover_media_id, row.og_media_id, shown.cover_media_id, shown.og_media_id].filter((v): v is string => !!v)
      const [categories, authors, slugs, mediaRows] = await Promise.all([
        fetchArticleCategories(client),
        fetchArticleAuthors(client),
        takenSlugs(client, id),
        fetchMediaByIds(client, [...new Set(ids)]),
      ])
      return { found: true as const, row, shown, stored, categories, authors, slugs, mediaRows }
    },
    { server: false },
  )

  const categories = computed(() => (load.data.value?.found ? load.data.value.categories : []))
  const authors = computed(() => (load.data.value?.found ? load.data.value.authors : []))
  const notFound = computed(() => load.data.value?.found === false)

  /** CHECKs the database refused while autosaving, shown on their fields. */
  const refused = useServerFieldErrors((key) => key.split('.').reduce<unknown>((value, part) => (value as Record<string, unknown> | null | undefined)?.[part], form.value))
  const errors = computed(() => (form.value ? { ...refused.errors.value, ...validateArticle(form.value, taken.value) } : {}))
  /** Maps a refused CHECK to its fields and saves once more without them; never twice for the same values. */
  function onSaveError(e: unknown) {
    const constraint = violatedCheck(e)
    const check = constraint ? articleCheckFields(constraint, form.value?.en.title ?? '') : null
    if (check && refused.add(check)) setTimeout(() => void (live.value ? draft.save() : direct.save()), 0)
  }
  const live = computed(() => (meta.value ? articleDisplay({ status: meta.value.status, published_at: meta.value.publishedAt }) === 'published' : false))
  /** Loaded articles are always editable: directly when not live, on a draft of changes when live. */
  const editable = computed(() => !!form.value && !!meta.value)

  const alt = useContentAlt('article', id)
  const nameOf = (mediaId: string) => mediaOf(mediaId)?.original_filename ?? alt.issues.value.find((i) => i.id === mediaId)?.name
  const draft = useArticleDraft({ id, form, errors, enabled: live, onError: (e) => onSaveError(e), nameOf, onAltRefused: () => void alt.refresh() })
  const direct = useArticleAutosave({
    id,
    form,
    errors,
    enabled: computed(() => editable.value && !live.value),
    onError: (e) => onSaveError(e),
    onSaved: (updatedAt) => {
      if (meta.value) meta.value.updatedAt = updatedAt
    },
  })

  watch(
    () => load.data.value,
    (data) => {
      if (!data?.found || form.value) return
      form.value = formFromRow(data.shown)
      meta.value = metaFromRow(data.row)
      taken.value = data.slugs
      media.value = Object.fromEntries(data.mediaRows.map((m) => [m.id, m]))
      direct.reset(form.value)
      if (live.value) {
        const { stored } = data
        draft.init(formFromRow(data.row), data.row.updated_at, stored ? { article: draftArticleOf(stored.payload), baseUpdatedAt: stored.baseUpdatedAt, updatedAt: stored.updatedAt } : null)
      }
    },
    { immediate: true },
  )

  /** One saver for the page: the draft's when the article is live, the direct one otherwise. */
  const autosave = {
    state: computed(() => (live.value ? draft.state.value : direct.state.value)),
    savedAt: computed(() => (live.value ? draft.savedAt.value : direct.savedAt.value)),
    errorMessage: computed(() => (live.value ? draft.errorMessage.value : direct.errorMessage.value)),
    save: () => (live.value ? draft.save() : direct.save()),
    retry: () => (live.value ? draft.save() : direct.save()),
  }

  /** Throws the local form away and reads everything again (after a publish conflict). */
  async function reload() {
    form.value = null
    meta.value = null
    await load.refresh()
  }

  const mediaOf = (mediaId: string | null) => (mediaId ? (media.value[mediaId] ?? null) : null)
  const remember = (item: AdminMedia) => (media.value = { ...media.value, [item.id]: item })

  const slugTaken = (locale: FormLocale) => {
    const slug = form.value?.[locale].slug
    return !!slug && taken.value[locale].has(slug)
  }
  const slugSuggestion = (locale: FormLocale) => uniqueSlug(form.value?.[locale].slug || 'articulo', taken.value[locale])

  const checklist = computed(() => {
    if (!form.value) return []
    const cover = mediaOf(form.value.coverMediaId)
    const og = mediaOf(form.value.ogMediaId)
    const local = [cover, og].filter((m): m is AdminMedia => !!m && !m.alt_es?.trim()).map((m) => ({ id: m.id, name: m.original_filename }))
    return publishChecklist(form.value, errors.value, { hasCover: !!cover, altIssues: mergeAlt(local, alt.issues.value), altEnIssues: alt.issuesEn.value, altEnAdvice: alt.adviceEn.value })
  })
  /** D27: reads the saved article's images without alt text (flushing the autosave first). */
  async function checkAlt() {
    await autosave.save()
    await alt.refresh()
  }
  const canPublish = computed(() => checklist.value.filter((i) => i.blocking).every((i) => i.ok))
  const missing = computed(() => checklist.value.filter((i) => i.blocking && !i.ok).map((i) => i.hint ?? i.label))

  const busy = ref(false)
  /** Flushes the autosave, then changes status. Returns whether it worked. */
  async function transition(patch: { status: 'draft' | 'published' | 'scheduled'; published_at: string | null }, message: string) {
    if (!meta.value || busy.value) return false
    busy.value = true
    try {
      await autosave.save()
      if (autosave.state.value === 'error' || autosave.state.value === 'blocked') {
        toastError('Hay cambios sin guardar con errores. Corrígelos primero.')
        return false
      }
      const updatedAt = await saveArticleChanges(client, id, patch)
      meta.value = { ...meta.value, status: patch.status, publishedAt: patch.published_at, updatedAt }
      if (live.value && form.value) draft.init(form.value, updatedAt, null)
      success(message)
      return true
    } catch (e) {
      toastError({ message: articleErrorMessage(e, nameOf), action: { label: 'Cerrar', run: () => {} } })
      if (altRefusal(e)) void alt.refresh()
      return false
    } finally {
      busy.value = false
    }
  }

  const publishNow = () => transition({ status: 'published', published_at: new Date().toISOString() }, 'Artículo publicado')
  const schedule = (iso: string) => transition({ status: 'scheduled', published_at: iso }, 'Artículo programado')
  const backToDraft = () => transition({ status: 'draft', published_at: null }, 'Vuelve a ser un borrador')

  /**
   * Takes the article off the site (RPC `unpublish_article`): it becomes a draft and keeps any
   * unpublished changes. The autosave is flushed first and the editor is read again, so it comes
   * back as a plain draft, editable in place.
   */
  async function unpublish() {
    if (!meta.value || busy.value || !live.value) return false
    busy.value = true
    try {
      await autosave.save()
      if (autosave.state.value === 'error' || autosave.state.value === 'blocked') {
        toastError('Hay cambios sin guardar con errores. Corrígelos primero.')
        return false
      }
      await unpublishArticle(client, id)
      await reload()
      success('Artículo despublicado')
      return true
    } catch (e) {
      toastError({ message: articleErrorMessage(e), action: { label: 'Cerrar', run: () => {} } })
      return false
    } finally {
      busy.value = false
    }
  }

  return {
    load,
    form,
    meta,
    categories,
    authors,
    notFound,
    errors,
    live,
    editable,
    autosave,
    draft,
    reload,
    mediaOf,
    remember,
    slugTaken,
    slugSuggestion,
    checklist,
    checkAlt,
    canPublish,
    missing,
    busy,
    publishNow,
    schedule,
    backToDraft,
    unpublish,
  }
}
