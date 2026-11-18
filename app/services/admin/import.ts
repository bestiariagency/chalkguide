import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import type { ImportReport } from '~/utils/admin-import-report'
import type { ItemCategory } from '~/utils/item-spec'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

/** Importer (F6.15b, D50). `apply` always follows a `dry_run` and brings its `hash`; the server checks everything again. */
export async function importItems(
  client: Client,
  category: ItemCategory,
  rows: Record<string, unknown>[],
  mode: 'dry_run' | 'apply',
  options: { hash?: string; batchId?: string } = {},
): Promise<ImportReport> {
  const result = await guideSchema(client).rpc('admin_import_items', {
    p_category: category,
    p_rows: rows as Json,
    p_mode: mode,
    ...(options.hash ? { p_hash: options.hash } : {}),
    ...(options.batchId ? { p_batch_id: options.batchId } : {}),
  })
  return unwrap(result) as unknown as ImportReport
}

export interface UndoResult {
  batch_id: string
  status: string
  results: { item_id: string; action: string; result: string }[]
}

export async function undoImportBatch(client: Client, batchId: string): Promise<UndoResult> {
  return unwrap(await guideSchema(client).rpc('undo_import_batch', { p_batch_id: batchId })) as unknown as UndoResult
}

export interface PublishResult {
  published: number
  results: { id: string; ok: boolean; published_at?: string; code?: string; blockers?: string[] }[]
}

/** Publishes 1 to 100 items; each one is judged on its own on the server (the rest go on if one fails). */
export async function publishItems(client: Client, ids: string[]): Promise<PublishResult> {
  return unwrap(await guideSchema(client).rpc('publish_items', { p_ids: ids })) as unknown as PublishResult
}

/** What each item of the category still needs to be published (column "Para publicar"; computed on the server). */
export async function fetchPublishBlockers(client: Client, category: ItemCategory): Promise<Map<string, string[]>> {
  const rows = unwrap(await guideSchema(client).rpc('admin_item_publish_blockers', { p_category: category }))
  return new Map(rows.map((row) => [row.item_id, row.blockers ?? []]))
}

export interface ImportBatchInfo {
  id: string
  status: string
  rowCount: number
  createdAt: string
}

/** Last import of the category (card "Última importación"). */
export async function fetchLastImport(client: Client, category: ItemCategory): Promise<ImportBatchInfo | null> {
  const rows = unwrap(await guideSchema(client).from('import_batches').select('id, status, row_count, created_at').eq('category', category).order('created_at', { ascending: false }).limit(1))
  const row = rows[0]
  return row ? { id: row.id, status: row.status, rowCount: row.row_count, createdAt: row.created_at } : null
}

/** Items written by the imports of today (filter "Importación de hoy" of the list) and the time of the first one. */
export async function fetchTodayImport(client: Client, category: ItemCategory): Promise<{ ids: string[]; since: string } | null> {
  const start = new Date()
  start.setHours(0, 0, 0, 0)
  const batches = unwrap(await guideSchema(client).from('import_batches').select('id, created_at').eq('category', category).gte('created_at', start.toISOString()).order('created_at'))
  if (!batches.length) return null
  const items = unwrap(await guideSchema(client).from('import_batch_items').select('item_id').in('batch_id', batches.map((b) => b.id)).is('undone_at', null))
  return { ids: [...new Set(items.map((i) => i.item_id))], since: batches[0]!.created_at }
}
