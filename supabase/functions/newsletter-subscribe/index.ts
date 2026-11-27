// F4.6 · Alta en la newsletter (docs/security/F4.6-brevo-spec.md §2, §5, §7.1; B6–B12; L8).
//
// verify_jwt = false. Puerta única: cabecera `x-cg-relay` = NEWSLETTER_RELAY_SECRET (solo la conoce la ruta Nitro
// POST /api/newsletter). Sin ese secreto, ALTCHA_HMAC_KEY o RATE_LIMIT_KEY (≥ 32) responde 503 y no hace nada.
//   GET  → reto ALTCHA firmado (5 min).
//   POST → honeypot, ALTCHA (modo js) o tope sin JS, IP hasheada con HMAC diario, JWT opcional validado con
//          auth.getUser y guide.svc_subscribe (solo service_role). Respuesta neutra (B8).
// Cabeceras que pone Nitro: x-cg-client-ip (IP real de Netlify; la del cliente se ignora), x-cg-mode: js|nojs y,
// con sesión, x-cg-user-jwt. No registra cuerpo, email, IP, JWT ni cabeceras.
import { createChallenge, verifySolution } from '../_shared/newsletter/altcha.ts'
import {
  empty,
  envInt,
  hmacHex,
  json,
  logEvent,
  readBody,
  safeEqual,
  serviceClient,
  strongSecret,
} from '../_shared/newsletter/http.ts'

const SOURCES = new Set([
  'footer',
  'article',
  'article_mid',
  'article_end',
  'item_page',
  'home',
  'popup',
  'newsletter_page',
  'noticias',
])
const IP_RE = /^[0-9A-Fa-f:.]{2,64}$/

Deno.serve(async (req) => {
  const relay = strongSecret('NEWSLETTER_RELAY_SECRET')
  const altchaKey = strongSecret('ALTCHA_HMAC_KEY')
  const rateKey = strongSecret('RATE_LIMIT_KEY')
  if (!relay || !altchaKey || !rateKey) return empty(503)
  if (!safeEqual(req.headers.get('x-cg-relay') ?? '', relay)) return empty(401)

  if (req.method === 'GET') {
    const max = envInt('ALTCHA_MAX_NUMBER', 100000)
    if (max === null || max < 1000 || max > 10_000_000) return empty(503)
    return json(await createChallenge(altchaKey, max))
  }
  if (req.method !== 'POST') return empty(405)

  const db = serviceClient()
  if (!db) return empty(503)

  const mode = req.headers.get('x-cg-mode')
  const ip = (req.headers.get('x-cg-client-ip') ?? '').trim()
  if ((mode !== 'js' && mode !== 'nojs') || !IP_RE.test(ip)) return json({ error: 'invalid' }, 400)

  const raw = await readBody(req, 4096)
  if (raw === null) return json({ error: 'invalid' }, 413)
  let b: Record<string, unknown>
  try {
    const parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error('shape')
    b = parsed as Record<string, unknown>
  } catch {
    return json({ error: 'invalid' }, 400)
  }

  // Honeypot lleno: 200 neutro sin hacer nada.
  if (typeof b.website === 'string' && b.website.trim() !== '') {
    logEvent('newsletter_subscribe', { result: 'honeypot', mode })
    return json({ ok: true })
  }

  let captchaHash: string | null = null
  if (mode === 'js') {
    captchaHash = await verifySolution(altchaKey, b.altcha)
    if (!captchaHash) {
      logEvent('newsletter_subscribe', { result: 'captcha', mode })
      return json({ error: 'captcha' }, 400)
    }
  }

  const email = typeof b.email === 'string' ? b.email.slice(0, 320) : ''
  const locale = b.locale === 'en' ? 'en' : 'es'
  const source = typeof b.source === 'string' && SOURCES.has(b.source) ? b.source : ''
  const page = typeof b.page === 'string' ? b.page.slice(0, 600) : null
  const consent = b.consent === true || b.consent === 'on' || b.consent === 'true'
  const related =
    b.related_consent === true || b.related_consent === 'on' || b.related_consent === 'true'

  // B12: el user_id solo sale de un JWT válido; la RPC exige además que el email coincida (H3).
  let userId: string | null = null
  const jwt = req.headers.get('x-cg-user-jwt')
  if (jwt && jwt.length < 4096) {
    const { data, error } = await db.auth.getUser(jwt)
    if (!error && data?.user?.id) userId = data.user.id
  }

  const day = new Date().toISOString().slice(0, 10)
  const ipHash = await hmacHex(rateKey, `${day}|${ip}`)

  const { data, error } = await db.rpc('svc_subscribe', {
    p_email: email,
    p_locale: locale,
    p_source: source,
    p_consent: consent,
    p_page: page,
    p_related_consent: related,
    p_user_id: userId,
    p_ip_hash: ipHash,
    p_mode: mode,
    p_captcha_hash: captchaHash,
  })
  if (error) {
    logEvent('newsletter_subscribe', { result: 'rpc_error', code: error.code ?? 'unknown', mode })
    return error.code === '22023' ? json({ error: 'invalid' }, 400) : json({ error: 'server' }, 500)
  }
  logEvent('newsletter_subscribe', { result: String(data), mode })
  switch (data) {
    case 'ok':
      return json({ ok: true })
    case 'limit':
      return json({ error: 'limit' }, 429)
    case 'captcha':
      return json({ error: 'captcha' }, 400)
    default:
      return json({ error: 'invalid' }, 400)
  }
})
