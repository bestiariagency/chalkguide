import type { Database } from '~/types/database.types'
import { createNewsCategory, deleteNewsCategory, fetchNewsCategoryCounts, reorderNewsCategories, updateNewsCategory } from '~/services/admin/news'
import type { NewsCategory } from '~/utils/admin-news'
import { newsError } from '~/utils/admin-news-form'
import { slugify } from '~/utils/admin-form'

/** Categories drawer of Noticias (README §19.2): sortable list with counts, create, rename and delete with reassignment. */
export function useAdminNewsCategories(source: () => readonly NewsCategory[], reload: () => Promise<unknown>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const items = ref<NewsCategory[]>([])
  const counts = ref<Record<string, number>>({})
  const busy = ref(false)
  const error = ref<string>()

  async function load() {
    try {
      counts.value = await fetchNewsCategoryCounts(client)
    } catch {
      counts.value = {}
    }
    items.value = [...source()]
  }

  async function attempt(run: () => Promise<void>, message: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    error.value = undefined
    try {
      await run()
      await reload()
      await load()
      success(message)
      return true
    } catch (e) {
      error.value = newsError(e).message
      return false
    } finally {
      busy.value = false
    }
  }

  const create = (es: string, en: string) =>
    attempt(() => createNewsCategory(client, { key: slugify(es).slice(0, 40), label_es: es.trim(), label_en: en.trim() || es.trim() }, items.value.length + 1), 'Categoría creada')
  const rename = (c: NewsCategory, es: string, en: string) => attempt(() => updateNewsCategory(client, c.id, { label_es: es.trim(), label_en: en.trim() }), 'Categoría guardada')
  const remove = (c: NewsCategory, reassignTo?: string) => attempt(() => deleteNewsCategory(client, c.id, reassignTo), 'Categoría eliminada')

  /** Saved once per committed move; on failure the list goes back to what the database has. */
  async function reorder(next: NewsCategory[]) {
    try {
      await reorderNewsCategories(client, next.map((c) => c.id))
      await reload()
    } catch (e) {
      toastError({ message: newsError(e).message })
      await load()
    }
  }

  return { items, counts, busy, error, load, create, rename, remove, reorder }
}
