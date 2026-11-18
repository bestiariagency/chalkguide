import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminMedia } from '~/utils/admin-media'
import { guideSchema, one, unwrap } from '../client'

type Client = SupabaseClient<Database>
export type HeroSlot = 1 | 2

type MediaEmbed = AdminMedia | AdminMedia[] | null

/** The two photo-only cards of the home hero (guide.site_settings, single row id 1). */
export async function fetchHeroPhotos(client: Client): Promise<[AdminMedia | null, AdminMedia | null]> {
  const row = unwrap(
    await guideSchema(client)
      .from('site_settings')
      // Literal on purpose: the typed client parses the select string.
      .select(`
        hero_photo_1:media!site_settings_hero_photo_1_media_id_fkey(id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color),
        hero_photo_2:media!site_settings_hero_photo_2_media_id_fkey(id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color)`)
      .eq('id', 1)
      .single(),
  )
  return [one(row.hero_photo_1 as MediaEmbed), one(row.hero_photo_2 as MediaEmbed)]
}

/** Sets (or clears with `null`) one slot. The database refuses a photo without alt text (PT422). */
export async function setHeroPhoto(client: Client, slot: HeroSlot, mediaId: string | null): Promise<void> {
  if (slot !== 1 && slot !== 2) throw new RangeError(`Invalid hero photo slot: ${String(slot)}`)
  const patch = slot === 1 ? { hero_photo_1_media_id: mediaId } : { hero_photo_2_media_id: mediaId }
  unwrap(await guideSchema(client).from('site_settings').update(patch).eq('id', 1).select('id').single())
}
