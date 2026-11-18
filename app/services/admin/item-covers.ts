import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminMediaItem } from '~/utils/admin-media-library'
import { patchOf } from '~/utils/item-patch'
import type { ItemCategory } from '~/utils/item-spec'
import { fetchItemDraft, saveItemDraft } from './item-drafts'
import { saveItemChanges } from './item-editor'
import { fetchMediaPage, saveMedia } from './media'

type Client = SupabaseClient<Database>

export interface CoverAssignment {
  itemId: string
  published: boolean
  /** `updated_at` of the published item: the base of its draft. */
  version: string
  media: AdminMediaItem
  /** Alt (ES) written in Medios when the photo had none: it is valid for every item using it. */
  altEs?: string
}

/** Photos of Medios that could be the cover of this slug (`search_media` looks at name and alt). */
export async function findCoverCandidates(client: Client, slug: string): Promise<AdminMediaItem[]> {
  return (await fetchMediaPage(client, { search: slug, filter: 'all' }, 0, 12)).items
}

/** Sets the cover of an item. Published ones get it in their draft of changes (D23); the others, straight away. */
export async function assignCover(client: Client, category: ItemCategory, a: CoverAssignment): Promise<void> {
  const media = a.media
  if (a.altEs) await saveMedia(client, media.id, { alt_es: a.altEs, alt_en: media.alt_en, caption_es: media.caption_es, caption_en: media.caption_en, credit: media.credit })
  if (!a.published) {
    await saveItemChanges(client, a.itemId, category, { item: { cover_media_id: media.id } }, null)
    return
  }
  const draft = await fetchItemDraft(client, a.itemId)
  const patch = patchOf(draft?.payload ?? {})
  await saveItemDraft(client, a.itemId, { ...patch, item: { ...(patch.item ?? {}), cover_media_id: media.id } }, draft?.baseUpdatedAt ?? a.version)
}
