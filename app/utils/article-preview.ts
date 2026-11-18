import type { Article } from '~/types/domain'
import type { AdminMedia } from '~/utils/admin-media'
import { countWords, isEmptyDoc, readingMinutes } from '~/utils/article-editor'
import type { ArticleForm, FormLocale } from '~/utils/article-form'

/** The editor's current content in the public `Article` shape, for the panel preview. `null` when that language is empty. */
export async function previewArticle(
  form: ArticleForm,
  locale: FormLocale,
  ctx: { id: string; updatedAt: string; publishedAt: string | null; categoryName: string | null; authorName?: string | null; cover: AdminMedia | null; supabaseUrl: string },
): Promise<Article | null> {
  const f = form[locale]
  if (!f.title.trim() && isEmptyDoc(f.body.json)) return null
  // Panel only: the sanitizer is loaded on demand so it never lands in a public chunk (D64, F6.19 C7).
  const { sanitizeArticleHtml, EMPTY_SAFE_HTML } = await import('~~/shared/lib/sanitize/sanitize-article-html')
  const html = isEmptyDoc(f.body.json) ? EMPTY_SAFE_HTML : sanitizeArticleHtml(f.body.html, { supabaseUrl: ctx.supabaseUrl })
  const cover = ctx.cover
  return {
    id: ctx.id,
    slug: f.slug,
    slugs: {},
    title: f.title.trim(),
    excerpt: f.excerpt.trim() || null,
    category: ctx.categoryName ? { slug: '', name: ctx.categoryName } : null,
    cover: cover
      ? { path: cover.storage_path, alt: (locale === 'en' ? cover.alt_en : cover.alt_es) ?? cover.alt_es, width: cover.width, height: cover.height, dominantColor: cover.dominant_color }
      : null,
    publishedAt: ctx.publishedAt,
    updatedAt: ctx.updatedAt,
    readingMinutes: readingMinutes(countWords(html)) || null,
    isFeatured: form.isFeatured,
    hasEn: !!form.en.title.trim(),
    categoryId: form.categoryId,
    // Preview shows the chosen author's name only (role, bio and photo are not loaded).
    author: ctx.authorName ? { name: ctx.authorName, role: null, lede: null, bio: null, photo: null, stats: [] } : null,
    bodyHtml: html,
    seoTitle: f.seoTitle.trim() || null,
    seoDescription: f.seoDescription.trim() || null,
    noindex: form.noindex,
  }
}
