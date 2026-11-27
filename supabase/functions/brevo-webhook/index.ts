// F4.6 · Webhook de Brevo: bajas, hard bounces, quejas y bloqueos (docs/security/F4.6-brevo-spec.md §7.5–7.6;
// B19–B21; L4, L5, L8).
//
// verify_jwt = false. Puerta (L5): `Authorization: Bearer <BREVO_WEBHOOK_SECRET>` o, si la cuenta de Brevo no deja
// configurar la cabecera, segmento secreto en la ruta `/functions/v1/brevo-webhook/<BREVO_WEBHOOK_SECRET>` (nunca en
// la query string). Comparación en tiempo constante; 401 sin cuerpo si falla; 503 si falta el secreto (≥ 32) o
// BREVO_API_KEY.
// Verificación por callback obligatoria (L5): antes de aplicar nada se pregunta a la API de Brevo.
//   Marketing (lleva camp_id): GET /v3/contacts/{email} → id real del contacto; solo se aplica si Brevo lo tiene en
//     lista negra o dado de baja de una de nuestras listas. svc_apply_brevo_event exige id + email de una fila active.
//   Transaccional (lleva message-id, email de confirmación): GET /v3/smtp/statistics/events?messageId=…&event=… debe
//     devolver el mismo evento. svc_apply_brevo_tx_event exige messageId del outbox + email (L4).
// Solo baja estados (B20). No guarda ni registra el payload (B21): solo recuentos.
import { brevo, getContact, listIdFor } from '../_shared/newsletter/brevo.ts'
import {
  empty,
  env,
  json,
  logEvent,
  readBody,
  safeEqual,
  serviceClient,
  strongSecret,
} from '../_shared/newsletter/http.ts'

type Ev = Record<string, unknown>
type Kind = 'unsubscribed' | 'hardBounce' | 'spam' | 'blocked'

const KIND: Record<string, Kind> = {
  unsubscribe: 'unsubscribed',
  unsubscribed: 'unsubscribed',
  hard_bounce: 'hardBounce',
  hardbounce: 'hardBounce',
  hardBounce: 'hardBounce',
  spam: 'spam',
  complaint: 'spam',
  blocked: 'blocked',
  invalid_email: 'blocked',
  invalid: 'blocked',
}
// Nombre del evento en /smtp/statistics/events
const TX_EVENT: Record<Kind, string> = {
  hardBounce: 'hardBounces',
  spam: 'spam',
  blocked: 'blocked',
  unsubscribed: 'unsubscribed',
}
const EMAIL_RE = /^[^@\s]{1,64}@[^@\s]{1,190}\.[^@\s]{1,63}$/

function authorized(req: Request, secret: string): boolean {
  const auth = req.headers.get('authorization') ?? ''
  if (auth.startsWith('Bearer ') && safeEqual(auth.slice(7).trim(), secret)) return true
  const seg = new URL(req.url).pathname.split('/').filter(Boolean).pop() ?? ''
  return safeEqual(seg, secret)
}

function eventDate(ev: Ev): string | null {
  for (const k of ['date_event', 'date', 'ts_event', 'ts']) {
    const v = ev[k]
    if (typeof v === 'number' && Number.isFinite(v)) return new Date(v * 1000).toISOString()
    if (typeof v === 'string' && v.length <= 40) {
      const d = new Date(v.replace(' ', 'T'))
      if (!Number.isNaN(d.getTime())) return d.toISOString()
    }
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return empty(405)
  const secret = strongSecret('BREVO_WEBHOOK_SECRET')
  const apiKey = env('BREVO_API_KEY')
  const db = serviceClient()
  if (!secret || !apiKey || !db) return empty(503)
  if (!authorized(req, secret)) return empty(401)

  const raw = await readBody(req, 65536)
  if (raw === null) return empty(413)
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    return empty(400)
  }
  const events = (Array.isArray(parsed) ? parsed : [parsed])
    .slice(0, 50)
    .filter((e): e is Ev => !!e && typeof e === 'object')
  const ourLists = [listIdFor('es'), listIdFor('en')].filter((x): x is number => x !== null)
  const counts = { applied: 0, ignored: 0, unverified: 0, error: 0 }

  for (const ev of events) {
    const kind = KIND[String(ev.event ?? '')]
    const email = typeof ev.email === 'string' ? ev.email.trim().toLowerCase() : ''
    if (!kind || !EMAIL_RE.test(email)) {
      counts.ignored++
      continue
    }
    const messageId =
      typeof ev['message-id'] === 'string'
        ? ev['message-id']
        : typeof ev.messageId === 'string'
          ? ev.messageId
          : null
    const marketing = ev.camp_id !== undefined && ev.camp_id !== null

    if (!marketing && messageId && messageId.length <= 200) {
      if (kind === 'unsubscribed') {
        counts.ignored++
        continue
      } // el email de confirmación no lleva baja
      const q = `/smtp/statistics/events?limit=10&days=30&messageId=${encodeURIComponent(messageId)}&email=${encodeURIComponent(email)}&event=${TX_EVENT[kind]}`
      const r = await brevo<{ events?: Array<{ messageId?: string; email?: string }> }>(
        apiKey,
        'GET',
        q,
      )
      const ok =
        r.ok &&
        (r.data?.events ?? []).some(
          (e) => e.messageId === messageId && (e.email ?? '').toLowerCase() === email,
        )
      if (!ok) {
        counts.unverified++
        continue
      }
      const { data, error } = await db.rpc('svc_apply_brevo_tx_event', {
        p_event: kind,
        p_message_id: messageId,
        p_email: email,
      })
      if (error) counts.error++
      else if (data === 'applied') counts.applied++
      else counts.ignored++
      continue
    }

    const c = await getContact(apiKey, email)
    if (!c.ok || typeof c.data?.id !== 'number' || (c.data.email ?? '').toLowerCase() !== email) {
      counts.unverified++
      continue
    }
    const blacklisted = c.data.emailBlacklisted === true
    const listUnsub = (c.data.listUnsubscribed ?? []).some((id) => ourLists.includes(id))
    const confirmed = kind === 'unsubscribed' ? blacklisted || listUnsub : blacklisted
    if (!confirmed) {
      counts.unverified++
      continue
    }
    const { data, error } = await db.rpc('svc_apply_brevo_event', {
      p_event: kind,
      p_contact_id: c.data.id,
      p_email: email,
      p_event_at: eventDate(ev),
    })
    if (error) counts.error++
    else if (data === 'applied') counts.applied++
    else counts.ignored++
  }

  logEvent('brevo_webhook', counts)
  // Un fallo de BD → 500 para que Brevo reintente (las RPC son idempotentes). Lo ignorado o no verificado → 200: un
  // reintento no lo arreglaría.
  if (counts.error > 0) return empty(500)
  return json({ ok: true })
})
