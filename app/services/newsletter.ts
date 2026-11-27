import type { Locale } from '~/types/domain'
import type { NewsletterSource } from '~/utils/newsletter'
import { type GuideClient, ServiceError } from './client'

export type { NewsletterSource }

/** Failure kinds of `POST /api/newsletter` (`ServiceError.code`). */
export type SubscribeFailure = 'invalid' | 'captcha' | 'limit' | 'server'

/**
 * Double opt-in sign-up through the server relay (F4.6): Nitro -> Edge Function (ALTCHA, rate limits) ->
 * `svc_subscribe`. The reply is neutral (the same for new, existing or active emails), so callers must
 * never reveal whether the email existed. The confirmation email is sent by the backend worker.
 */
export async function subscribeNewsletter(input: {
  email: string
  locale: Locale
  source: NewsletterSource
  consent: boolean
  page?: string
  /** D66: the separate, optional box. Never required, never inferred. */
  relatedConsent?: boolean
  /** ALTCHA solution; without it the relay uses the stricter no-JS limits. */
  altcha?: string | null
  /** Honeypot value (must stay empty for people). */
  website?: string
  /** Session access token, only so a signed-in user's account is linked when the email matches (H3). */
  accessToken?: string | null
}): Promise<void> {
  try {
    await $fetch('/api/newsletter', {
      method: 'POST',
      headers: input.accessToken ? { authorization: `Bearer ${input.accessToken}` } : undefined,
      body: {
        email: input.email,
        locale: input.locale,
        source: input.source,
        consent: input.consent,
        page: input.page,
        related_consent: input.relatedConsent === true,
        website: input.website ?? '',
        altcha: input.altcha ?? '',
      },
    })
  } catch (e) {
    const status = (e as { statusCode?: number; status?: number }).statusCode ?? (e as { status?: number }).status
    const kind = (e as { data?: { error?: string } }).data?.error
    const code: SubscribeFailure =
      status === 429 ? 'limit' : status === 400 ? (kind === 'captcha' ? 'captcha' : 'invalid') : 'server'
    throw new ServiceError('newsletter sign-up failed', code)
  }
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
