import { BLOCKER_TEXT } from '~/utils/item-blockers'
import type { ImportIssue } from '~/utils/admin-import-report'
import { IMPORT_SPECS } from '~/utils/admin-import-spec'

/** Texts (provisional, loro-lola) of the codes the server and the client give per row (audit F6.15b §4). */
const list = (value: unknown) => (Array.isArray(value) ? value.map((v) => `«${String(v)}»`).join(', ') : '')

const str = (value: unknown) => (value === undefined || value === null ? '' : String(value))

/** Allowed DB values of an error as the Spanish labels the importer accepts (first label of each value); unknown values stay as they are. */
function allowedLabels(column: string | undefined, allowed: unknown): unknown {
  if (!Array.isArray(allowed)) return allowed
  const options = Object.values(IMPORT_SPECS).map((spec) => spec.columns.get(column ?? '')?.options).find((o) => o?.length)
  return [...new Set(allowed.map((v) => options?.find(([value]) => String(value) === String(v))?.[1] ?? v))]
}

const TEXTS: Record<string, (p: Record<string, unknown>) => string> = {
  // Errors
  unknown_column: () => 'Esta columna no se reconoce.',
  null_not_allowed: () => 'Una celda vacía no borra nada. Para vaciar un campo, usa el editor.',
  invalid_type: (p) => `El valor no tiene el formato esperado${p.expected ? ` (${str(p.expected)})` : ''}.`,
  empty_value: () => 'No puede ir vacío.',
  out_of_range: () => 'El valor está fuera del rango permitido.',
  invalid_date: () => 'La fecha no es válida. Usa AAAA-MM-DD o una fecha de Excel.',
  too_long: (p) => `Es demasiado largo${p.max ? ` (máximo ${str(p.max)} caracteres)` : ''}.`,
  invalid_value: () => 'El valor no es válido.',
  not_allowed_value: (p) => `Valor no permitido${list(p.allowed) ? `. Opciones: ${list(p.allowed)}` : ''}.`,
  check: () => 'Algún dato no cumple las reglas de la ficha.',
  invalid_url: () => 'La URL no es válida: empieza por https:// y no lleva espacios.',
  invalid_hours: () => 'El horario no se puede leer. Usa «10:00-14:00, 17:00-23:00» o «Cerrado». Para cerrar a medianoche, escribe 24:00.',
  required: () => 'Falta un dato obligatorio.',
  slug_placeholder: () => 'La URL está vacía o es «sin-nombre». Escribe una propia: es la identidad de la ficha.',
  duplicate_in_file: (p) => `La URL está repetida en el archivo${p.first ? ` (ya sale en la fila ${str(p.first)})` : ''}.`,
  slug_is_redirect: () => 'Esta URL es una redirección de otra ficha. Usa otra.',
  exists_as: (p) => `Esta URL ya es de otra ficha${p.slug ? ` («${str(p.slug)}»)` : ''} de otro tipo. Usa otra.`,
  identity_conflict: (p) => `Esta fila coincide con otra ficha${p.slug ? ` («${str(p.slug)}»)` : ''} por otro dato. Revisa la URL.`,
  slug_taken: () => 'Esta URL ya la usa otra ficha.',
  brand_model_taken: () => 'Ya existe un pie de gato con esa marca y ese modelo.',
  owned_only: () => 'Solo los pies que has usado llevan reseña, notas y tallas. Marca «Los tengo y los he usado» o quita este dato.',
  sizes_pair: () => 'Rellena las dos tallas o ninguna.',
  needs_es: () => 'La nota en inglés necesita la de español.',
  unknown_criterion: () => 'Esta nota no es de un criterio de esta categoría.',
  inactive_criterion: () => 'Este criterio está desactivado. Reactívalo en Criterios de nota.',
  media_external_url: () => 'Las fotos van antes a Medios: una URL de otra web no se descarga.',
  pending_draft: () => 'Ya tiene cambios sin publicar en el editor y no se mezclan con el archivo. Publícalos o descártalos y vuelve a subir el archivo.',
  draft_conflict: () => 'Tiene un borrador distinto. Publícalo o descártalo y vuelve a subir el archivo.',
  live_guard: () => 'La ficha está publicada y no se puede escribir directamente.',
  reference_missing: () => 'Falta un dato relacionado (imagen o criterio).',
  unexpected: () => 'Error inesperado al comprobar esta fila. Inténtalo de nuevo.',
  // Warnings
  rounded: (p) => `Tiene más decimales de los que caben: se guarda como ${str(p.value)}.`,
  duplicates_removed: () => 'La lista tenía repetidos: se quitan.',
  looks_like_html: () => 'Parece HTML. La reseña se guarda como texto plano.',
  review_body_kept: () => 'La ficha ya tiene reseña: se conserva la del panel y no se toca.',
  same_name: (p) => `Tiene el mismo nombre que otra ficha${p.slug ? ` («${str(p.slug)}»)` : ''} con otra URL. Si has cambiado la URL, se creará otra ficha.`,
  media_not_found: () => 'La foto no está en Medios todavía: entra sin ella y bloqueará publicar.',
  media_ambiguous: (p) => `Hay ${str(p.count) || 'varias'} fotos con este nombre en Medios: no se elige ninguna. Asígnala a mano.`,
  media_no_alt: () => 'La foto no tiene texto alternativo (ES) en Medios: bloqueará publicar.',
  postal_zero: (p) => `Excel quitó el 0 del código postal: se importa como ${str(p.value)}.`,
}

const FALLBACK_ERROR = 'La fila tiene un problema que impide importarla.'

export function issueText(issue: ImportIssue): string {
  const code = issue.code.startsWith('check:') ? 'check' : issue.code
  const make = TEXTS[code]
  const params = issue.params?.allowed ? { ...issue.params, allowed: allowedLabels(issue.column, issue.params.allowed) } : (issue.params ?? {})
  const base = make ? make(params) : issue.level === 'error' ? FALLBACK_ERROR : `Aviso: ${issue.code}.`
  return issue.index !== undefined ? `${base} (imagen ${issue.index + 1} de la galería)` : base
}

export const LEVEL_LABEL = { error: 'Error', blocker: 'Bloqueará publicar', warning: 'Aviso' } as const

export const blockerShort = (blockers: readonly string[]) => (blockers.length === 1 && blockers[0] === 'cover' ? 'Falta portada' : `${blockers.length} ${blockers.length === 1 ? 'bloqueo' : 'bloqueos'}`)
export const blockerList = (blockers: readonly string[]) => blockers.map((code) => BLOCKER_TEXT[code] ?? `un requisito pendiente (${code})`)

/** CSV of errors to correct the Excel next to it (README §13.3). */
export function errorsCsvRows(rows: { row: number; issues: ImportIssue[] }[], letters: Record<string, string>, payloadOf: (row: number) => Record<string, unknown> | undefined) {
  return rows.flatMap((r) =>
    r.issues.filter((i) => i.level === 'error').map((i) => ({
      fila: r.row,
      columna: i.column ? (letters[i.column] ?? '') : '',
      campo: i.column ?? '',
      valor: i.column ? str(payloadOf(r.row)?.[i.column.split('.')[0]!]) : '',
      problema: issueText(i),
    })),
  )
}

/** Spanish text for a failed importer call (no report came back, so nothing was written by that call). */
export function importErrorMessage(error: unknown): string {
  const code = (error as { code?: string } | null)?.code
  const message = (error as { message?: string } | null)?.message ?? ''
  if (code === '42501') return 'No tienes permiso para importar. Vuelve a entrar en el panel.'
  if (code === '22023' && /batch/i.test(message)) return 'El lote de esta importación ya no admite más trozos. Sube el archivo de nuevo: lo que ya se escribió saldrá «Sin cambios».'
  if (code === '22023') return 'El servidor no ha aceptado el archivo (demasiadas filas o un tamaño excesivo). Divídelo en archivos más pequeños.'
  if (code === 'P0002') return 'El lote de esta importación ya no existe. Sube el archivo de nuevo.'
  if (code === '57014' || /timeout/i.test(message)) return 'La comprobación ha tardado demasiado. Prueba con menos filas.'
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la importación. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}

/** A value of the "antes → después" of a change, short and readable. */
export function formatChange(value: unknown): string {
  if (value === null || value === undefined || value === '') return '(vacío)'
  const text = Array.isArray(value) ? value.map(String).join(' | ') : typeof value === 'object' ? JSON.stringify(value) : typeof value === 'boolean' ? (value ? 'Sí' : 'No') : String(value)
  return text.length > 90 ? `${text.slice(0, 90)}…` : text
}

/** What the "Portada" cell of the review says, from the warnings of the row. */
export function coverStatus(issues: readonly ImportIssue[], cover: string): { label: string; ok: boolean } {
  const gallery = (i: ImportIssue) => i.column === 'cover'
  if (issues.some((i) => i.code === 'media_not_found' && gallery(i))) return { label: 'No está en Medios', ok: false }
  const ambiguous = issues.find((i) => i.code === 'media_ambiguous' && gallery(i))
  if (ambiguous) return { label: `${String(ambiguous.params?.count ?? 'Varias')} con este nombre`, ok: false }
  if (issues.some((i) => i.code === 'media_no_alt' && gallery(i))) return { label: 'Sin texto alt', ok: false }
  return cover ? { label: 'En Medios', ok: true } : { label: 'Sin archivo', ok: false }
}
