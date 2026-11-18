/** A CHECK refused by the database while saving (`23514`, message `check violation: <constraint>`), mapped to form fields. */
export interface FieldCheck {
  /** Form keys involved (all of them are held back from the autosave until one changes). */
  fields: string[]
  message: string
}

/** Name of the violated CHECK, or `null` when the error is not a `check violation: <constraint>`. */
export function violatedCheck(error: unknown): string | null {
  const e = error as { code?: string; message?: string; constraint?: string } | null
  if (e?.code !== '23514') return null
  return e.constraint ?? /check violation:\s*(\S+)/i.exec(e.message ?? '')?.[1] ?? null
}

export const AFFILIATE_URL_MESSAGE = 'Enlace no válido: empieza por https://, con un dominio, sin espacios ni comillas y hasta 2048 caracteres.'

export const SHOE_DUPLICATE_MESSAGE = 'Ya existe un pie de gato con esa marca y ese modelo.'

const GENERIC = 'Este valor no cumple las reglas de la base de datos (formato, longitud o rango).'

/** Field(s) behind a CHECK of an item (`items`, `gyms`, `resolers`, `shoes`); `has` tells which ids the form really has. */
export function itemCheckFields(constraint: string, has: (id: string) => boolean): FieldCheck | null {
  if (constraint === 'resolers_turnaround_range') return { fields: ['turnaround_days_min', 'turnaround_days_max'], message: 'El plazo máximo no puede ser menor que el mínimo.' }
  if (constraint === 'resolers_services_allowed') return { fields: ['services'], message: 'Algún servicio no es válido. Desmárcalo y vuelve a marcarlo.' }
  if (constraint === 'shoes_price_range') return { fields: ['price_min_eur', 'price_max_eur'], message: 'El precio máximo no puede ser menor que el mínimo.' }
  if (constraint === 'shoes_author_sizes_owned') return { fields: ['author_size_eu', 'author_street_size_eu', 'author_size_note_es', 'author_size_note_en', 'owned_by_author'], message: 'Las tallas y las notas de ajuste solo valen si activas «Los tengo y los he usado».' }
  if (constraint === 'shoes_author_size_note_en_needs_es') return { fields: ['author_size_note_es', 'author_size_note_en'], message: 'La nota en inglés necesita la nota en español.' }
  if (constraint === 'shoes_affiliate_program_needs_url') return { fields: ['affiliate_program', 'affiliate_url'], message: 'El programa solo vale con enlace de afiliado: quita el programa o pon el enlace.' }
  if (constraint === 'shoes_price_dated') return { fields: ['price_checked_at', 'price_min_eur', 'price_max_eur'], message: 'Si hay precio, falta la fecha en que lo verificaste.' }
  if (constraint === 'shoes_brand_trimmed') return { fields: ['brand'], message: 'La marca no puede empezar ni acabar con espacios ni caracteres invisibles. Bórralos o vuelve a escribirla.' }
  if (constraint === 'shoes_model_trimmed') return { fields: ['model'], message: 'El modelo no puede empezar ni acabar con espacios ni caracteres invisibles. Bórralos o vuelve a escribirlo.' }
  if (constraint === 'shoes_brand_model_required') return { fields: ['brand', 'model'], message: 'Para publicar hacen falta la marca y el modelo.' }
  if (constraint === 'shoes_affiliate_url_check') return { fields: ['affiliate_url'], message: AFFILIATE_URL_MESSAGE }
  const size = /^shoes_(author_(?:street_)?size_eu)_range$/.exec(constraint)?.[1]
  if (size) return { fields: [size], message: 'La talla va de 30 a 50, de media en media.' }
  const note = /^shoes_(author_size_note_(?:es|en))_length$/.exec(constraint)?.[1]
  if (note) return { fields: [note], message: 'La nota va de 1 a 140 caracteres.' }
  const column = /^(?:items|gyms|resolers|shoes)_(.+)_check$/.exec(constraint)?.[1]
  return column && has(column) ? { fields: [column], message: GENERIC } : null
}

/** Field(s) behind a CHECK of an article or page: ES/EN pairs (`title_en` goes with `slug_en`) and per-column limits. */
export function articleCheckFields(constraint: string, englishTitle: string): FieldCheck | null {
  if (/^(?:articles|pages)_en_coherent$/.test(constraint)) {
    return { fields: ['en.title', 'en.slug'], message: englishTitle.trim() ? 'Falta la URL en inglés (o vacía también el título).' : 'Falta el título en inglés (o vacía también la URL).' }
  }
  const match = /^(?:articles|pages)_(title|excerpt|seo_title|seo_description)_(es|en)_check$/.exec(constraint)
  if (!match) return null
  const field = match[1] === 'seo_title' ? 'seoTitle' : match[1] === 'seo_description' ? 'seoDescription' : match[1]!
  return { fields: [`${match[2]}.${field}`], message: GENERIC }
}

/** The unique brand + model index refused the save (`23505 shoes_brand_model_key`), mapped to both fields. */
export function duplicateShoeCheck(error: unknown): FieldCheck | null {
  const e = error as { code?: string; message?: string; constraint?: string } | null
  if (e?.code !== '23505' || !/shoes_brand_model_key/.test(`${e.constraint ?? ''} ${e.message ?? ''}`)) return null
  return { fields: ['brand', 'model'], message: SHOE_DUPLICATE_MESSAGE }
}
