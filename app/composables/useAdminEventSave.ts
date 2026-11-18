import type { Database } from '~/types/database.types'
import { approveEvent, createEvent, updateEvent } from '~/services/admin/events'
import type { AdminEvent } from '~/utils/admin-events'
import { eventError, formToWrite, type EventError, type EventForm } from '~/utils/admin-events-form'

export type EventSaveAction = 'draft' | 'publish' | 'save' | 'save-approve'

/**
 * Saves the event drawer. Events are small and are saved at once (no draft of changes, D23): a new one as a
 * draft or published, an existing one in place; "Guardar y aprobar" writes and then approves. The error
 * (field or banner) stays in `error` for the drawer.
 */
export function useAdminEventSave(reload: () => Promise<void>) {
  const client = useSupabaseClient<Database>()
  const { success } = useAdminToast()
  const busy = ref(false)
  const error = ref<EventError>()

  async function save(event: AdminEvent | undefined, form: EventForm, action: EventSaveAction): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    error.value = undefined
    try {
      const write = formToWrite(form)
      if (!event) {
        await createEvent(client, write, action === 'publish' ? 'approved' : 'draft')
        success(action === 'publish' ? 'Publicado · sale en la agenda en unos minutos' : 'Guardado como borrador · está en Por aprobar')
      } else {
        await updateEvent(client, event.id, write)
        if (action === 'save-approve') await approveEvent(client, event.id)
        success(
          action === 'save-approve'
            ? 'Aprobado · sale en la agenda en unos minutos'
            : event.status === 'draft'
              ? 'Guardado · sigue en Por aprobar'
              : event.status === 'rejected'
                ? 'Guardado'
                : 'Guardado · se actualiza en la agenda en unos minutos',
        )
      }
      await reload()
      return true
    } catch (e) {
      error.value = eventError(e)
      if (error.value.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  return { busy, error, save }
}
