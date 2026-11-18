import type { AdminMedia } from '~/utils/admin-media'
import type { ChecklistItem } from '~/utils/article-form'
import type { GymForm } from '~/utils/gym-fields'
import type { AltIssue } from '~/utils/content-alt'
import { itemChecklist } from '~/utils/item-checklist'
import type { ItemErrors } from '~/utils/item-patch'

/** "Listo para publicar" of a gym: the shared checklist plus a valid weekly schedule. */
export function gymChecklist(form: GymForm, errors: ItemErrors, mediaOf: (id: string | null) => AdminMedia | null, serverAlt: AltIssue[] = [], serverAltEn: { required: AltIssue[]; advisory: AltIssue[] } = { required: [], advisory: [] }): ChecklistItem[] {
  const hoursError = Object.keys(errors).find((key) => key.startsWith('opening_hours'))
  return itemChecklist(form, errors, mediaOf, serverAlt, serverAltEn, {
    ownErrorPrefix: 'opening_hours',
    blocking: [{ key: 'hours', label: 'Horario válido', ok: !hoursError, blocking: true, hint: hoursError ? errors[hoursError] : undefined }],
  })
}
