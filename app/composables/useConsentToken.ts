import { CONSENT_TOKEN_STORAGE_KEY, isConsentToken, tokenFromSearch, urlWithoutToken } from '~/utils/consent-token'

/**
 * Consent token of the email links (D66, O1/O7). Client only: call from `onMounted`.
 * Reads `?t=`, removes it from the address bar with `replaceState` and keeps it in memory (and in
 * sessionStorage so a reload still works). It is never rendered, put in a link or logged.
 * `forget()` clears both once the token is known to be dead.
 */
export function useConsentToken() {
  const token = ref<string | null>(null)

  function read(): string | null {
    const fromUrl = tokenFromSearch(window.location.search)
    if (fromUrl) {
      try {
        sessionStorage.setItem(CONSENT_TOKEN_STORAGE_KEY, fromUrl)
      } catch {
        // Private mode or blocked storage: in-memory only; a reload will need the link again.
      }
      window.history.replaceState(window.history.state, '', urlWithoutToken(window.location.href))
      token.value = fromUrl
      return fromUrl
    }
    try {
      const stored = sessionStorage.getItem(CONSENT_TOKEN_STORAGE_KEY)
      token.value = isConsentToken(stored) ? stored : null
    } catch {
      token.value = null
    }
    return token.value
  }

  function forget() {
    token.value = null
    try {
      sessionStorage.removeItem(CONSENT_TOKEN_STORAGE_KEY)
    } catch {
      // Nothing stored.
    }
  }

  return { token, read, forget }
}
