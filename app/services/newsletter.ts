import type { Locale } from '~/types/domain'
import { type GuideClient, ServiceError } from './client'

export type NewsletterSource = 'footer' | 'article' | 'article_mid' | 'article_end' | 'item_page' | 'home' | 'popup' | 'newsletter_page' | 'noticias'

/**
 * Double opt-in sign-up: the row is created as `pending`. The RPC answers the same whether or
 * not the email already existed, so callers must never reveal that. The confirmation email is
 * NOT sent here: the F4.6 integration (Database Webhook -> Edge Function -> Brevo) sends it.
 */
export async function subscribeNewsletter(
  db: GuideClient,
  input: {
    email: string
    locale: Locale
    source: NewsletterSource
    page?: string
    /** D66: the separate, optional box. Never required, never inferred. */
    relatedConsent?: boolean
  },
): Promise<void> {
  // Consent is always true here: the RPC rejects false, and the form only submits when checked.
  const { error } = await db.rpc('subscribe_newsletter', {
    p_email: input.email,
    p_locale: input.locale,
    p_source: input.source,
    p_consent: true,
    p_page: input.page,
    p_related_consent: input.relatedConsent === true,
  })
  if (error) throw new ServiceError(error.message, error.code)
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export const isValidUnsubscribeToken = (token: unknown): token is string =>
  typeof token === 'string' && UUID_RE.test(token)

/** Neutral response: it succeeds whether or not the token matched a subscriber. */
export async function unsubscribeNewsletter(db: GuideClient, token: string): Promise<void> {
  const { error } = await db.rpc('unsubscribe_newsletter', { p_token: token })
  if (error) throw new ServiceError(error.message, error.code)
}

export type NewsletterPreference = 'active' | 'pending' | 'inactive'
export type RelatedPreference = 'granted' | 'pending' | 'none'
export interface ConsentPreferences {
  newsletter: NewsletterPreference
  related: RelatedPreference
  canGrantRelated: boolean
  locale: Locale
}
/** `set_related_consent` answer; `unconfirmed` = the email is not confirmed yet. */
export type RelatedConsentResult = 'ok' | 'invalid' | 'unconfirmed'

const NEWSLETTER_STATES: readonly string[] = ['active', 'pending', 'inactive']
const RELATED_STATES: readonly string[] = ['granted', 'pending', 'none']

/**
 * Reads the state of both consents by token. Null = the token matches nobody (invalid or expired).
 * A reply with an unexpected shape is a service error, not "invalid".
 */
export async function getConsentPreferences(
  db: GuideClient,
  token: string,
): Promise<ConsentPreferences | null> {
  const { data, error } = await db.rpc('get_consent_preferences', { p_token: token })
  if (error) throw new ServiceError(error.message, error.code)
  if (data === null) return null
  const row = data as Record<string, unknown>
  if (
    typeof row !== 'object' ||
    !NEWSLETTER_STATES.includes(String(row.newsletter)) ||
    !RELATED_STATES.includes(String(row.related_products))
  ) {
    throw new ServiceError('Unexpected get_consent_preferences reply')
  }
  return {
    newsletter: row.newsletter as NewsletterPreference,
    related: row.related_products as RelatedPreference,
    canGrantRelated: row.can_grant_related === true,
    locale: row.locale === 'en' ? 'en' : 'es',
  }
}

/** Grants or withdraws the related-products consent. Only call it from an explicit click (POST). */
export async function setRelatedConsent(
  db: GuideClient,
  token: string,
  granted: boolean,
): Promise<RelatedConsentResult> {
  const { data, error } = await db.rpc('set_related_consent', {
    p_token: token,
    p_granted: granted,
    p_channel: 'preferences',
  })
  if (error) throw new ServiceError(error.message, error.code)
  return data === 'ok' || data === 'unconfirmed' ? data : 'invalid'
}
