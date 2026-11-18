import type { Database } from '~/types/database.types'
import {
  createDraftArticle,
  deleteArticles,
  discardArticleChanges,
  duplicateArticle,
  fetchAdminArticles,
  fetchArticleAuthors,
  fetchArticleCategories,
  moveArticles,
  unpublishArticle,
} from '~/services/admin/articles'
import {
  articleErrorMessage,
  countByView,
  isArticleLive,
  SITE_AUTHOR_FILTER,
  matchesView,
  type AdminArticleRow,
  type ArticleView,
} from '~/utils/admin-articles'

/** Articles list of the panel (F6.4): data, views/filters and the safe actions (create, duplicate, move, delete, discard). */
export function useAdminArticles() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const list = useAsyncData('admin-articles', async () => {
    const [rows, categories, authors] = await Promise.all([fetchAdminArticles(client), fetchArticleCategories(client), fetchArticleAuthors(client)])
    return { rows, categories, authors }
  }, { server: false })

  const rows = computed(() => list.data.value?.rows ?? [])
  const categories = computed(() => list.data.value?.categories ?? [])
  const authors = computed(() => list.data.value?.authors ?? [])

  const view = ref<ArticleView>('all')
  const categoryId = ref('')
  /** '' = all, 'site' = signed by the site author (no `author_id`), otherwise an author id (`?autor=`). */
  const authorId = ref('')
  const featuredOnly = ref(false)
  const counts = computed(() => countByView(rows.value))
  const visible = computed(() =>
    rows.value.filter(
      (row) =>
        matchesView(row, view.value) &&
        (!categoryId.value || row.category_id === categoryId.value) &&
        (!authorId.value || (authorId.value === SITE_AUTHOR_FILTER ? row.author_id === null : row.author_id === authorId.value)) &&
        (!featuredOnly.value || row.is_featured),
    ),
  )
  const filtering = computed(() => view.value !== 'all' || !!categoryId.value || !!authorId.value || featuredOnly.value)
  function clearFilters() {
    view.value = 'all'
    categoryId.value = ''
    authorId.value = ''
    featuredOnly.value = false
  }

  const busy = ref(false)
  async function run<T>(action: () => Promise<T>, onDone: (result: T) => void): Promise<boolean> {
    busy.value = true
    try {
      onDone(await action())
      return true
    } catch (e) {
      toastError({ message: articleErrorMessage(e), action: { label: 'Cerrar', run: () => {} } })
      // A mixed selection still changed the non-live rows: reload so the table matches.
      if ((e as { code?: string }).code === 'LIVE') await list.refresh()
      return false
    } finally {
      busy.value = false
    }
  }

  /** Creates a minimal draft and opens it in the editor. */
  const create = (options: { replace?: boolean; title?: string } = {}) =>
    run(() => createDraftArticle(client, options.title), (id) => void navigateTo(adminPath(`articulos/${id}`), { replace: options.replace }))

  const duplicate = (row: AdminArticleRow) =>
    run(() => duplicateArticle(client, row.id), async (copy) => {
      await list.refresh()
      success({ message: `Duplicado como borrador: «${copy.title}»`, action: { label: 'Abrir', run: () => void navigateTo(adminPath(`articulos/${copy.id}`)) } })
    })

  const remove = (targets: readonly AdminArticleRow[]) =>
    run(() => deleteArticles(client, targets.map((t) => t.id)), async (count) => {
      await list.refresh()
      success(count === 1 ? 'Artículo eliminado' : `${count} artículos eliminados`)
    })

  const move = (targets: readonly AdminArticleRow[], toCategoryId: string) =>
    run(() => moveArticles(client, targets.map((t) => t.id), toCategoryId), async (count) => {
      await list.refresh()
      success(count === 1 ? 'Artículo movido' : `${count} artículos movidos`)
    })

  const discardChanges = (row: AdminArticleRow) =>
    run(() => discardArticleChanges(client, row.id), async () => {
      await list.refresh()
      success('Cambios descartados')
    })

  const unpublish = (row: AdminArticleRow) =>
    run(() => unpublishArticle(client, row.id), async () => {
      await list.refresh()
      success('Artículo despublicado')
    })

  return {
    list,
    rows,
    categories,
    authors,
    view,
    categoryId,
    authorId,
    featuredOnly,
    counts,
    visible,
    filtering,
    clearFilters,
    busy,
    create,
    duplicate,
    remove,
    move,
    discardChanges,
    unpublish,
    isLive: (row: AdminArticleRow) => isArticleLive(row),
  }
}
