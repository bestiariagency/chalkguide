import type { Locale } from '~/types/domain'
import type { AuthorReview, ItemExtras } from '~/types/item-detail'
import { listArticlesForItem } from './articles'
import { type GuideClient, one, pick, unwrap, unwrapMaybe } from './client'
import { MEDIA_COLUMNS, refreshBodyHtml, toMediaRef } from './media'

async function fetchReview(db: GuideClient, locale: Locale, itemId: string) {
  const row = unwrapMaybe(
    await db
      .from('author_reviews')
      .select(
        `headline_es, headline_en, body_html_es, body_html_en, visit_date, visit_type,
        disclosure_note_es, disclosure_note_en`,
      )
      .eq('item_id', itemId)
      .maybeSingle(),
  )
  if (!row) return null
  const review: AuthorReview<string> = {
    headline: pick(locale, row.headline_es, row.headline_en),
    bodyHtml: await refreshBodyHtml(db, pick(locale, row.body_html_es, row.body_html_en) ?? ''),
    visitDate: row.visit_date,
    visitType: row.visit_type,
    disclosureNote: pick(locale, row.disclosure_note_es, row.disclosure_note_en),
  }
  return review
}

async function fetchGallery(db: GuideClient, locale: Locale, itemId: string) {
  const rows = unwrap(
    await db
      .from('item_media')
      .select(`sort_order, media:media!item_media_media_id_fkey(${MEDIA_COLUMNS})`)
      .eq('item_id', itemId)
      .order('sort_order'),
  )
  return rows.flatMap((row) => {
    const ref = toMediaRef(one(row.media), locale)
    return ref ? [ref] : []
  })
}

/** Author review, gallery and related articles of any item: 3 independent queries in parallel. */
export async function getItemExtras(
  db: GuideClient,
  locale: Locale,
  itemId: string,
): Promise<ItemExtras<string>> {
  const [review, gallery, articles] = await Promise.all([
    fetchReview(db, locale, itemId),
    fetchGallery(db, locale, itemId),
    listArticlesForItem(db, locale, itemId),
  ])
  return { review, gallery, articles }
}
