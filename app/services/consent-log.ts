export interface ConsentLogInput {
  /** The id the consent library made: never an id of our own. */
  consentId: string
  action: 'first' | 'change'
  categories: string[]
  revision: number
  locale: 'es' | 'en'
}

export interface ConsentLogTarget {
  supabaseUrl: string
  /** Publishable key only: never the user's JWT. */
  publishableKey: string
}

/**
 * Writes one row of the consent proof through `guide.log_cookie_consent` (D87). Direct `fetch` with
 * `keepalive`: withdrawing a category reloads the page right after `onChange`, and a supabase-js
 * call (it awaits `getSession`, no keepalive) would be cancelled. Never blocks, never throws.
 */
export function logCookieConsent(target: ConsentLogTarget, input: ConsentLogInput): void {
  if (!target.supabaseUrl || !target.publishableKey) return
  try {
    void fetch(`${target.supabaseUrl}/rest/v1/rpc/log_cookie_consent`, {
      method: 'POST',
      keepalive: true,
      headers: {
        apikey: target.publishableKey,
        Authorization: `Bearer ${target.publishableKey}`,
        'Content-Type': 'application/json',
        'Content-Profile': 'guide',
      },
      body: JSON.stringify({
        p_consent_id: input.consentId,
        p_action: input.action,
        p_categories: input.categories,
        p_revision: input.revision,
        p_locale: input.locale,
      }),
    }).catch(() => {})
  } catch {
    // Swallowed on purpose.
  }
}
