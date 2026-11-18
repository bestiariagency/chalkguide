import type { LocalizedRouteName } from '~~/i18n/localized-routes'
import type { ArticleSummary, GuideEvent, MediaRef } from '~/types/domain'

/** Minimal, anon-readable data behind the desktop nav preview cards (one query per domain). */
export interface NavPreviewSource {
  gyms: { name: string; cover: MediaRef | null; updatedAt: string; priceMonthly: number | null }[]
  shoes: { cover: MediaRef | null; updatedAt: string; priceMin: number | null; levels: string[] }[]
  resolers: {
    pricePerPair: number | null
    turnaroundMin: number | null
    turnaroundMax: number | null
  }[]
  article: ArticleSummary | null
  events: GuideEvent[]
}

export type NavCardTile =
  | { kind: 'photo' | 'shoe'; src: string; width: number; height: number }
  | { kind: 'num'; text: string }
  | { kind: 'date'; day: string; month: string }

/** One preview card, keyed by the route name of the nav link it belongs to. */
export interface NavCard {
  name: LocalizedRouteName
  tile: NavCardTile
  title: string
  note: string
  /** Long titles (article, event) use the smaller size. */
  tight?: boolean
}
