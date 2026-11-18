import {
  type ConsentPreferences,
  getConsentPreferences,
  setRelatedConsent,
  unsubscribeNewsletter,
} from '~/services/newsletter'

export type PreferencesStatus = 'loading' | 'ready' | 'invalid' | 'error'
export type PreferenceRow = 'newsletter' | 'related'
/** i18n key suffix under `consent.prefs.flash`, shown inside the row that changed. */
export interface PreferenceFlash {
  row: PreferenceRow
  kind: 'ok' | 'error'
  key: 'newsletterOff' | 'relatedOff' | 'relatedOn' | 'unconfirmed' | 'failed'
}

/**
 * State of /newsletter/preferencias (D66). The token comes from the email link, is read once
 * after mount and never exposed. Nothing is written on load: every change is an explicit click
 * that calls a POST RPC (O1). After each change the state is read again so the page always
 * shows what the server holds.
 */
export function useConsentPreferences() {
  const db = useGuideClient()
  const { token, read, forget } = useConsentToken()
  const status = ref<PreferencesStatus>('loading')
  const prefs = ref<ConsentPreferences | null>(null)
  const busy = ref<'newsletter-off' | 'related-on' | 'related-off' | null>(null)
  const flash = ref<PreferenceFlash | null>(null)

  async function load() {
    status.value = 'loading'
    if (!token.value && !read()) {
      status.value = 'invalid'
      return
    }
    try {
      const result = await getConsentPreferences(db, token.value!)
      if (!result) {
        forget()
        status.value = 'invalid'
        return
      }
      prefs.value = result
      status.value = 'ready'
    } catch {
      status.value = 'error'
    }
  }

  /** Runs one change; on success reads the state again. The row's own message tells the outcome. */
  async function run(
    action: NonNullable<typeof busy.value>,
    row: PreferenceRow,
    okKey: PreferenceFlash['key'],
    call: (value: string) => Promise<'ok' | 'invalid' | 'unconfirmed'>,
  ) {
    if (busy.value || !token.value) return
    busy.value = action
    flash.value = null
    try {
      const result = await call(token.value)
      if (result === 'invalid') {
        forget()
        status.value = 'invalid'
        return
      }
      flash.value = { row, kind: 'ok', key: result === 'ok' ? okKey : 'unconfirmed' }
      const fresh = await getConsentPreferences(db, token.value)
      if (fresh) prefs.value = fresh
    } catch {
      flash.value = { row, kind: 'error', key: 'failed' }
    } finally {
      busy.value = null
    }
  }

  const grantRelated = () =>
    run('related-on', 'related', 'relatedOn', (t) => setRelatedConsent(db, t, true))
  const withdrawRelated = () =>
    run('related-off', 'related', 'relatedOff', (t) => setRelatedConsent(db, t, false))
  /** Newsletter unsubscribe is neutral: it answers the same for any token, so "ok" is all we know. */
  const leaveNewsletter = () =>
    run('newsletter-off', 'newsletter', 'newsletterOff', async (t) => {
      await unsubscribeNewsletter(db, t)
      return 'ok'
    })

  onMounted(load)
  return { status, prefs, busy, flash, load, grantRelated, withdrawRelated, leaveNewsletter }
}
