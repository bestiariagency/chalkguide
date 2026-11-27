import { CONFIRM_TOKEN_RE } from '../../../app/utils/newsletter'

/** Resends the confirmation, once per sign-up (F4.6 §15.5). The reply is neutral: `resent` in every valid case. */
export default defineEventHandler(async (event) => {
  guardNewsletterRequest(event, true)
  const { fields } = await readNewsletterBody(event)
  const locale = fieldLocale(fields.locale)
  const token = fieldText(fields.t, 64)
  if (!CONFIRM_TOKEN_RE.test(token)) return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'invalid' }))

  const { data, error } = await guideClient(event).rpc('request_confirm_resend', { p_token: token })
  if (error) return seeOther(event, newsletterPath('newsletter-confirm', locale, { status: 'error', t: token }))
  const status = data === 'invalid' ? 'invalid' : 'resent'
  return seeOther(event, newsletterPath('newsletter-confirm', locale, { status }))
})
