import type { EventType, GuideEvent, Locale } from '~/types/domain'
import { type GuideClient, one, pick, unwrap } from './client'
import { MEDIA_COLUMNS, toMediaRef } from './media'

/**
 * Published events (approved or cancelled, which stay marked) that start before `to` and have not ended
 * before `from`: a multi-day event in progress keeps showing. In English only events with an English title (D3).
 */
export async function listEvents(
  db: GuideClient,
  locale: Locale,
  { from, to, limit = 50 }: { from: string; to?: string; limit?: number },
): Promise<GuideEvent[]> {
  let query = db
    .from('events')
    .select(
      `id, title_es, title_en, description_es, description_en, event_type, starts_at, ends_at,
      all_day, location_text, url, price_text, has_en, status, item:items!events_item_id_fkey(name, slug, has_en, cover:media!items_cover_media_id_fkey(${MEDIA_COLUMNS}), author_review:author_reviews(has_en))`,
    )
    .in('status', ['approved', 'cancelled'])
    .or(`ends_at.gte.${from},and(ends_at.is.null,starts_at.gte.${from})`)
  if (to) query = query.lt('starts_at', to)
  if (locale === 'en') query = query.eq('has_en', true)
  const rows = unwrap(await query.order('starts_at').limit(limit))
  return rows.map((row) => {
    const item = one(
      row.item as { name: string; slug: string; has_en: boolean | null; cover: unknown; author_review: { has_en: boolean | null }[] | { has_en: boolean | null } | null } | null,
    )
    const review = one(item?.author_review)
    return {
      id: row.id,
      title: pick(locale, row.title_es, row.title_en) ?? row.title_es,
      description: pick(locale, row.description_es, row.description_en),
      type: row.event_type as EventType,
      startsAt: row.starts_at,
      endsAt: row.ends_at,
      allDay: row.all_day,
      place: item?.name ?? row.location_text,
      gymSlug: item?.slug ?? null,
      // Cover inherited from the gym page (D49); null without a gym or without a photo.
      cover: toMediaRef(one(item?.cover as Parameters<typeof toMediaRef>[0]), locale),
      // D3: the gym page exists in English only if the item and its author review are translated
      gymHasEn: item?.has_en === true && (!review || review.has_en === true),
      url: row.url,
      priceText: row.price_text,
      cancelled: row.status === 'cancelled',
    }
  })
}
