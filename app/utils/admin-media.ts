/** Media row as the editor needs it (cover, OG image, body images, picker). */
export interface AdminMedia {
  id: string
  storage_path: string
  original_filename: string
  alt_es: string | null
  alt_en: string | null
  width: number | null
  height: number | null
  dominant_color: string | null
}
