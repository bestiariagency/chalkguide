import { TRI_FIELDS } from '~/utils/gym-fields'
import type { ItemTab } from '~/utils/item-tabs'

export type GymTabKey = 'general' | 'location' | 'prices' | 'facilities' | 'style' | 'review' | 'gallery' | 'related' | 'seo'

/** Tabs of the editor (docs/design/admin/rocodromo-editor.html). */
export const GYM_TABS: readonly ItemTab<GymTabKey>[] = [
  { key: 'general', hash: 'general', label: 'General', ids: ['name', 'slug', 'summary_es', 'summary_en', 'cover_media_id', 'is_featured', 'verified_at', 'source', 'source_url'] },
  { key: 'location', hash: 'ubicacion', label: 'Ubicación y horarios', ids: ['address', 'city', 'district', 'postal_code', 'lat', 'lng', 'metro_stations', 'website_url', 'instagram_url', 'phone', 'opening_hours', 'opening_hours_note_es', 'opening_hours_note_en'] },
  { key: 'prices', hash: 'precios', label: 'Precios', ids: ['price_registration_eur', 'price_day_eur', 'price_10_pass_eur', 'price_monthly_eur', 'discounts_es', 'discounts_en', 'prices_verified_at'] },
  { key: 'facilities', hash: 'instalaciones', label: 'Instalaciones', ids: ['surface_m2', 'max_height_m', 'routes_count', 'autobelays_count', 'kids_min_age', ...TRI_FIELDS.map(([id]) => id)] },
  { key: 'style', hash: 'estilo', label: 'Grados y estilo', ids: ['grading_difficulty', 'setting_dynamism'] },
  { key: 'review', hash: 'resena', label: 'Reseña y notas', ids: ['visit_type', 'visit_date', 'disclosure_note_es', 'disclosure_note_en', 'headline_es', 'headline_en', 'body_json_es', 'body_json_en', 'scores'] },
  { key: 'gallery', hash: 'galeria', label: 'Galería', ids: ['gallery'] },
  { key: 'related', hash: 'relacionados', label: 'Relacionados', ids: [] },
  { key: 'seo', hash: 'seo', label: 'SEO', ids: ['seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en', 'og_media_id', 'noindex'] },
]
