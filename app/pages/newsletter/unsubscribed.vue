<script setup lang="ts">
definePageMeta({ newsletterBlock: false })

const { t } = useI18n()
const { status, retry } = useNewsletterUnsubscribe()

// Never claim the unsubscription before it is done (SSR renders "loading").
const title = computed(() => {
  if (status.value === 'success') return t('newsletter.unsubscribed')
  if (status.value === 'loading') return t('newsletter.sending')
  if (status.value === 'error') return t('states.errorTitle')
  return t('newsletter.linkInvalidTitle')
})
</script>

<template>
  <PagePlaceholder display :title="title" robots="noindex, nofollow">
    <div role="status" aria-live="polite" class="mt-4 max-w-measure">
      <p v-if="status === 'loading'" class="sr-only">{{ t('newsletter.sending') }}</p>
      <p v-else-if="status === 'success'" class="text-lead text-meta">
        {{ t('newsletter.unsubscribedBody') }}
      </p>
      <p v-else-if="status === 'invalid'" class="text-lead text-meta">
        {{ t('newsletter.unsubscribeInvalidBody') }}
      </p>
      <template v-else-if="status === 'error'">
        <p class="text-lead text-meta">{{ t('newsletter.unsubscribeErrorBody') }}</p>
        <UiButton class="mt-6 min-h-11" variant="ghost" @click="retry">{{ t('common.retry') }}</UiButton>
      </template>
      <div v-if="status === 'success'" class="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-6">
        <UiButton to="/" variant="ghost" class="min-h-11 self-start">{{ t('states.notFoundHome') }}</UiButton>
        <UiTextLink :to="{ name: 'newsletter' }" class="self-start sm:self-center">
          {{ t('newsletter.resubscribe') }}
        </UiTextLink>
      </div>
    </div>
  </PagePlaceholder>
</template>
