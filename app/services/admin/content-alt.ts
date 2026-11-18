import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>
export type AltEntity = 'article' | 'page' | 'item'
export interface ContentAltRow {
  media_id: string
  missing_alt_es: boolean
  missing_alt_en: boolean
  alt_en_required: boolean
}

/** Images of the SAVED content without alt text (rpc `content_alt_check`, D27; admin only). */
export async function fetchContentAlt(client: Client, entity: AltEntity, id: string): Promise<ContentAltRow[]> {
  return unwrap(await guideSchema(client).rpc('content_alt_check', { p_entity: entity, p_entity_id: id }))
}
