export const ADMIN_BASE = '/administrador'
export const ADMIN_LOGIN = `${ADMIN_BASE}/entrar`

/** Panel URL of a menu slug ('' = Inicio). */
export function adminPath(slug: string): string {
  return slug ? `${ADMIN_BASE}/${slug}` : ADMIN_BASE
}

/** `next` for the panel: an internal path inside /administrador (never the login page itself). */
export function adminNextPath(value: unknown): string {
  const path = safeNextPath(value, ADMIN_BASE)
  const inPanel = path === ADMIN_BASE || path.startsWith(`${ADMIN_BASE}/`) || path.startsWith(`${ADMIN_BASE}?`)
  return inPanel && !path.startsWith(ADMIN_LOGIN) ? path : ADMIN_BASE
}

export type AdminLoginFailure = 'invalid' | 'rate-limit' | 'no-access' | 'unknown'

/** Maps a Supabase Auth error to one message: never reveals whether the email exists. */
export function adminLoginFailure(error: unknown): AdminLoginFailure {
  const { code } = (error ?? {}) as { code?: string }
  if (code === 'over_request_rate_limit' || code === '429') return 'rate-limit'
  if (code === 'invalid_credentials' || code === 'user_not_found' || code === '400') return 'invalid'
  if (code === 'email_not_confirmed') return 'invalid'
  return 'unknown'
}

export const ADMIN_LOGIN_MESSAGES: Record<AdminLoginFailure, string> = {
  invalid: 'El email o la contraseña no son correctos.',
  'rate-limit': 'Demasiados intentos. Prueba de nuevo en 5 minutos.',
  'no-access': 'Esta cuenta no tiene acceso al panel. Si eres lector, tu cuenta sirve en la guía.',
  unknown: 'No se ha podido entrar. Revisa tu conexión e inténtalo de nuevo.',
}

export const ADMIN_RESET = `${ADMIN_BASE}/restablecer`
export const ADMIN_PASSWORD_MIN = 10

/** Always-neutral confirmation: never reveals whether the email has an account. */
export const ADMIN_RESET_SENT = 'Si el email tiene cuenta, te hemos enviado un enlace para elegir una contraseña nueva.'

export type AdminResetFailure = 'rate-limit' | 'unknown'

export function adminResetFailure(error: unknown): AdminResetFailure {
  const { code } = (error ?? {}) as { code?: string }
  return code === 'over_email_send_rate_limit' || code === 'over_request_rate_limit' || code === '429'
    ? 'rate-limit'
    : 'unknown'
}

/** Supabase failure while setting the new password → message + whether the link is no longer valid. */
export function adminPasswordFailure(error: unknown): { message: string; expired: boolean } {
  const { code } = (error ?? {}) as { code?: string }
  if (code === 'same_password') return { message: 'La contraseña nueva debe ser distinta de la actual.', expired: false }
  if (code === 'weak_password') return { message: 'Esa contraseña es demasiado fácil de adivinar. Elige otra más larga.', expired: false }
  if (code === 'session_expired' || code === 'session_not_found' || code === 'refresh_token_not_found' || code === '401') {
    return { message: 'El enlace ha caducado.', expired: true }
  }
  if (code === 'over_request_rate_limit' || code === '429') {
    return { message: 'Demasiados intentos. Prueba de nuevo en unos minutos.', expired: false }
  }
  return { message: 'No se ha podido cambiar la contraseña. Revisa tu conexión e inténtalo de nuevo.', expired: false }
}

/** True when the URL carries a Supabase auth error (expired or already used link). */
export function hasAuthLinkError(search: string, hash: string): boolean {
  const params = [new URLSearchParams(search), new URLSearchParams(hash.replace(/^#/, ''))]
  return params.some((p) => p.has('error') || p.has('error_code') || p.has('error_description'))
}
