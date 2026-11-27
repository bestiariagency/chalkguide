<script setup lang="ts">
import { CalendarDays, Pencil, Star } from 'lucide-vue-next'

definePageMeta({ newsletterBlock: false })

const { t } = useI18n()
const route = useRoute()
useHead({ meta: [{ name: 'referrer', content: 'no-referrer' }] })

// F4.6: bad links now land on /newsletter/confirmar (it has the token and the resend button).
const localePath = useLocalePath()
const status = String(route.query.status)
if (status === 'expired' || status === 'invalid') {
  await navigateTo(localePath({ name: 'newsletter-confirm', query: { status } }), { replace: true })
}
const receives = [
  { icon: CalendarDays, key: 'newsletter.receiveItem1' },
  { icon: Pencil, key: 'newsletter.receiveItem2' },
  { icon: Star, key: 'newsletter.receiveItem3' },
]
</script>

<template>
  <PagePlaceholder
    display
    :title="t('newsletter.confirmed')"
    robots="noindex, nofollow"
  >
    <template #before-title>
      <UiSuccessCheck :size="64" class="mt-8" />
    </template>
    <div class="mt-4 grid items-start gap-10 lg:grid-cols-12">
      <div class="lg:col-span-7">
        <p role="status" class="max-w-read text-body-lg text-meta">{{ t('newsletter.confirmedBody') }}</p>
        <NewsletterRelatedOffer />
        <div class="mt-10 flex flex-col gap-3 sm:flex-row">
          <UiButton :to="{ name: 'climbing-gyms' }" arrow>{{ t('newsletter.confirmedGymsCta') }}</UiButton>
          <UiButton :to="{ name: 'blog' }" variant="ghost">{{ t('newsletter.confirmedNextCta') }}</UiButton>
        </div>
      </div>
      <aside class="slab bg-background p-6 lg:col-span-5">
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
