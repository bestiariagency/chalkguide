/** «En números» of the site author (`site_settings.author_stats`, README §17.2): up to 2 written figures. */
export interface StatRow {
  value: string
  label_es: string
  label_en: string
}

export interface StatPayload {
  value: string
  label_es: string
  label_en?: string
}

export const STAT_MAX_ROWS = 2
export const STAT_VALUE_MAX = 24
export const STAT_LABEL_MAX = 60
export const STATS_FIELD = 'author_stats'
export const statId = (index: number, field: keyof StatRow) => `${STATS_FIELD}.${index}.${field}`

const text = (value: unknown): string => (typeof value === 'number' ? String(value) : typeof value === 'string' ? value : '')

/** Rows of the form from the saved jsonb (anything malformed is ignored). */
export function statRowsFromJson(raw: unknown): StatRow[] {
  if (!Array.isArray(raw)) return []
  return raw.slice(0, STAT_MAX_ROWS).flatMap((entry) => {
    if (!entry || typeof entry !== 'object') return []
    const { value, label_es, label_en } = entry as Record<string, unknown>
    return [{ value: text(value), label_es: text(label_es), label_en: text(label_en) }]
  })
}

const blank = (row: StatRow) => !row.value.trim() && !row.label_es.trim() && !row.label_en.trim()

/** What is sent: empty rows dropped, texts trimmed, an empty `label_en` omitted (the database treats it as absent). */
export function statsPayload(rows: readonly StatRow[]): StatPayload[] {
  return rows.filter((row) => !blank(row)).map((row) => {
    const out: StatPayload = { value: row.value.trim(), label_es: row.label_es.trim() }
    if (row.label_en.trim()) out.label_en = row.label_en.trim()
    return out
  })
}

/** True when the rows differ from the saved jsonb once both are normalised. */
export function statsDiffer(rows: readonly StatRow[], raw: unknown): boolean {
  return JSON.stringify(statsPayload(rows)) !== JSON.stringify(statsPayload(statRowsFromJson(raw)))
}

/** Same rules as `guide.author_stats_valid`; an empty row is discarded on save, not an error. */
export function validateStats(rows: readonly StatRow[]): Record<string, string> {
  const errors: Record<string, string> = {}
  rows.forEach((row, index) => {
    if (blank(row)) return
    const value = row.value.trim()
    if (!value) errors[statId(index, 'value')] = 'Escribe la cifra.'
    else if (value.length > STAT_VALUE_MAX) errors[statId(index, 'value')] = `Máximo ${STAT_VALUE_MAX} caracteres.`
    const label = row.label_es.trim()
    if (!label) errors[statId(index, 'label_es')] = 'Escribe la etiqueta en español.'
    else if (label.length > STAT_LABEL_MAX) errors[statId(index, 'label_es')] = `Máximo ${STAT_LABEL_MAX} caracteres.`
    if (row.label_en.trim().length > STAT_LABEL_MAX) errors[statId(index, 'label_en')] = `Máximo ${STAT_LABEL_MAX} caracteres.`
  })
  return errors
}

export interface StatBox {
  value: string
  label: string
}

/** Boxes of «Sobre mí» as the site draws them: first written, calculated (> 0), second written; fewer than 2 = none. */
export function aboutBoxes(rows: readonly StatRow[], lang: 'es' | 'en', calc: { gyms: number; shoes: number } | null): StatBox[] {
  const written = statsPayload(rows).map((row) => ({ value: row.value, label: (lang === 'en' && row.label_en) || row.label_es }))
  const calculated = [
    { value: calc?.gyms ?? 0, label: lang === 'en' ? 'gyms with a profile' : 'rocódromos con ficha' },
    { value: calc?.shoes ?? 0, label: lang === 'en' ? 'climbing shoes compared' : 'pies de gato comparados' },
  ].filter((box) => box.value > 0).map((box) => ({ value: String(box.value), label: box.label }))
  const boxes = [written[0], ...calculated, written[1]].filter((box): box is StatBox => !!box)
  return boxes.length >= 2 ? boxes : []
}

/** Plain text of the saved figures (conflict view). */
export function statsSummary(raw: unknown): string {
  const rows = statsPayload(statRowsFromJson(raw))
  return rows.length ? rows.map((r) => `${r.value} ${r.label_es}`).join(' · ') : '(vacío)'
}
