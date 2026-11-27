// F4.6 · Utilidades comunes de las Edge Functions de newsletter (docs/security/F4.6-brevo-spec.md §5, L8, B29).
// Nada de lo que hay aquí registra cuerpos, emails, tokens, IP ni cabeceras.
import { createClient } from 'npm:@supabase/supabase-js@2'

const enc = new TextEncoder()

/** Comparación en tiempo constante (las longitudes distintas salen pronto: la longitud del secreto no es secreta). */
export function safeEqual(a: string, b: string): boolean {
  const ea = enc.encode(a)
  const eb = enc.encode(b)
  if (ea.length !== eb.length) return false
  let diff = 0
  for (let i = 0; i < ea.length; i++) diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0)
  return diff === 0
}

/** L8: un secreto propio vale solo con ≥ 32 caracteres; si no, la función falla cerrada. */
export function strongSecret(name: string): string | null {
  const v = Deno.env.get(name) ?? ''
  return v.length >= 32 ? v : null
}

export function env(name: string): string | null {
  const v = (Deno.env.get(name) ?? '').trim()
  return v === '' ? null : v
}

export function envInt(name: string, fallback: number | null = null): number | null {
  const v = env(name)
  if (v === null) return fallback
  return /^\d{1,9}$/.test(v) ? Number(v) : null
}

const BASE_HEADERS = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...BASE_HEADERS, 'Content-Type': 'application/json' },
  })
}

/** Respuesta sin cuerpo (401/503 de las puertas). */
export function empty(status: number): Response {
  return new Response(null, { status, headers: BASE_HEADERS })
}

/** Lee el cuerpo con tope de bytes; null si se pasa o no es UTF-8 legible. */
export async function readBody(req: Request, maxBytes: number): Promise<string | null> {
  const declared = Number(req.headers.get('content-length') ?? '0')
  if (Number.isFinite(declared) && declared > maxBytes) return null
  if (!req.body) return ''
  const reader = req.body.getReader()
  const chunks: Uint8Array[] = []
  let size = 0
  for (;;) {
    const { done, value } = await reader.read()
    if (done) break
    size += value.byteLength
    if (size > maxBytes) {
      await reader.cancel()
      return null
    }
    chunks.push(value)
  }
  const all = new Uint8Array(size)
  let off = 0
  for (const c of chunks) {
    all.set(c, off)
    off += c.byteLength
  }
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(all)
  } catch {
    return null
  }
}

function toHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, '0')).join('')
}

export async function sha256Hex(s: string): Promise<string> {
  return toHex(await crypto.subtle.digest('SHA-256', enc.encode(s)))
}

export async function hmacHex(key: string, msg: string): Promise<string> {
  const k = await crypto.subtle.importKey(
    'raw',
    enc.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return toHex(await crypto.subtle.sign('HMAC', k, enc.encode(msg)))
}

export function randomHex(bytes: number): string {
  const a = new Uint8Array(bytes)
  crypto.getRandomValues(a)
  return Array.from(a, (b) => b.toString(16).padStart(2, '0')).join('')
}

/** Cliente service_role con schema guide. Solo puede usar las svc_* (O3: sin grants de tabla). */
export function serviceClient() {
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !key) return null
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
    db: { schema: 'guide' },
  })
}

/** Lista de prueba (B27): emails en minúsculas; vacía = producción. */
export function testAllowlist(): string[] {
  return (Deno.env.get('NEWSLETTER_TEST_ALLOWLIST') ?? '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0)
}

/** Registro mínimo: evento y recuentos/códigos. Nunca PII (B29). */
export function logEvent(
  event: string,
  data: Record<string, number | string | boolean | null>,
): void {
  console.log(JSON.stringify({ event, ...data }))
}

/** SITE_URL sin barra final; https obligatorio salvo localhost (placeholder hasta el dominio). */
export function siteUrl(): string | null {
  const v = env('SITE_URL')
  if (!v) return null
  try {
    const u = new URL(v)
    const local = u.hostname === 'localhost' || u.hostname === '127.0.0.1'
    if (u.protocol !== 'https:' && !(local && u.protocol === 'http:')) return null
    if (u.search || u.hash || u.username || u.password) return null
    return u.origin + u.pathname.replace(/\/+$/, '')
  } catch {
    return null
  }
}
