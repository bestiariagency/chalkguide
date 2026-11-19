import { File, FileText, Footprints, Image, Mountain, Newspaper, Settings, UserRound, Wrench } from 'lucide-vue-next'
import type { Component } from 'lucide-vue-next'
import type { MediaUsageRow } from './admin-media-library'

const ITEM_ICONS: Record<string, Component> = { gym: Mountain, shoe: Footprints, resoler: Wrench }

/** Icon per kind of owner, aligned with the admin navigation (`admin-nav.ts`). */
export function usageIcon(row: Pick<MediaUsageRow, 'owner_table' | 'item_category'>): Component {
  if (row.owner_table === 'articles') return FileText
  if (row.owner_table === 'pages') return File
  if (row.owner_table === 'news') return Newspaper
  if (row.owner_table === 'site_settings') return Settings
  if (row.owner_table === 'authors') return UserRound
  if (row.owner_table === 'items') return ITEM_ICONS[row.item_category ?? ''] ?? Image
  return Image
}
