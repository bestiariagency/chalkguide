import type { JSONContent } from '@tiptap/core'
import type { Database } from '~/types/database.types'
import { emptyBody, isEmptyDoc, type ArticleBody } from '~/utils/article-editor'
import { SEO_LIMITS } from '~/utils/admin-form'
import { altChecklistItem, altEnChecklistItem, type AltIssue } from '~/utils/content-alt'

type ArticleRow = Database['guide']['Tables']['articles']['Row']
export type ArticleUpdate = Database['guide']['Tables']['articles']['Update']
export type FormLocale = 'es' | 'en'

export interface LocaleFields {
  title: string
  slug: string
  excerpt: string
  seoTitle: string
  seoDescription: string
  body: ArticleBody
}

/** What the author edits. Status and publication date are NOT here: they change only through explicit actions. */
export interface ArticleForm {
  categoryId: string
  /** guide.authors id; null = site author (site_settings). */
  authorId: string | null
  isFeatured: boolean
  noindex: boolean
  canonicalUrl: string
  coverMediaId: string | null
  ogMediaId: string | null
  es: LocaleFields
  en: LocaleFields
}

/** Read-only facts of the stored article. */
export interface ArticleMeta {
  id: string
  status: ArticleRow['status']
  publishedAt: string | null
  createdAt: string
  updatedAt: string
  readingMinutes: Record<FormLocale, number | null>
}

export const EXCERPT_MAX = 300
export const TITLE_MAX = 200
const SLUG_MAX = 120
const SLUG_FORMAT = /^[a-z0-9]+(-[a-z0-9]+)*$/

function body(json: unknown, html: string | null): ArticleBody {
  if (!json || typeof json !== 'object') return emptyBody()
  return { json: json as JSONContent, html: html ?? '' }
}

export function formFromRow(row: ArticleRow): ArticleForm {
  return {
    categoryId: row.category_id,
    authorId: row.author_id,
    isFeatured: row.is_featured,
    noindex: row.noindex,
    canonicalUrl: row.canonical_url ?? '',
    coverMediaId: row.cover_media_id,
    ogMediaId: row.og_media_id,
    es: {
      title: row.title_es,
      slug: row.slug_es,
      excerpt: row.excerpt_es ?? '',
      seoTitle: row.seo_title_es ?? '',
      seoDescription: row.seo_description_es ?? '',
      body: body(row.body_json_es, row.body_html_es),
    },
    en: {
      title: row.title_en ?? '',
      slug: row.slug_en ?? '',
      excerpt: row.excerpt_en ?? '',
      seoTitle: row.seo_title_en ?? '',
      seoDescription: row.seo_description_en ?? '',
      body: body(row.body_json_en, row.body_html_en),
    },
  }
}

export function metaFromRow(row: ArticleRow): ArticleMeta {
  return {
    id: row.id,
    status: row.status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    readingMinutes: { es: row.reading_minutes_es, en: row.reading_minutes_en },
  }
}

export type ArticleErrors = Partial<Record<string, string>>

/** Slugs already used by OTHER articles, per locale. */
export interface TakenSlugs {
  es: ReadonlySet<string>
  en: ReadonlySet<string>
}

function validateSlug(slug: string, taken: ReadonlySet<string>, locale: FormLocale): string | undefined {
  if (!slug) return `Falta la URL${locale === 'en' ? ' en inglés' : ''}.`
  if (slug.length > SLUG_MAX || !SLUG_FORMAT.test(slug)) return 'La URL solo admite minúsculas, números y guiones.'
  if (taken.has(slug)) return 'Ya existe otro artículo con esta URL.'
  return undefined
}

/** Field errors that the database would reject (CHECKs, unique). Keys: `es.title`, `en.slug`, `categoryId`… */
export function validateArticle(form: ArticleForm, taken: TakenSlugs): ArticleErrors {
  const errors: ArticleErrors = {}
  if (!form.categoryId) errors.categoryId = 'Elige una categoría.'
  if (form.canonicalUrl.trim() && !/^https?:\/\/\S+$/.test(form.canonicalUrl.trim())) {
    errors.canonicalUrl = 'Debe empezar por http:// o https://.'
  }
  for (const locale of ['es', 'en'] as const) {
    const f = form[locale]
    const en = locale === 'en'
    if (f.title.trim().length > TITLE_MAX) errors[`${locale}.title`] = `Máximo ${TITLE_MAX} caracteres.`
    if (f.excerpt.length > EXCERPT_MAX) errors[`${locale}.excerpt`] = `Máximo ${EXCERPT_MAX} caracteres.`
    if (f.seoTitle.length > SEO_LIMITS.title.max) errors[`${locale}.seoTitle`] = `Máximo ${SEO_LIMITS.title.max} caracteres.`
    if (f.seoDescription.length > SEO_LIMITS.description.max) errors[`${locale}.seoDescription`] = `Máximo ${SEO_LIMITS.description.max} caracteres.`
    if (!en) {
      if (!f.title.trim()) errors['es.title'] = 'Escribe un título.'
      const slugError = validateSlug(f.slug, taken.es, 'es')
      if (slugError) errors['es.slug'] = slugError
    } else if (f.title.trim() || f.slug) {
      // CHECK articles_en_coherent: title_en and slug_en go together.
      if (!f.title.trim()) errors['en.title'] = 'Falta el título en inglés (o vacía también la URL).'
      const slugError = validateSlug(f.slug, taken.en, 'en')
      if (slugError) errors['en.slug'] = slugError
    }
  }
  return errors
}

const hasEnglish = (en: LocaleFields) =>
  !!(en.title.trim() || en.slug || en.excerpt.trim() || en.seoTitle.trim() || en.seoDescription.trim() || !isEmptyDoc(en.body.json))

export interface ChecklistItem {
  key: string
  label: string
  ok: boolean
  /** Blocking items stop "Publicar"/"Programar"; the others are advice. */
  blocking: boolean
  hint?: string
  /** Where to fix it (e.g. images without alt text → Medios). */
  links?: { label: string; to: string }[]
}

export interface ChecklistContext {
  hasCover: boolean
  /** Images without Spanish alt text (D27): local ones plus the server's check. They block publishing. */
  altIssues: AltIssue[]
  /** English alt text: blocking (required by the EN body) and warning-only lists. */
  altEnIssues?: AltIssue[]
  altEnAdvice?: AltIssue[]
}

/** Images in the body without alt text (they are decorative at best, a gap at worst). */
export function imagesWithoutAlt(html: string): number {
  return [...html.matchAll(/<img\b[^>]*>/gi)].filter((m) => !/\balt="[^"]+"/i.test(m[0])).length
}

export function publishChecklist(form: ArticleForm, errors: ArticleErrors, ctx: ChecklistContext): ChecklistItem[] {
  const enFilled = hasEnglish(form.en)
  const enComplete = !!form.en.title.trim() && !!form.en.slug && !isEmptyDoc(form.en.body.json)
  const noErrors = Object.keys(errors).length === 0
  const bodyNoAlt = imagesWithoutAlt(form.es.body.html)
  return [
    { key: 'title', label: 'Título y URL', ok: !errors['es.title'] && !errors['es.slug'], blocking: true },
    { key: 'category', label: 'Categoría', ok: !!form.categoryId, blocking: true },
    { key: 'body', label: 'Cuerpo del artículo', ok: !isEmptyDoc(form.es.body.json), blocking: true },
    {
      key: 'en',
      label: 'Inglés completo o vacío',
      ok: !enFilled || enComplete,
      blocking: true,
      hint: 'Rellena título, URL y cuerpo en EN, o deja todo el inglés vacío.',
    },
    { key: 'fields', label: 'Campos sin errores', ok: noErrors, blocking: true },
    altChecklistItem(ctx.altIssues),
    altEnChecklistItem(ctx.altEnIssues ?? [], ctx.altEnAdvice ?? []),
    { key: 'cover', label: 'Portada', ok: ctx.hasCover, blocking: false },
    { key: 'lead', label: 'Entradilla', ok: !!form.es.excerpt.trim(), blocking: false },
    {
      key: 'alt-body',
      label: 'Texto alternativo dentro del texto',
      ok: bodyNoAlt === 0,
      blocking: false,
      hint: bodyNoAlt ? `${bodyNoAlt === 1 ? '1 imagen del cuerpo no lleva' : `${bodyNoAlt} imágenes del cuerpo no llevan`} texto alternativo en el contenido. ${bodyNoAlt === 1 ? 'Insértala' : 'Insértalas'} de nuevo desde Medios: se copia su texto alternativo.` : undefined,
    },
  ]
}
