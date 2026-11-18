<script setup lang="ts">
/**
 * /newsletter (D44): the orange field with the sign-up (h1), then what arrives and how it works.
 * It carries its own field, so the layout block is off (never two forms). No past letters,
 * figures or testimonials: only existing copy.
 */
definePageMeta({ newsletterBlock: false })

const { t } = useI18n()
const { linkFor } = usePageLinks()
const seoText = useSeoText()
usePageSeo(() => ({ title: seoText('newsletterTitle'), description: seoText('newsletterDescription') }))
</script>

<template>
  <div>
    <NewsletterField source="newsletter_page" heading="h1" success-cta />

    <section class="bg-background" :aria-label="t('newsletter.howTitle')">
      <div
        class="mx-auto grid max-w-page gap-x-6 gap-y-14 px-4 py-16 md:px-6 md:py-24 lg:grid-cols-12"
      >
        <div class="lg:col-span-5">
          <h2 class="text-title-3 font-medium">{{ t('newsletter.receiveTitle') }}</h2>
          <ul class="mt-6 border-t border-foreground text-lead">
            <li v-for="n in 3" :key="n" class="border-b border-line-strong py-4">
              {{ t(`newsletter.receiveItem${n}`) }}
            </li>
          </ul>
          <p class="mt-6 text-body-sm text-meta">
            {{ t('footer.promise') }}
            <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('transparency.learnMore') }}</UiTextLink>.
          </p>
        </div>
        <div class="lg:col-span-6 lg:col-start-7">
          <h2 class="text-title-3 font-medium">{{ t('newsletter.howTitle') }}</h2>
          <ol class="mt-6 border-t border-foreground text-lead">
            <li v-for="n in 3" :key="n" class="flex gap-4 border-b border-line-strong py-4">
              <span class="w-7 shrink-0 pt-1 font-mono text-body-sm text-accent">0{{ n }}</span>
              <span>{{ t(`newsletter.howStep${n}`) }}</span>
            </li>
          </ol>
          <p class="mt-6 origin-left -rotate-1 font-hand text-[28px] leading-[1.15]">
            {{ t('newsletter.signature') }}
            <UiTextLink :to="{ name: 'about' }" v-bind="linkFor('about')">{{ t('blog.author.name') }}</UiTextLink>
          </p>
        </div>
      </div>
    </section>
  </div>
</template>
