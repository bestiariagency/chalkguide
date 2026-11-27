import { subscribeNewsletter, type NewsletterSource, type SubscribeFailure } from '~/services/newsletter'

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/

export type NewsletterStatus = 'idle' | 'loading' | 'success' | 'error'

/**
 * Newsletter form state and validation (validate on submit, not while typing).
 * Consent is unchecked by default and required. The success state means "check your inbox"
 * (double opt-in) and is identical whether or not the email was already subscribed.
 * Success is shared between every form on the page (footer, article cards) via `useState`.
 */
export function useNewsletterForm(source: NewsletterSource = 'footer') {
  const locale = useGuideLocale()
  const route = useRoute()
  const { track } = useTrack()
  const session = useSupabaseSession()

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
  /** Why the last attempt failed; picks the message. `server` also covers network errors. */
  const failure = ref<SubscribeFailure>('server')
  /** Honeypot (F4.6 B7): must stay empty for people. */
  const website = ref('')
  const ownStatus = ref<NewsletterStatus>('idle')
  const status = computed<NewsletterStatus>({
    get: () => (subscribed.value ? 'success' : ownStatus.value),
    set: (value) => {
      ownStatus.value = value
      if (value === 'success') subscribed.value = true
    },
  })

  watch(consent, (checked) => checked && (consentError.value = false))

  // No-JS fallback (F4.6 §6): the server redirects back with #newsletter-ok|error|limit. NewsletterNotice shows it
  // with :target; with JS we take it into the form state and clear the hash so the banner goes away.
  onMounted(() => {
    const flag = /^#newsletter-(ok|error|limit)$/.exec(window.location.hash)?.[1]
    if (!flag) return
    if (flag === 'ok') status.value = 'success'
    else {
      failure.value = flag === 'limit' ? 'limit' : 'server'
      status.value = 'error'
    }
    window.history.replaceState(window.history.state, '', window.location.pathname + window.location.search)
  })

  /**
   * Returns the first invalid field so the component can focus it. `solveCaptcha` yields the ALTCHA payload
   * (null if the widget is missing: the relay then applies the stricter no-JS limits).
   */
  async function submit(solveCaptcha: () => Promise<string | null>): Promise<'email' | 'consent' | null> {
    if (status.value === 'loading') return null
    emailError.value = !EMAIL_RE.test(email.value.trim())
    emailMissingDomain.value = emailError.value && /^[^@\s]+@[^@\s.]+$/.test(email.value.trim())
    consentError.value = !consent.value
    if (emailError.value) return 'email'
    if (consentError.value) return 'consent'

    status.value = 'loading'
    try {
      // The confirmation email is sent by the backend worker (F4.6), not from here.
      await subscribeNewsletter({
        email: email.value.trim(),
        locale: locale.value,
        source,
        consent: consent.value,
        page: route.path,
        relatedConsent: related.value,
        altcha: await solveCaptcha(),
        website: website.value,
        accessToken: session.value?.access_token ?? null,
      })
      subscribedRelated.value = related.value
      status.value = 'success'
      track('newsletter_submit') // no email, no free text
    } catch (e) {
      failure.value = (e as { code?: SubscribeFailure }).code ?? 'server'
      status.value = 'error' // the user can retry with the same data
    }
    return null
  }

  return { email, consent, related, website, failure, subscribedRelated, emailError, emailMissingDomain, consentError, status, submit }
}
