import type { GymDetail } from '../../../../../app/types/gym-detail'
import type { ItemExtras } from '../../../../../app/types/item-detail'
import type { ResolerDetail } from '../../../../../app/types/resoler-detail'
import { getGymDetail } from '../../../../../app/services/gym-detail'
import { getItemExtras } from '../../../../../app/services/item-detail'
import { getResolerDetail } from '../../../../../app/services/resolers'
import { sanitizeArticleHtml } from '../../../../../shared/lib/sanitize/sanitize-article-html'

/**
 * Extras of a published item (author review, gallery, related articles; plus the gym or resoler
 * data) with the review body sanitized (D64, F6.19 C2). Shape depends on `kind`: gym → GymDetail,
 * resoler → ResolerDetail, shoe → ItemExtras.
 */
export default defineEventHandler(async (event): Promise<GymDetail | ResolerDetail | ItemExtras> => {
  const kind = contentItemKind(getRouterParam(event, 'kind'))
  const slug = contentSlug(getRouterParam(event, 'slug'))
  const locale = contentLocale(event)
  const db = guideClient(event)
  const supabaseUrl = supabasePublicUrl(event)

  const item = await readContent(async () => {
    const { data, error } = await db
      .from('items')
      .select('id, has_en')
      .eq('slug', slug)
      .eq('category', kind)
      .eq('published', true)
      .maybeSingle()
    if (error) throw new Error(error.message)
    return data
  })
  if (!item || (locale === 'en' && item.has_en !== true)) throw contentNotFound()

  const detail = await readContent(() =>
    kind === 'gym' ? getGymDetail(db, locale, item.id) : kind === 'resoler' ? getResolerDetail(db, locale, item.id) : getItemExtras(db, locale, item.id),
  )
  if (!detail) throw contentNotFound()
  return {
    ...detail,
    review: detail.review ? { ...detail.review, bodyHtml: sanitizeArticleHtml(detail.review.bodyHtml, { supabaseUrl }) } : null,
  }
})
