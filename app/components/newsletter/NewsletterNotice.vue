<script setup lang="ts">
import { CircleAlert, MailCheck } from 'lucide-vue-next'

/**
 * No-JS result of the sign-up (F4.6): the relay redirects to `<page>#newsletter-ok|error|limit` and the
 * matching paragraph shows with `:target`. Prerendered with the layout, hidden otherwise. With JS the form
 * reads the hash and clears it (useNewsletterForm), so this never competes with the form's own message.
 */
const { t } = useI18n()
// Border and background live on each message: the empty wrapper must leave no stray line.
const base = 'hidden items-start gap-2 border-b-[0.5px] border-line bg-background px-4 py-3 text-body-sm md:px-6'
</script>

<template>
  <div>
    <p id="newsletter-ok" role="status" :class="[base, 'target:flex']">
      <MailCheck :size="16" aria-hidden="true" class="mt-0.5 shrink-0 text-accent" />
      <span><strong class="font-medium">{{ t('newsletter.checkInbox') }}</strong> {{ t('newsletter.checkInboxBody') }}</span>
    </p>
    <p id="newsletter-error" role="alert" :class="[base, 'text-danger-text target:flex']">
      <CircleAlert :size="16" aria-hidden="true" class="mt-0.5 shrink-0" />{{ t('newsletter.error') }}
    </p>
    <p id="newsletter-limit" role="alert" :class="[base, 'text-danger-text target:flex']">
      <CircleAlert :size="16" aria-hidden="true" class="mt-0.5 shrink-0" />{{ t('newsletter.errorLimit') }}
    </p>
  </div>
</template>
