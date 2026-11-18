import { blocksOf, type ChangeEntry } from '~/utils/article-changes'
import type { PageForm, PageRow } from '~/utils/page-form'
import { changedPageGroups, pageSignature } from '~/utils/page-patch'
import { blockDiff, wordDiff } from '~/utils/text-diff'

type Locale = 'es' | 'en'

/** The stored draft's `page` section laid over the published row (what the editor shows). */
export function applyDraftPage(row: PageRow, page: Record<string, unknown> | undefined): PageRow {
  return { ...row, ...(page ?? {}) } as PageRow
}

/** `payload.page` of a stored draft. */
export function draftPageOf(payload: unknown): Record<string, unknown> {
  const section = (payload as { page?: unknown } | null)?.page
  return section && typeof section === 'object' && !Array.isArray(section) ? { ...(section as Record<string, unknown>) } : {}
}

interface Meta {
  label: string
  lang?: 'ES' | 'EN'
  kind: ChangeEntry['kind']
  read?: (form: PageForm) => string
}

const text = (label: string, locale: Locale, read: (f: PageForm[Locale]) => string): Meta => ({ label, lang: locale === 'en' ? 'EN' : 'ES', kind: 'words', read: (form) => read(form[locale]) })

const META: Record<string, Meta> = {
  'es.title': text('Título', 'es', (f) => f.title.trim()),
  'en.title': text('Título', 'en', (f) => f.title.trim()),
  'es.seoTitle': text('Título SEO', 'es', (f) => f.seoTitle.trim()),
  'en.seoTitle': text('Título SEO', 'en', (f) => f.seoTitle.trim()),
  'es.seoDescription': text('Descripción SEO', 'es', (f) => f.seoDescription.trim()),
  'en.seoDescription': text('Descripción SEO', 'en', (f) => f.seoDescription.trim()),
  'es.body': { label: 'Cuerpo', lang: 'ES', kind: 'body' },
  'en.body': { label: 'Cuerpo', lang: 'EN', kind: 'body' },
  ogMediaId: { label: 'Imagen para compartir', kind: 'media' },
  noindex: { label: 'No indexar', kind: 'value', read: (f) => (f.noindex ? 'Sí' : 'No') },
}

/** Human summary of every group that differs between the published and the current form. */
export function describePageChanges(published: PageForm, current: PageForm): ChangeEntry[] {
  const entries: ChangeEntry[] = []
  for (const key of changedPageGroups(current, pageSignature(published))) {
    const meta = META[key]
    if (!meta) continue
    const entry: ChangeEntry = { key, label: meta.label, lang: meta.lang, kind: meta.kind }
    const locale: Locale = key.startsWith('en.') ? 'en' : 'es'
    if (meta.kind === 'media') entry.mediaIds = { before: published.ogMediaId, after: current.ogMediaId }
    else if (meta.kind === 'body') entry.blocks = blockDiff(blocksOf(published[locale].body.json), blocksOf(current[locale].body.json))
    else if (meta.kind === 'value') entry.values = { before: meta.read!(published), after: meta.read!(current) }
    else entry.words = wordDiff(meta.read!(published), meta.read!(current))
    entries.push(entry)
  }
  return entries
}

const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T

/** Copies the published value of one group into the form ("Revertir"). */
export function revertPageGroup(form: PageForm, published: PageForm, key: string): void {
  const [scope, field] = key.split('.') as [string, string | undefined]
  if (scope === 'es' || scope === 'en') {
    ;(form[scope] as unknown as Record<string, unknown>)[field!] = plain((published[scope] as unknown as Record<string, unknown>)[field!])
    return
  }
  ;(form as unknown as Record<string, unknown>)[key] = (published as unknown as Record<string, unknown>)[key]
}
