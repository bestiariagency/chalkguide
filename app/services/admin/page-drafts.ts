import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import { ServiceError, guideSchema, unwrap, unwrapMaybe } from '../client'
import type { StoredDraft } from './article-drafts'

type Client = SupabaseClient<Database>
export type PageRevision = 'today' | 'keep'

/** The draft of changes of a published page (D23, entity `page`), or `null` when there is none. */
export async function fetchPageDraft(client: Client, pageId: string): Promise<StoredDraft | null> {
  const row = unwrapMaybe(await guideSchema(client).from('content_drafts').select('payload, base_updated_at, updated_at').eq('entity', 'page').eq('page_id', pageId).maybeSingle())
  return row ? { payload: row.payload, baseUpdatedAt: row.base_updated_at, updatedAt: row.updated_at } : null
}

/** Replaces the draft payload. `base` is the published version it started from. Never carries slugs, `revised_on`, `key` or `published`. */
export async function savePageDraft(client: Client, pageId: string, page: Record<string, unknown>, base: string): Promise<StoredDraft> {
  const rows = unwrap(await guideSchema(client).rpc('save_draft', { p_entity: 'page', p_entity_id: pageId, p_payload: { page } as Json, p_base_updated_at: base }))
  if (!rows[0]) throw new ServiceError('No se ha podido guardar el borrador de cambios.')
  return { payload: { page } as Json, baseUpdatedAt: rows[0].base_updated_at, updatedAt: rows[0].updated_at }
}

/**
 * Applies the draft to the published page; returns its new version. `revision` (legal pages only):
 * `today` (default) or `keep` the previous "Última actualización"; other pages must not send it (22023).
 */
export async function publishPageDraft(client: Client, pageId: string, force = false, revision?: PageRevision): Promise<string> {
  return unwrap(await guideSchema(client).rpc('publish_draft', { p_entity: 'page', p_entity_id: pageId, p_force: force, ...(revision ? { p_revision: revision } : {}) }))
}

/** Deletes the draft; returns whether there was one. */
export async function discardPageDraft(client: Client, pageId: string): Promise<boolean> {
  return unwrap(await guideSchema(client).rpc('discard_draft', { p_entity: 'page', p_entity_id: pageId }))
}
