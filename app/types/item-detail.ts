import type { ArticleSummary, MediaRef, VisitType } from '~/types/domain'
import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'

/** Author review in full (the summary only carries the visit type). */
/** `H` is `SafeHtml` for everything the pages see; services (server-side) hand over the raw `string`. */
export interface AuthorReview<H extends string = SafeHtml> {
  headline: string | null
  /** Editorial HTML sanitized by `/api/content/item/*` (the only HTML rendered with v-html, via `UiProse`). */
  bodyHtml: H
  visitDate: string | null
  visitType: VisitType
  disclosureNote: string | null
}

/** What every item page (gym, resoler, shoe) loads beyond the summary. */
export interface ItemExtras<H extends string = SafeHtml> {
  review: AuthorReview<H> | null
  gallery: MediaRef[]
  articles: ArticleSummary[]
}
