// F4.6 B7 · ALTCHA autoalojado (decisión 1 de Xavi): prueba de trabajo sin terceros ni cookies. Protocolo del widget
// `altcha` (MIT): challenge = SHA-256(salt + number), signature = HMAC-SHA256(ALTCHA_HMAC_KEY, challenge). El salt
// lleva `?expires=<unix>` (5 min). El uso único lo garantiza guide.captcha_spent (svc_subscribe).
import { hmacHex, randomHex, safeEqual, sha256Hex } from './http.ts'

const TTL_S = 300

export async function createChallenge(key: string, maxNumber: number) {
  const salt = `${randomHex(12)}?expires=${Math.floor(Date.now() / 1000) + TTL_S}`
  const rnd = new Uint32Array(1)
  crypto.getRandomValues(rnd)
  const number = (rnd[0] ?? 0) % (maxNumber + 1)
  const challenge = await sha256Hex(salt + number)
  return {
    algorithm: 'SHA-256',
    challenge,
    maxnumber: maxNumber,
    salt,
    signature: await hmacHex(key, challenge),
  }
}

/** Devuelve el SHA-256 de la firma (para captcha_spent) si la solución vale; null si no. */
export async function verifySolution(key: string, payload: unknown): Promise<string | null> {
  if (typeof payload !== 'string' || payload.length > 2000) return null
  let p: Record<string, unknown>
  try {
    p = JSON.parse(atob(payload))
  } catch {
    return null
  }
  const { algorithm, challenge, number, salt, signature } = p
  if (
    algorithm !== 'SHA-256' ||
    typeof challenge !== 'string' ||
    typeof salt !== 'string' ||
    typeof signature !== 'string'
  )
    return null
  if (typeof number !== 'number' || !Number.isInteger(number) || number < 0) return null
  if (!/^[0-9a-f]{64}$/.test(challenge) || !/^[0-9a-f]{64}$/.test(signature) || salt.length > 200)
    return null
  const expires = Number(new URLSearchParams(salt.split('?')[1] ?? '').get('expires'))
  if (
    !Number.isFinite(expires) ||
    expires * 1000 < Date.now() ||
    expires * 1000 > Date.now() + (TTL_S + 60) * 1000
  )
    return null
  if (!safeEqual(await sha256Hex(salt + number), challenge)) return null
  if (!safeEqual(await hmacHex(key, challenge), signature)) return null
  return await sha256Hex(signature)
}
