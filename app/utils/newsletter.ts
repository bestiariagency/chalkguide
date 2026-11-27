/** Values allowed by `subscribers_consent_source_check`. Shared by the form, the service and the Nitro relay. */
export const NEWSLETTER_SOURCES = [
  'footer',
  'article',
  'article_mid',
  'article_end',
  'item_page',
  'home',
  'popup',
  'newsletter_page',
  'noticias',
] as const

export type NewsletterSource = (typeof NEWSLETTER_SOURCES)[number]

/** 64 lowercase hex characters: the confirmation token that travels in the email link. */
export const CONFIRM_TOKEN_RE = /^[0-9a-f]{64}$/

/** Statuses of /newsletter/confirmar (`?status=`). `resent` and `error` are page-only states. */
export const CONFIRM_STATUSES = ['expired', 'invalid', 'resent', 'error'] as const
export type ConfirmStatus = (typeof CONFIRM_STATUSES)[number]
