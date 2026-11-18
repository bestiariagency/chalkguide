import type { AboutCheckedItem, AboutNumbers, Locale } from '~/types/domain'
import { type GuideClient, one, unwrap } from './client'
import { fetchAuthorScores } from './items'
import { MEDIA_COLUMNS, toMediaRef } from './media'

const LATEST_LIMIT = 3

const isCategory = (value: string): value is AboutCheckedItem['category'] =>
  value === 'gym' || value === 'resoler' || value === 'shoe'

async function countPublished(db: GuideClient, category: 'gym' | 'shoe'): Promise<number> {
  const { count, error } = await db
    .from('items')
    .select('id', { count: 'exact', head: true })
    .eq('published', true)
    .eq('category', category)
  if (error) throw new Error(error.message)
  return count ?? 0
}

/** "En números" (calculated boxes) and "Lo último que he comprobado". Public data only. */
export async function getAboutNumbers(db: GuideClient, locale: Locale): Promise<AboutNumbers> {
  let latest = db
    .from('items')
    .select(`id, name, slug, category, verified_at, has_en, cover:media!items_cover_media_id_fkey(${MEDIA_COLUMNS})`)
    .eq('published', true)
    .not('verified_at', 'is', null)
  // Under /en a detail page without English version is a 404 (D3): do not link to it.
  if (locale === 'en') latest = latest.eq('has_en', true)
  const [gyms, shoes, rows] = await Promise.all([
    countPublished(db, 'gym'),
    countPublished(db, 'shoe'),
    latest.order('verified_at', { ascending: false }).limit(LATEST_LIMIT),
  ])
  const checked = unwrap(rows)
  const { overall } = await fetchAuthorScores(db, locale, checked.map((row) => row.id))
  return {
    gyms,
    shoes,
    latest: checked.flatMap((row) =>
      row.verified_at && isCategory(row.category)
        ? [
            {
              name: row.name,
              slug: row.slug,
              category: row.category,
              verifiedAt: row.verified_at,
              hasEn: row.has_en === true,
              cover: toMediaRef(one(row.cover as Parameters<typeof toMediaRef>[0]), locale),
              authorScore: overall.get(row.id) ?? null,
            },
          ]
        : [],
    ),
  }
}
