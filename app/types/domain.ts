import type { Locale } from '~/services/client'
import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'

export type { Locale }

export interface MediaRef {
  path: string
  alt: string | null
  width: number | null
  height: number | null
  /** Photo credit (media.credit), when the file needs one. */
  credit?: string | null
  /** `#rrggbb` computed at upload (media.dominant_color); validate before using it in CSS. */
  dominantColor?: string | null
}

export interface CategoryRef {
  slug: string
  /** Spanish slug in every locale: the `pillar` of the analytics events (D69). */
  slugEs?: string
  name: string
}

export interface ArticleSummary {
  id: string
  slug: string
  /** Slug per locale, for useSetI18nParams and the language switcher (D3). */
  slugs: Partial<Record<Locale, string>>
  title: string
  excerpt: string | null
  category: CategoryRef | null
  cover: MediaRef | null
  publishedAt: string | null
  updatedAt: string
  readingMinutes: number | null
  isFeatured: boolean
  hasEn: boolean
}

export interface Article extends ArticleSummary {
  categoryId: string
  /** Own author (guide.authors); null = the site author (site_settings.author_*). */
  author: AuthorProfile | null
  /** Editorial HTML, sanitized by the server (`/api/content/*`) or by the panel preview. */
  bodyHtml: SafeHtml
  seoTitle: string | null
  seoDescription: string | null
  noindex: boolean
}

/** A DTO as the services read it, before the server sanitizes its `bodyHtml` (D64). */
export type RawBody<T extends { bodyHtml: string }> = Omit<T, 'bodyHtml'> & { bodyHtml: string }

export interface ArticleCategory {
  id: string
  slug: string
  slugs: Partial<Record<Locale, string>>
  name: string
  description: string | null
  hasEn: boolean
}

/** Item (gym, resoler, shoe) linked from an article through guide.article_items. */
export interface ArticleItemRef {
  id: string
  slug: string
  name: string
  kind: 'gym' | 'resoler' | 'shoe'
  summary: string | null
  cover: MediaRef | null
  visitType: VisitType | null
  isAffiliate: boolean
}

export interface CategoryNavItem {
  slug: string
  name: string
  count: number
}

export type VisitType = 'paid' | 'invited'

export interface ItemBase {
  id: string
  slug: string
  name: string
  summary: string | null
  cover: MediaRef | null
  isFeatured: boolean
  verifiedAt: string | null
  hasEn: boolean
  /** Editor-set SEO overrides (guide.items.seo_*) and the `noindex` flag. */
  seoTitle: string | null
  seoDescription: string | null
  noindex: boolean
  updatedAt: string
  /** Author review (null if none): its visit type is always shown (transparency). */
  visitType: VisitType | null
  /** Overall author score 1–5 from guide.item_author_scores. */
  authorScore: number | null
}

export interface GymSummary extends ItemBase {
  district: string | null
  metroStations: string[]
  hasLead: boolean | null
  hasBoulder: boolean | null
  hasKidsArea: boolean | null
  belayTestRequired: boolean | null
  /** Earliest opening time of the week in minutes since 00:00 (null: no schedule). */
  opensAtMinutes: number | null
  priceMonthly: number | null
  /** Tallest wall in metres (gyms.max_height_m). */
  maxHeightM: number | null
  pricesVerifiedAt: string | null
  /** From guide.gym_indices (never recomputed in the client). */
  monthlyCost2pw: number | null
  priceIndex: number | null
  beginnerIndex: number | null
  familyIndex: number | null
  /** Single day entry (guide.gyms.price_day_eur). */
  priceDay: number | null
  /** Author's score in the `variety` criterion (null without review). */
  variety: number | null
  /** 1 (generous) to 5 (hard) against the Barcelona average. A description, not a score. */
  gradingDifficulty: number | null
  /** 1 (very technical) to 5 (very dynamic). A description, not a score. */
  settingDynamism: number | null
}

export interface ShoeSummary extends ItemBase {
  brand: string
  model: string
  fit: 'unisex' | 'women' | 'men' | 'kids' | null
  profile: 'flat' | 'moderate' | 'aggressive' | null
  asymmetry: 'none' | 'slight' | 'moderate' | 'strong' | null
  closure: 'lace' | 'velcro' | 'slipper' | null
  rubber: string | null
  rubberThicknessMm: number | null
  /** 1 (soft) to 5 (stiff). */
  stiffness: number | null
  recommendedUse: string[]
  priceMin: number | null
  priceMax: number | null
  priceCheckedAt: string | null
  levels: string[]
  isAffiliate: boolean
  affiliateUrl: string | null
  /** Shop or programme named on the affiliate button ("Deporvillage"). */
  affiliateProgram: string | null
  ownedByAuthor: boolean
  /** Author's shoe size (EU) in this model; only if he owns it. */
  authorSizeEu: number | null
  /** Author's street shoe size (EU), the reference for the difference. */
  authorStreetSizeEu: number | null
  /** Free-text fitting note ("Justos pero sin dolor…"), only with sizes. */
  authorSizeNote: string | null
  /** Short author verdict ("Lo que aprendí"), only if the author owns the model. */
  authorHeadline: string | null
  /** Latest edit among item, shoe detail and author review (ISO). */
  editedAt: string
  /** Author scores per criterion (only models the author has used). */
  criteria: AuthorScore[]
}

export type ResolerService =
  | 'half_sole'
  | 'full_sole'
  | 'rand'
  | 'toe_patch'
  | 'closure_repair'
  | 'stitching'
  | 'other'

export interface ResolerSummary extends ItemBase {
  district: string | null
  pricePerPair: number | null
  /** Extra charge for rebuilding the rand. */
  priceRand: number | null
  turnaroundMin: number | null
  turnaroundMax: number | null
  acceptsMail: boolean | null
  mailNotes: string | null
  rubberBrands: string[]
  /** Known services only (see RESOLER_SERVICES), in canonical order. */
  services: ResolerService[]
  pricesVerifiedAt: string | null
}

export interface AuthorScore {
  criterionKey: string
  name: string
  score: number
}

export interface UserRatings {
  reviewCount: number
  /** null when there are fewer than site_settings.min_user_reviews_for_average reviews. */
  avgOverall: number | null
  /** Average per criterion key; empty while avgOverall is null. */
  byCriterion: Record<string, number>
}

/** Approved photo of a reader's review; `path` is relative to the public `review-photos` bucket. */
export interface ReviewPhoto {
  id: string
  path: string
  width: number
  height: number
}

export interface UserReview {
  id: string
  authorName: string
  /** Global score 1–5 given by the reader. */
  overall: number
  body: string | null
  locale: Locale
  createdAt: string
  editedAt: string | null
  photos: ReviewPhoto[]
}

export type EventType = 'competition' | 'workshop' | 'outing' | 'social' | 'course' | 'other'

export interface GuideEvent {
  id: string
  title: string
  description: string | null
  type: EventType
  startsAt: string
  endsAt: string | null
  allDay: boolean
  place: string | null
  gymSlug: string | null
  /** Cover of the gym's page (D49); null: typographic date poster. */
  cover: MediaRef | null
  /** The gym page exists in English (false: link to the Spanish one under /en). */
  gymHasEn: boolean
  url: string | null
  priceText: string | null
  /** Called off by the organizer: it stays on the site, marked. */
  cancelled: boolean
}

export interface PageContent {
  key: string
  slug: string
  title: string
  bodyHtml: SafeHtml
  hasEn: boolean
  seoTitle: string | null
  seoDescription: string | null
  noindex: boolean
  /** `YYYY-MM-DD` shown as "Última actualización" (legal pages only; null when unset). */
  revisedOn: string | null
  /** Own share image (about / transparency); null = the default one. */
  ogImage: MediaRef | null
}

/** A figure of "En números" written by the author (site_settings.author_stats). */
export interface AuthorStat {
  value: string
  label: string
}

/** Author data of site_settings (D51). Every field can be missing: blocks without data are not drawn. */
export interface AuthorProfile {
  name: string | null
  role: string | null
  lede: string | null
  bio: string | null
  photo: MediaRef | null
  stats: AuthorStat[]
}

/** Items counted and listed in "Sobre mí" (always published ones). */
export interface AboutCheckedItem {
  name: string
  slug: string
  category: 'gym' | 'resoler' | 'shoe'
  verifiedAt: string
  hasEn: boolean
  cover: MediaRef | null
  authorScore: number | null
}

export interface AboutNumbers {
  gyms: number
  shoes: number
  latest: AboutCheckedItem[]
}

export interface SiteSettings {
  author: AuthorProfile
  tagline: string | null
  contactEmail: string | null
  socialLinks: Record<string, string>
  newsletterTitle: string | null
  newsletterBody: string | null
  newsletterConsentText: string | null
  newsletterConsentLocale: Locale
  consentVersion: number
  /** Checkbox text of the related-products consent (D66), from the DB. Null when empty: the box is hidden. */
  relatedConsentText: string | null
  relatedConsentLocale: Locale
  minUserReviewsForAverage: number
  /** Home carousel photos (site_settings.hero_photo_1/2); each can be missing. */
  heroPhotos: (MediaRef | null)[]
}
