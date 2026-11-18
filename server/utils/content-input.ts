import type { H3Event } from 'h3'
import type { Locale } from '../../app/types/domain'

/** Input rules of `/api/content/*` (F6.19 C4): closed lists and strict patterns, 400 on anything else. */
const SLUG = /^[a-z0-9-]{1,120}$/
const CONTENT_PAGE_KEYS = ['about', 'transparency', 'privacy', 'cookies', 'legal_notice'] as const
const CONTENT_ITEM_KINDS = ['gym', 'resoler', 'shoe'] as const

const bad = (message: string) => createError({ statusCode: 400, statusMessage: message })

export function contentSlug(value: string | undefined): string {
  if (!value || !SLUG.test(value)) throw bad('Invalid slug')
  return value
}

export function contentPageKey(value: string | undefined): (typeof CONTENT_PAGE_KEYS)[number] {
  const key = CONTENT_PAGE_KEYS.find((k) => k === value)
  if (!key) throw bad('Invalid page key')
  return key
}

export function contentItemKind(value: string | undefined): (typeof CONTENT_ITEM_KINDS)[number] {
  const kind = CONTENT_ITEM_KINDS.find((k) => k === value)
  if (!kind) throw bad('Invalid item kind')
  return kind
}

/** `?locale=es|en` (default `es`). Any other query parameter is refused: it would only bust the shared cache. */
export function contentLocale(event: H3Event): Locale {
  const query = getQuery(event)
  for (const name of Object.keys(query)) if (name !== 'locale') throw bad('Unknown query parameter')
  const locale = query.locale
  if (locale === undefined || locale === 'es') return 'es'
  if (locale === 'en') return 'en'
  throw bad('Invalid locale')
}

export const contentNotFound = () => createError({ statusCode: 404, statusMessage: 'Not Found' })

/** Supabase hiccups become a generic 502 (no internals in the response). */
export async function readContent<T>(read: () => Promise<T>): Promise<T> {
  try {
    return await read()
  } catch (error) {
    console.error('[content]', error instanceof Error ? error.message : error)
    throw createError({ statusCode: 502, statusMessage: 'Content unavailable' })
  }
}
