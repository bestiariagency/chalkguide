import type { Database } from '~/types/database.types'
import { fetchNewsById } from '~/services/admin/news'
import type { AdminNews } from '~/utils/admin-news'

/** Reads one news item by id (deep link `?noticia=`); `null` while loading or when it is gone. */
export function useAdminNewsLookup(id: MaybeRefOrGetter<string | undefined>) {
  const client = useSupabaseClient<Database>()
  const news = ref<AdminNews | null>(null)
  watch(
    () => toValue(id),
    async (value) => {
      news.value = null
      if (!value) return
      try {
        news.value = await fetchNewsById(client, value)
      } catch {
        // The link just opens the list.
      }
    },
    { immediate: true },
  )
  return news
}
