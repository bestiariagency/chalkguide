import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'

export type Locale = Database['guide']['Enums']['locale']

/** The only schema the site reads. Services receive this typed client, never build one. */
export function guideSchema(client: SupabaseClient<Database>) {
  return client.schema('guide')
}

export type GuideClient = ReturnType<typeof guideSchema>

/** PostgREST returns an array or an object for embeds depending on the FK shape. */
export function one<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value[0] ?? null
  return value ?? null
}

/** Picks the localized column (`x_es` / `x_en`); in English there is no Spanish fallback (D3). */
export function pick<T>(locale: Locale, es: T, en: T): T {
  return locale === 'en' ? en : es
}

/** Live = published or scheduled with a past date (mirrors guide.article_is_live). */
export const nowIso = () => new Date().toISOString()

export class ServiceError extends Error {
  constructor(
    message: string,
    readonly code?: string,
    readonly detail?: string,
  ) {
    super(message)
    this.name = 'ServiceError'
  }
}

type PostgrestLike<D> = { data: D; error: { message: string; code?: string; details?: string | null } | null }

/** Throws a ServiceError so useAsyncData exposes it as `error` (pages show the error state). */
export function unwrap<D>(result: PostgrestLike<D>): NonNullable<D> {
  if (result.error) throw new ServiceError(result.error.message, result.error.code, result.error.details ?? undefined)
  return result.data as NonNullable<D>
}

/** Same as unwrap for `.maybeSingle()`: no row is `null`, not an error. */
export function unwrapMaybe<D>(result: PostgrestLike<D>): NonNullable<D> | null {
  if (result.error) throw new ServiceError(result.error.message, result.error.code, result.error.details ?? undefined)
  return (result.data ?? null) as NonNullable<D> | null
}
