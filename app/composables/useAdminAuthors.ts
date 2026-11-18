import type { Database } from '~/types/database.types'
import { deleteAuthor, fetchAdminAuthors, reorderAuthors, saveAuthor } from '~/services/admin/authors'
import { authorErrorMessage, isSlugTaken, type AdminAuthor, type AuthorCounts, type AuthorForm } from '~/utils/admin-authors'
import { pluralArticles } from '~/utils/admin-categories'

/**
 * Authors screen (D62): data, local order (saved on each committed change, serialised; on failure the
 * list is reloaded), save, and delete (their articles pass to the site author at once, with a notice).
 */
export function useAdminAuthors() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-authors', () => fetchAdminAuthors(client), { server: false })

  const authors = ref<AdminAuthor[]>([])
  /** Last order saved in the database: the reference for «Deshacer». */
  const savedOrder = ref<string[]>([])
  watch(() => list.data.value?.authors, (rows) => {
    authors.value = rows ? [...rows] : []
    savedOrder.value = authors.value.map((a) => a.id)
  }, { immediate: true })
  const site = computed(() => list.data.value?.site ?? null)
  const siteCounts = computed(() => list.data.value?.siteCounts ?? { total: 0, live: 0 })
  const countsFor = (id: string): AuthorCounts => list.data.value?.counts[id] ?? { total: 0, live: 0 }

  const busy = ref(false)
  /** Slug already used (database answer): the form marks the field. */
  const slugTaken = ref(false)
  let queue: Promise<unknown> = Promise.resolve()

  /** One request at a time; any failure reloads so the screen shows what the database has. */
  function reorder() {
    const ids = authors.value.map((a) => a.id)
    queue = queue.then(async () => {
      const previous = [...savedOrder.value]
      try {
        await reorderAuthors(client, ids)
        savedOrder.value = ids
        success({
          message: 'Orden guardado',
          action: { label: 'Deshacer', run: () => void undo(previous) },
        })
      } catch (e) {
        toastError(isStale(e) ? 'La lista había cambiado y se ha recargado. Vuelve a ordenar.' : authorErrorMessage(e))
        await list.refresh()
      }
    })
    return queue
  }
  const isStale = (e: unknown) => (e as { message?: string })?.message?.includes('list must include every author') === true

  /** Restores the previous order (still the same set of authors) and saves it. */
  async function undo(previous: string[]) {
    const byId = new Map(authors.value.map((a) => [a.id, a]))
    if (previous.length !== byId.size || previous.some((id) => !byId.has(id))) return void list.refresh()
    authors.value = previous.map((id) => byId.get(id)!)
    queue = queue.then(async () => {
      try {
        await reorderAuthors(client, previous)
        savedOrder.value = previous
        success('Orden restaurado')
      } catch (e) {
        toastError(authorErrorMessage(e))
        await list.refresh()
      }
    })
    await queue
  }

  async function save(id: string | undefined, form: AuthorForm): Promise<boolean> {
    busy.value = true
    slugTaken.value = false
    try {
      await saveAuthor(client, id, form, Math.max(0, ...authors.value.map((a) => a.sort_order)) + 1)
      await list.refresh()
      success(id ? 'Autor guardado' : 'Autor creado')
      return true
    } catch (e) {
      if (isSlugTaken(e)) slugTaken.value = true
      else toastError(authorErrorMessage(e))
      return false
    } finally {
      busy.value = false
    }
  }

  async function remove(author: AdminAuthor, moved: number): Promise<boolean> {
    busy.value = true
    try {
      await deleteAuthor(client, author.id)
      await list.refresh()
      // «Autor eliminado: Ana» keeps the gender neutral whatever the author's name.
      const siteName = site.value?.name?.trim()
      const dest = siteName ? `a ${siteName}` : 'al autor del sitio'
      success({ message: moved ? `Autor eliminado: ${author.name} · ${pluralArticles(moved)} ${moved === 1 ? 'pasa' : 'pasan'} ${dest}` : `Autor eliminado: ${author.name}`, duration: 8000 })
      return true
    } catch (e) {
      toastError(authorErrorMessage(e))
      if ((e as { code?: string })?.code === 'P0002') void list.refresh()
      return false
    } finally {
      busy.value = false
    }
  }

  return { list, authors, site, siteCounts, countsFor, busy, slugTaken, reorder, save, remove }
}
