<script setup lang="ts">
import { CalendarDays, CircleAlert, Pencil, Star } from 'lucide-vue-next'

definePageMeta({ newsletterBlock: false })

const { t } = useI18n()
const route = useRoute()
useHead({ meta: [{ name: 'referrer', content: 'no-referrer' }] })

// There is no public confirm RPC: the double opt-in is confirmed by the F4.6 integration
// (Brevo), which then redirects here. It signals a bad link with `?status=expired|invalid`.
const failure = computed(() => {
  const status = String(route.query.status)
  return status === 'expired' || status === 'invalid' ? status : null
})
const receives = [
  { icon: CalendarDays, key: 'newsletter.receiveItem1' },
  { icon: Pencil, key: 'newsletter.receiveItem2' },
  { icon: Star, key: 'newsletter.receiveItem3' },
]
</script>

<template>
  <PagePlaceholder
    display
    :title="failure ? t('newsletter.linkInvalidTitle') : t('newsletter.confirmed')"
    robots="noindex, nofollow"
  >
    <template #before-title>
      <CircleAlert v-if="failure" :size="40" aria-hidden="true" class="mt-8 text-danger-text" />
      <UiSuccessCheck v-else :size="64" class="mt-8" />
    </template>
    <div class="mt-4 grid items-start gap-10 lg:grid-cols-12">
      <div class="lg:col-span-7">
        <template v-if="failure">
          <p role="status" class="max-w-read text-lead text-meta">
            {{ failure === 'expired' ? t('newsletter.linkExpiredBody') : t('newsletter.linkInvalidBody') }}
          </p>
          <UiButton :to="{ name: 'newsletter' }" variant="ghost" class="mt-8 min-h-11">
            {{ t('newsletter.resubscribe') }}
          </UiButton>
        </template>
        <template v-else>
          <p role="status" class="max-w-read text-body-lg text-meta">{{ t('newsletter.confirmedBody') }}</p>
          <NewsletterRelatedOffer />
          <div class="mt-10 flex flex-col gap-3 sm:flex-row">
            <UiButton :to="{ name: 'climbing-gyms' }" arrow>{{ t('newsletter.confirmedGymsCta') }}</UiButton>
            <UiButton :to="{ name: 'blog' }" variant="ghost">{{ t('newsletter.confirmedNextCta') }}</UiButton>
          </div>
        </template>
      </div>
      <aside v-if="!failure" class="slab bg-background p-6 lg:col-span-5">
        <p class="font-hand text-[28px] leading-tight text-accent -rotate-1">{{ t('newsletter.receiveTitle') }}</p>
        <ul class="mt-4 space-y-3 text-body-sm">
          <li v-for="item in receives" :key="item.key" class="flex gap-3">
            <component :is="item.icon" :size="20" aria-hidden="true" class="text-meta" />
            <span>{{ t(item.key) }}</span>
          </li>
        </ul>
        <p class="mt-5 text-caption text-meta">{{ t('newsletter.noSpam') }}</p>
      </aside>
    </div>
  </PagePlaceholder>
</template>
