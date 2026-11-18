import type { Database } from '~/types/database.types'
import { fetchSubscriber } from '~/services/admin/subscribers'
import type { SubscriberDetail } from '~/utils/admin-subscribers'

/** Loads the ficha (`admin_get_subscriber`) of the selected subscriber. Read only; a stale answer is dropped. */
export function useAdminSubscriberDetail(id: Ref<string | undefined>) {
  const client = useSupabaseClient<Database>()
  const detail = ref<SubscriberDetail>()
  const status = ref<'idle' | 'pending' | 'error' | 'ready'>('idle')
  const errorCode = ref<string>()
  let token = 0

  async function load() {
    const current = id.value
    const mine = ++token
    detail.value = undefined
    errorCode.value = undefined
    if (!current) {
      status.value = 'idle'
      return
    }
    status.value = 'pending'
    try {
      const found = await fetchSubscriber(client, current)
      if (mine !== token) return
      detail.value = found
      status.value = 'ready'
    } catch (e) {
      if (mine !== token) return
      errorCode.value = (e as { code?: string })?.code
      status.value = 'error'
    }
  }
  watch(id, load, { immediate: true })

  return { detail, status, errorCode, retry: load }
}
