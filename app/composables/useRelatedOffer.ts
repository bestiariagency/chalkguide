import { type ConsentPreferences, getConsentPreferences, setRelatedConsent } from '~/services/newsletter'

export type RelatedOfferState = 'hidden' | 'offer' | 'saving' | 'done-yes' | 'done-no' | 'error' | 'already'

/**
 * Offer of the related-products consent on /newsletter/confirmada (D66, README §14.3). Shows
 * only with a valid token and `can_grant_related`. "Yes" is an explicit click (POST); "No" makes
 * no call: there is nothing to record. Without token or on any read error nothing is shown and
 * the page stays as the plain confirmation.
 */
export function useRelatedOffer() {
  const db = useGuideClient()
  const { token, read, forget } = useConsentToken()
  const state = ref<RelatedOfferState>('hidden')

  async function load() {
    if (!read()) return
    try {
      const prefs: ConsentPreferences | null = await getConsentPreferences(db, token.value!)
      if (!prefs) return forget()
      if (prefs.related === 'granted') state.value = 'already'
      else if (prefs.canGrantRelated) state.value = 'offer'
    } catch {
      // The confirmation stands on its own: no offer.
    }
  }

  async function accept() {
    if (!token.value || state.value === 'saving') return
    state.value = 'saving'
    try {
      const result = await setRelatedConsent(db, token.value, true)
      state.value = result === 'ok' ? 'done-yes' : 'error'
    } catch {
      state.value = 'error'
    }
  }

  const decline = () => {
    if (state.value !== 'saving') state.value = 'done-no'
  }

  onMounted(load)
  return { state, accept, decline }
}
