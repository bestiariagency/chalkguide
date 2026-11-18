import { isValidUnsubscribeToken, unsubscribeNewsletter } from '~/services/newsletter'

export type UnsubscribeStatus = 'loading' | 'success' | 'invalid' | 'error'

/**
 * Reads `?token=` and calls the unsubscribe RPC on the client (after mount, so link
 * scanners that do not run JS cannot unsubscribe anyone). The RPC is neutral, so "invalid"
 * only means the token is missing or not a UUID.
 */
export function useNewsletterUnsubscribe() {
  const db = useGuideClient()
  const route = useRoute()
  const status = ref<UnsubscribeStatus>('loading')

  async function run() {
    const token = Array.isArray(route.query.token) ? route.query.token[0] : route.query.token
    if (!isValidUnsubscribeToken(token)) {
      status.value = 'invalid'
      return
    }
    status.value = 'loading'
    try {
      await unsubscribeNewsletter(db, token)
      status.value = 'success'
    } catch {
      status.value = 'error'
    }
  }

  onMounted(run)
  return { status, retry: run }
}
