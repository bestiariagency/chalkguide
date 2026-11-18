/** Normalises text into a URL slug: lowercase, no accents, hyphens, no edge/double hyphens. */
export function slugify(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/&/g, ' y ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

/** Same as `slugify` while typing: keeps a trailing hyphen so the user can type "a-b". */
export function slugifyTyping(value: string): string {
  const slug = slugify(value)
  return /[\s-]$/.test(value) && slug ? `${slug}-` : slug
}

export type CounterTone = 'ok' | 'warn' | 'over'

export interface CounterInfo {
  tone: CounterTone
  /** 0–100 for the meter. */
  percent: number
  /** Characters beyond the hard max (0 when within). */
  excess: number
}

/**
 * Counter status. `ideal` is the recommended length (green up to it, amber after); `max` is the hard
 * limit (red, and the DB CHECK blocks saving). Without `ideal`, `max` is the only threshold.
 */
export function counterInfo(length: number, max: number, ideal = max): CounterInfo {
  const tone: CounterTone = length > max ? 'over' : length > ideal ? 'warn' : 'ok'
  return { tone, percent: Math.min(100, Math.round((length / max) * 100)), excess: Math.max(0, length - max) }
}

/** SEO limits (docs/design/admin/README.md §4.2): ideal title ≤ 60 (max 70), description ≤ 155 (max 160). */
export const SEO_LIMITS = {
  title: { ideal: 60, max: 70 },
  description: { ideal: 155, max: 160 },
} as const

/** Joins the ids of the help/error/counter nodes that describe a control (aria-describedby). */
export function describedBy(...ids: (string | false | null | undefined)[]): string | undefined {
  const list = ids.filter(Boolean)
  return list.length ? list.join(' ') : undefined
}

export interface AdminOption {
  value: string
  label: string
  disabled?: boolean
}

/** A place where a piece of content is used (blocked-delete list). */
export interface AdminUsage {
  label: string
  /** Where inside the item ("Portada", "Cuerpo ES"). */
  where?: string
  href?: string
}
