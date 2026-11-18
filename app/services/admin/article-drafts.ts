import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import { ServiceError, guideSchema, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>

export interface StoredDraft {
  payload: Json
  baseUpdatedAt: string
  updatedAt: string
}

/** The draft of changes of a live article (D23), or `null` when there is none. */
export async function fetchArticleDraft(client: Client, articleId: string): Promise<StoredDraft | null> {
  const row = unwrapMaybe(
    await guideSchema(client).from('content_drafts').select('payload, base_updated_at, updated_at').eq('entity', 'article').eq('article_id', articleId).maybeSingle(),
  )
  return row ? { payload: row.payload, baseUpdatedAt: row.base_updated_at, updatedAt: row.updated_at } : null
}

/** Replaces the draft payload. `base` is the published version the draft was started from. */
export async function saveArticleDraft(client: Client, articleId: string, article: Record<string, unknown>, base: string): Promise<StoredDraft> {
  const rows = unwrap(
    await guideSchema(client).rpc('save_draft', {
      p_entity: 'article',
      p_entity_id: articleId,
      p_payload: { article } as Json,
      p_base_updated_at: base,
    }),
  )
  if (!rows[0]) throw new ServiceError('No se ha podido guardar el borrador de cambios.')
  return { payload: { article } as Json, baseUpdatedAt: rows[0].base_updated_at, updatedAt: rows[0].updated_at }
}

/** Applies the draft to the published article; returns its new version. `force` skips the conflict check (PT409). */
export async function publishArticleDraft(client: Client, articleId: string, force = false): Promise<string> {
  return unwrap(await guideSchema(client).rpc('publish_draft', { p_entity: 'article', p_entity_id: articleId, p_force: force }))
}

/** Deletes the draft; returns whether there was one. */
export async function discardArticleDraft(client: Client, articleId: string): Promise<boolean> {
  return unwrap(await guideSchema(client).rpc('discard_draft', { p_entity: 'article', p_entity_id: articleId }))
}
