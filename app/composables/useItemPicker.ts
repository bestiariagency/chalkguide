import type { Database } from '~/types/database.types'
import type { ItemKind } from '~/utils/article-embeds'
import { searchItems, type ItemChoice } from '~/services/admin/article-items'

/** Results of the item-card picker: loads when opened and re-queries (debounced) while typing. */
export function useItemPicker(open: Ref<boolean>) {
  const client = useSupabaseClient<Database>()
  const query = ref('')
  const kind = ref<ItemKind | null>(null)
  const debounced = useDebouncedValue(query, 300)
  const items = ref<ItemChoice[]>([])
  const pending = ref(false)
  const failed = ref(false)
  let token = 0

  async function reload() {
    const mine = ++token
    pending.value = true
    failed.value = false
    try {
      const rows = await searchItems(client, debounced.value, kind.value)
      if (mine === token) items.value = rows
    } catch {
      if (mine === token) failed.value = true
    } finally {
      if (mine === token) pending.value = false
    }
  }
  watch([open, debounced, kind], () => open.value && void reload())

  return { query, kind, items, pending, failed, reload }
}
