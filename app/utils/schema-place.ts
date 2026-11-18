import { type OpeningHours, WEEKDAYS } from './opening-hours'
import { clampDescription } from './seo'
import { compactLd, personLd, type JsonLd } from './schema'

/** schema.org builders of places (gym, resoler), shoes and the author's review / readers' rating. */
const DAY_URL: Record<(typeof WEEKDAYS)[number], string> = {
  mon: 'https://schema.org/Monday',
  tue: 'https://schema.org/Tuesday',
  wed: 'https://schema.org/Wednesday',
  thu: 'https://schema.org/Thursday',
  fri: 'https://schema.org/Friday',
  sat: 'https://schema.org/Saturday',
  sun: 'https://schema.org/Sunday',
}

/** Mon–Fri with the same hours become one specification with several days. */
export function openingHoursLd(hours: OpeningHours): JsonLd[] {
  const bySlot = new Map<string, { days: string[]; opens: string; closes: string }>()
  for (const day of WEEKDAYS) {
    for (const [opens, closes] of hours[day] ?? []) {
      const key = `${opens}-${closes}`
      const entry = bySlot.get(key) ?? { days: [], opens, closes }
      entry.days.push(DAY_URL[day])
      bySlot.set(key, entry)
    }
  }
  return [...bySlot.values()].map((entry) => ({
    '@type': 'OpeningHoursSpecification',
    dayOfWeek: entry.days,
    opens: entry.opens,
    closes: entry.closes,
  }))
}

interface AuthorReviewInput {
  headline: string | null
  bodyHtml: string
}

/** Author's `Review` (Xavi). Needs the review text; the rating is added when there is a score. */
export function authorReviewLd(
  review: AuthorReviewInput | null | undefined,
  score: number | null | undefined,
  aboutUrl?: string,
): JsonLd | undefined {
  if (!review) return undefined
  const body = clampDescription(review.bodyHtml, 400)
  if (!body && !review.headline) return undefined
  return compactLd({
    '@type': 'Review',
    name: review.headline,
    reviewBody: body,
    author: personLd(aboutUrl),
    reviewRating:
      typeof score === 'number'
        ? { '@type': 'Rating', ratingValue: Number(score.toFixed(1)), bestRating: 5, worstRating: 1 }
        : undefined,
  })
}

/** Readers' average: only with the minimum number of real opinions (the view already hides it). */
export function aggregateRatingLd(
  ratings: { reviewCount: number; avgOverall: number | null } | null | undefined,
  minReviews: number,
): JsonLd | undefined {
  if (!ratings || ratings.avgOverall === null) return undefined
  if (ratings.reviewCount < Math.max(minReviews, 3)) return undefined
  return {
    '@type': 'AggregateRating',
    ratingValue: Number(ratings.avgOverall.toFixed(1)),
    reviewCount: ratings.reviewCount,
    bestRating: 5,
    worstRating: 1,
  }
}

interface PlaceInput {
  type: 'SportsActivityLocation' | 'LocalBusiness'
  url: string
  name: string
  description?: string
  image?: string
  address?: string | null
  postalCode?: string | null
  city?: string | null
  websiteUrl?: string | null
  priceRange?: string
  openingHours?: OpeningHours
  review?: JsonLd
  aggregateRating?: JsonLd
}

/** Gym (`SportsActivityLocation`, a LocalBusiness subtype) or resoler (`LocalBusiness`). */
export function placeLd(input: PlaceInput): JsonLd {
  const hasAddress = input.address || input.postalCode || input.city
  return {
    '@context': 'https://schema.org',
    ...compactLd({
      '@type': input.type,
      '@id': `${input.url}#place`,
      name: input.name,
      description: input.description,
      url: input.url,
      image: input.image,
      sameAs: input.websiteUrl ? [input.websiteUrl] : undefined,
      address: hasAddress
        ? compactLd({
            '@type': 'PostalAddress',
            streetAddress: input.address,
            postalCode: input.postalCode,
            addressLocality: input.city,
            addressCountry: 'ES',
          })
        : undefined,
      priceRange: input.priceRange,
      openingHoursSpecification: input.openingHours ? openingHoursLd(input.openingHours) : undefined,
      review: input.review,
      aggregateRating: input.aggregateRating,
    }),
  }
}

/** Shoe model: `Product` with a price range (`AggregateOffer`), no affiliate URL in the data. */
export function productLd(input: {
  url: string
  name: string
  brand: string
  description?: string
  image?: string
  priceMin: number | null
  priceMax: number | null
  review?: JsonLd
}): JsonLd {
  const { priceMin, priceMax } = input
  const low = priceMin ?? priceMax
  const high = priceMax ?? priceMin
  return {
    '@context': 'https://schema.org',
    ...compactLd({
      '@type': 'Product',
      '@id': `${input.url}#product`,
      name: input.name,
      brand: { '@type': 'Brand', name: input.brand },
      description: input.description,
      image: input.image,
      url: input.url,
      offers:
        low !== null && low !== undefined
          ? {
              '@type': 'AggregateOffer',
              priceCurrency: 'EUR',
              lowPrice: low,
              highPrice: high,
            }
          : undefined,
      review: input.review,
    }),
  }
}
