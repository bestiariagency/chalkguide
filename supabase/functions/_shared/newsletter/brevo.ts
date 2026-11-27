// F4.6 · Cliente mínimo de la API v3 de Brevo. Las respuestas de Brevo nunca se registran ni se guardan (B15/B29):
// solo se traducen a un código de lista blanca.
const API = 'https://api.brevo.com/v3'
const TIMEOUT_MS = 15000

export type BrevoCode =
  'brevo_4xx' | 'brevo_404' | 'brevo_429' | 'brevo_5xx' | 'timeout' | 'network' | 'config'

export type BrevoResult<T> =
  { ok: true; status: number; data: T } | { ok: false; status: number; code: BrevoCode }

export function codeFor(status: number): BrevoCode {
  if (status === 401 || status === 403) return 'config'
  if (status === 404) return 'brevo_404'
  if (status === 429) return 'brevo_429'
  if (status >= 500) return 'brevo_5xx'
  return 'brevo_4xx'
}

export async function brevo<T = unknown>(
  apiKey: string,
  method: 'GET' | 'POST' | 'PUT' | 'DELETE',
  path: string,
  body?: unknown,
): Promise<BrevoResult<T>> {
  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS)
  try {
    const res = await fetch(API + path, {
      method,
      headers: {
        'api-key': apiKey,
        accept: 'application/json',
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: ctrl.signal,
      redirect: 'error',
    })
    const text = await res.text()
    if (!res.ok) return { ok: false, status: res.status, code: codeFor(res.status) }
    let data: unknown = null
    if (text) {
      try {
        data = JSON.parse(text)
      } catch {
        data = null
      }
    }
    return { ok: true, status: res.status, data: data as T }
  } catch (e) {
    const aborted = e instanceof DOMException && e.name === 'AbortError'
    return { ok: false, status: 0, code: aborted ? 'timeout' : 'network' }
  } finally {
    clearTimeout(timer)
  }
}

export type BrevoContact = {
  id?: number
  email?: string
  emailBlacklisted?: boolean
  listIds?: number[]
  listUnsubscribed?: number[]
}

export function listIdFor(locale: string): number | null {
  const v = (Deno.env.get(locale === 'en' ? 'BREVO_LIST_ID_EN' : 'BREVO_LIST_ID_ES') ?? '').trim()
  return /^\d{1,9}$/.test(v) && Number(v) > 0 ? Number(v) : null
}

export function getContact(apiKey: string, email: string): Promise<BrevoResult<BrevoContact>> {
  return brevo<BrevoContact>(
    apiKey,
    'GET',
    `/contacts/${encodeURIComponent(email)}?identifierType=email_id`,
  )
}

/** Todos los contactos de una lista (páginas de 500). null si falla alguna página. */
export async function listContacts(
  apiKey: string,
  listId: number,
  max = 20000,
): Promise<BrevoContact[] | null> {
  const out: BrevoContact[] = []
  for (let offset = 0; offset < max; offset += 500) {
    const r = await brevo<{ contacts?: BrevoContact[]; count?: number }>(
      apiKey,
      'GET',
      `/contacts/lists/${listId}/contacts?limit=500&offset=${offset}`,
    )
    if (!r.ok) return null
    const page = r.data?.contacts ?? []
    out.push(...page)
    if (page.length < 500) return out
  }
  return null
}
