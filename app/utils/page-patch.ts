import type { Database } from '~/types/database.types'
import { EMPTY_DOC, isEmptyDoc } from '~/utils/article-editor'
import type { ArticleErrors } from '~/utils/article-form'
import type { FormSignature } from '~/utils/article-patch'
import type { PageForm, PageUpdate } from '~/utils/page-form'

type Json = Database['guide']['Tables']['pages']['Row']['body_json_es']
type Locale = 'es' | 'en'

interface FieldGroup {
  key: string
  /** Error keys that keep the group out of the patch while they are present. */
  errorKeys: string[]
  read: (form: PageForm) => unknown
  write: (patch: PageUpdate, form: PageForm, clean: (html: string) => string) => void
}

const nullIfEmpty = (value: string) => value.trim() || null

function localeGroups(locale: Locale): FieldGroup[] {
  const en = locale === 'en'
  return [
    {
      key: `${locale}.title`,
      errorKeys: [`${locale}.title`],
      read: (f) => f[locale].title.trim(),
      write: (p, f) => {
        const title = f[locale].title.trim()
        if (en) p.title_en = title || null
        else p.title_es = title
      },
    },
    {
      key: `${locale}.seoTitle`,
      errorKeys: [`${locale}.seoTitle`],
      read: (f) => f[locale].seoTitle.trim(),
      write: (p, f) => void (p[en ? 'seo_title_en' : 'seo_title_es'] = nullIfEmpty(f[locale].seoTitle)),
    },
    {
      key: `${locale}.seoDescription`,
      errorKeys: [`${locale}.seoDescription`],
      read: (f) => f[locale].seoDescription.trim(),
      write: (p, f) => void (p[en ? 'seo_description_en' : 'seo_description_es'] = nullIfEmpty(f[locale].seoDescription)),
    },
    {
      key: `${locale}.body`,
      errorKeys: [],
      read: (f) => (isEmptyDoc(f[locale].body.json) ? '' : f[locale].body.html),
      write: (p, f, clean) => {
        const empty = isEmptyDoc(f[locale].body.json)
        const json = (empty ? EMPTY_DOC : f[locale].body.json) as unknown as Json
        const html = empty ? '' : clean(f[locale].body.html)
        if (en) {
          // Empty English is `null`, never an empty document (D3: it is all or nothing).
          p.body_json_en = empty ? null : json
          p.body_html_en = empty ? null : html
        } else {
          p.body_json_es = json
          p.body_html_es = html
        }
      },
    },
  ]
}

const GROUPS: FieldGroup[] = [
  { key: 'noindex', errorKeys: [], read: (f) => f.noindex, write: (p, f) => void (p.noindex = f.noindex) },
  { key: 'ogMediaId', errorKeys: [], read: (f) => f.ogMediaId, write: (p, f) => void (p.og_media_id = f.ogMediaId) },
  ...localeGroups('es'),
  ...localeGroups('en'),
]

export function pageSignature(form: PageForm): FormSignature {
  return Object.fromEntries(GROUPS.map((g) => [g.key, JSON.stringify(g.read(form))]))
}

/** Keys of the groups whose value differs from `base` (changed, valid or not). */
export function changedPageGroups(form: PageForm, base: FormSignature): string[] {
  return GROUPS.filter((g) => JSON.stringify(g.read(form)) !== base[g.key]).map((g) => g.key)
}

export interface PagePatch {
  patch: PageUpdate
  saved: string[]
  blocked: string[]
}

/** Only what changed since `base` and is valid; sanitised HTML goes into the patch. */
export function buildPagePatch(form: PageForm, base: FormSignature, errors: ArticleErrors, clean: (html: string) => string): PagePatch {
  const patch: PageUpdate = {}
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

/**
 * Draft payload `page` section (D23): every white-listed column that differs from the PUBLISHED
 * version. A changed group with errors is not sent but keeps what the stored draft already had for
 * its columns, so a half-typed invalid value never erases saved work.
 */
export function buildDraftPage(
  form: PageForm,
  published: FormSignature,
  errors: ArticleErrors,
  clean: (html: string) => string,
  previous: Record<string, unknown>,
): { page: Record<string, unknown>; blocked: string[] } {
  const { patch, blocked } = buildPagePatch(form, published, errors, clean)
  const page: Record<string, unknown> = { ...patch }
  for (const key of blocked) {
    const columns: PageUpdate = {}
    GROUPS.find((g) => g.key === key)?.write(columns, form, (html) => html)
    for (const column of Object.keys(columns)) if (column in previous) page[column] = previous[column]
  }
  return { page, blocked }
}
