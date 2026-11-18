import type { ItemTab } from '~/utils/item-tabs'

export type ResolerTabKey = 'general' | 'location' | 'services' | 'review' | 'gallery' | 'related' | 'seo'

/** Tabs of the resoler editor (docs/design/admin/resolador-editor.html; "Relacionados" as in gyms). */
export const RESOLER_TABS: readonly ItemTab<ResolerTabKey>[] = [
  { key: 'general', hash: 'general', label: 'General', ids: ['name', 'slug', 'summary_es', 'summary_en', 'cover_media_id', 'is_featured', 'verified_at', 'source', 'source_url'] },
  { key: 'location', hash: 'ubicacion', label: 'Ubicación', ids: ['address', 'city', 'district', 'postal_code', 'lat', 'lng', 'website_url', 'instagram_url', 'phone'] },
  { key: 'services', hash: 'servicios', label: 'Servicios y precios', ids: ['services', 'price_per_pair_eur', 'price_rand_eur', 'turnaround_days_min', 'turnaround_days_max', 'rubber_brands', 'prices_verified_at', 'accepts_mail', 'mail_notes_es', 'mail_notes_en'] },
  { key: 'review', hash: 'resena', label: 'Reseña y notas', ids: ['visit_type', 'visit_date', 'disclosure_note_es', 'disclosure_note_en', 'headline_es', 'headline_en', 'body_json_es', 'body_json_en', 'scores'] },
  { key: 'gallery', hash: 'galeria', label: 'Galería', ids: ['gallery'] },
  { key: 'related', hash: 'relacionados', label: 'Relacionados', ids: [] },
  { key: 'seo', hash: 'seo', label: 'SEO', ids: ['seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en', 'og_media_id', 'noindex'] },
]
