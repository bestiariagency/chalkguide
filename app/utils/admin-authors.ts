import type { AdminMedia } from '~/utils/admin-media'
import { slugify } from '~/utils/admin-form'

/** Author of the blog (`guide.authors`); `photo` is the joined media. `is_primary` is hidden (D62). */
export interface AdminAuthor {
  id: string
  slug: string
  name: string
  role_es: string | null
  role_en: string | null
  bio_es: string | null
  bio_en: string | null
  photo_media_id: string | null
  sort_order: number
  photo: AdminMedia | null
}

/** The site author (`site_settings`): fixed on top of the list, edited in Ajustes. */
export interface SiteAuthor {
  name: string | null
  role_es: string | null
  role_en: string | null
  bio_en: string | null
  photo: AdminMedia | null
}

export interface AuthorCounts {
  total: number
  live: number
}

export interface AuthorImpact {
  counts: AuthorCounts
  /** First three articles (title and state) for the delete dialog. */
  titles: { id: string; title: string; status: 'draft' | 'published' | 'scheduled'; published_at: string | null }[]
}

export interface AuthorForm {
  name: string
  slug: string
  role_es: string
  role_en: string
  bio_es: string
  bio_en: string
  photo_media_id: string | null
}

export type AuthorErrors = Partial<Record<keyof AuthorForm, string>>

export const AUTHOR_LIMITS = { name: 80, role: 80, bio: 160, slug: 120 } as const

export const emptyAuthorForm = (): AuthorForm => ({ name: '', slug: '', role_es: '', role_en: '', bio_es: '', bio_en: '', photo_media_id: null })

export const authorToForm = (a: AdminAuthor): AuthorForm => ({
  name: a.name,
  slug: a.slug,
  role_es: a.role_es ?? '',
  role_en: a.role_en ?? '',
  bio_es: a.bio_es ?? '',
  bio_en: a.bio_en ?? '',
  photo_media_id: a.photo_media_id,
})

const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/

/** Mirrors the table checks (`name` 1–80, roles ≤ 80, bios ≤ 160) and the `guide.slug` domain. */
export function validateAuthor(form: AuthorForm, photo: AdminMedia | null): AuthorErrors {
  const errors: AuthorErrors = {}
  const name = form.name.trim()
  if (!name) errors.name = 'Escribe el nombre con el que firma.'
  else if (name.length > AUTHOR_LIMITS.name) errors.name = `Máximo ${AUTHOR_LIMITS.name} caracteres.`
  const slug = form.slug.trim()
  if (!slug) errors.slug = 'Escribe un identificador.'
  else if (slug.length > AUTHOR_LIMITS.slug || !SLUG.test(slug)) errors.slug = 'Usa minúsculas, números y guiones, sin espacios.'
  for (const key of ['role_es', 'role_en'] as const) if (form[key].trim().length > AUTHOR_LIMITS.role) errors[key] = `Máximo ${AUTHOR_LIMITS.role} caracteres.`
  for (const key of ['bio_es', 'bio_en'] as const) if (form[key].trim().length > AUTHOR_LIMITS.bio) errors[key] = `Máximo ${AUTHOR_LIMITS.bio} caracteres.`
  if (form.photo_media_id && photo && (!photo.alt_es?.trim() || !photo.alt_en?.trim())) {
    errors.photo_media_id = 'Esta foto no tiene texto alternativo en español e inglés. Añádelo en Medios o elige otra.'
  }
  return errors
}

const orNull = (value: string) => value.trim() || null

/** Columns to write: blank optional texts become null. */
export const authorPayload = (form: AuthorForm) => ({
  name: form.name.trim(),
  slug: form.slug.trim(),
  role_es: orNull(form.role_es),
  role_en: orNull(form.role_en),
  bio_es: orNull(form.bio_es),
  bio_en: orNull(form.bio_en),
  photo_media_id: form.photo_media_id,
})

export const authorSlugFrom = (name: string) => slugify(name)

export const authorInitial = (name: string) => name.trim().charAt(0).toUpperCase() || '?'

/** «ninguno publicado», «1 publicado», «3 publicados». */
export const publishedText = (live: number) => (live === 0 ? 'ninguno publicado' : live === 1 ? '1 publicado' : `${live} publicados`)

export type EnState ='full' | 'part' | 'none'

/** English status of a signature: role and bio in English («completo», «a medias» with what is missing, «sin inglés»). */
export function enStatus(role: string | null | undefined, bio: string | null | undefined): { state: EnState; text: string } {
  const hasRole = !!role?.trim()
  const hasBio = !!bio?.trim()
  if (hasRole && hasBio) return { state: 'full', text: 'Inglés completo: rol y bio.' }
  if (!hasRole && !hasBio) return { state: 'none', text: 'Sin inglés: en /en la firma sale sin rol ni bio.' }
  return { state: 'part', text: hasRole ? 'Inglés a medias: falta la bio.' : 'Inglés a medias: falta el rol.' }
}

export function isSlugTaken(e: unknown): boolean {
  const err = e as { code?: string; message?: string } | null
  return err?.code === '23505' && (err.message ?? '').includes('authors_slug_key')
}

/** Spanish text for a failed authors request. */
export function authorErrorMessage(e: unknown): string {
  const code = (e as { code?: string } | null)?.code
  if (code === '42501') return 'Tu cuenta no tiene permiso para cambiar los autores.'
  if (code === 'PT422') return 'La foto no tiene texto alternativo en español e inglés. Añádelo en Medios o elige otra.'
  if (code === '23514') return 'Algún valor no es válido. Revisa los campos.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo.'
}
