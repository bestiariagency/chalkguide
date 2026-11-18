import type { Database } from '~/types/database.types'
import { searchMedia } from '~/services/admin/article-editor'
import type { AdminMedia } from '~/utils/admin-media'

/** Results of the media picker: loads when opened and re-queries (debounced) while typing. */
export function useMediaPicker(open: Ref<boolean>) {
  const client = useSupabaseClient<Database>()
  const query = ref('')
  const debounced = useDebouncedValue(query, 300)
  const items = ref<AdminMedia[]>([])
  const pending = ref(false)
  const failed = ref(false)
  let token = 0

  async function reload() {
    const mine = ++token
    pending.value = true
    failed.value = false
    try {
      const rows = await searchMedia(client, debounced.value)
      if (mine === token) items.value = rows
    } catch {
      if (mine === token) failed.value = true
    } finally {
      if (mine === token) pending.value = false
    }
  }
  watch([open, debounced], () => open.value && void reload())

  return { query, items, pending, failed, reload }
}
