import type { Article } from '../../../../app/types/domain'
import { getArticleBySlug } from '../../../../app/services/articles'
import { sanitizeArticleHtml } from '../../../../shared/lib/sanitize/sanitize-article-html'

/**
 * Published article with its body already sanitized (D64, F6.19 C2). Anon-only data: cacheable by
 * `routeRules` (C5). 400 invalid input, 404 missing / draft / no English version.
 */
export default defineEventHandler(async (event): Promise<Article> => {
  const slug = contentSlug(getRouterParam(event, 'slug'))
  const locale = contentLocale(event)
  const db = guideClient(event)
  const article = await readContent(() => getArticleBySlug(db, locale, slug))
  if (!article) throw contentNotFound()
  return { ...article, bodyHtml: sanitizeArticleHtml(article.bodyHtml, { supabaseUrl: supabasePublicUrl(event) }) }
})
