import type { Database } from '~/types/database.types'
import {
  deleteCategory,
  fetchAdminCategories,
  reorderCategories,
  reorderCategoryArticles,
  saveCategory,
} from '~/services/admin/categories'
import {
  articleCounts,
  categoryErrorMessage,
  isTargetRequiredError,
  type AdminCategory,
  type AdminCategoryArticle,
  type CategoryForm,
} from '~/utils/admin-categories'

/**
 * Categories screen (F6.5): data, local order of categories and of the articles of the selected one,
 * and the actions (save, reorder, delete with reassignment). Orders are saved on each committed change
 * (serialised); on failure the lists are reloaded so the screen always shows what the database has.
 */
export function useAdminCategories() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-categories', () => fetchAdminCategories(client), { server: false })

  const categories = ref<AdminCategory[]>([])
  const articles = computed(() => list.data.value?.articles ?? [])
  const selectedId = ref<string>()
  const selectedArticles = ref<AdminCategoryArticle[]>([])
  const selected = computed(() => categories.value.find((c) => c.id === selectedId.value))

  const countsFor = (id: string) => articleCounts(articles.value.filter((a) => a.category_id === id))
  const selectedCounts = computed(() => countsFor(selectedId.value ?? ''))

  watch(() => list.data.value?.categories, (rows) => {
    categories.value = rows ? [...rows] : []
    if (!categories.value.some((c) => c.id === selectedId.value)) selectedId.value = categories.value[0]?.id
  }, { immediate: true })
  watch([articles, selectedId], () => {
    selectedArticles.value = articles.value.filter((a) => a.category_id === selectedId.value)
  }, { immediate: true })

  const busy = ref(false)
  let queue: Promise<unknown> = Promise.resolve()

  function fail(e: unknown) {
    toastError({ message: categoryErrorMessage(e) })
  }

  /** Saves in order, one request at a time; reloads on failure to drop the order the DB refused. */
  function saveOrder(action: () => Promise<void>) {
    queue = queue.then(async () => {
      try {
        await action()
        success('Orden guardado')
      } catch (e) {
        fail(e)
        await list.refresh()
      }
    })
    return queue
  }

  const reorder = () => saveOrder(() => reorderCategories(client, categories.value.map((c) => c.id)))
  const reorderArticles = () => {
    const id = selectedId.value
    if (!id) return Promise.resolve()
    return saveOrder(() => reorderCategoryArticles(client, id, selectedArticles.value.map((a) => a.id)))
  }

  async function run(action: () => Promise<void>, message: string, onError?: (e: unknown) => void): Promise<boolean> {
    busy.value = true
    try {
      await action()
      await list.refresh()
      success(message)
      return true
    } catch (e) {
      fail(e)
      onError?.(e)
      return false
    } finally {
      busy.value = false
    }
  }

  const save = (id: string | undefined, form: CategoryForm) =>
    run(
      () => saveCategory(client, id, form, Math.max(0, ...categories.value.map((c) => c.sort_order)) + 1),
      id ? 'Categoría guardada' : 'Categoría creada',
    )

  /** Category whose delete needs a destination although it looks empty (pending drafts use it). */
  const needsTargetId = ref<string>()

  async function remove(category: AdminCategory, reassignTo: string | undefined): Promise<boolean> {
    const moved = countsFor(category.id).total
    return run(
      () => deleteCategory(client, category.id, reassignTo),
      moved ? `Categoría eliminada · ${moved} ${moved === 1 ? 'artículo movido' : 'artículos movidos'}` : 'Categoría eliminada',
      (e) => {
        if (isTargetRequiredError(e)) needsTargetId.value = category.id
        else if (['P0002', '22023'].includes((e as { code?: string })?.code ?? '')) void list.refresh()
      },
    )
  }

  return { list, categories, selectedId, selected, selectedArticles, selectedCounts, busy, needsTargetId, countsFor, reorder, reorderArticles, save, remove }
}
