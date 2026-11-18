import type { PageContent } from '../../../../app/types/domain'
import { getPageByKey } from '../../../../app/services/pages'
import { sanitizeArticleHtml } from '../../../../shared/lib/sanitize/sanitize-article-html'

/** Published editorial page (about, transparency, legal) with its body sanitized (D64, F6.19 C2). */
export default defineEventHandler(async (event): Promise<PageContent> => {
  const key = contentPageKey(getRouterParam(event, 'key'))
  const locale = contentLocale(event)
  const db = guideClient(event)
  const page = await readContent(() => getPageByKey(db, locale, key))
  if (!page) throw contentNotFound()
  return { ...page, bodyHtml: sanitizeArticleHtml(page.bodyHtml, { supabaseUrl: supabasePublicUrl(event) }) }
})
