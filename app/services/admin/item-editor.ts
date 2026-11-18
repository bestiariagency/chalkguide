import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { Columns } from '~/utils/item-fields'
import type { ItemPatch } from '~/utils/item-patch'
import type { ItemCategory } from '~/utils/item-spec'
import { fetchGymIndices, type GymIndices } from './gym-editor'
import { ServiceError, guideSchema, one, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>
type Update<T extends keyof Database['guide']['Tables']> = Database['guide']['Tables'][T]['Update']

export interface ItemCriterion {
  id: string
  key: string
  name: string
  description: string | null
}
export interface ItemRelatedArticle {
  id: string
  title: string
  live: boolean
}
export interface LoadedItem {
  item: Columns & { id: string; published: boolean; published_at: string | null; updated_at: string; slug: string; name: string }
  detail: Columns
  review: (Columns & { id: string }) | null
  scores: Record<string, number>
  gallery: string[]
  criteria: ItemCriterion[]
  articles: ItemRelatedArticle[]
  indices: GymIndices | null
  reviews: number
  /** Draft version (guide.draft_entity_version): newest of item, detail and author review. */
  version: string
}

/** The version save_draft/publish_draft compare against; items.updated_at alone misses detail and review edits. */
async function fetchItemVersion(client: Client, id: string): Promise<string> {
  return unwrap(await guideSchema(client).rpc('draft_entity_version', { p_entity: 'item', p_id: id }))
}

/** The item as stored (published values, never the draft), with everything the editor shows around it. */
export async function fetchItemForEdit(client: Client, id: string, category: ItemCategory): Promise<LoadedItem | null> {
  const schema = guideSchema(client)
  const item = unwrapMaybe(await schema.from('items').select('*').eq('id', id).eq('category', category).maybeSingle())
  if (!item) return null
  const [detail, review, media, criteria, links, indices, reviews, version] = await Promise.all([
    (category === 'gym' ? schema.from('gyms') : category === 'shoe' ? schema.from('shoes') : schema.from('resolers')).select('*').eq('item_id', id).maybeSingle().then(unwrapMaybe),
    schema.from('author_reviews').select('*').eq('item_id', id).maybeSingle().then(unwrapMaybe),
    schema.from('item_media').select('media_id, sort_order').eq('item_id', id).order('sort_order').then(unwrap),
    schema.from('criteria').select('id, key, name_es, description_es').eq('category', category).eq('is_active', true).order('sort_order').then(unwrap),
    schema.from('article_items').select('articles(id, title_es, status, published_at)').eq('item_id', id).order('sort_order').then(unwrap),
    category === 'gym' ? fetchGymIndices(client, id) : Promise.resolve(null),
    schema.from('user_reviews').select('id', { count: 'exact', head: true }).eq('item_id', id).then((r) => r.count ?? 0),
    fetchItemVersion(client, id),
  ])
  const scores = review ? unwrap(await schema.from('author_review_scores').select('criterion_id, score').eq('review_id', review.id)) : []
  const now = Date.now()
  return {
    item: item as LoadedItem['item'],
    detail: (detail ?? {}) as Columns,
    review: review as LoadedItem['review'],
    scores: Object.fromEntries(scores.map((s) => [s.criterion_id, s.score])),
    gallery: media.map((m) => m.media_id),
    criteria: criteria.map((c) => ({ id: c.id, key: c.key, name: c.name_es, description: c.description_es })),
    articles: links.flatMap((l) => {
      const a = one(l.articles)
      return a ? [{ id: a.id, title: a.title_es, live: a.status !== 'draft' && !!a.published_at && Date.parse(a.published_at) <= now }] : []
    }),
    indices,
    reviews,
    version,
  }
}

async function assertNotPublished(client: Client, id: string) {
  const row = unwrap(await guideSchema(client).from('items').select('published').eq('id', id).single())
  if (row.published) throw new ServiceError('La ficha ya está publicada: se edita con borrador de cambios.', 'LIVE')
}

/** Writes the changes of an UNPUBLISHED item straight to its tables. Returns the review id (created on first use) and the new `updated_at`. */
export async function saveItemChanges(client: Client, id: string, category: ItemCategory, patch: ItemPatch, reviewId: string | null): Promise<{ reviewId: string | null; updatedAt: string }> {
  const schema = guideSchema(client)
  await assertNotPublished(client, id)
  if (patch.item) unwrap(await schema.from('items').update(patch.item as Update<'items'>).eq('id', id).eq('published', false).select('id'))
  if (patch.detail) {
    if (category === 'gym') unwrap(await schema.from('gyms').update(patch.detail as Update<'gyms'>).eq('item_id', id).select('item_id'))
    else if (category === 'shoe') unwrap(await schema.from('shoes').update(patch.detail as Update<'shoes'>).eq('item_id', id).select('item_id'))
    else unwrap(await schema.from('resolers').update(patch.detail as Update<'resolers'>).eq('item_id', id).select('item_id'))
  }
  let review = reviewId
  const wantsReview = !!patch.author_review || (patch.scores && Object.keys(patch.scores).length > 0)
  if (!review && wantsReview) {
    const created = unwrap(await schema.from('author_reviews').insert({ item_id: id, category, ...(patch.author_review ?? {}) } as never).select('id').single())
    review = created.id
  } else if (review && patch.author_review) {
    unwrap(await schema.from('author_reviews').update(patch.author_review as Update<'author_reviews'>).eq('id', review).select('id'))
  }
  if (patch.scores && review) await saveScores(client, review, category, patch.scores)
  if (patch.gallery) await saveGallery(client, id, patch.gallery)
  const row = unwrap(await schema.from('items').select('updated_at').eq('id', id).single())
  return { reviewId: review, updatedAt: row.updated_at }
}

async function saveScores(client: Client, reviewId: string, category: ItemCategory, scores: Record<string, number>) {
  const schema = guideSchema(client)
  const ids = Object.keys(scores)
  const del = schema.from('author_review_scores').delete().eq('review_id', reviewId)
  unwrap(await (ids.length ? del.not('criterion_id', 'in', `(${ids.join(',')})`) : del).select('criterion_id'))
  if (ids.length) {
    unwrap(await schema.from('author_review_scores').upsert(ids.map((criterion_id) => ({ review_id: reviewId, criterion_id, category, score: scores[criterion_id]! })), { onConflict: 'review_id,criterion_id' }).select('criterion_id'))
  }
}

/** Adds the new photos, removes the dropped ones and stores the order (rpc `reorder_item_media`). */
async function saveGallery(client: Client, id: string, ids: string[]) {
  const schema = guideSchema(client)
  const current = unwrap(await schema.from('item_media').select('media_id').eq('item_id', id)).map((m) => m.media_id)
  const removed = current.filter((m) => !ids.includes(m))
  if (removed.length) unwrap(await schema.from('item_media').delete().eq('item_id', id).in('media_id', removed).select('media_id'))
  const added = ids.filter((m) => !current.includes(m))
  if (added.length) unwrap(await schema.from('item_media').insert(added.map((media_id) => ({ item_id: id, media_id, sort_order: ids.indexOf(media_id) + 1 }))).select('media_id'))
  if (ids.length) unwrap(await schema.rpc('reorder_item_media', { p_item_id: id, p_media_ids: ids }))
}

/** Publishes an unpublished item ("Publicar"). The database stamps `published_at` the first time. */
export async function publishItem(client: Client, id: string): Promise<string> {
  const rows = unwrap(await guideSchema(client).from('items').update({ published: true }).eq('id', id).eq('published', false).select('updated_at'))
  if (!rows[0]) throw new ServiceError('La ficha ya estaba publicada.', 'LIVE')
  return rows[0].updated_at
}

/** Hides a published item (it keeps opinions and review). Atomic: the rpc applies and removes any pending draft, then hides. */
export async function hideItem(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('unpublish_item', { p_item_id: id }))
}

/** Verification columns: the item's own, or the date of the prices (`price_checked_at` in shoes). */
export type PriceStamp = 'verified_at' | 'prices_verified_at' | 'price_checked_at'

/**
 * Stamps a verification date straight on a (possibly published) item: only that column is written,
 * which the database allows on live items. Returns the item's new `updated_at`.
 */
export async function stampItemVerified(client: Client, id: string, category: ItemCategory, column: PriceStamp, date: string): Promise<string> {
  const schema = guideSchema(client)
  if (column === 'verified_at') unwrap(await schema.from('items').update({ verified_at: date }).eq('id', id).select('id'))
  else if (category === 'shoe') unwrap(await schema.from('shoes').update({ price_checked_at: date }).eq('item_id', id).select('item_id'))
  else if (category === 'gym') unwrap(await schema.from('gyms').update({ prices_verified_at: date }).eq('item_id', id).select('item_id'))
  else unwrap(await schema.from('resolers').update({ prices_verified_at: date }).eq('item_id', id).select('item_id'))
  return fetchItemVersion(client, id)
}
