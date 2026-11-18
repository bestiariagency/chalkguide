import type { JSONContent } from '@tiptap/core'
import type { Database } from '~/types/database.types'
import { SEO_LIMITS } from '~/utils/admin-form'
import type { PageDef, PageKey } from '~/utils/admin-pages'
import { emptyBody, isEmptyDoc, type ArticleBody } from '~/utils/article-editor'
import { imagesWithoutAlt, type ArticleErrors, type ChecklistContext, type ChecklistItem } from '~/utils/article-form'
import { altChecklistItem, altEnChecklistItem } from '~/utils/content-alt'
import { countProvisional } from '~/utils/page-provisional'

export type PageRow = Database['guide']['Tables']['pages']['Row']
export type PageUpdate = Database['guide']['Tables']['pages']['Update']

export interface PageLocaleFields {
  title: string
  seoTitle: string
  seoDescription: string
  body: ArticleBody
}

/** What the author edits. Slugs, `key`, `published` and `revised_on` are NOT here: the database owns them. */
export interface PageForm {
  noindex: boolean
  ogMediaId: string | null
  es: PageLocaleFields
  en: PageLocaleFields
}

/** Read-only facts of the stored page. */
export interface PageMeta {
  id: string
  key: PageKey
  published: boolean
  /** `YYYY-MM-DD` shown to readers as "Última actualización" (legal pages). */
  revisedOn: string | null
  createdAt: string
  updatedAt: string
}

export const PAGE_TITLE_MAX = 200

function body(json: unknown, html: string | null): ArticleBody {
  if (!json || typeof json !== 'object') return emptyBody()
  return { json: json as JSONContent, html: html ?? '' }
}

export function pageFormFromRow(row: PageRow): PageForm {
  return {
    noindex: row.noindex,
    ogMediaId: row.og_media_id,
    es: { title: row.title_es, seoTitle: row.seo_title_es ?? '', seoDescription: row.seo_description_es ?? '', body: body(row.body_json_es, row.body_html_es) },
    en: { title: row.title_en ?? '', seoTitle: row.seo_title_en ?? '', seoDescription: row.seo_description_en ?? '', body: body(row.body_json_en, row.body_html_en) },
  }
}

export function pageMetaFromRow(row: PageRow): PageMeta {
  return { id: row.id, key: row.key as PageKey, published: row.published, revisedOn: row.revised_on, createdAt: row.created_at, updatedAt: row.updated_at }
}

/** Field errors that the database would reject (CHECK limits). Keys: `es.title`, `en.seoTitle`… */
export function validatePage(form: PageForm): ArticleErrors {
  const errors: ArticleErrors = {}
  for (const locale of ['es', 'en'] as const) {
    const f = form[locale]
    if (f.title.trim().length > PAGE_TITLE_MAX) errors[`${locale}.title`] = `Máximo ${PAGE_TITLE_MAX} caracteres.`
    if (f.seoTitle.length > SEO_LIMITS.title.max) errors[`${locale}.seoTitle`] = `Máximo ${SEO_LIMITS.title.max} caracteres.`
    if (f.seoDescription.length > SEO_LIMITS.description.max) errors[`${locale}.seoDescription`] = `Máximo ${SEO_LIMITS.description.max} caracteres.`
  }
  if (!form.es.title.trim()) errors['es.title'] = 'Escribe un título.'
  return errors
}

/** English is all-or-nothing (D3): a title without body, or a body without title, is half-done. */
export const englishFilled = (en: PageLocaleFields) => !!en.title.trim() || !isEmptyDoc(en.body.json)
export const englishComplete = (en: PageLocaleFields) => !!en.title.trim() && !isEmptyDoc(en.body.json)

/** Whether the change touches what the reader sees as the text (the date "Última actualización" only moves then). */
export function textChanged(published: PageForm, current: PageForm): boolean {
  return (['es', 'en'] as const).some((l) => published[l].title.trim() !== current[l].title.trim() || bodyKey(published[l]) !== bodyKey(current[l]))
}
const bodyKey = (f: PageLocaleFields) => (isEmptyDoc(f.body.json) ? '' : f.body.html)

/** Checklist item that points at where to fix it (field or language). */
export interface PageChecklistItem extends ChecklistItem {
  target?: 'title' | 'body' | 'en' | 'seo' | 'marks'
}

/** Provisional marks (`[XAVI: …]`, "Texto provisional") left in the text of both languages. */
export const provisionalCount = (form: PageForm) => countProvisional(form.es.body.html) + countProvisional(form.en.body.html) + countProvisional(form.es.title)

export function pageChecklist(def: PageDef, form: PageForm, errors: ArticleErrors, ctx: ChecklistContext): PageChecklistItem[] {
  const marks = provisionalCount(form)
  const bodyNoAlt = def.legal ? 0 : imagesWithoutAlt(form.es.body.html)
  const items: PageChecklistItem[] = [
    { key: 'title', label: 'Título', ok: !errors['es.title'], blocking: true, target: 'title' },
    { key: 'body', label: 'Cuerpo (ES)', ok: !isEmptyDoc(form.es.body.json), blocking: true, hint: 'Escribe el texto para poder publicar.', target: 'body' },
  ]
  if (!def.legal) items.push(altChecklistItem(ctx.altIssues), altEnChecklistItem(ctx.altEnIssues ?? [], ctx.altEnAdvice ?? []))
  const half = englishFilled(form.en) && !englishComplete(form.en)
  items.push(
    {
      key: 'en',
      label: 'Inglés completo o vacío',
      ok: !half,
      blocking: true,
      hint: form.en.title.trim() && isEmptyDoc(form.en.body.json) ? 'Hay título en inglés pero no cuerpo: complétalo o vacía el título EN.' : 'Hay cuerpo en inglés pero no título: complétalo o vacía el cuerpo EN.',
      target: 'en',
    },
    { key: 'fields', label: 'Campos sin errores', ok: Object.keys(errors).length === 0, blocking: true, hint: 'Revisa los campos marcados en rojo (título, título SEO o descripción).', target: 'seo' },
    {
      key: 'marks',
      label: marks === 0 ? 'Sin marcas de texto provisional' : marks === 1 ? 'Queda 1 marca de texto provisional' : `Quedan ${marks} marcas de texto provisional`,
      ok: marks === 0,
      blocking: false,
      hint: 'Se publicarían tal cual.',
      target: 'marks',
    },
    { key: 'seo-description', label: 'Descripción SEO propia', ok: !!form.es.seoDescription.trim(), blocking: false, hint: 'Vacía, se usa la descripción por defecto de la página.' },
  )
  if (!def.legal) {
    items.push({
      key: 'alt-body',
      label: 'Texto alternativo en las imágenes del cuerpo',
      ok: bodyNoAlt === 0,
      blocking: false,
      hint: bodyNoAlt ? `${bodyNoAlt === 1 ? '1 imagen del cuerpo no lleva texto alternativo. Insértala' : `${bodyNoAlt} imágenes del cuerpo no llevan texto alternativo. Insértalas`} de nuevo desde Medios.` : undefined,
    })
  }
  return items
}
