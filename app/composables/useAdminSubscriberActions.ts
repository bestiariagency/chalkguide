import type { Database } from '~/types/database.types'
import { eraseSubscriber, unsubscribeSubscribers, withdrawRelated } from '~/services/admin/subscribers'
import { subscriberError } from '~/utils/admin-subscriber-detail'

/**
 * The two writes of Suscriptores (F6.14): unsubscribe (also in bulk, all or nothing) and erase (RGPD, one by one).
 * Neither can be undone, so the toasts carry no "Deshacer". A failure is a persistent toast, with "Reintentar"
 * when retrying can help (not when the list was stale: then it is re-read instead).
 */
export function useAdminSubscriberActions(reload: () => Promise<void>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const busy = ref(false)
  /** Typed-email mismatch of the erase dialog (shown in its field, not as a toast). */
  const mismatch = ref(false)

  async function unsubscribe(ids: string[], reason: string, label: string): Promise<boolean> {
    if (busy.value || !ids.length) return false
    busy.value = true
    try {
      await unsubscribeSubscribers(client, ids, reason)
      success(ids.length === 1 ? `${label} dado de baja` : `${ids.length} suscriptores dados de baja`)
      await reload()
      return true
    } catch (e) {
      const failure = subscriberError(e, 'unsubscribe')
      toastError({ message: failure.message, action: failure.reload ? undefined : { label: 'Reintentar', run: () => void unsubscribe(ids, reason, label) } })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  /** D66: only the related-products consent; the newsletter is untouched. No "Deshacer": only the person can give it again. */
  async function withdraw(id: string, reason: string, label: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      await withdrawRelated(client, id, reason)
      success(`Afines retirados a ${label} · la newsletter no cambia`)
      await reload()
      return true
    } catch (e) {
      const failure = subscriberError(e, 'withdraw')
      toastError({ message: failure.message, action: failure.reload ? undefined : { label: 'Reintentar', run: () => void withdraw(id, reason, label) } })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  async function erase(id: string, typedEmail: string, reason: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    mismatch.value = false
    try {
      await eraseSubscriber(client, id, typedEmail, reason)
      success('Datos suprimidos · el registro queda anónimo')
      await reload()
      return true
    } catch (e) {
      const failure = subscriberError(e, 'erase')
      if (failure.mismatch) mismatch.value = true
      else toastError({ message: failure.message, action: failure.reload ? undefined : { label: 'Reintentar', run: () => void erase(id, typedEmail, reason) } })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  /** Copies plain text (email or proof) and says so; the browser may refuse. */
  const copyLink = useCopyLink()
  const copy = (value: string, done: string) => copyLink(value, done, '')

  return { busy, mismatch, unsubscribe, withdraw, erase, copy }
}
