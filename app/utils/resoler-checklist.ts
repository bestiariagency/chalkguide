import type { AdminMedia } from '~/utils/admin-media'
import type { ChecklistItem } from '~/utils/article-form'
import type { AltIssue } from '~/utils/content-alt'
import { itemChecklist } from '~/utils/item-checklist'
import type { ItemErrors } from '~/utils/item-patch'
import type { ResolerForm } from '~/utils/resoler-fields'

/** "Listo para publicar" of a resoler: the shared checklist plus a warning when no service is ticked. */
export function resolerChecklist(form: ResolerForm, errors: ItemErrors, mediaOf: (id: string | null) => AdminMedia | null, serverAlt: AltIssue[] = [], serverAltEn: { required: AltIssue[]; advisory: AltIssue[] } = { required: [], advisory: [] }): ChecklistItem[] {
  return itemChecklist(form, errors, mediaOf, serverAlt, serverAltEn, {
    advice: [{ key: 'services', label: 'Al menos un servicio marcado', ok: form.services.length > 0, blocking: false, hint: 'Sin servicios, el taller no sale en los filtros de /resolar-pies-de-gato.' }],
  })
}
