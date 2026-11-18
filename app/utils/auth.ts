/**
 * `next` param guard: only internal paths ("/x"), never protocol-relative ("//host") or
 * backslash tricks. Anything else falls back to the home page (no open redirect).
 */
export function safeNextPath(value: unknown, fallback = '/'): string {
  if (typeof value !== 'string') return fallback
  if (!value.startsWith('/') || value.startsWith('//') || value.includes('\\')) return fallback
  if ([...value].some((char) => char.charCodeAt(0) < 32)) return fallback
  return value
}
