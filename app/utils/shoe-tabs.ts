import type { ItemTab } from '~/utils/item-tabs'

export type ShoeTabKey = 'general' | 'specs' | 'price' | 'review' | 'gallery' | 'seo'

/** Tabs of the shoe editor (docs/design/admin/pie-de-gato-editor.html). */
export const SHOE_TABS: readonly ItemTab<ShoeTabKey>[] = [
  { key: 'general', hash: 'general', label: 'General', ids: ['name', 'slug', 'summary_es', 'summary_en', 'cover_media_id', 'is_featured', 'verified_at', 'source', 'source_url'] },
  { key: 'specs', hash: 'ficha-tecnica', label: 'Ficha técnica', ids: ['brand', 'model', 'fit', 'profile', 'asymmetry', 'closure', 'rubber', 'rubber_thickness_mm', 'stiffness', 'recommended_use', 'levels'] },
  { key: 'price', hash: 'precio', label: 'Precio y afiliado', ids: ['price_min_eur', 'price_max_eur', 'price_checked_at', 'affiliate_url', 'affiliate_program'] },
  { key: 'review', hash: 'lo-que-aprendi', label: 'Lo que aprendí', ids: ['owned_by_author', 'visit_type', 'visit_date', 'author_size_eu', 'author_street_size_eu', 'author_size_note_es', 'author_size_note_en', 'disclosure_note_es', 'disclosure_note_en', 'headline_es', 'headline_en', 'body_json_es', 'body_json_en', 'scores'] },
  { key: 'gallery', hash: 'galeria', label: 'Galería', ids: ['gallery'] },
  { key: 'seo', hash: 'seo', label: 'SEO', ids: ['seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en', 'og_media_id', 'noindex'] },
]
