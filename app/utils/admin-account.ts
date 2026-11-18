/** "xavi@correo.com" → "x•••@•••.com": enough to recognise the account without writing it on screen. */
export function maskEmail(email: string): string {
  const at = email.lastIndexOf('@')
  if (at < 1) return '•••'
  const tld = email.slice(email.lastIndexOf('.') > at ? email.lastIndexOf('.') : email.length)
  return `${email[0]}•••@•••${tld}`
}

/** Device name from a user agent: "Chrome en Mac". Falls back to "Dispositivo desconocido". */
export function deviceName(userAgent: string | null | undefined): string {
  const ua = userAgent ?? ''
  const os = /iPhone/.test(ua) ? 'iPhone'
    : /iPad/.test(ua) ? 'iPad'
    : /Android/.test(ua) ? 'Android'
    : /Windows/.test(ua) ? 'Windows'
    : /Mac OS X|Macintosh/.test(ua) ? 'Mac'
    : /CrOS/.test(ua) ? 'Chromebook'
    : /Linux/.test(ua) ? 'Linux'
    : ''
  const browser = /Edg\//.test(ua) ? 'Edge'
    : /OPR\/|Opera/.test(ua) ? 'Opera'
    : /Firefox\/|FxiOS/.test(ua) ? 'Firefox'
    : /Chrome\/|CriOS/.test(ua) ? 'Chrome'
    : /Safari\//.test(ua) ? 'Safari'
    : ''
  if (browser && os) return `${browser} en ${os}`
  return browser || os || 'Dispositivo desconocido'
}
