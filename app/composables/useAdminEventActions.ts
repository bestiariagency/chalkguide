import type { Database } from '~/types/database.types'
import { approveEvent, deleteEvent, rejectEvent, reopenEvent, setEventsStatus, setEventStatus } from '~/services/admin/events'
import type { AdminEvent } from '~/utils/admin-events'
import { eventError } from '~/utils/admin-events-form'

/**
 * Status changes of the Agenda with their toasts. Approve, discard, withdraw, recover and (un)cancel carry
 * "Deshacer"; each one goes through the RPCs of F6.12 and then `reload()` re-reads list and counters.
 */
export function useAdminEventActions(reload: () => Promise<void>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const busy = ref(false)

  /** Runs one change; `undo` (if any) is offered in the toast. Returns whether it worked. */
  async function run(change: () => Promise<void>, message: string, undo?: () => Promise<void>): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      await change()
      success({ message, action: undo ? { label: 'Deshacer', run: () => void revert(undo) } : undefined })
      await reload()
      return true
    } catch (e) {
      const failure = eventError(e)
      toastError({ message: failure.message })
      if (failure.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }
  async function revert(undo: () => Promise<void>) {
    try {
      await undo()
      await reload()
    } catch (e) {
      toastError({ message: eventError(e).message })
    }
  }

  const approve = (e: AdminEvent) => run(() => approveEvent(client, e.id), 'Aprobado · sale en la agenda en unos minutos', () => reopenEvent(client, e.id))

  const reject = (e: AdminEvent, reason: string | null) =>
    run(
      () => rejectEvent(client, e.id, reason),
      e.source === 'agent' ? 'Descartado · el agente no lo volverá a proponer' : 'Descartado',
      () => reopenEvent(client, e.id),
    )

  /** Approved or cancelled → draft. Undo restores what it was. */
  const retire = (e: AdminEvent) =>
    run(
      () => reopenEvent(client, e.id),
      'Retirado · vuelve a Por aprobar',
      async () => {
        await approveEvent(client, e.id)
        if (e.status === 'cancelled') await setEventStatus(client, e.id, 'cancelled')
      },
    )

  const recover = (e: AdminEvent) =>
    run(() => reopenEvent(client, e.id), 'Recuperado · vuelve a Por aprobar', () => rejectEvent(client, e.id, e.rejectReason === 'expired' ? null : e.rejectReason))

  const cancel = (e: AdminEvent) =>
    run(() => setEventStatus(client, e.id, 'cancelled'), 'Marcado como cancelado · sigue en la agenda, con el aviso', () => setEventStatus(client, e.id, 'approved'))

  const uncancel = (e: AdminEvent) =>
    run(() => setEventStatus(client, e.id, 'approved'), 'De vuelta en la agenda', () => setEventStatus(client, e.id, 'cancelled'))

  const remove = (e: AdminEvent) => run(() => deleteEvent(client, e.id), 'Evento eliminado')

  /** Batch approve / discard: failures are listed, the rest goes through. */
  async function batch(ids: string[], kind: 'approve' | 'reject', reason: string | null = null): Promise<boolean> {
    if (busy.value || !ids.length) return false
    busy.value = true
    try {
      const result = await setEventsStatus(client, ids, kind === 'approve' ? 'approved' : 'rejected', kind === 'reject' ? reason : undefined)
      const done = result.ok.length
      const verb = kind === 'approve' ? (done === 1 ? 'aprobado' : 'aprobados') : done === 1 ? 'descartado' : 'descartados'
      const failed = result.failed.length
      if (done) {
        success({
          message: `${done} ${done === 1 ? 'evento' : 'eventos'} ${verb}${failed ? ` · ${failed} no se ${failed === 1 ? 'ha podido cambiar' : 'han podido cambiar'}` : ''}`,
          action: { label: 'Deshacer', run: () => void revert(async () => void (await setEventsStatus(client, result.ok, 'draft'))) },
        })
      } else {
        toastError({ message: `No se ha podido cambiar ninguno${result.failed[0] ? ` · ${eventError(result.failed[0]).message}` : ''}` })
      }
      await reload()
      return !result.failed.length
    } catch (e) {
      toastError({ message: eventError(e).message })
      return false
    } finally {
      busy.value = false
    }
  }

  return { busy, approve, reject, retire, recover, cancel, uncancel, remove, batch }
}
