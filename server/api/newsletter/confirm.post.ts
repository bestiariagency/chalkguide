import { CONFIRM_TOKEN_RE } from '../../../app/utils/newsletter'

/**
 * Confirms the double opt-in (F4.6 §15.4). Only by POST: link scanners that open the email URL (GET)
 * confirm nobody. The token is never logged and never put in a URL except on `expired`/`error`, where the
 * page needs it to offer a retry and strips it at once (no-referrer, no-store, noindex).
 */
export default defineEventHandler(async (event) => {
  guardNewsletterRequest(event, true)
  const { fields } = await readNewsletterBody(event)
  const locale = fieldLocale(fields.locale)
  const token = fieldText(fields.t, 64)
  if (!CONFIRM_TOKEN_RE.test(token)) return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'invalid' }))

  const { data, error } = await guideClient(event).rpc('confirm_newsletter', { p_token: token })
  if (error) return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'error', t: token }))
  if (data === 'ok') return seeOther(event, newsletterPath('newsletter-confirmed', locale))
  if (data === 'expired') return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'expired', t: token }))
  return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'invalid' }))
})
