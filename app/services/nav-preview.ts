import type { Locale } from '~/types/domain'
import type { NavPreviewSource } from '~/types/nav-preview'
import { startOfToday } from '~/utils/dates'
import { type GuideClient, one } from './client'
import { listArticles } from './articles'
import { listEvents } from './events'
import { type ItemRow, fetchItems, num } from './items'
import { toMediaRef } from './media'

type Detail = Record<string, unknown>

const cover = (row: ItemRow, locale: Locale) =>
  toMediaRef(one(row.cover as Parameters<typeof toMediaRef>[0]), locale)

const detailOf = (row: ItemRow): Detail => {
  const detail = one(row.detail as Detail | Detail[] | null)
  return detail ?? {}
}

const settled = <T>(result: PromiseSettledResult<T>, fallback: T): T =>
  result.status === 'fulfilled' ? result.value : fallback

/**
 * What the nav preview cards need, in parallel and each domain on its own: a failing query only
 * drops its card. Same public reads as the listings (RLS decides), nothing extra.
 * `null` when every query failed, so the caller can retry on the next hover.
 */
export async function fetchNavPreviewSource(
  db: GuideClient,
  locale: Locale,
): Promise<NavPreviewSource | null> {
  const results = await Promise.allSettled([
    fetchItems(db, 'gym', locale),
    fetchItems(db, 'shoe', locale),
    fetchItems(db, 'resoler', locale),
    listArticles(db, locale, { limit: 1 }),
    listEvents(db, locale, { from: startOfToday().toISOString(), limit: 5 }),
  ])
  if (results.every((result) => result.status === 'rejected')) return null
  const [gyms, shoes, resolers, articles, events] = results
  return {
    gyms: settled(gyms, []).map((row) => ({
      name: row.name,
      cover: cover(row, locale),
      updatedAt: row.updated_at,
      priceMonthly: num(detailOf(row).price_monthly_eur as number | null),
    })),
    shoes: settled(shoes, []).map((row) => ({
      cover: cover(row, locale),
      updatedAt: row.updated_at,
      priceMin: num(detailOf(row).price_min_eur as number | null),
      levels: (detailOf(row).levels as string[] | undefined) ?? [],
    })),
    resolers: settled(resolers, []).map((row) => ({
      pricePerPair: num(detailOf(row).price_per_pair_eur as number | null),
      turnaroundMin: (detailOf(row).turnaround_days_min as number | null) ?? null,
      turnaroundMax: (detailOf(row).turnaround_days_max as number | null) ?? null,
    })),
    article: settled(articles, [])[0] ?? null,
    events: settled(events, []),
  }
}
