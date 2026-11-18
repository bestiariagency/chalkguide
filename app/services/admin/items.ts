import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminItemRow } from '~/utils/admin-items'
import { draftChanges, patchOf } from '~/utils/item-patch'
import type { ItemCategory } from '~/utils/item-spec'
import { ServiceError, guideSchema, one, unwrap } from '../client'

type Client = SupabaseClient<Database>

/** All items of a category for the panel list (no bodies), with unpublished-change and opinion counts. */
export async function fetchAdminItems(client: Client, category: ItemCategory): Promise<AdminItemRow[]> {
  const schema = guideSchema(client)
  const [items, drafts, reviews] = await Promise.all([
    schema
      .from('items')
      .select('id, name, slug, published, published_at, is_featured, has_en, cover_media_id, verified_at, updated_at, gyms(city, district), resolers(city, district), shoes(brand)')
      .eq('category', category)
      .order('updated_at', { ascending: false })
      .then(unwrap),
    schema.from('content_drafts').select('item_id, payload').eq('entity', 'item').then(unwrap),
    schema.from('user_reviews').select('item_id').eq('category', category).then(unwrap),
  ])
  const changes = new Map(drafts.filter((d) => d.item_id).map((d) => [d.item_id!, draftChanges(d.payload)]))
  // A draft that carries `cover_media_id` (even null = cover removed) wins over the stored one, like in the editor.
  const draftCovers = new Map(drafts.filter((d) => d.item_id).flatMap((d) => {
    const item = patchOf(d.payload).item
    return item && 'cover_media_id' in item ? [[d.item_id!, item.cover_media_id] as const] : []
  }))
  const counts = new Map<string, number>()
  for (const r of reviews) counts.set(r.item_id, (counts.get(r.item_id) ?? 0) + 1)
  return items.map((row) => {
    const detail = one(row.gyms) ?? one(row.resolers)
    // Shoes have no district: the list column shows the brand instead.
    const brand = one(row.shoes)?.brand ?? null
    return {
      id: row.id,
      name: row.name,
      slug: row.slug,
      published: row.published,
      published_at: row.published_at,
      is_featured: row.is_featured,
      has_en: row.has_en === true,
      verified_at: row.verified_at,
      updated_at: row.updated_at,
      district: category === 'shoe' ? brand : (detail?.district ?? null),
      city: category === 'shoe' ? '' : (detail?.city ?? 'Barcelona'),
      has_cover: !!(draftCovers.has(row.id) ? draftCovers.get(row.id) : row.cover_media_id),
      changes: changes.get(row.id) ?? 0,
      reviews: counts.get(row.id) ?? 0,
    }
  })
}

/** Slugs of the other items of the category (the unique key is category + slug). */
export async function takenItemSlugs(client: Client, category: ItemCategory, excludeId?: string): Promise<Set<string>> {
  const rows = unwrap(await guideSchema(client).from('items').select('id, slug').eq('category', category))
  return new Set(rows.filter((r) => r.id !== excludeId).map((r) => r.slug))
}

/** Minimal unpublished item ("Sin nombre") with its detail row (rpc `create_item`; the server picks the free slug). Returns the id so the editor can open it. */
export async function createItem(client: Client, category: ItemCategory): Promise<string> {
  const rows = unwrap(await guideSchema(client).rpc('create_item', { p_category: category, p_name: 'Sin nombre', p_slug: 'sin-nombre' }))
  if (!rows[0]) throw new ServiceError('No se ha podido crear la ficha.')
  return rows[0].id
}

/** Deletes unpublished items. Items with opinions are refused by the database (23503 "item has user reviews"); published ones too (PT423). */
export async function deleteItems(client: Client, category: ItemCategory, ids: string[]): Promise<number> {
  const rows = unwrap(await guideSchema(client).from('items').delete().in('id', ids).eq('category', category).eq('published', false).select('id'))
  if (rows.length !== ids.length) throw new ServiceError('Alguna ficha está publicada y no se ha eliminado: ocúltala primero.', 'LIVE')
  return rows.length
}

/** True when another shoe already has this brand and model (rpc `shoe_model_taken`, admin only; case and outer spaces do not count). */
export async function shoeModelTaken(client: Client, brand: string, model: string, exceptId: string): Promise<boolean> {
  return unwrap(await guideSchema(client).rpc('shoe_model_taken', { p_brand: brand, p_model: model, p_except_id: exceptId }))
}
