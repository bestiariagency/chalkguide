import { ARTICLE_VIEWS, type ArticleView } from '~/utils/admin-articles'
import { EVENT_VIEWS, type EventFilters, type EventView } from '~/utils/admin-events'
import type { ExportInitial } from '~/utils/admin-export'
import { NEWS_VIEWS, type NewsFilters, type NewsView } from '~/utils/admin-news'
import { ITEM_VIEWS, type ItemView } from '~/utils/admin-items'
import { dayKey } from '~/utils/admin-dashboard'
import { recentSince, REVIEW_VIEWS, type ReviewView } from '~/utils/admin-reviews'
import { SUBSCRIBER_VIEWS, type SubscriberFilters, type SubscriberView } from '~/utils/admin-subscribers'

/** What each listing hands to the export modal: its tab as «Estado» and its other filters as values (README §12.2). */
const label = (list: readonly { value: string; label: string }[], value: string) => list.find((v) => v.value === value)?.label
/** Views the modal cannot reproduce (computed in the listing, no export filter): no `viewLabel`, so the description does not promise them. */
const NOT_EXPORTABLE = new Set(['changes', 'stale', 'photos', 'low'])
const viewLabelOf = (list: readonly { value: string; label: string }[], view: string) => (NOT_EXPORTABLE.has(view) ? undefined : label(list, view))

export function articlesExportInitial(view: ArticleView, categoryId: string): ExportInitial {
  const status = view === 'published' || view === 'scheduled' || view === 'draft' ? view : 'all'
  return { status, viewLabel: viewLabelOf(ARTICLE_VIEWS, view), values: { category_id: categoryId, has_en: view === 'no-en' ? 'false' : '' } }
}

export function itemsExportInitial(view: ItemView): ExportInitial {
  return { status: view === 'published' ? 'published' : view === 'draft' ? 'hidden' : 'all', viewLabel: viewLabelOf(ITEM_VIEWS, view) }
}

export function reviewsExportInitial(view: ReviewView, category: string, item: string): ExportInitial {
  const real = (v: string) => (v === 'all' ? '' : v)
  return { status: view === 'hidden' ? 'hidden' : view === 'all' ? 'all' : 'visible', viewLabel: viewLabelOf(REVIEW_VIEWS, view), values: { category: real(category), item_id: real(item), from: view === 'recent' ? dayKey(recentSince()) : '' } }
}

export function subscribersExportInitial(view: SubscriberView, f: SubscriberFilters): ExportInitial {
  return {
    status: view,
    viewLabel: label(SUBSCRIBER_VIEWS, view),
    values: { sources: f.sources.join(','), locale: f.locale, consent_version: f.versions.join(','), date_field: f.dateField, from: f.from, to: f.to },
  }
}

/** Agenda: Próximos = approved from today; Pasados = approved up to today; the rest by status. */
export function eventsExportInitial(view: EventView, f: EventFilters, today: string): ExportInitial {
  const status = { revisar: 'draft', proximos: 'approved', pasados: 'approved', descartados: 'rejected', todos: 'all' }[view]
  const from = view === 'proximos' ? today : ''
  const to = view === 'pasados' ? today : ''
  return { status, viewLabel: label(EVENT_VIEWS, view), values: { source: f.source, item_id: f.itemId, from: f.from || from, to: f.to || to } }
}

/** Noticias: the tab as «Estado»; scope and one category carry over (several categories cannot: the export takes one). */
export function newsExportInitial(view: NewsView, f: NewsFilters, categoryId: string): ExportInitial {
  const status = { revisar: 'draft', publicadas: 'published', rechazadas: 'rejected', todas: 'all' }[view]
  return { status, viewLabel: label(NEWS_VIEWS, view), values: { scopes: f.scope, category_id: categoryId } }
}
