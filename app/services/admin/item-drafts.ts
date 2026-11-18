import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import type { ItemPatch } from '~/utils/item-patch'
import { ServiceError, guideSchema, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>

export interface StoredItemDraft {
  payload: Json
  baseUpdatedAt: string
  updatedAt: string
}

/** The draft of changes of a live item (D23, entity `item`), or `null`. */
export async function fetchItemDraft(client: Client, itemId: string): Promise<StoredItemDraft | null> {
  const row = unwrapMaybe(await guideSchema(client).from('content_drafts').select('payload, base_updated_at, updated_at').eq('entity', 'item').eq('item_id', itemId).maybeSingle())
  return row ? { payload: row.payload, baseUpdatedAt: row.base_updated_at, updatedAt: row.updated_at } : null
}

/** Replaces the draft payload. `base` is the published version it started from. */
export async function saveItemDraft(client: Client, itemId: string, patch: ItemPatch, base: string): Promise<StoredItemDraft> {
  const rows = unwrap(await guideSchema(client).rpc('save_draft', { p_entity: 'item', p_entity_id: itemId, p_payload: patch as Json, p_base_updated_at: base }))
  if (!rows[0]) throw new ServiceError('No se ha podido guardar el borrador de cambios.')
  return { payload: patch as Json, baseUpdatedAt: rows[0].base_updated_at, updatedAt: rows[0].updated_at }
}

/** Applies the draft to the published item; returns its new version. `force` skips the conflict check (PT409). */
export async function publishItemDraft(client: Client, itemId: string, force = false): Promise<string> {
  return unwrap(await guideSchema(client).rpc('publish_draft', { p_entity: 'item', p_entity_id: itemId, p_force: force }))
}

export async function discardItemDraft(client: Client, itemId: string): Promise<boolean> {
  return unwrap(await guideSchema(client).rpc('discard_draft', { p_entity: 'item', p_entity_id: itemId }))
}
