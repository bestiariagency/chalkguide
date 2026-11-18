import type { AdminMedia } from '~/utils/admin-media'

/** How the photos of Medios fit the slug of an item without cover (README §13.6, "Asignar portadas"). */
export type CoverState = 'match' | 'similar' | 'several' | 'none'

const baseName = (filename: string) => filename.replace(/\.[a-z0-9]+$/i, '').toLowerCase()

export function classifyCover<T extends AdminMedia>(slug: string, found: readonly T[]): { state: CoverState; options: T[]; choice?: T } {
  const wanted = slug.toLowerCase()
  const exact = found.filter((m) => baseName(m.original_filename) === wanted)
  if (exact.length === 1) return { state: 'match', options: exact, choice: exact[0] }
  if (exact.length > 1) return { state: 'several', options: exact }
  const similar = found.filter((m) => baseName(m.original_filename).includes(wanted) || wanted.includes(baseName(m.original_filename)))
  if (similar.length) return { state: 'similar', options: similar, choice: similar[0] }
  return { state: 'none', options: [] }
}

export const COVER_LABEL: Record<CoverState, string> = {
  match: 'Coincide',
  similar: 'Parecida, confírmala',
  several: 'Varias con este nombre',
  none: 'No está en Medios',
}
