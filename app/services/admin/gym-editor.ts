import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import { guideSchema, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>

export interface GymIndices {
  beginner: number | null
  family: number | null
  price: number | null
  beginnerComplete: boolean
}

/** Stored indices of a gym (view `gym_indices`), or `null` when it has none yet. */
export async function fetchGymIndices(client: Client, id: string): Promise<GymIndices | null> {
  const indices = unwrapMaybe(await guideSchema(client).from('gym_indices').select('beginner_index, family_index, price_index, beginner_index_complete').eq('item_id', id).maybeSingle())
  return indices ? { beginner: indices.beginner_index, family: indices.family_index, price: indices.price_index, beginnerComplete: indices.beginner_index_complete === true } : null
}

export interface GymIndicesPreview extends GymIndices {
  monthlyCost: number | null
}

/** Indices computed by the database from the values given (form or draft), also for unpublished gyms (rpc `gym_indices_preview`). */
export async function previewGymIndices(client: Client, id: string, detail: Json, scores: Json): Promise<GymIndicesPreview | null> {
  const rows = unwrap(await guideSchema(client).rpc('gym_indices_preview', { p_item_id: id, p_detail: detail, p_scores: scores }))
  const r = rows[0]
  return r ? { beginner: r.beginner_index, family: r.family_index, price: r.price_index, beginnerComplete: r.beginner_index_complete === true, monthlyCost: r.monthly_cost_2pw_eur } : null
}
