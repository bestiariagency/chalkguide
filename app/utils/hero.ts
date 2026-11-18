import type { ArticleSummary, GuideEvent, GymSummary, ShoeSummary } from '~/types/domain'

/**
 * `sizes` for the card image (the image is 118% of the card): ~87vw on phones, ~54vw from 600px (JS
 * card = 46vw), ~25vw on the desktop ring (21vw). Numeric keys are viewport widths, so the
 * srcset only has useful candidates (no 1w/2w).
 */
export const HERO_IMAGE_SIZES = '390:88vw 560:88vw 600:55vw 900:25vw 1440:25vw'

/** Rounded copies stacked behind each card (their edge is the card's thickness). */
export const HERO_PLIES = 18

/** The 2 most recently edited shoes that have a cover (newest first). */
export function pickHeroShoes(shoes: ShoeSummary[]): ShoeSummary[] {
  return pickLatestShoes(
    shoes.filter((shoe) => shoe.cover),
    2,
  )
}

/**
 * The 2 most recently edited gyms with a cover; equal dates break by name so the order is stable.
 * A gym whose cover is the carousel article's is skipped (same photo side by side): the next one takes its place.
 */
export function pickHeroGyms(gyms: GymSummary[], articleCoverPath?: string | null): GymSummary[] {
  return gyms
    .filter((gym) => gym.cover && (!articleCoverPath || gym.cover.path !== articleCoverPath))
    .sort(
      (a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt) || a.name.localeCompare(b.name),
    )
    .slice(0, 2)
}

/** First upcoming event that is not called off (the list arrives sorted by start). */
export const pickHeroEvent = (events: GuideEvent[]): GuideEvent | null =>
  events.find((event) => !event.cancelled) ?? null

/**
 * Latest article for the carousel; the blog section gets the next ones, featured first,
 * so the carousel article is never repeated there. `articles` arrives newest first.
 */
export function splitHomeArticles(articles: ArticleSummary[]) {
  const [latest = null, ...rest] = articles
  const featured = rest.filter((article) => article.isFeatured)
  const others = rest.filter((article) => !article.isFeatured)
  return { latest, blog: [...featured, ...others].slice(0, 3) }
}

/** "Escalar en" / "Barcelona": the last word drops to its own line on narrow screens. */
export function splitHeroTitle(title: string): [string, string] {
  const at = title.lastIndexOf(' ')
  return at < 0 ? [title, ''] : [title.slice(0, at), title.slice(at + 1)]
}

/** First sentence of a note ("Talla 1 más. Ajusta bien." -> "Talla 1 más."), so it fits in 2 lines. */
export function firstSentence(text: string): string {
  const trimmed = text.trim()
  return /^.+?[.!?…](?=\s|$)/s.exec(trimmed)?.[0] ?? trimmed
}

export const capitalise = (text: string): string => text.charAt(0).toUpperCase() + text.slice(1)

/** Turns the ring so it starts on the first card that is not a photo; ring order stays the same. */
export function startOffPhoto<T extends { kind: string }>(cards: T[]): T[] {
  const start = cards.findIndex((card) => card.kind !== 'photo')
  return start > 0 ? [...cards.slice(start), ...cards.slice(0, start)] : cards
}
