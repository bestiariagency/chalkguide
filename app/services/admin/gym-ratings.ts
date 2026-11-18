import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { guideSchema, unwrapMaybe } from '../client'

/** Average opinion score of a gym (view `item_user_ratings`); `null` when it has none. */
export async function fetchUserAverage(client: SupabaseClient<Database>, itemId: string): Promise<number | null> {
  const row = unwrapMaybe(await guideSchema(client).from('item_user_ratings').select('avg_overall').eq('item_id', itemId).maybeSingle())
  return row?.avg_overall ?? null
}
