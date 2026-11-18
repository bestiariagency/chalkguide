import type { Database } from '~/types/database.types'
import { EMPTY_DOC, isEmptyDoc } from '~/utils/article-editor'
import type { ArticleErrors, ArticleForm, ArticleUpdate, FormLocale, LocaleFields } from '~/utils/article-form'

// --- Autosave diff -----------------------------------------------------------------------------

interface FieldGroup {
  key: string
  /** Error keys that keep the group out of the patch while they are present. */
  errorKeys: string[]
  /** Comparable value (stringified) to know whether it changed. */
  read: (form: ArticleForm) => unknown
  write: (patch: ArticleUpdate, form: ArticleForm, clean: (html: string) => string) => void
}

const nullIfEmpty = (value: string) => value.trim() || null

function localeGroups(locale: FormLocale): FieldGroup[] {
  const en = locale === 'en'
  const l = (form: ArticleForm) => form[locale]
  const body = (f: LocaleFields, clean: (html: string) => string) =>
    en && isEmptyDoc(f.body.json)
      ? { json: null, html: null }
      : isEmptyDoc(f.body.json)
        ? { json: EMPTY_DOC as unknown as Database['guide']['Tables']['articles']['Row']['body_json_es'], html: '' }
        : { json: f.body.json as unknown as Database['guide']['Tables']['articles']['Row']['body_json_es'], html: clean(f.body.html) }
  const groups: FieldGroup[] = [
    en
      ? {
          key: 'en.titleSlug',
          errorKeys: ['en.title', 'en.slug'],
          read: (f) => [f.en.title.trim(), f.en.slug],
          write: (p, f) => {
            const empty = !f.en.title.trim() && !f.en.slug
            p.title_en = empty ? null : f.en.title.trim()
            p.slug_en = empty ? null : f.en.slug
          },
        }
      : {
          key: 'es.title',
          errorKeys: ['es.title'],
          read: (f) => f.es.title.trim(),
          write: (p, f) => void (p.title_es = f.es.title.trim()),
        },
    {
      key: `${locale}.excerpt`,
      errorKeys: [`${locale}.excerpt`],
      read: (f) => l(f).excerpt.trim(),
      write: (p, f) => void (p[en ? 'excerpt_en' : 'excerpt_es'] = nullIfEmpty(l(f).excerpt)),
    },
    {
      key: `${locale}.seoTitle`,
      errorKeys: [`${locale}.seoTitle`],
      read: (f) => l(f).seoTitle.trim(),
      write: (p, f) => void (p[en ? 'seo_title_en' : 'seo_title_es'] = nullIfEmpty(l(f).seoTitle)),
    },
    {
      key: `${locale}.seoDescription`,
      errorKeys: [`${locale}.seoDescription`],
      read: (f) => l(f).seoDescription.trim(),
      write: (p, f) => void (p[en ? 'seo_description_en' : 'seo_description_es'] = nullIfEmpty(l(f).seoDescription)),
    },
    {
      key: `${locale}.body`,
      errorKeys: [],
      read: (f) => (isEmptyDoc(l(f).body.json) ? '' : l(f).body.html),
      write: (p, f, clean) => {
        const b = body(l(f), clean)
        if (en) {
          p.body_json_en = b.json
          p.body_html_en = b.html
        } else {
          p.body_json_es = b.json ?? undefined
          p.body_html_es = b.html ?? ''
        }
      },
    },
  ]
  if (!en) {
    groups.push({
      key: 'es.slug',
      errorKeys: ['es.slug'],
      read: (f) => f.es.slug,
      write: (p, f) => void (p.slug_es = f.es.slug),
    })
  }
  return groups
}

const GROUPS: FieldGroup[] = [
  { key: 'categoryId', errorKeys: ['categoryId'], read: (f) => f.categoryId, write: (p, f) => void (p.category_id = f.categoryId) },
  { key: 'authorId', errorKeys: [], read: (f) => f.authorId, write: (p, f) => void (p.author_id = f.authorId) },
  { key: 'isFeatured', errorKeys: [], read: (f) => f.isFeatured, write: (p, f) => void (p.is_featured = f.isFeatured) },
  { key: 'noindex', errorKeys: [], read: (f) => f.noindex, write: (p, f) => void (p.noindex = f.noindex) },
  { key: 'canonicalUrl', errorKeys: ['canonicalUrl'], read: (f) => f.canonicalUrl.trim(), write: (p, f) => void (p.canonical_url = nullIfEmpty(f.canonicalUrl)) },
  { key: 'coverMediaId', errorKeys: [], read: (f) => f.coverMediaId, write: (p, f) => void (p.cover_media_id = f.coverMediaId) },
  { key: 'ogMediaId', errorKeys: [], read: (f) => f.ogMediaId, write: (p, f) => void (p.og_media_id = f.ogMediaId) },
  ...localeGroups('es'),
  ...localeGroups('en'),
]

/** Signature of every field group; the autosave compares against the last saved one. */
export type FormSignature = Record<string, string>

export function formSignature(form: ArticleForm): FormSignature {
  return Object.fromEntries(GROUPS.map((g) => [g.key, JSON.stringify(g.read(form))]))
}

export interface ArticlePatch {
  patch: ArticleUpdate
  /** Groups included in the patch (to mark them saved). */
  saved: string[]
  /** Changed groups left out because their fields have errors. */
  blocked: string[]
}

/** Only what changed since `base` and is valid; sanitised HTML goes into the patch. */
export function buildPatch(
  form: ArticleForm,
  base: FormSignature,
  errors: ArticleErrors,
  clean: (html: string) => string,
): ArticlePatch {
  const patch: ArticleUpdate = {}
  const saved: string[] = []
  const blocked: string[] = []
  for (const group of GROUPS) {
    if (JSON.stringify(group.read(form)) === base[group.key]) continue
    if (group.errorKeys.some((key) => errors[key])) blocked.push(group.key)
    else {
      group.write(patch, form, clean)
      saved.push(group.key)
    }
  }
  return { patch, saved, blocked }
}

/** Marks as saved the groups sent in a patch, using the form as it was when the save started. */
export function markSaved(base: FormSignature, sent: FormSignature, saved: readonly string[]): FormSignature {
  const next = { ...base }
  for (const key of saved) next[key] = sent[key]!
  return next
}

/** Keys of the groups whose value differs from `base` (changed, valid or not). */
export function changedGroups(form: ArticleForm, base: FormSignature): string[] {
  return GROUPS.filter((g) => JSON.stringify(g.read(form)) !== base[g.key]).map((g) => g.key)
}

/**
 * Draft payload `article` section (D23): everything that differs from the PUBLISHED version, not just
 * what changed since the last save. A changed group with errors is not sent, but keeps whatever the
 * stored draft already had for its columns, so a half-typed invalid value never erases saved work.
 */
export function buildDraftArticle(
  form: ArticleForm,
  published: FormSignature,
  errors: ArticleErrors,
  clean: (html: string) => string,
  previous: Record<string, unknown>,
): { article: Record<string, unknown>; blocked: string[]; changed: string[] } {
  const { patch, blocked, saved } = buildPatch(form, published, errors, clean)
  const article: Record<string, unknown> = { ...patch }
  for (const key of blocked) {
    const columns: ArticleUpdate = {}
    GROUPS.find((g) => g.key === key)?.write(columns, form, (html) => html)
    for (const column of Object.keys(columns)) if (column in previous) article[column] = previous[column]
  }
  return { article, blocked, changed: [...saved, ...blocked] }
}
