<script setup lang="ts">
import type { NewsletterSource } from '~/services/newsletter'

/**
 * The orange field: the only full-bleed orange of the site and the product's goal. Title at
 * 72 px, the promise on the left and the sign-up slab on the right. One component for the
 * block that closes the pages (`#newsletter`, h2) and for /newsletter (h1, no anchor).
 */
const props = withDefaults(
  defineProps<{ source: NewsletterSource; heading?: 'h1' | 'h2'; anchor?: boolean; successCta?: boolean }>(),
  { heading: 'h2', anchor: false, successCta: false },
)
const { t } = useI18n()
// "Una carta al mes. Nada más." breaks after the first sentence.
const title = computed(() => t('newsletter.title').replace(/\.\s+/, '.\n'))
const titleId = props.anchor ? 'newsletter-title' : 'newsletter-page-title'
</script>

<template>
  <section
    :id="anchor ? 'newsletter' : undefined"
    class="field-orange dust scroll-mt-14"
    :aria-labelledby="titleId"
  >
    <div
      class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]"
      :class="!anchor && 'pt-14 md:pt-20 lg:pt-[88px]'"
    >
      <component :is="heading" :id="titleId" class="title-section-lg whitespace-pre-line">
        {{ title }}
      </component>
      <div class="mt-10 grid items-start gap-x-6 gap-y-8 lg:mt-14 lg:grid-cols-12">
        <div class="lg:col-span-5">
          <p class="max-w-[26ch] text-[20px] leading-[1.35] font-medium tracking-[-0.01em] md:text-[24px]">
            {{ t('newsletter.subtitle') }}
          </p>
          <p class="mt-4 text-body-sm text-meta">{{ t('newsletter.noSpam') }}</p>
        </div>
        <div class="lg:col-span-6 lg:col-start-7">
          <NewsletterSignup :source="source" :success-cta="successCta" />
        </div>
      </div>
    </div>
  </section>
</template>
