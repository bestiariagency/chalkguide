const TOKEN_PARAMS = ['t', 'token'] as const
export const CONSENT_TOKEN_STORAGE_KEY = 'cg:consent-token'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

/** The token of the unsubscribe link (UUID). Anything else is treated as "no token". */
export const isConsentToken = (value: unknown): value is string =>
  typeof value === 'string' && UUID_RE.test(value)

/** Token from `?t=` (or `?token=`, the name the unsubscribe link already uses). */
export function tokenFromSearch(search: string): string | null {
  const params = new URLSearchParams(search)
  for (const name of TOKEN_PARAMS) {
    const value = params.get(name)
    if (isConsentToken(value)) return value
  }
  return null
}

/** The URL without the token parameters (keeps path, other params and hash). */
export function urlWithoutToken(href: string): string {
  const url = new URL(href)
  for (const name of TOKEN_PARAMS) url.searchParams.delete(name)
  return `${url.pathname}${url.search}${url.hash}`
}
