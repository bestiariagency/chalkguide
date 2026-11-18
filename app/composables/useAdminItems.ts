import type { Database } from '~/types/database.types'
import { createItem, deleteItems, fetchAdminItems } from '~/services/admin/items'
import { hideItem } from '~/services/admin/item-editor'
import { discardItemDraft } from '~/services/admin/item-drafts'
import { countItemViews, itemErrorMessage, matchesItemView, type AdminItemRow, type ItemView } from '~/utils/admin-items'
import type { ItemInfo } from '~/utils/item-spec'

/** Items list of the panel (F6.7 gyms, F6.8 resolers): data, views and the safe actions (create, hide, discard changes, delete unpublished). */
export function useAdminItems(info: ItemInfo) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const list = useAsyncData(`admin-items-${info.category}`, () => fetchAdminItems(client, info.category), { server: false })
  const rows = computed(() => list.data.value ?? [])
  const view = ref<ItemView>('all')
  const featuredOnly = ref(false)
  const counts = computed(() => countItemViews(rows.value))
  const visible = computed(() => rows.value.filter((row) => matchesItemView(row, view.value) && (!featuredOnly.value || row.is_featured)))
  const filtering = computed(() => view.value !== 'all' || featuredOnly.value)
  function clearFilters() {
    view.value = 'all'
    featuredOnly.value = false
  }

  const busy = ref(false)
  async function run<T>(action: () => Promise<T>, onDone: (result: T) => void | Promise<void>): Promise<boolean> {
    busy.value = true
    try {
      await onDone(await action())
      return true
    } catch (e) {
      toastError({ message: itemErrorMessage(e, undefined, info.noun), action: { label: 'Cerrar', run: () => {} } })
      if ((e as { code?: string }).code === 'LIVE') await list.refresh()
      return false
    } finally {
      busy.value = false
    }
  }

  const create = (options: { replace?: boolean } = {}) => run(() => createItem(client, info.category), (id) => void navigateTo(adminPath(`${info.route}/${id}`), { replace: options.replace }))

  const remove = (targets: readonly AdminItemRow[]) =>
    run(() => deleteItems(client, info.category, targets.map((t) => t.id)), async (count) => {
      await list.refresh()
      success(count === 1 ? info.removedToast : info.removedManyToast(count))
    })

  const discardChanges = (row: AdminItemRow) =>
    run(() => discardItemDraft(client, row.id), async () => {
      await list.refresh()
      success('Cambios descartados')
    })

  const hide = (row: AdminItemRow) =>
    run(() => hideItem(client, row.id), async () => {
      await list.refresh()
      success('Ficha oculta')
    })

  return { list, rows, view, featuredOnly, counts, visible, filtering, clearFilters, busy, create, remove, discardChanges, hide }
}
