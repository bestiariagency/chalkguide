import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { guideSchema, unwrap, unwrapMaybe, ServiceError } from '../client'

type Client = SupabaseClient<Database>
export type StatsArgs = Database['guide']['Functions']['admin_stats']['Args']

/** Raw `guide.admin_stats` (jsonb): parsed in utils/admin-stats.ts. One call gives the whole screen. */
export async function fetchStats(client: Client, args: StatsArgs): Promise<unknown> {
  return unwrap(await guideSchema(client).rpc('admin_stats', args))
}

export interface StatsArticle {
  id: string
  title: string
  publishedAt: string
}

const toArticle = (row: { id: string; title_es: string; published_at: string | null }): StatsArticle => ({
  id: row.id,
  title: row.title_es,
  publishedAt: row.published_at ?? '',
})

/** Published articles whose date falls in [fromIso, toIso): the list under the 30-day chart. */
export async function fetchArticlesBetween(client: Client, fromIso: string, toIso: string): Promise<StatsArticle[]> {
  const rows = unwrap(
    await guideSchema(client)
      .from('articles')
      .select('id, title_es, published_at')
      .eq('status', 'published')
      .gte('published_at', fromIso)
      .lt('published_at', toIso)
      .order('published_at', { ascending: false }),
  )
  return rows.map(toArticle)
}

/** The most recent live article («Último: …» under the 12-month chart). */
export async function fetchLastArticle(client: Client): Promise<StatsArticle | null> {
  const row = unwrapMaybe(
    await guideSchema(client)
      .from('articles')
      .select('id, title_es, published_at')
      .eq('status', 'published')
      .lte('published_at', new Date().toISOString())
      .order('published_at', { ascending: false })
      .limit(1)
      .maybeSingle(),
  )
  return row ? toArticle(row) : null
}

export async function countArticleDrafts(client: Client): Promise<number> {
  const { count, error } = await guideSchema(client).from('articles').select('id', { count: 'exact', head: true }).eq('status', 'draft')
  if (error) throw new ServiceError(error.message, error.code)
  return count ?? 0
}
