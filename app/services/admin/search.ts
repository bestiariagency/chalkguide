import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

export type SearchRow = Database['guide']['Functions']['admin_search']['Returns'][number]

/**
 * `guide.admin_search`: content search of the ⌘K palette (admins only). `kinds` null = every kind. Rows come already
 * ordered by group and rank. The `signal` lets the caller drop a request that a newer one has replaced.
 */
export async function searchAdminContent(client: Client, query: string, kinds: string[] | null, limit: number, signal?: AbortSignal): Promise<SearchRow[]> {
  const call = guideSchema(client).rpc('admin_search', { p_query: query, p_kinds: kinds ?? undefined, p_limit: limit })
  return unwrap(await (signal ? call.abortSignal(signal) : call))
}
