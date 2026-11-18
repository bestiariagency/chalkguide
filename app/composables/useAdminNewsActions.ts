import type { Database } from '~/types/database.types'
import { approveNews, deleteNews, rejectNews, releaseNewsDedupe, reopenNews, type NewsBatchResult } from '~/services/admin/news'
import type { AdminNews } from '~/utils/admin-news'
import { newsError } from '~/utils/admin-news-form'

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`

/**
 * Status changes of Noticias with their toasts (D77): approve and reject happen at once and the toast offers «Deshacer»
 * (`reopen_news`); the batch dialog only exists when some item has warnings (the page decides). Each change goes through the
 * F8 RPCs and then `reload()` re-reads list and counters.
 */
export function useAdminNewsActions(reload: () => Promise<void>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const busy = ref(false)

  async function revert(undo: () => Promise<unknown>) {
    try {
      await undo()
      await reload()
    } catch (e) {
      toastError({ message: newsError(e).message })
    }
  }

  /** Runs one change over `ids`; failures are counted in the toast and the rest goes through. Returns whether none failed. */
  async function run(change: () => Promise<NewsBatchResult>, message: (done: number) => string, undo?: (done: string[]) => Promise<unknown>): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      const result = await change()
      const failed = result.failed.length
      if (result.ok.length) {
        const text = `${message(result.ok.length)}${failed ? ` · ${plural(failed, 'no se ha podido cambiar', 'no se han podido cambiar')}` : ''}`
        success({ message: text, action: undo ? { label: 'Deshacer', run: () => void revert(() => undo(result.ok)) } : undefined })
      } else {
        toastError({ message: result.failed[0] ? `No se ha podido cambiar · ${newsError(result.failed[0]).message}` : 'No se ha podido cambiar' })
      }
      await reload()
      return !failed
    } catch (e) {
      const failure = newsError(e)
      toastError({ message: failure.message })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  const approve = (idsToApprove: string[]) =>
    run(
      () => approveNews(client, idsToApprove),
      (n) => (n === 1 ? 'Publicada · sale en /noticias en unos minutos' : `${n} publicadas · salen en /noticias en unos minutos`),
      (done) => reopenNews(client, done),
    )

  const reject = (rows: readonly AdminNews[], reason: string | null) => {
    const agent = rows.some((r) => r.source === 'agent')
    return run(
      () => rejectNews(client, rows.map((r) => r.id), reason),
      (n) => `${n === 1 ? 'Rechazada' : `${n} rechazadas`}${agent ? ` · el agente no la${n === 1 ? '' : 's'} volverá a proponer` : ''}`,
      (done) => reopenNews(client, done),
    )
  }

  /** Published → draft. Undo publishes again. */
  const retire = (n: AdminNews) =>
    run(
      () => reopenNews(client, [n.id]),
      () => 'Retirada · vuelve a Por revisar y sale del sitio',
      (done) => approveNews(client, done),
    )

  /** Rejected → draft. Undo rejects again with the same reason. */
  const recover = (n: AdminNews) =>
    run(
      () => reopenNews(client, [n.id]),
      () => 'Recuperada · vuelve a Por revisar',
      (done) => rejectNews(client, done, n.rejectReason),
    )

  async function single(change: () => Promise<void>, message: string): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      await change()
      success(message)
      await reload()
      return true
    } catch (e) {
      const failure = newsError(e)
      toastError({ message: failure.message })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  const remove = (n: AdminNews) => single(() => deleteNews(client, n.id), 'Noticia eliminada')
  const release = (n: AdminNews) => single(() => releaseNewsDedupe(client, n.id), 'Liberada · el agente podrá volver a proponerla')

  return { busy, approve, reject, retire, recover, remove, release }
}
