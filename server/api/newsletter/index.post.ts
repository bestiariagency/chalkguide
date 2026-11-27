import { NEWSLETTER_SOURCES } from '../../../app/utils/newsletter'

type Outcome = 'ok' | 'invalid' | 'captcha' | 'limit' | 'server'

/**
 * Sign-up relay (F4.6 §15.2). With JS: JSON in, JSON out. Without JS: form in, 303 back to the page with
 * `#newsletter-ok|error|limit` (shown by NewsletterNotice with :target). The only client data forwarded are the body fields below, the optional
 * session token and nothing else: the IP comes from Netlify, never from the client (B11).
 */
export default defineEventHandler(async (event) => {
  guardNewsletterRequest(event, true)
  const { secret, url } = newsletterRelay(event)
  const { fields, isForm } = await readNewsletterBody(event)
  const locale = fieldLocale(fields.locale)
  const altcha = fieldText(fields.altcha, 2000)
  const source = fieldText(fields.source, 30)
  const body = {
    email: fieldText(fields.email, 320),
    locale,
    source: (NEWSLETTER_SOURCES as readonly string[]).includes(source) ? source : '',
    consent: fieldFlag(fields.consent),
    page: safeReturnPath(fields.page, locale),
    related_consent: fieldFlag(fields.related_consent),
    website: fieldText(fields.website, 200),
    altcha,
  }

  const headers: Record<string, string> = {
    'content-type': 'application/json',
    'x-cg-relay': secret,
    'x-cg-mode': altcha ? 'js' : 'nojs',
  }
  // Dev only: the Nuxt dev worker may not expose the socket address, so fall back to loopback (stripped from the build).
  const ip =
    getRequestHeader(event, 'x-nf-client-connection-ip') ??
    (import.meta.dev ? (getRequestIP(event, { xForwardedFor: true }) ?? '127.0.0.1') : undefined)
  if (ip) headers['x-cg-client-ip'] = ip
  const bearer = /^Bearer (\S{20,3500})$/.exec(getRequestHeader(event, 'authorization') ?? '')
  if (bearer?.[1] && !isForm) headers['x-cg-user-jwt'] = bearer[1]

  const res = await $fetch.raw<{ error?: string }>(url, {
    method: 'POST',
    headers,
    body,
    ignoreResponseError: true,
    timeout: 10000,
    retry: 0,
  }).catch(() => null)

  let outcome: Outcome = 'server'
  if (res?.status === 200) outcome = 'ok'
  else if (res?.status === 429) outcome = 'limit'
  else if (res?.status === 400) outcome = res._data?.error === 'captcha' ? 'captcha' : 'invalid'

  if (isForm) {
    const flag = outcome === 'ok' ? 'ok' : outcome === 'limit' ? 'limit' : 'error'
    return seeOther(event, `${body.page}#newsletter-${flag}`)
  }
  if (outcome === 'ok') return { ok: true }
  setResponseStatus(event, outcome === 'limit' ? 429 : outcome === 'server' ? 502 : 400)
  return { error: outcome }
})
