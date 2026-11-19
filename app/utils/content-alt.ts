import type { ChecklistItem } from '~/utils/article-form'

/** D27: published content needs Spanish alt text on every image. Pure helpers for the UI. */
export interface AltIssue {
  id: string
  name: string
}

type AltLang = 'es' | 'en'

interface AltRefusal {
  mediaIds: string[]
  /** Which language is missing for which image (empty when the server does not say). */
  missing: { mediaId: string; lang: AltLang }[]
  /** `entity_id` is empty for `site_settings`. */
  usedBy: { entity: string; entityId: string }[]
  /** Top-level `entity` of the refusal (`site_settings` for the default share image). */
  entity: string
}

/** The database refusal (HTTP 422, code PT422, `details` = JSON string); `null` for any other error. */
export function altRefusal(error: unknown): AltRefusal | null {
  const { code, detail, details } = (error ?? {}) as { code?: string; detail?: string; details?: string }
  if (code !== 'PT422') return null
  let parsed: { media_ids?: unknown; used_by?: unknown; missing?: unknown; entity?: unknown } = {}
  try {
    parsed = JSON.parse(detail ?? details ?? '{}') ?? {}
  } catch { /* the message is still useful without ids */ }
  const mediaIds = Array.isArray(parsed.media_ids) ? parsed.media_ids.filter((v): v is string => typeof v === 'string') : []
  const missing = Array.isArray(parsed.missing)
    ? parsed.missing
        .map((m: { media_id?: unknown; lang?: unknown }) => ({ mediaId: String(m?.media_id ?? ''), lang: m?.lang === 'en' ? 'en' : 'es' }) as { mediaId: string; lang: AltLang })
        .filter((m) => m.mediaId)
    : []
  const usedBy = Array.isArray(parsed.used_by)
    ? parsed.used_by.map((u: { entity?: string; entity_id?: string | null }) => ({ entity: String(u?.entity ?? ''), entityId: String(u?.entity_id ?? '') }))
    : []
  return { mediaIds, missing, usedBy, entity: typeof parsed.entity === 'string' ? parsed.entity : '' }
}

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`

/** "en español", "en inglés" or "en español e inglés" from the languages the server reports; `''` when unknown. */
function langPhrase(missing: AltRefusal['missing']): string {
  const es = missing.some((m) => m.lang === 'es')
  const en = missing.some((m) => m.lang === 'en')
  if (es && en) return ' en español e inglés'
  if (en) return ' en inglés'
  if (es) return ' en español'
  return ''
}

/** "Publicar" refused: how many images (and which, when the caller knows their names) and in which language. */
export function altPublishMessage(error: unknown, nameOf?: (id: string) => string | undefined): string | null {
  const refusal = altRefusal(error)
  if (!refusal) return null
  const ids = [...new Set([...refusal.mediaIds, ...refusal.missing.map((m) => m.mediaId)])]
  const n = ids.length
  const names = ids.map((id) => nameOf?.(id)).filter((v): v is string => !!v)
  const which = names.length ? ` (${names.join(', ')})` : ''
  const lang = langPhrase(refusal.missing)
  const subject = refusal.entity === 'site_settings' ? 'la imagen para compartir por defecto del sitio' : ''
  if (subject) return `No se puede guardar: ${subject} no tiene texto alternativo${lang || ' en español e inglés'}${which}. Añádelo en Medios y vuelve a intentarlo.`
  const head = n
    ? `No se puede publicar: ${plural(n, 'imagen no tiene', 'imágenes no tienen')} texto alternativo${lang || ' en español'}${which}.`
    : `No se puede publicar: hay imágenes sin texto alternativo${lang || ' en español'}.`
  return `${head} Añádelo en Medios y vuelve a intentarlo.`
}

const ENTITY_LABEL: Record<string, [string, string]> = { article: ['artículo', 'artículos'], page: ['página', 'páginas'], item: ['ficha', 'fichas'], author: ['autor', 'autores'], news: ['noticia', 'noticias'] }
const SETTINGS = 'site_settings'

/** Emptying the alt of an image used by published content (or the default share image): where it is used. */
export function altMediaMessage(error: unknown): string | null {
  const refusal = altRefusal(error)
  if (!refusal) return null
  const counts = new Map<string, number>()
  let settings = false
  for (const { entity } of refusal.usedBy) {
    if (entity === SETTINGS) settings = true
    else counts.set(entity, (counts.get(entity) ?? 0) + 1)
  }
  const parts = [...counts].map(([entity, n]) => plural(n, ...(ENTITY_LABEL[entity] ?? ['contenido', 'contenidos']) as [string, string]))
  if (settings) parts.push('la imagen para compartir por defecto del sitio')
  const where = parts.join(', ')
  const lang = langPhrase(refusal.missing) || ' en español'
  return `No se puede vaciar el texto alternativo${lang}: la imagen se usa en contenido publicado${where ? ` (${where})` : ''}. Cámbialo por otro texto o quítala de ahí primero.`
}

export const mediaLink = (id: string) => `${adminPath('medios')}?imagen=${id}`

/** Union by media id (the local and the server lists overlap). */
export function mergeAlt(...lists: AltIssue[][]): AltIssue[] {
  return [...new Map(lists.flat().map((i) => [i.id, i])).values()]
}

/** Blocking checklist item: every image needs Spanish alt text (D27). */
export function altChecklistItem(issues: AltIssue[]): ChecklistItem {
  return {
    key: 'alt',
    label: 'Texto alternativo en Medios (ES)',
    ok: issues.length === 0,
    blocking: true,
    hint: issues.length ? `${plural(issues.length, 'imagen sin texto alternativo', 'imágenes sin texto alternativo')}. Añádelo en Medios:` : undefined,
    links: issues.map((i) => ({ label: i.name, to: mediaLink(i.id) })),
  }
}

/**
 * English alt text (D27 extended). Blocking when the server says the English body/review needs it
 * (`alt_en_required`); otherwise (cover, share image, gallery) it is only a warning.
 */
export function altEnChecklistItem(required: AltIssue[], advisory: AltIssue[]): ChecklistItem {
  const issues = required.length ? required : advisory
  return {
    key: 'alt-en',
    label: 'Texto alternativo en Medios (EN)',
    ok: issues.length === 0,
    blocking: required.length > 0,
    hint: issues.length ? `${plural(issues.length, 'imagen sin texto alternativo en inglés', 'imágenes sin texto alternativo en inglés')}. Añádelo en Medios:` : undefined,
    links: issues.map((i) => ({ label: i.name, to: mediaLink(i.id) })),
  }
}
