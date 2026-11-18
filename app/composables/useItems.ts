import { isGymCriterionActive, listGyms } from '~/services/gyms'
import { type ListItemsOptions, getAuthorScores, getUserRatings } from '~/services/items'
import { listResolers } from '~/services/resolers'
import type { GymDetail } from '~/types/gym-detail'
import type { ItemExtras } from '~/types/item-detail'
import type { ResolerDetail } from '~/types/resoler-detail'
import { listShoes } from '~/services/shoes'
import { listUserReviews } from '~/services/reviews'

export function useGyms(key = 'all', options: ListItemsOptions = {}) {
  return useGuideData(`gyms:${key}`, (db, locale) => listGyms(db, locale, options))
}

/** Variety is optional for the listing: when the criterion is off, its column, sort and legend go away. */
export function useGymVarietyActive() {
  return useGuideData('gyms:variety-active', (db) => isGymCriterionActive(db, 'variety'))
}

export function useShoes(key = 'all', options: ListItemsOptions = {}) {
  return useGuideData(`shoes:${key}`, (db, locale) => listShoes(db, locale, options))
}

export function useResolers(key = 'all', options: ListItemsOptions = {}) {
  return useGuideData(`resolers:${key}`, (db, locale) => listResolers(db, locale, options))
}

/** Single item by slug (null → the page responds 404). */
export function useGym(slug: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `gym:${toValue(slug)}`,
    async (db, locale) => (await listGyms(db, locale, { slug: toValue(slug) }))[0] ?? null,
  )
}

export function useShoe(slug: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `shoe:${toValue(slug)}`,
    async (db, locale) => (await listShoes(db, locale, { slug: toValue(slug) }))[0] ?? null,
  )
}

export function useResoler(slug: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `resoler:${toValue(slug)}`,
    async (db, locale) => (await listResolers(db, locale, { slug: toValue(slug) }))[0] ?? null,
  )
}

/** Author scores, readers' ratings (≥ 3 rule applied by the view) and visible reviews. */
export function useItemReviews(itemId: MaybeRefOrGetter<string>) {
  return useGuideData(
    () => `item-reviews:${toValue(itemId)}`,
    async (db, locale) => {
      const id = toValue(itemId)
      const [author, ratings, reviews] = await Promise.all([
        getAuthorScores(db, locale, id),
        getUserRatings(db, id),
        listUserReviews(db, id),
      ])
      return { author, ratings, reviews }
    },
  )
}

/** Full gym record (prices, schedule, facilities, author review, gallery, related articles), by item slug. */
export function useGymDetail(slug: MaybeRefOrGetter<string>) {
  return useContentData<GymDetail>(() => `gym-detail:${toValue(slug)}`, () => `/api/content/item/gym/${encodeURIComponent(toValue(slug))}`)
}

/** Resoler page extras (contact, author review, gallery, related articles), by item slug. */
export function useResolerDetail(slug: MaybeRefOrGetter<string>) {
  return useContentData<ResolerDetail>(() => `resoler-detail:${toValue(slug)}`, () => `/api/content/item/resoler/${encodeURIComponent(toValue(slug))}`)
}

/** Shoe page extras (author review, gallery, related articles): the model has no table of its own beyond the summary. */
export function useShoeExtras(slug: MaybeRefOrGetter<string>) {
  return useContentData<ItemExtras>(() => `shoe-extras:${toValue(slug)}`, () => `/api/content/item/shoe/${encodeURIComponent(toValue(slug))}`)
}
