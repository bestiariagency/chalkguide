import type { Database } from '~/types/database.types'
import { discardPageDraft } from '~/services/admin/page-drafts'
import { fetchAdminPages, unpublishPage } from '~/services/admin/pages'
import { PAGE_DEFS, PAGE_ORDER, pageErrorMessage, type AdminPageRow, type PageDef } from '~/utils/admin-pages'

/** Pages list of the panel (F6.13): the five fixed rows grouped, plus the two safe actions (discard changes, unpublish). */
export function useAdminPages() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const list = useAsyncData('admin-pages', () => fetchAdminPages(client), { server: false })
  const rows = computed(() => {
    const byKey = new Map((list.data.value ?? []).map((row) => [row.key, row]))
    return PAGE_ORDER.flatMap((key) => {
      const row = byKey.get(key)
      return row ? [{ def: PAGE_DEFS[key], row }] : []
    })
  })
  const unpublishedLegal = computed(() => rows.value.filter(({ def, row }) => def.legal && !row.published).length)

  const busy = ref(false)
  async function run(action: () => Promise<unknown>, done: string) {
    busy.value = true
    try {
      await action()
      await list.refresh()
      success(done)
      return true
    } catch (e) {
      toastError({ message: pageErrorMessage(e), action: { label: 'Cerrar', run: () => {} } })
      return false
    } finally {
      busy.value = false
    }
  }
  const discard = (def: PageDef, row: AdminPageRow) => run(() => discardPageDraft(client, row.id), `Cambios de «${def.label}» descartados`)
  const unpublish = (def: PageDef, row: AdminPageRow) => run(() => unpublishPage(client, row.id), `«${def.label}» despublicada · vuelve a borrador`)

  return { list, rows, unpublishedLegal, busy, discard, unpublish }
}
