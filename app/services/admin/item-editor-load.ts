import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { patchOf, type ItemPatch } from '~/utils/item-patch'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemSpec } from '~/utils/item-spec'
import { fetchMediaByIds } from './article-editor'
import { fetchItemDraft } from './item-drafts'
import { fetchItemForEdit, type LoadedItem } from './item-editor'
import { takenItemSlugs } from './items'

/** The stored item with a stored draft (if the item is published) laid over it: what the editor shows. */
function shownForm<F extends ItemForm>(spec: ItemSpec<F>, loaded: LoadedItem, patch: ItemPatch): F {
  const review = loaded.review || patch.author_review ? { ...(loaded.review ?? {}), ...patch.author_review } : null
  return spec.fromRows({ item: { ...loaded.item, ...patch.item }, detail: { ...loaded.detail, ...patch.detail }, review }, patch.scores ?? loaded.scores, patch.gallery ?? loaded.gallery)
}

/** Everything the item editor needs to open: row, stored draft, form shown, taken slugs and media of the images. */
export async function loadItemForEditor<F extends ItemForm>(client: SupabaseClient<Database>, id: string, spec: ItemSpec<F>) {
  const row = await fetchItemForEdit(client, id, spec.category)
  if (!row) return { found: false as const }
  const stored = row.item.published ? await fetchItemDraft(client, id) : null
  const shown = shownForm(spec, row, patchOf(stored?.payload))
  const ids = [row.item.cover_media_id, row.item.og_media_id, ...row.gallery, shown.cover_media_id, shown.og_media_id, ...shown.gallery].filter((v): v is string => typeof v === 'string')
  const [slugs, mediaRows] = await Promise.all([takenItemSlugs(client, spec.category, id), fetchMediaByIds(client, [...new Set(ids)])])
  return { found: true as const, row, stored, shown, slugs, mediaRows }
}
