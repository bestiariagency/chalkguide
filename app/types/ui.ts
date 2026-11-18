import type { LocalizedRouteName } from '~~/i18n/localized-routes'

/** Target for NuxtLinkLocale: a localized route name (+ params) or '/'. */
export type LocaleRouteTo =
  '/' | {
      name: LocalizedRouteName
      params?: Record<string, string>
      query?: Record<string, string>
      hash?: string
    }

export interface SegmentOption<V extends string = string> {
  value: V
  label: string
  /** Shorter label shown below md (narrow segmented controls). */
  shortLabel?: string
  disabled?: boolean
}

export interface BreadcrumbItem {
  label: string
  /** Omitted for the current page (last crumb is not a link). */
  to?: LocaleRouteTo
}

export type ToastType = 'success' | 'info' | 'error'

export interface ToastItem {
  id: number
  type: ToastType
  title: string
  body?: string
}

export interface DataRow {
  label: string
  value: string | null
  /** Highlight (accent) or de-emphasize (meta) the value. */
  tone?: 'accent' | 'muted'
}

/** One card of the home hero carousel (already localised; the view only renders it). */
export interface HeroCardData {
  key: string
  kind: 'photo' | 'shoe' | 'event' | 'gym' | 'article'
  /** Gyms and articles sit on the near-black base. */
  strong: boolean
  /** Null: plain card with no link (the two photos). */
  to: LocaleRouteTo | null
  /** Announced when the card is centred. */
  label: string
  image: { src: string; width: number; height: number; alt: string } | null
  eyebrow?: string
  title?: string
  note?: string
  date?: { day: string; month: string }
}
