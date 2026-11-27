<script setup lang="ts">
import { CircleAlert, MailCheck } from 'lucide-vue-next'
import { CONFIRM_STATUSES, CONFIRM_TOKEN_RE, type ConfirmStatus } from '~/utils/newsletter'

/**
 * F4.6 §15.3: the page the confirmation email links to (`?t=<64 hex>`). Opening it (GET) confirms nobody,
 * so link scanners cannot do it: the button POSTs to /api/newsletter/confirm. The token leaves the address
 * bar at once and only lives in the hidden field. No analytics (see isUntrackedPath), no-referrer, no-store.
 * Minimal layout on the existing result-page shell: pending a review by buho-pixel.
 */
definePageMeta({ newsletterBlock: false })

const { t, locale } = useI18n()
const route = useRoute()
const router = useRouter()

const queryValue = (key: string) => {
  const value = route.query[key]
  return typeof value === 'string' ? value : ''
}
const token = ref(CONFIRM_TOKEN_RE.test(queryValue('t')) ? queryValue('t') : '')
const status = computed<ConfirmStatus | null>(() => {
  const value = queryValue('status')
  return (CONFIRM_STATUSES as readonly string[]).includes(value) ? (value as ConfirmStatus) : null
})
/** What the page shows: the confirm button, or the result of the last attempt. */
const view = computed<'confirm' | ConfirmStatus>(() => status.value ?? (token.value ? 'confirm' : 'invalid'))
/** Double-submit guard (with JS): the button shows loading and further submits are ignored. */
const sending = ref(false)
function onSubmit(event: Event) {
  if (sending.value) event.preventDefault()
  sending.value = true
}
const canRetry = computed(() => !!token.value && (view.value === 'expired' || view.value === 'error'))

useHead({ meta: [{ name: 'referrer', content: 'no-referrer' }] })

onMounted(() => {
  if (!route.query.t) return
  // Through the router (not raw replaceState) so vue-router's `current` stays in sync (leona-lia O2).
  const { t: _token, ...rest } = route.query
  void router.replace({ query: rest })
})

const copy = computed(() => {
  switch (view.value) {
    case 'confirm':
      return { title: t('newsletter.confirmPageTitle'), body: t('newsletter.confirmPageBody') }
    case 'expired':
      return { title: t('newsletter.expiredTitle'), body: t('newsletter.expiredBody') }
    case 'resent':
      return { title: t('newsletter.resentTitle'), body: t('newsletter.resentBody') }
    case 'error':
      return { title: t('newsletter.confirmErrorTitle'), body: t('newsletter.confirmErrorBody') }
    default:
      return { title: t('newsletter.linkInvalidTitle'), body: t('newsletter.linkInvalidBody') }
  }
})
</script>

<template>
  <PagePlaceholder display :title="copy.title" robots="noindex, nofollow">
    <template #before-title>
      <MailCheck v-if="view === 'confirm' || view === 'resent'" :size="40" aria-hidden="true" class="mt-8 text-accent" />
      <CircleAlert v-else :size="40" aria-hidden="true" class="mt-8 text-danger-text" />
    </template>
    <div class="mt-4 grid items-start gap-10 lg:grid-cols-12">
      <div class="lg:col-span-7">
      <p :role="view === 'confirm' ? undefined : 'status'" class="max-w-read text-lead text-meta">{{ copy.body }}</p>

      <form v-if="view === 'confirm'" action="/api/newsletter/confirm" method="post" class="mt-8" @submit="onSubmit">
        <input type="hidden" name="t" :value="token" />
        <input type="hidden" name="locale" :value="locale" />
        <UiButton type="submit" variant="ink" arrow :loading="sending">{{ t('newsletter.confirmButton') }}</UiButton>
      </form>

      <form v-else-if="canRetry" :action="view === 'expired' ? '/api/newsletter/resend' : '/api/newsletter/confirm'" method="post" class="mt-8" @submit="onSubmit">
        <input type="hidden" name="t" :value="token" />
        <input type="hidden" name="locale" :value="locale" />
        <UiButton type="submit" variant="ink" :loading="sending">
          {{ view === 'expired' ? t('newsletter.resendButton') : t('common.retry') }}
        </UiButton>
      </form>

      <UiButton v-else-if="view !== 'resent'" :to="{ name: 'newsletter' }" variant="ghost" class="mt-8 min-h-11">
        {{ t('newsletter.resubscribe') }}
      </UiButton>
      </div>
    </div>
  </PagePlaceholder>
</template>
