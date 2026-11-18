<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'
import type { NewsletterSource } from '~/services/newsletter'

/**
 * Newsletter sign-up on a paper slab (inside the orange field): the one form of the block and of
 * /newsletter. Consent text and version come from guide.site_settings (never from i18n); the
 * checkbox starts unchecked. The second, optional checkbox (D66, related-products consent) is
 * independent of the first, also unchecked, never an error, and hidden if the DB has no text for it. Validates on submit, focus goes to the first error; success keeps the
 * slab's height and is shared with the other forms of the page.
 */
const props = defineProps<{ source: NewsletterSource; successCta?: boolean }>()
const { t } = useI18n()
const { linkFor } = usePageLinks()
const { data: settings } = await useSiteSettings()
const consentText = computed(() => settings.value?.newsletterConsentText ?? null)
const { email, consent, related, subscribedRelated, emailError, emailMissingDomain, consentError, status, submit } =
  useNewsletterForm(props.source)
const relatedText = computed(() => settings.value?.relatedConsentText ?? null)

const box = ref<HTMLElement | null>(null)
const minHeight = ref<string | undefined>()
const emailField = ref<{ focus: () => void } | null>(null)
const consentField = ref<{ focus: () => void } | null>(null)
const successBox = ref<HTMLElement | null>(null)

const emailMessage = computed(() => {
  if (!emailError.value) return undefined
  return t(emailMissingDomain.value ? 'newsletter.emailMissingDomain' : 'newsletter.emailInvalid')
})

async function onSubmit() {
  const before = box.value?.offsetHeight
  const invalid = await submit()
  // The slab keeps its height only when the form is replaced by the success message.
  minHeight.value = status.value === 'success' && before ? `${before}px` : undefined
  if (invalid === 'email') emailField.value?.focus()
  else if (invalid === 'consent') consentField.value?.focus()
  else if (status.value === 'success') nextTick(() => successBox.value?.focus())
}
</script>

<template>
  <div
    ref="box"
    class="on-paper slab-dark bg-paper p-5 md:p-7"
    :style="minHeight ? { minHeight } : undefined"
  >
    <div v-if="status === 'success'" ref="successBox" role="status" tabindex="-1" class="py-3 focus-visible:shadow-none">
      <UiSuccessCheck />
      <p class="mt-3 text-xl font-medium">{{ t('newsletter.checkInbox') }}</p>
      <p class="mt-1 text-meta">{{ t('newsletter.checkInboxBody') }}</p>
      <!-- O7: names both purposes without revealing whether the email already existed. -->
      <p v-if="subscribedRelated" class="mt-3 text-body-sm text-meta">{{ t('newsletter.relatedSuccess') }}</p>
      <UiButton v-if="successCta" :to="{ name: 'blog' }" variant="ghost" arrow class="mt-5">
        {{ t('newsletter.successBlogCta') }}
      </UiButton>
    </div>
    <form
      v-else
      method="post"
      novalidate
      class="grid gap-3 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-start lg:gap-x-3"
      :aria-label="t('newsletter.formLabel')"
      @submit.prevent="onSubmit"
    >
      <!-- DOM order = tab order: email, checkbox, related checkbox + more info, button; from lg the grid puts the button in row 1. -->
      <UiInput
        ref="emailField"
        v-model="email"
        type="email"
        name="email"
        autocomplete="email"
        class="min-w-0 lg:col-start-1 lg:row-start-1 [&_input]:min-h-13 [&_input]:bg-board [&_label]:text-body-sm [&_label]:font-medium [&_label]:text-foreground"
        :label="t('newsletter.emailLabel')"
        :placeholder="t('newsletter.emailPlaceholder')"
        :error="emailMessage"
      />
      <UiCheckbox
        v-if="consentText"
        ref="consentField"
        v-model="consent"
        name="consent"
        class="lg:col-span-2 lg:row-start-2"
        :error="consentError ? t('newsletter.consentRequired') : undefined"
      >
        <span :lang="settings?.newsletterConsentLocale">{{ consentText }}</span>
        {{ ' ' }}
        <UiTextLink :to="{ name: 'privacy' }" v-bind="linkFor('privacy')">{{ t('newsletter.privacyLink') }}</UiTextLink>.
      </UiCheckbox>
      <UiCheckbox
        v-if="relatedText"
        v-model="related"
        name="related_consent"
        class="lg:col-span-2 lg:row-start-3"
      >
        <span :lang="settings?.relatedConsentLocale">{{ relatedText }}</span>
        {{ ' ' }}
        <span class="text-meta">{{ t('newsletter.relatedOptional') }}</span>
        <template #after><NewsletterConsentInfo /></template>
      </UiCheckbox>
      <UiButton
        type="submit"
        variant="ink"
        arrow
        :loading="status === 'loading'"
        :disabled="!consentText"
        class="w-full lg:col-start-2 lg:row-start-1 lg:mt-[30px] lg:w-auto"
      >
        {{ t('newsletter.cta') }}
      </UiButton>
      <p
        v-if="status === 'error' || !consentText"
        role="alert"
        class="flex items-start gap-1.5 text-body-sm text-danger-text lg:col-span-2 lg:row-start-4"
      >
        <CircleAlert :size="16" aria-hidden="true" class="mt-0.5" />{{ t('newsletter.error') }}
      </p>
    </form>
  </div>
</template>
