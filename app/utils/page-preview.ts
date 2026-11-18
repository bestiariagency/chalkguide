import { isEmptyDoc } from '~/utils/article-editor'
import type { PageForm } from '~/utils/page-form'
import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'

/** What the preview draws: title and sanitised body of one language; `null` when that language is empty. */
export async function previewPage(form: PageForm, locale: 'es' | 'en', supabaseUrl: string): Promise<{ title: string; bodyHtml: SafeHtml } | null> {
  const f = form[locale]
  if (!f.title.trim() && isEmptyDoc(f.body.json)) return null
  // Panel only: loaded on demand so the sanitizer never lands in a public chunk (D64, F6.19 C7).
  const { sanitizeArticleHtml, EMPTY_SAFE_HTML } = await import('~~/shared/lib/sanitize/sanitize-article-html')
  return { title: f.title.trim(), bodyHtml: isEmptyDoc(f.body.json) ? EMPTY_SAFE_HTML : sanitizeArticleHtml(f.body.html, { supabaseUrl }) }
}
