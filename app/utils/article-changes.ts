import type { JSONContent } from '@tiptap/core'
import type { Database } from '~/types/database.types'
import { changedGroups, formSignature } from '~/utils/article-patch'
import type { ArticleForm, FormLocale } from '~/utils/article-form'
import { blockDiff, wordDiff, type Block, type BlockSummary, type DiffPart } from '~/utils/text-diff'

type ArticleRow = Database['guide']['Tables']['articles']['Row']

/** One changed field of the draft against the published version, ready to show in plain language. */
export interface ChangeEntry {
  /** Group key of the form (`es.title`, `coverMediaId`…): the unit "Revertir" works on. */
  key: string
  label: string
  lang?: 'ES' | 'EN'
  kind: 'words' | 'body' | 'media' | 'value'
  words?: DiffPart[]
  blocks?: BlockSummary
  mediaIds?: { before: string | null; after: string | null }
  values?: { before: string; after: string }
}

/** The stored draft's `article` section laid over the published row (what the editor shows). */
export function applyDraftArticle(row: ArticleRow, article: Record<string, unknown> | undefined): ArticleRow {
  return { ...row, ...(article ?? {}) } as ArticleRow
}

/** `payload.article` of a stored draft (the only section articles use besides `item_ids`). */
export function draftArticleOf(payload: unknown): Record<string, unknown> {
  const section = (payload as { article?: unknown } | null)?.article
  return section && typeof section === 'object' && !Array.isArray(section) ? { ...(section as Record<string, unknown>) } : {}
}

function nodeText(node: JSONContent): string {
  if (node.type === 'image') return `[Imagen${node.attrs?.alt ? `: ${node.attrs.alt}` : ''}]`
  if (node.type === 'hardBreak') return ' '
  if (typeof node.text === 'string') return node.text
  return (node.content ?? []).map(nodeText).join(node.type?.endsWith('List') ? ' ' : '')
}

export function blocksOf(doc: JSONContent | null | undefined): Block[] {
  return (doc?.content ?? []).map((node) => ({ key: JSON.stringify(node), text: nodeText(node).trim() }))
}

const yesNo = (value: boolean) => (value ? 'Sí' : 'No')

interface Meta {
  label: string
  lang?: 'ES' | 'EN'
  kind: ChangeEntry['kind']
  read?: (form: ArticleForm) => string
}

const text = (label: string, locale: FormLocale, read: (f: ArticleForm['es']) => string): Meta => ({
  label,
  lang: locale === 'en' ? 'EN' : 'ES',
  kind: 'words',
  read: (form) => read(form[locale]),
})

const META: Record<string, Meta> = {
  'es.title': text('Título', 'es', (f) => f.title.trim()),
  'en.titleSlug': text('Título y URL', 'en', (f) => (f.title.trim() || f.slug ? `${f.title.trim()} · /${f.slug}` : '')),
  'es.slug': text('URL', 'es', (f) => `/${f.slug}`),
  'es.excerpt': text('Entradilla', 'es', (f) => f.excerpt.trim()),
  'en.excerpt': text('Entradilla', 'en', (f) => f.excerpt.trim()),
  'es.seoTitle': text('Título SEO', 'es', (f) => f.seoTitle.trim()),
  'en.seoTitle': text('Título SEO', 'en', (f) => f.seoTitle.trim()),
  'es.seoDescription': text('Descripción SEO', 'es', (f) => f.seoDescription.trim()),
  'en.seoDescription': text('Descripción SEO', 'en', (f) => f.seoDescription.trim()),
  'es.body': { label: 'Cuerpo', lang: 'ES', kind: 'body' },
  'en.body': { label: 'Cuerpo', lang: 'EN', kind: 'body' },
  coverMediaId: { label: 'Portada', kind: 'media' },
  ogMediaId: { label: 'Imagen para compartir', kind: 'media' },
  canonicalUrl: { label: 'URL canónica', kind: 'words', read: (f) => f.canonicalUrl.trim() },
  isFeatured: { label: 'Destacado en el blog', kind: 'value', read: (f) => yesNo(f.isFeatured) },
  noindex: { label: 'No indexar', kind: 'value', read: (f) => yesNo(f.noindex) },
}

/** Human summary of every group that differs between the published and the current form. */
export function describeChanges(
  published: ArticleForm,
  current: ArticleForm,
  categoryName: (id: string) => string,
  authorName: (id: string | null) => string = () => '',
): ChangeEntry[] {
  const entries: ChangeEntry[] = []
  for (const key of changedGroups(current, formSignature(published))) {
    const meta: Meta | undefined =
      key === 'categoryId' ? { label: 'Categoría', kind: 'value' } : key === 'authorId' ? { label: 'Autor', kind: 'value' } : META[key]
    if (!meta) continue
    const entry: ChangeEntry = { key, label: meta.label, lang: meta.lang, kind: meta.kind }
    const locale: FormLocale = key.startsWith('en.') ? 'en' : 'es'
    if (key === 'categoryId') entry.values = { before: categoryName(published.categoryId), after: categoryName(current.categoryId) }
    else if (key === 'authorId') entry.values = { before: authorName(published.authorId), after: authorName(current.authorId) }
    else if (meta.kind === 'media') {
      const field = key as 'coverMediaId' | 'ogMediaId'
      entry.mediaIds = { before: published[field], after: current[field] }
    } else if (meta.kind === 'body') entry.blocks = blockDiff(blocksOf(published[locale].body.json), blocksOf(current[locale].body.json))
    else if (meta.kind === 'value') entry.values = { before: meta.read!(published), after: meta.read!(current) }
    else entry.words = wordDiff(meta.read!(published), meta.read!(current))
    entries.push(entry)
  }
  return entries
}

const plain = <T>(value: T): T => JSON.parse(JSON.stringify(value)) as T

/** Copies the published value of one group into the form ("Revertir"). */
export function revertGroup(form: ArticleForm, published: ArticleForm, key: string): void {
  const [scope, field] = key.split('.') as [string, string | undefined]
  if (scope === 'es' || scope === 'en') {
    const from = published[scope] as unknown as Record<string, unknown>
    const to = form[scope] as unknown as Record<string, unknown>
    if (field === 'titleSlug') Object.assign(to, { title: from.title, slug: from.slug })
    else to[field!] = plain(from[field!])
    return
  }
  ;(form as unknown as Record<string, unknown>)[key] = (published as unknown as Record<string, unknown>)[key]
}
