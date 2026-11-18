<script setup lang="ts">
import { CircleAlert, CircleCheck } from 'lucide-vue-next'

/**
 * Offer of the related-products consent after the double opt-in (D66, README §14.3). "Yes" and
 * "No, thanks" are the same ghost button, same width, no colour order: declining must be as easy
 * as accepting. The text shown is the one stored in the DB (the one that gets recorded); without
 * it the offer is not shown at all.
 */
const { t } = useI18n()
const { data: settings } = await useSiteSettings()
const { state, accept, decline } = useRelatedOffer()
const text = computed(() => settings.value?.relatedConsentText ?? null)
const doneBox = ref<HTMLElement | null>(null)
watch(state, (value) => (value === 'done-yes' || value === 'done-no') && nextTick(() => doneBox.value?.focus()))
</script>

<template>
  <section
    v-if="text && (state === 'offer' || state === 'saving' || state === 'error')"
    class="slab mt-10 bg-board p-5 md:p-7"
    aria-labelledby="related-offer-title"
  >
    <h2 id="related-offer-title" class="text-[20px] leading-tight font-medium tracking-[-0.01em] md:text-[22px]">
      {{ t('consent.offer.title') }}
    </h2>
    <p class="mt-2 text-body-sm text-meta">{{ t('consent.offer.intro') }}</p>
    <fieldset class="mt-5 border-t border-line pt-5">
      <legend class="sr-only">{{ t('consent.offer.legend') }}</legend>
      <p id="related-offer-text" class="max-w-[60ch] text-[17px] leading-normal" :lang="settings?.relatedConsentLocale">
        «{{ text }}»
      </p>
      <NewsletterConsentInfo />
      <div class="mt-4 grid max-w-[440px] gap-3 sm:grid-cols-2" role="group" aria-describedby="related-offer-text">
        <UiButton variant="ghost" class="w-full" :loading="state === 'saving'" @click="accept">
          {{ t('consent.offer.yes') }}
        </UiButton>
        <UiButton variant="ghost" class="w-full" :disabled="state === 'saving'" @click="decline">
          {{ t('consent.offer.no') }}
        </UiButton>
      </div>
      <p v-if="state === 'saving'" class="sr-only" role="status">{{ t('consent.offer.saving') }}</p>
      <p v-if="state === 'error'" role="alert" class="mt-3 flex items-start gap-1.5 text-body-sm text-danger-text">
        <CircleAlert :size="16" aria-hidden="true" class="mt-0.5 shrink-0" />{{ t('consent.offer.error') }}
      </p>
    </fieldset>
  </section>
  <section
    v-else-if="state === 'done-yes' || state === 'done-no'"
    ref="doneBox"
    role="status"
    tabindex="-1"
    class="slab mt-10 bg-board p-5 focus-visible:shadow-none md:p-7"
  >
    <h2 class="text-[20px] leading-tight font-medium tracking-[-0.01em] md:text-[22px]">
      {{ t(state === 'done-yes' ? 'consent.offer.yesTitle' : 'consent.offer.noTitle') }}
    </h2>
    <p class="mt-2 max-w-[60ch] text-body-sm text-meta">
      {{ t(state === 'done-yes' ? 'consent.offer.yesBody' : 'consent.offer.noBody') }}
    </p>
  </section>
  <p v-else-if="state === 'already'" class="mt-6 flex max-w-[60ch] items-start gap-2 text-body-sm text-meta">
    <span class="mt-px inline-flex shrink-0 items-center gap-1.5 rounded-xs bg-success-muted px-2 py-1 text-note font-medium text-success-text">
      <CircleCheck :size="14" aria-hidden="true" />{{ t('consent.offer.active') }}
    </span>
    <span>{{ t('consent.offer.alreadyBody') }}</span>
  </p>
</template>
