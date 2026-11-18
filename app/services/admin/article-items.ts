import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ITEM_KINDS, type ItemKind } from '~/utils/article-embeds'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

/** Item (rocódromo, resolador, pie de gato) that can be embedded as a card in an article. */
export interface ItemChoice {
  id: string
  kind: ItemKind
  name: string
  slug: string
  summary: string | null
  published: boolean
}

/** Items by name (all of them, published or not; the picker flags the unpublished ones). */
export async function searchItems(client: Client, query: string, kind: ItemKind | null = null, limit = 20): Promise<ItemChoice[]> {
  let request = guideSchema(client)
    .from('items')
    .select('id, category, name, slug, summary_es, published')
    .in('category', kind ? [kind] : [...ITEM_KINDS])
    .order('name')
    .limit(limit)
  const term = query.trim().replace(/[%_,()]/g, ' ')
  if (term) request = request.ilike('name', `%${term}%`)
  return unwrap(await request).map((row) => ({
    id: row.id,
    kind: row.category as ItemKind,
    name: row.name,
    slug: row.slug,
    summary: row.summary_es,
    published: row.published,
  }))
}
