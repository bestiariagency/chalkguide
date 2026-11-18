import type { AdminMedia } from '~/utils/admin-media'
import type { ChecklistItem } from '~/utils/article-form'
import type { AltIssue } from '~/utils/content-alt'
import { isFresh, itemChecklist } from '~/utils/item-checklist'
import type { ItemErrors } from '~/utils/item-patch'
import type { ShoeForm } from '~/utils/shoe-fields'

/** Review items only apply when he owns the model. */
const OWN_ONLY = new Set(['disclosure', 'disclosure_en', 'scores', 'alt-body'])

/** Shoes have no city, and the transparency note is about brand loans, not invited visits. */
const LABELS: Record<string, string> = { name: 'Nombre y URL', disclosure: 'Nota de transparencia (cedidos por la marca)' }

/** "Listo para publicar" of a shoe: brand and model block; the review items only count for models he owns; price is advice. */
export function shoeChecklist(form: ShoeForm, errors: ItemErrors, mediaOf: (id: string | null) => AdminMedia | null, serverAlt: AltIssue[] = [], serverAltEn: { required: AltIssue[]; advisory: AltIssue[] } = { required: [], advisory: [] }): ChecklistItem[] {
  const priced = !!form.price_min_eur.trim() || !!form.price_max_eur.trim()
  const items = itemChecklist(form, errors, mediaOf, serverAlt, serverAltEn, {
    blocking: [{ key: 'model', label: 'Marca y modelo', ok: !!form.brand.trim() && !!form.model.trim() && !errors.brand && !errors.model, blocking: true, hint: 'Faltan la marca o el modelo, o alguno no es válido.' }],
    advice: [{ key: 'price', label: 'Precio verificado hace menos de 6 meses', ok: priced && !!form.price_checked_at && isFresh(form.price_checked_at), blocking: false, hint: priced ? 'Pon la fecha en que verificaste el precio («Verificar hoy»).' : 'Sin precio, la ficha no sale en el filtro de precio del comparador.' }],
  })
  const labelled = items.map((item) => (LABELS[item.key] ? { ...item, label: LABELS[item.key]! } : item))
  return form.owned_by_author ? labelled : labelled.filter((item) => !OWN_ONLY.has(item.key))
}
