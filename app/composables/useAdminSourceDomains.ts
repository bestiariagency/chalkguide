import type { Database } from '~/types/database.types'
import { fetchSources } from '~/services/admin/ingest'

/** `news_sources.id -> domain`, shared by key and cached after the first read (the news detail compares it with the real host). */
export function useAdminSourceDomains() {
  const client = useSupabaseClient<Database>()
  const { data } = useAsyncData(
    'admin-source-domains',
    async () => Object.fromEntries((await fetchSources(client).catch(() => [])).map((s) => [s.id, s.domain])) as Record<string, string>,
    { server: false, getCachedData: (key, nuxt) => nuxt.payload.data[key] ?? nuxt.static.data[key] },
  )
  return computed(() => data.value ?? {})
}
