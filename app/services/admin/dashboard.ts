import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ServiceError, guideSchema, one, unwrap, unwrapMaybe } from '../client'
import { PROVISIONAL_PAGES_FILTER } from './pages'

type Client = SupabaseClient<Database>

/** Raw `guide.admin_dashboard_stats()` payload (jsonb): parsed in utils/admin-dashboard.ts. */
export async function fetchDashboardStats(client: Client): Promise<unknown> {
  return unwrap(await guideSchema(client).rpc('admin_dashboard_stats'))
}

/** `guide.admin_timeseries`: dates are `YYYY-MM-DD`. */
export async function fetchTimeseries(
  client: Client,
  metric: 'subscribers_new' | 'subscribers_total' | 'articles_published' | 'user_reviews',
  from: string,
  to: string,
  bucket: 'day' | 'week' | 'month',
) {
  return unwrap(
    await guideSchema(client).rpc('admin_timeseries', { p_metric: metric, p_from: from, p_to: to, p_bucket: bucket }),
  )
}

export interface CalendarArticleRow {
  id: string
  title_es: string
  status: Database['guide']['Enums']['article_status']
  published_at: string
  category: string | null
}
export interface CalendarEventRow {
  id: string
  title_es: string
  starts_at: string
  status: Database['guide']['Enums']['event_status']
  location_text: string | null
}

/** Scheduled and published articles whose date falls in [fromIso, toIso). */
export async function fetchCalendarArticles(client: Client, fromIso: string, toIso: string): Promise<CalendarArticleRow[]> {
  const rows = unwrap(
    await guideSchema(client)
      .from('articles')
      .select('id, title_es, status, published_at, article_categories(name_es)')
      .in('status', ['scheduled', 'published'])
      .gte('published_at', fromIso)
      .lt('published_at', toIso)
      .order('published_at'),
  )
  return rows.map((row) => ({
    id: row.id,
    title_es: row.title_es,
    status: row.status,
    published_at: row.published_at as string,
    category: one(row.article_categories)?.name_es ?? null,
  }))
}

/** Agenda events (draft or approved) starting in [fromIso, toIso). */
export async function fetchCalendarEvents(client: Client, fromIso: string, toIso: string): Promise<CalendarEventRow[]> {
  return unwrap(
    await guideSchema(client)
      .from('events')
      .select('id, title_es, starts_at, status, location_text')
      .neq('status', 'rejected')
      .gte('starts_at', fromIso)
      .lt('starts_at', toIso)
      .order('starts_at'),
  )
}

export interface DraftRow {
  entity: string
  article_id: string | null
}

/** Content with unpublished changes (`guide.content_drafts`). Only ids and entity: no payloads. */
export async function fetchContentDrafts(client: Client): Promise<DraftRow[]> {
  return unwrap(await guideSchema(client).from('content_drafts').select('entity, article_id'))
}

/** The signed-in admin's own `reviews_seen_at` (read only: this screen never marks as seen). */
export async function fetchReviewsSeenAt(client: Client, userId: string): Promise<string | null> {
  const row = unwrapMaybe(
    await guideSchema(client).from('admins').select('reviews_seen_at').eq('user_id', userId).maybeSingle(),
  )
  return row?.reviews_seen_at ?? null
}

/** Reviews created after `sinceIso`. */
export async function countReviewsSince(client: Client, sinceIso: string): Promise<number> {
  const { count, error } = await guideSchema(client)
    .from('user_reviews')
    .select('id', { count: 'exact', head: true })
    .gt('created_at', sinceIso)
  if (error) throw new ServiceError(error.message, error.code)
  return count ?? 0
}

/** Pages whose text is still provisional (no RPC: same marks as the pages list). */
export async function countProvisionalPages(client: Client): Promise<number> {
  const { count, error } = await guideSchema(client).from('pages').select('key', { count: 'exact', head: true }).or(PROVISIONAL_PAGES_FILTER)
  if (error) throw new ServiceError(error.message, error.code)
  return count ?? 0
}

export interface LastPublished {
  title: string
  publishedAt: string
}

/** The most recent live article (for the empty calendar's context line). */
export async function fetchLastPublished(client: Client): Promise<LastPublished | null> {
  const row = unwrapMaybe(
    await guideSchema(client)
      .from('articles')
      .select('title_es, published_at')
      .eq('status', 'published')
      .lte('published_at', new Date().toISOString())
      .order('published_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
  )
  return row?.published_at ? { title: row.title_es, publishedAt: row.published_at } : null
}
