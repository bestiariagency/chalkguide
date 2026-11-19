import { subscribeNewsletter, type NewsletterSource } from '~/services/newsletter'

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

export type NewsletterStatus = 'idle' | 'loading' | 'success' | 'error'

/**
 * Newsletter form state and validation (validate on submit, not while typing).
 * Consent is unchecked by default and required. The success state means "check your inbox"
 * (double opt-in) and is identical whether or not the email was already subscribed.
 * Success is shared between every form on the page (footer, article cards) via `useState`.
 */
export function useNewsletterForm(source: NewsletterSource = 'footer') {
  const db = useGuideClient()
  const locale = useGuideLocale()
  const route = useRoute()
  const { track } = useTrack()

  const email = ref('')
  const consent = ref(false)
  /** D66 optional box: never required, never an error, unchecked by default. */
  const related = ref(false)
  const emailError = ref(false)
  /** The address has an @ but no dot in the domain: a more specific message. */
  const emailMissingDomain = ref(false)
  const consentError = ref(false)
  const subscribed = useState('newsletter:subscribed', () => false)
  /** Whether the shared success message must also name the related-products notices (O7). */
  const subscribedRelated = useState('newsletter:subscribed-related', () => false)
  const ownStatus = ref<NewsletterStatus>('idle')
  const status = computed<NewsletterStatus>({
    get: () => (subscribed.value ? 'success' : ownStatus.value),
    set: (value) => {
      ownStatus.value = value
      if (value === 'success') subscribed.value = true
    },
  })

  watch(consent, (checked) => checked && (consentError.value = false))

  /** Returns the first invalid field so the component can focus it. */
  async function submit(): Promise<'email' | 'consent' | null> {
    if (status.value === 'loading') return null
    emailError.value = !EMAIL_RE.test(email.value.trim())
    emailMissingDomain.value = emailError.value && /^[^@\s]+@[^@\s.]+$/.test(email.value.trim())
    consentError.value = !consent.value
    if (emailError.value) return 'email'
    if (consentError.value) return 'consent'

    status.value = 'loading'
    try {
      // The confirmation email is sent by the F4.6 integration (Brevo), not from here.
      await subscribeNewsletter(db, {
        email: email.value.trim(),
        locale: locale.value,
        source,
        page: route.path,
        relatedConsent: related.value,
      })
      subscribedRelated.value = related.value
      status.value = 'success'
      track('newsletter_submit') // no email, no free text
    } catch {
      status.value = 'error' // network/server error: the user can retry with the same data
    }
    return null
  }

  return { email, consent, related, subscribedRelated, emailError, emailMissingDomain, consentError, status, submit }
}
