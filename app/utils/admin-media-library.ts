import { altMediaMessage } from './content-alt'
import type { AdminMedia } from './admin-media'
import type { AdminUsage } from './admin-form'

/** Library row: what the editor needs plus the file data, texts and how many places use it. */
export interface AdminMediaItem extends AdminMedia {
  version: number
  mime_type: string
  size_bytes: number
  caption_es: string | null
  caption_en: string | null
  credit: string | null
  created_at: string
  updated_at: string
  /** Places using it (cover, OG, gallery, body), from `search_media`. */
  usage_count: number
}

/** Same values as the `p_filter` of `search_media`. */
export type MediaFilter = 'all' | 'unused' | 'in_use' | 'missing_alt' | 'missing_en'

/** Result of `media_stats`; `storageBytes` is what Storage really holds. */
export interface MediaCounts {
  total: number
  inUse: number
  unused: number
  missingAlt: number
  missingEn: number
  rowsBytes: number
  storageBytes: number
  storageObjects: number
}

/** Editable part of a media item (detail panel). Empty text means `null` in the database. */
export interface MediaForm {
  alt_es: string
  alt_en: string
  caption_es: string
  caption_en: string
  credit: string
  dominant_color: string
}
export type MediaErrors = Partial<Record<keyof MediaForm, string>>

/** Mirrors the CHECKs of `guide.media` and the bucket (jpeg/png/webp/avif/gif, 10 MB). */
export const MEDIA_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/avif', 'image/gif'] as const
export const MEDIA_ACCEPT = MEDIA_MIME_TYPES.join(',')
export const MEDIA_MAX_BYTES = 10 * 1024 * 1024
export const MEDIA_PAGE_SIZE = 48
/** Reference only (the real quota cannot be read from the client); shown as "referencia". */
export const MEDIA_QUOTA_BYTES = 1024 * 1024 * 1024
export const MEDIA_LIMITS = { alt: 300, altIdeal: 250, caption: 500, credit: 200 } as const

const EXTENSIONS: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/avif': 'avif', 'image/gif': 'gif' }
const LABELS: Record<string, string> = { 'image/jpeg': 'JPG', 'image/png': 'PNG', 'image/webp': 'WebP', 'image/avif': 'AVIF', 'image/gif': 'GIF' }
export const mediaExtension = (mime: string) => EXTENSIONS[mime] ?? 'bin'

/** `crypto.randomUUID()` in lowercase: it becomes the `id` of the row and the first folder of the path. */
export const newMediaId = () => crypto.randomUUID().toLowerCase()

/** Lowercase, no accents, anything outside [a-z0-9] -> `-`, trimmed, <= 80, empty -> `imagen`. */
export function mediaSlug(filename: string): string {
  const base = filename.replace(/\.[^./\\]*$/, '')
  const slug = base
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80)
    .replace(/-+$/g, '')
  return slug || 'imagen'
}

/** Bucket path `<media_id>/<version>-<slug>.<ext>` (<= 160); a new version is a new path, so caches never go stale. */
export function mediaStoragePath(id: string, version: number, filename: string, mime: string): string {
  return `${id}/${version}-${mediaSlug(filename)}.${mediaExtension(mime)}`
}

export const mediaFormatLabel = (mime: string) => LABELS[mime] ?? mime

/** Error text for a file we will not upload, or `undefined` when it is fine. */
export function validateImageFile(file: Pick<File, 'type' | 'size' | 'name'>): string | undefined {
  if (!(MEDIA_MIME_TYPES as readonly string[]).includes(file.type)) {
    const ext = file.name.split('.').pop()?.toUpperCase() || file.type || 'desconocido'
    return `Formato no admitido (${ext}). Expórtala como JPG, PNG o WebP.`
  }
  if (file.size > MEDIA_MAX_BYTES) return `Pesa ${formatBytes(file.size)}; el máximo son 10 MB.`
  return undefined
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`
  if (bytes < 1024 ** 3) return `${(bytes / 1024 / 1024).toLocaleString('es', { maximumFractionDigits: 1 })} MB`
  return `${(bytes / 1024 ** 3).toLocaleString('es', { maximumFractionDigits: 1 })} GB`
}

export const hasAlt = (media: Pick<AdminMedia, 'alt_es'>) => !!media.alt_es?.trim()

export function mediaToForm(media: AdminMediaItem): MediaForm {
  return {
    alt_es: media.alt_es ?? '',
    alt_en: media.alt_en ?? '',
    caption_es: media.caption_es ?? '',
    caption_en: media.caption_en ?? '',
    credit: media.credit ?? '',
    dominant_color: media.dominant_color ?? '',
  }
}

const orNull = (value: string) => value.trim() || null

export function formToMediaPatch(form: MediaForm) {
  return {
    alt_es: orNull(form.alt_es),
    alt_en: orNull(form.alt_en),
    caption_es: orNull(form.caption_es),
    caption_en: orNull(form.caption_en),
    credit: orNull(form.credit),
    dominant_color: orNull(form.dominant_color)?.toLowerCase() ?? null,
  }
}

export function validateMediaForm(form: MediaForm): MediaErrors {
  const errors: MediaErrors = {}
  if (form.alt_es.length > MEDIA_LIMITS.alt) errors.alt_es = `Máximo ${MEDIA_LIMITS.alt} caracteres.`
  if (form.alt_en.length > MEDIA_LIMITS.alt) errors.alt_en = `Máximo ${MEDIA_LIMITS.alt} caracteres.`
  if (form.caption_es.length > MEDIA_LIMITS.caption) errors.caption_es = `Máximo ${MEDIA_LIMITS.caption} caracteres.`
  if (form.caption_en.length > MEDIA_LIMITS.caption) errors.caption_en = `Máximo ${MEDIA_LIMITS.caption} caracteres.`
  if (form.credit.length > MEDIA_LIMITS.credit) errors.credit = `Máximo ${MEDIA_LIMITS.credit} caracteres.`
  if (form.dominant_color.trim() && !/^#[0-9a-f]{6}$/i.test(form.dominant_color.trim())) errors.dominant_color = 'Usa el formato #rrggbb.'
  return errors
}

/** One "where it is used" row (rpc `media_usages`). `owner_id` is null for site settings. */
export interface MediaUsageRow {
  owner_table: string
  owner_id: string | null
  item_category: string | null
  label: string
  role: string
}

const ROLES: Record<string, string> = {
  cover: 'Portada',
  og: 'Imagen para compartir',
  gallery: 'Galería',
  hero: 'Carrusel de la portada',
  author: 'Autor',
  body_es: 'Cuerpo (ES)',
  body_en: 'Cuerpo (EN)',
  review_body_es: 'Reseña (ES)',
  review_body_en: 'Reseña (EN)',
  draft: 'Borrador',
}
export const usageRoleLabel = (role: string) => ROLES[role] ?? role

const ITEM_ROUTES: Record<string, string> = {
  gym: '/administrador/rocodromos/',
  shoe: '/administrador/pies-de-gato/',
  resoler: '/administrador/resoladores/',
}

function usageHref(row: MediaUsageRow): string | undefined {
  if (row.owner_table === 'site_settings') return row.role === 'hero' ? '/administrador/paginas' : '/administrador/ajustes'
  if (!row.owner_id) return undefined
  if (row.owner_table === 'articles') return `/administrador/articulos/${row.owner_id}`
  if (row.owner_table === 'pages') return `/administrador/paginas/${row.owner_id}`
  if (row.owner_table === 'news') return `/administrador/noticias?noticia=${row.owner_id}`
  if (row.owner_table === 'items') {
    const base = ITEM_ROUTES[row.item_category ?? '']
    return base ? `${base}${row.owner_id}` : undefined
  }
  return undefined
}

export function usageToAdmin(row: MediaUsageRow): AdminUsage {
  return { label: row.label, where: usageRoleLabel(row.role), href: usageHref(row) }
}

/** Friendly Spanish text for a backend error; the raw `message` is never shown. */
export function mediaErrorMessage(e: unknown): string {
  const alt = altMediaMessage(e)
  if (alt) return alt
  const { code, detail } = (e ?? {}) as { code?: string; detail?: string }
  switch (code) {
    case '42501':
      return 'No tienes permiso para gestionar medios.'
    case 'P0002':
      return 'Esa imagen ya no existe. Lista recargada.'
    case 'PT409':
      return 'Otra persona ha cambiado esta imagen mientras la editabas. Recarga la lista e inténtalo de nuevo.'
    case '23503': {
      const n = Number(detail)
      return n > 0
        ? `La imagen está en uso en ${n} ${n === 1 ? 'sitio' : 'sitios'}; quítala de ahí antes de eliminarla.`
        : 'La imagen está en uso; quítala de esos sitios antes de eliminarla.'
    }
    case '23514':
      return 'La extensión del archivo no coincide con su formato real.'
    case '23505':
      return 'Esa imagen ya estaba subida.'
    case '22023':
      return 'El servidor ha rechazado la imagen o sus datos. Revisa el archivo y los textos (longitud máxima) e inténtalo de nuevo.'
    case '403':
      return 'No se ha podido subir: ruta no permitida.'
    case '409':
      return 'Ese archivo ya existe en el almacenamiento.'
  }
  return 'No se ha podido completar la acción. Inténtalo de nuevo.'
}
