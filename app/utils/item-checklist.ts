import { BLOCKER_INFO } from '~/utils/item-blockers'
import { isStale, monthsSince } from '~/utils/freshness'
import type { AdminMedia } from '~/utils/admin-media'
import { imagesWithoutAlt, type ChecklistItem } from '~/utils/article-form'
import { isEmptyDoc } from '~/utils/article-editor'
import type { ItemErrors } from '~/utils/item-patch'
import type { ItemForm } from '~/utils/item-fields'
import { altChecklistItem, altEnChecklistItem, mergeAlt, type AltIssue } from '~/utils/content-alt'

/** "Verificado hace menos de 6 meses" (after that the public page warns "puede haber cambiado"). */
export const isFresh = (date: string) => !isStale(date)

/** Real state of "Reseña escrita y al menos 3 notas". */
const scoresHint = (hasReview: boolean, scored: number) => `${hasReview ? 'Reseña escrita' : 'Sin reseña'} · ${scored} de 3 notas`

/** Real state of "Verificada hace menos de 6 meses". */
function verifiedHint(date: string): string {
  if (!date) return 'Sin fecha de verificación'
  const months = monthsSince(date)
  return months < 1 ? 'Verificada hace menos de un mes' : `Verificada hace ${months} ${months === 1 ? 'mes' : 'meses'}`
}

/** Media without Spanish alt text among cover, share image, gallery (D27: they block publishing). */
export function mediaWithoutAlt(form: ItemForm, mediaOf: (id: string | null) => AdminMedia | null): AdminMedia[] {
  const ids = [form.cover_media_id, form.og_media_id, ...form.gallery].filter((id): id is string => !!id)
  return [...new Set(ids)].map(mediaOf).filter((m): m is AdminMedia => !!m && !m.alt_es?.trim())
}

/**
 * "Listo para publicar". Blocking items stop publishing; the rest only warn. `serverAlt` is the D27
 * check of the saved content (all images, body included); the local one covers unsaved edits.
 */
export function itemChecklist(form: ItemForm, errors: ItemErrors, mediaOf: (id: string | null) => AdminMedia | null, serverAlt: AltIssue[], serverAltEn: { required: AltIssue[]; advisory: AltIssue[] }, extra: { blocking?: ChecklistItem[]; advice?: ChecklistItem[]; ownErrorPrefix?: string } = {}): ChecklistItem[] {
  const noAlt = mergeAlt(mediaWithoutAlt(form, mediaOf).map((m) => ({ id: m.id, name: m.original_filename })), serverAlt)
  const cover = mediaOf(form.cover_media_id)
  const own = extra.ownErrorPrefix
  const otherErrors = Object.keys(errors).filter((key) => !own || !key.startsWith(own))
  const invited = form.visit_type === 'invited'
  const reviewImages = imagesWithoutAlt(form.body_json_es.html)
  const scored = Object.keys(form.scores).length
  return [
    { key: 'name', label: 'Nombre, URL y ciudad', ok: !!form.name.trim() && !!form.slug && !errors.name && !errors.slug && !errors.city, blocking: true, hint: BLOCKER_INFO.name!.hint },
    ...(extra.blocking ?? []),
    { key: 'fields', label: 'Campos sin errores', ok: !otherErrors.length, blocking: true, hint: 'Corrige los campos marcados en rojo.' },
    { key: 'disclosure', label: 'Nota de transparencia (visita invitada)', ok: !invited || !!form.disclosure_note_es.trim(), blocking: true, hint: BLOCKER_INFO.disclosure!.hint },
    { key: 'cover', label: 'Portada', ok: !!cover, blocking: true, hint: BLOCKER_INFO.cover!.hint },
    altChecklistItem(noAlt),
    altEnChecklistItem(serverAltEn.required, serverAltEn.advisory),
    { key: 'summary', label: 'Resumen en español', ok: !!form.summary_es.trim(), blocking: false },
    { key: 'disclosure_en', label: 'Nota de transparencia en inglés', ok: !invited || !form.summary_en.trim() || !!form.disclosure_note_en.trim(), blocking: false, hint: 'La visita es invitada y hay resumen en inglés: añade también la nota en EN.' },
    { key: 'scores', label: 'Reseña escrita y al menos 3 notas', ok: scored >= 3 && !isEmptyDoc(form.body_json_es.json), blocking: false, hint: scoresHint(!isEmptyDoc(form.body_json_es.json), scored) },
    { key: 'verified', label: 'Verificada hace menos de 6 meses', ok: !!form.verified_at && isFresh(form.verified_at), blocking: false, hint: verifiedHint(form.verified_at) },
    ...(extra.advice ?? []),
    { key: 'alt-body', label: 'Texto alternativo dentro de la reseña', ok: reviewImages === 0, blocking: false, hint: reviewImages ? `${reviewImages === 1 ? '1 imagen de la reseña no lleva' : `${reviewImages} imágenes de la reseña no llevan`} texto alternativo en el contenido. ${reviewImages === 1 ? 'Insértala' : 'Insértalas'} de nuevo desde Medios: se copia su texto alternativo.` : undefined },
  ]
}
